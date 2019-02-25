" Detect if file in current buffer is part of a wiki we know about.
" Called from after/ftdetect/markdown.vim after a markdown file is detected.
function! wikidown#detect_wiki()
    let buf = expand('%:p')

    " First check if the file is part of the active wiki.
    let found_in_active_wiki = exists('b:active_wiki') &&
                \ s:file_in_wiki(b:active_wiki, buf)

    if found_in_active_wiki| return | endif

    " Next check if we need to switch to a new wiki.
    let [found_wiki, name] = s:get_wiki_from_filepath(g:wikidown_wikis, buf)
    if found_wiki | call s:activate_wiki(g:wikidown_wikis[name]) | endif
endfunction

function! wikidown#goto_wiki_index(wiki_name)
    if !has_key(g:wikidown_wikis, a:wiki_name) | return | endif

    let indexfile = expand(g:wikidown_wikis[a:wiki_name].path . '/' .
                \ g:wikidown_wikis[a:wiki_name].index_file)
    let prev_link = [indexfile, [0, 0, 1, 0]]
    if s:edit_file('edit', indexfile)
        let b:active_prev_link = prev_link
    endif
endfunction

function! wikidown#nextlink()
    call search(g:wikidown_page_link, 's')
endfunction

function! wikidown#prevlink()
    call search(g:wikidown_page_link, 'sb')
endfunction

function! wikidown#follow_link(split)
    if !exists('b:active_wiki') | return | endif

    let cmds = {'split': ':split', 'vsplit': ':vsplit', 'tabnew': ':tabnew'}
    let cmd = get(cmds, a:split, ':e ')

    let web_hit = matchstr(s:cursor_hit(g:wikidown_web_link), g:wikidown_link)
    let page_hit = matchstr(s:cursor_hit(g:wikidown_page_link), g:wikidown_link)

    if web_hit !=? ''
        call s:system_open_link(web_hit)
    elseif page_hit !=? ''
        let prev_link = [expand('%:p'), getpos('.')]
        if s:open_page(b:active_wiki, b:active_subdir, cmd, page_hit)
            let b:active_prev_link = prev_link
        endif
    endif
    return web_hit !=# '' || page_hit !=# ''
endfunction

function! wikidown#generate_link()
    if !exists('b:active_wiki') | return | endif

    let text = s:get_single_line_selection()
    if text ==# '' | return | endif

    let file = s:sanitize_filename(text)
    call wikidown#dbg('sanitized filename in generate_link: ' . file)
    let line = getline('.')
    let replacement = substitute(line, text, '['.text.']('.file.')', '')
    call setline('.', replacement)
endfunction

function! wikidown#delete_page()
    if !exists('b:active_wiki') | return | endif

    if s:input('Delete ['.expand('%').'] y/[n]? ', '') !=? 'y' | return | endif

    let fname = expand('%:p')

    call wikidown#dbg('Saving ' . fname)
    execute 'silent :w'
    try
        call wikidown#dbg('Deleting ' . fname)
        let a = delete(fname)
    catch
        echom '[WikiDown] Unable to delete ' . expand('%:t:r') .
                    \ ', caught: ' . v:exception
        return
    endtry

    call wikidown#go_back_link()
    execute 'bdelete! ' . escape(fname, ' ')

    if expand('%:p') !=? ''| redraw! | endif
endfunction

function! wikidown#create_or_follow_link(split)
    if !exists('b:active_wiki') | return | endif

    if !wikidown#follow_link(a:split) | call wikidown#generate_link() | endif
endfunction

function! wikidown#go_back_link()
    if !exists('b:active_wiki') | return | endif

    if !exists('b:active_prev_link')
        let index_file = b:active_wiki.path . '/' . b:active_wiki.index_file
        let prev_link = [expand(index_file), [0, 0, 1, 0]]
        b:active_prev_link = prev_link
    endif

    let previous_is_current_buf = b:active_prev_link[0] ==# expand('%:p')
    if previous_is_current_buf | return | endif

    let goto_pos = b:active_prev_link[1]
    execute ':e ' . substitute(b:active_prev_link[0], '\s', '\\\0', 'g')
    call setpos('.', goto_pos)
endfunction

