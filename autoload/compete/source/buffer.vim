function! compete#source#buffer#register() abort
  call compete#source#register({
  \   'name': 'buffer',
  \   'filetypes': ['*'],
  \   'priority': -1,
  \   'complete': function('s:complete'),
  \ })
endfunction


"
" complete
"
function! s:complete(context, callback) abort
  call a:callback({
  \   'items': map(a:context.keywords, { _, keyword -> {
  \     'word': keyword,
  \     'abbr': keyword,
  \     'menu': '[b]'
  \   } })
  \ })
endfunction

