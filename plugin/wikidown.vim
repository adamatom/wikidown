if exists('g:loaded_wikidown') || &compatible
    finish
endif

let g:loaded_wikidown = 1

let s:old_cpoptions = &cpoptions
set cpoptions&vim

if !exists('g:wikidown_debug')
    let g:wikidown_debug = 0
endif

if !exists('g:wikidown_wikis')
    let g:wikidown_wikis = {}
endif

if g:wikidown_wikis == {}
    let g:wikidown_wikis.default = {}
    call wikidown#complete_wiki_conf(g:wikidown_wikis.default)
endif

" define standard link syntax regex's
let g:wikidown_link = '(\zs.*\ze)' " given '[title](link)', get 'link'
let g:wikidown_page_link = '\[[^]]*\]([^)]*)'  " [title](link)
let g:wikidown_section_link = '\[[^]]*\](#[^)]*)'  " [title](#link)
let g:wikidown_web_link = '\[[^]]*\](http[s]\?://[^)]*)' " [t](http[s]://link)
let g:atx_header = '[#]\+\s*\(.\+\)$'
let g:setex_header = '\([[:alnum:][:space:]\|-]\+\)[\r\n]\([-\|=]\{2,}\)'

command! -nargs=1 WikiDown call wikidown#goto_wiki_index(<args>)
command! WikiDownPublish call wikidown#publish_to_html()
command! WikiDownEditLog call wikidown#edit_log()

command! WikiDownCreateLink call wikidown#generate_link()
command! WikiDownNextLink call wikidown#nextlink()
command! WikiDownPrevLink call wikidown#prevlink()

command! WikiDownFollowLink call wikidown#follow_link('edit')
command! WikiDownFollowLinkSplit call wikidown#follow_link('split')
command! WikiDownFollowLinkVSplit call wikidown#follow_link('vsplit')
command! WikiDownFollowLinkTab call wikidown#follow_link('tab')

command! WikiDownCreateOrFollow call wikidown#create_or_follow_link('edit')
command! WikiDownCreateOrFollowSplit call wikidown#create_or_follow_link('split')
command! WikiDownCreateOrFollowVSplit call wikidown#create_or_follow_link('vsplit')
command! WikiDownCreateOrFollowTab call wikidown#create_or_follow_link('tab')

command! WikiDownGoBack call wikidown#go_back_link()
command! WikiDownDeletePage call wikidown#delete_page()

nnoremap <silent><unique> <Plug>(WikiDownPublish)           :WikiDownPublish<CR>
nnoremap <silent><unique> <Plug>(WikiDownEditLog)           :WikiDownEditLog<CR>
nnoremap <silent><unique> <Plug>(WikiDownCreateLink)        :WikidownCreateLink<CR>
nnoremap <silent><unique> <Plug>(WikiDownDeletePage)        :WikiDownDeletePage<CR>
nnoremap <silent><unique> <Plug>(WikiDownNextLink)          :WikiDownNextLink<CR>
nnoremap <silent><unique> <Plug>(WikiDownPrevLink)          :WikiDownPrevLink<CR>
nnoremap <silent><unique> <Plug>(WikiDownGoBack)            :WikiDownGoBack<CR>

nnoremap <silent><unique> <Plug>(WikiDownFollowLink)        :WikiDownFollowLink<CR>
nnoremap <silent><unique> <Plug>(WikiDownFollowLinkSplit)   :WikiDownFollowLinkSplit<CR>
nnoremap <silent><unique> <Plug>(WikiDownFollowLinkVSplit)  :WikiDownFollowLinkVSplit<CR>
nnoremap <silent><unique> <Plug>(WikiDownFollowLinkTab)     :WikiDownFollowLinkTab<CR>

vnoremap <silent><unique> <Plug>(WikiDownCreateOrFollow)       :<C-U>WikiDownCreateOrFollow<CR>
vnoremap <silent><unique> <Plug>(WikiDownCreateOrFollowSplit)  :<C-U>WikiDownCreateOrFollowSplit<CR>
vnoremap <silent><unique> <Plug>(WikiDownCreateOrFollowVSplit) :<C-U>WikiDownCreateOrFollowVSplit<CR>
vnoremap <silent><unique> <Plug>(WikiDownCreateOrFollowTab)    :<C-U>WikiDownCreateOrFollowTab<CR>

let &cpoptions = s:old_cpoptions