function! wikidown#edit_log()
    if !exists('b:active_wiki') | return | endif

    let fname = s:sanitize_filename(strftime('%Y_%m_%d'))
    let full_path = expand(b:active_wiki.path . '/' .
                \ b:active_wiki.log_subdir . '/' . fname)

    let prev_link = [expand('%:p'), getpos('.')]
    let new_file = filereadable(full_path) == 0
    if s:edit_file('edit', full_path)
        let b:active_prev_link = prev_link
        if new_file
            let index_md = expand(fnamemodify(full_path, ':p:h') . '/index.md')
            let timestamp = strftime('%d %B %Y')
            let new_entry_text = '"* [' . timestamp . '](' . fname . ')"'

            let cmd = 'echo ' . new_entry_text . ' >> ' . index_md
            call system(cmd)
        endif
    endif
endfunction

function! wikidown#publish_to_html()
    if !exists('b:active_wiki') | return | endif

    call s:save_buffer()

    let path_html = expand(b:active_wiki.path_html)
    call s:mkdir(path_html)

    echomsg '[WikiDown] Removing html files without corresponding md source'
    call s:delete_unsourced_html_files(b:active_wiki, path_html)

    echomsg '[WikiDown] Converting markdown to html files ...'
    let setting_more = &more
    setlocal nomore

    let mdfiles = split(glob(b:active_wiki.path . '**/*.md'), '\n')
    echomsg '[WikiDown] ' . len(mdfiles) . ' files to convert'

    for mdfile in mdfiles
        let mdfile = fnamemodify(mdfile, ':p')
        let subdir = s:subdir(b:active_wiki.path, mdfile)

        if s:is_html_up_to_date(b:active_wiki, subdir, mdfile)
            echomsg '[WikiDown] Skipping ' . mdfile
        else
            echomsg '[WikiDown] Processing ' . mdfile
            call s:md2html(b:active_wiki, subdir, path_html, mdfile)
        endif
    endfor

    echomsg '[WikiDown] HTML exported to ' . path_html

    let &more = setting_more
endfunction

function! wikidown#complete_wiki_conf(wiki)
    let a:wiki.path = get(a:wiki, 'path', '~/projects/wiki')
    let a:wiki.index_file = get(a:wiki, 'index_file', 'index.md')
    let a:wiki.path_html = get(a:wiki, 'path_html', '~/projects/wiki_html')
    let a:wiki.log_subdir = get(a:wiki, 'log_subdir', 'log')
    let a:wiki.ignore_html = get(a:wiki, 'ignore_html', '')
    let a:wiki.author = get(a:wiki, 'author', 'anonymous')
    let a:wiki.css = get(a:wiki, 'css', '')
endfunction

function! wikidown#dbg(msg)
    if exists('g:wikidown_debug') && g:wikidown_debug >= 1
        echomsg '[WikiDown] DBG: ' . a:msg
    endif
endfunction

function! wikidown#info(msg)
    if exists('g:wikidown_debug') && g:wikidown_debug >= 2
        echomsg '[WikiDown] INFO: ' . a:msg
    endif
endfunction


function! s:activate_wiki(wiki)
    let b:active_wiki = a:wiki
    let b:active_subdir = s:subdir(b:active_wiki.path, expand('%:p'))
endfunction

function! s:input(prompt)
    call inputsave()
    let result = input(a:prompt)
    echomsg ' '
    call inputrestore()
    return result
endfunction

function! s:mkdir(path)
    let path = substitute(expand(a:path), '[/]\+$', '', '')

    if isdirectory(path) | return 1 | endif

    if !exists('*mkdir')
        echom ''
        echom 'Unable to create non-existent directory: ' .  path .
                    \ ', vim compiled without mkdir support'
        return 0
    endif

    if s:input('Make new directory: ' . path . ' y/[n]o? ') !=? 'y'
        return 0
    endif
    call wikidown#info('Making directory: ' . path)
    return mkdir(path, 'p')
endfunction

function! s:edit_file(command, filename)
    let fname = fnameescape(a:filename)
    let dir = fnamemodify(a:filename, ':p:h')

    if !s:mkdir(dir)
        echom 'Unable to edit file in non-existent directory: ' . dir
        return 0
    endif

    let cmd = a:command . ' ' . fname
    call wikidown#info('Running: ' . cmd)
    execute cmd
    return 1
