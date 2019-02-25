call wikidown#detect_wiki()

if exists('b:loaded_wikidown_ftplugin')
    finish
endif
let b:loaded_wikidown_ftplugin = 1  " Don't load another plugin for this buffer

if exists('g:wikidown_default_maps') && g:wikidown_default_maps
    if !hasmapto('<Plug>(WikiDownPublish)')
        nmap <silent><unique><buffer> <leader>wp <Plug>(WikiDownPublish)
    endif

    if !hasmapto('<Plug>(WikiDownEditLog)')
        nmap <silent><unique><buffer> <leader>wl <Plug>(WikiDownEditLog)
    endif

    if !hasmapto('<Plug>(WikiDownDeletePage)')
        nmap <silent><unique><buffer> <leader>wD <Plug>(WikiDownDeletePage)
    endif

    if !hasmapto('<Plug>(WikiDownNextLink)')
        nmap <silent><unique><buffer> <tab> <Plug>(WikiDownNextLink)
    endif

    if !hasmapto('<Plug>(WikiDownPrevLink)')
        nmap <silent><unique><buffer> <s-tab> <Plug>(WikiDownPrevLink)
    endif

    if !hasmapto('<Plug>(WikiDownGoBack)')
        nmap <silent><unique><buffer> <backspace> <Plug>(WikiDownGoBack)
    endif

    if !hasmapto('<Plug>(WikiDownFollowLink)') &&
                \ !hasmapto('<Plug>(WikiDownFollowLinkSplit)') &&
                \ !hasmapto('<Plug>(WikiDownFollowLinkVSplit)') &&
                \ !hasmapto('<Plug>(WikiDownFollowLinkTab)')
        nmap <silent><unique><buffer> <CR> <Plug>(WikiDownFollowLink)
    endif

    if !hasmapto('<Plug>(WikiDownCreateOrFollow)') &&
                \ !hasmapto('<Plug>(WikiDownCreateOrFollowSplit)') &&
                \ !hasmapto('<Plug>(WikiDownCreateOrFollowVSplit)') &&
                \ !hasmapto('<Plug>(WikiDownCreateOrFollowTab)')
        vmap <silent><unique><buffer> <CR> <Plug>(WikiDownCreateOrFollow)
    endif
endif
