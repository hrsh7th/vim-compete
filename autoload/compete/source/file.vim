"
" compete#source#file#register
"
function! compete#source#file#register() abort
  call compete#source#register({
  \   'name': 'file',
  \   'pattern': '\%(^\|[^<]\)\zs/[^/\\:\*?<>\|]*',
  \   'filetypes':  ['*'],
  \   'complete': function('s:complete')
  \ })
endfunction

"
" complete
"
function! s:complete(context, callback) abort
  let l:input = matchstr(a:context.before_line, '\%(\~/\|\./\|\.\./\|/\)\%([^/\\:\*?<>\|]*\)\%(/[^/\\:\*?<>\|]*\)*')
  let l:input = substitute(l:input, '[^/]*$', '', 'g')
  let l:paths = globpath(l:input, '*', '', v:true, v:true)
  let l:paths = map(l:paths, { _, path -> substitute(path, '\/$', '', '$') })
  let l:paths = map(l:paths, { _, path -> substitute(path, '^.*\ze\/[^\/\\:\*?<>\|]\+$', '', 'g') })

  call a:callback({
  \   'items': map(l:paths, { _, path -> {
  \     'word': path,
  \     'abbr': path,
  \   } })
  \ })
endfunction