endfunction

function! s:subdir(wiki_path, file_full_path)
    " Get the 'delta' subdir between the given file and wiki.
    "   e.g. /home/adam/wiki/ and /home/adam/wiki/log/somedate.md = log/
    let wiki_path = expand(fnamemodify(a:wiki_path, ':p'))
    let path = expand(fnamemodify(a:file_full_path, ':p:h') . '/')

    let is_child_path = wiki_path ==# matchstr(path, wiki_path)
    if !is_child_path
        echom matchstr(path, wiki_path)
        echom '[WikiDown] ERR: bad subdir, given ' . wiki_path . ', ' . path
        return ''
    endif

    let delta_subdir = substitute(path, '^' . fnameescape(wiki_path), '', '')
    return substitute(expand(delta_subdir), '[/]\+$', '', '')
endfunction

function! s:file_in_wiki(wiki, test_path)
    if type(a:wiki) != type({}) | return 0 | endif

    let wiki_path = get(a:wiki, 'path', '')
    if wiki_path ==# ''| return 0 | endif

    let wiki_path = expand(wiki_path)
    return wiki_path ==# matchstr(a:test_path, wiki_path)
endfunction

function! s:get_wiki_from_filepath(wiki_lookup, test_path)
    let test_path = expand(a:test_path)
    for key in keys(a:wiki_lookup)
        if s:file_in_wiki(a:wiki_lookup[key], a:test_path)
            return [1, key]
        endif
    endfor
    return [0, '']
endfunction

function! s:open_page(wiki, subdir, cmd, link)
    let full_path = a:wiki.path . '/' . a:subdir . '/' . a:link
    let full_path = substitute(expand(full_path), '\/\/', '/', 'g')
    call wikidown#dbg('open_page: full_path: ' . full_path)
    return s:edit_file(a:cmd, full_path)
endfunction

function! s:system_open_link(url)
    try
        call system('xdg-open ' . shellescape(a:url, 1).' &')
    catch
        echomsg '[WikiDown] Default link handler was unable to open ' . a:url
    endtry
endfunction

function! s:cursor_hit(regex) abort
    " Get what is under the cursor given a regex to capture. Returns an empty
    " string if nothing is captured.

    let cursor = {}
    let cursor.x  = col('.') - 1
    let cursor.y = getline('.')

    let match = {}
    let match.left = match(cursor.y, a:regex, 0)

    " loop through regex matches and do hit detection against
    " the bounds of the match and the cursor location.
    while match.left >= 0 && cursor.x >= match.left
        let match.right = matchend(cursor.y, a:regex, match.left)

        let cursor_hit = match.left <= cursor.x && cursor.x < match.right

        if !cursor_hit
            " No hit, check next match
            let match.left = match(cursor.y, a:regex, match.right)
            continue
        endif

        let start = match(cursor.y, a:regex, match.left)
        let length = match.right - start
        return strpart(cursor.y, start, length)
    endwh
    return ''
endfunction

function! s:get_single_line_selection()
    let [line_start, col_start] = getpos("'<")[1:2]
    let [line_end, col_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)

    if len(lines) != 1 | return '' | endif  " No multiline links

    let col_start = col_start - 1
    let col_end = col_end - (&selection ==? 'inclusive' ? 1 : 2)
    return lines[0][col_start : col_end]
endfunction

function! s:sanitize_filename(name)
    return fnameescape(tolower(substitute(a:name, ' ', '_', 'g')) . '.md')
endfunction

function! s:save_markdown_buffer()
    if &filetype ==? 'markdown' && filewritable(expand('%'))
        silent update
    endif
endfunction

function! s:save_buffer()
    let save_eventignore = &eventignore
    let &eventignore = 'all'

    let cur_buf = bufname('%')
    bufdo call s:save_markdown_buffer()
    execute 'buffer ' . cur_buf

    let &eventignore = save_eventignore
endfunction

