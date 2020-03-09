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
  let l:input = substitute(s:absolute(l:input), '[^/]*$', '', 'g')
  let l:paths = globpath(l:input, '*', v:true, v:true)
  let l:paths = map(l:paths, { _, path -> strpart(path, strlen(l:input) - 1, strlen(path) - strlen(l:input) + 1) })

  call a:callback({
  \   'items': map(l:paths, { _, path -> {
  \     'word': path,
  \     'abbr': path,
  \   } })
  \ })
endfunction


"
" absolute
"
function! s:absolute(input) abort
  if a:input =~# '^\V./' || a:input =~# '^\V../'
    let l:input = resolve(expand('%:p:h') . '/' . a:input) . '/'
    return l:input
  elseif a:input =~# '^\V~/'
    return expand(a:input)
  endif
  return a:input
endfunction

