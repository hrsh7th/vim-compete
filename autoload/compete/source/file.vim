let s:accept_pattern = '\%([^<[:digit:][:alpha:]\*\.]\)'
let s:prefix_pattern = '\%(\~/\|\./\|\.\./\|/\)'
let s:name_pattern = '\%([^/\\:\*?<>\|]*\)'

"
" compete#source#file#register
"
function! compete#source#file#register() abort
  call compete#source#register({
  \   'name': 'file',
  \   'pattern': '/' . s:name_pattern,
  \   'priority': 100,
  \   'filetypes':  ['*'],
  \   'complete': function('s:complete')
  \ })
endfunction


"
" complete
"
function! s:complete(context, callback) abort
  let l:input = matchstr(a:context.before_line, s:accept_pattern . '\zs' . s:prefix_pattern . s:name_pattern . '\%(/' . s:name_pattern . '\)*$')
  let l:input = substitute(s:absolute(l:input), '[^/]*$', '', 'g')

  if !isdirectory(l:input) && !filereadable(l:input)
    return a:context.abort()
  endif

  call a:callback({
  \   'items': sort(map(globpath(l:input, '*', v:true, v:true), function('s:convert', [l:input])), function('s:sort'))
  \ })
endfunction

"
" convert
"
function! s:convert(input, key, path) abort
  let l:part = fnamemodify(a:path, ':t')
  if isdirectory(a:path)
    let l:menu = '[d]'
    let l:abbr = '/' . l:part
  else
    let l:menu = '[f]'
    let l:abbr =  ' ' . l:part
  endif

  return {
  \   'word': '/' . l:part,
  \   'abbr': l:abbr,
  \   'menu': l:menu
  \ }
endfunction

"
" sort
"
function! s:sort(item1, item2) abort
  if a:item1.menu ==# '[d]' && a:item2.menu !=# '[d]'
    return -1
  endif
  if a:item1.menu !=# '[d]' && a:item2.menu ==# '[d]'
    return 1
  endif
  return 0
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