function! s:delete_unsourced_html_files(active_wiki, path)
    let htmlfiles = split(glob(a:path.'**/*.html'), '\n')
    for fname in htmlfiles
        " ignore user html files
        if stridx(a:active_wiki.ignore_html, fnamemodify(fname, ':t')) >= 0
            continue
        endif

        " delete if there is no corresponding md file
        let subdir = s:subdir(a:active_wiki.path_html, fname)
        let mdfile = expand(a:active_wiki.path . subdir . '/' .
                    \           fnamemodify(fname, ':t:r') . '.md')

        if filereadable(mdfile) | continue | endif

        try
            call wikidown#dbg('delete_unsource: deleting ' . fname)
            call delete(fname)
        catch
            echomsg '[WikiDown] Error: Cannot delete ' . fname
        endtry
    endfor
endfunction

function! s:is_html_up_to_date(wiki, subdir, mdfile)
    let mdfile = fnamemodify(a:mdfile, ':p')
    let htmlfile = expand(a:wiki.path_html . a:subdir . '/' .
                \        fnamemodify(mdfile, ':t:r') . '.html')
    let htmlfile = substitute(expand(htmlfile), '\/\/', '/', 'g')
    call wikidown#dbg('is_html_up_to_date: ' .
                \   mdfile . '(' . getftime(mdfile) . ')   ' .
                \   htmlfile . '(' . getftime(htmlfile) . ')')
    return getftime(mdfile) <= getftime(htmlfile)
endfunction

function! s:extract_title(mdfile)
    let contents = readfile(a:mdfile)
    for line in contents
        let header = matchlist(line, g:atx_header, '')
        if len(header) < 1 | return 'Untitled' | endif
        if header[1] !=# ''| return header[1] | endif
    endfor
    return 'Untitled'
endfunction

function! s:find_autoload_file(name)
    for path in split(&runtimepath, ',')
        let fname = path.'/autoload/wikidown/'.a:name
        if glob(fname) !=# '' | return fname | endif
    endfor
    return ''
endfunction

function! s:copy_style_css(path)
    call s:mkdir(fnamemodify(a:path, ':p:h'))
    let css = s:find_autoload_file('style.css')
    if css !=# ''| call writefile(readfile(css), a:path) | endif
endfunction

function! s:md2html(active_wiki, active_subdir, path_root_html, mdfile)
    let timestamp = strftime('%c')
    let md_file_full_path = fnamemodify(a:mdfile, ':p')
    let css_filename = fnamemodify(a:active_wiki.css, ':t')
    let html_path = expand(a:path_root_html . '/' . a:active_subdir)

    let html_filename = fnamemodify(md_file_full_path, ':t:r') . '.html'
    let html_file = expand(html_path . '/' . html_filename)

    let title = s:extract_title(md_file_full_path)

    call s:mkdir(html_path)

    if a:active_wiki.css !=# ''
        call system('cp '. expand(a:active_wiki.css) . ' ' .
                    \ shellescape(expand(a:path_root_html) . css_filename))
    else
        call s:copy_style_css(expand(a:path_root_html) . css_filename)
        let css_filename = 'style.css'
    endif

    let html_file = shellescape(html_file)
    let md_file_full_path = shellescape(md_file_full_path)

    let pandoc = 'pandoc --mathjax="https://cdn.mathjax.org/mathjax/latest/' .
                \             'MathJax.js?config=TeX-AMS-MML_HTMLorMML" ' .
                \             '-s -f markdown -t html ' .
                \             '-M author:' . shellescape(a:active_wiki.author). ' ' .
                \             '-M date:' . shellescape(timestamp) . ' ' .
                \             '-M title:' . shellescape(title) . ' ' .
                \             '-c ' . shellescape(css_filename)

    let link_sed = 'sed -r "s/(\[.+\])\(([^#)]+)\.md\)/\1(\2.html)/g"'
    let done0 = 's/<li>(.*)\[ \]/<li class="todo done0">\1/g'
    let done4 = 's/<li>(.*)\[[x|X]\]/<li class="todo done4">\1/g'
    let todo_sed = "sed -r '" . done0 . '; ' . done4 . "'"

    let cmd = link_sed . ' < '. md_file_full_path . '|' .
                \ pandoc . '|'. todo_sed . ' >' . html_file
    call wikidown#dbg('Running: ' . cmd)
    echomsg system(cmd)
endfunction
