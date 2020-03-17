let s:Floatwin = lamp#view#floatwin#import()
let s:floatwin = s:Floatwin.new({ 'fix': v:false, 'max_height': 15, 'max_width': -1 })
let s:state = {
\   'startcol': -1,
\   'items': [],
\   'top': 0,
\   'cursor': -1,
\   'prefix': v:null,
\ }

call sign_define('CompeteMenuSelected', {
\   'linehl': 'Cursor',
\ })

"
" compete#menu#show
"
function! compete#menu#show(startcol, items) abort
  let s:state.startcol = a:startcol
  let s:state.items = a:items
  let s:state.top = 0
  let s:state.cursor = -1
  call compete#menu#select(0)
  if len(a:items) ==  0
    call compete#menu#hide()
  else
    call s:render()
  endif
endfunction

"
" compete#menu#select
"
function! compete#menu#select(offset) abort
  let l:height = min([s:floatwin.max_height, len(s:state.items)])

  let s:state.cursor += a:offset
  let s:state.cursor = s:state.cursor == -2 ? len(s:state.items) - 1 : s:state.cursor
  if s:state.cursor > -1
    let l:line = getline('.')

    if s:state.prefix is v:null
      let s:state.prefix = l:line[s:state.startcol - 1 : col('.') - 2]
    endif

    let s:state.cursor = s:state.cursor % len(s:state.items)
    let l:before = strpart(l:line, 0, s:state.startcol - 1)
    let l:after = strpart(l:line, col('.') - 1, strlen(l:line) - col('.') + 1)
    let l:word = s:state.items[s:state.cursor].word
    undojoin | call setline('.', l:before . l:word . l:after)
    undojoin | call cursor(line('.'), strlen(l:before . l:word) + 1)
  elseif s:state.prefix isnot v:null
    let l:line = getline('.')
    let l:before = strpart(l:line, 0, s:state.startcol - 1)
    let l:after = strpart(l:line, col('.') - 1, strlen(l:line) - col('.') + 1)
    undojoin | call setline('.', l:before . s:state.prefix . l:after)
    undojoin | call cursor(line('.'), strlen(l:before . s:state.prefix) + 1)
  endif

  let s:state.top = max([0, s:state.cursor - l:height + 1])

  call s:render()
endfunction

"
" compete#menu#hide
"
function! compete#menu#hide() abort
  if compete#menu#selected()
    let l:item = get(s:state.items, s:state.cursor, v:null)
    if !empty(l:item)
    endif
  endif

  let s:state = {
  \   'startcol': -1,
  \   'items': [],
  \   'top': 0,
  \   'cursor': -1,
  \   'prefix': v:null,
  \ }
  call s:floatwin.hide()
endfunction

"
" compete#menu#selected
"
function! compete#menu#selected() abort
  return s:state.cursor > -1
endfunction

"
" compete#menu#confirm
"
function! compete#menu#confirm(offset) abort
  let l:item = get(s:state.items, s:state.cursor, v:null)
  if !empty(l:item)
    call complete(s:state.startcol, [l:item])
    call feedkeys("\<C-n>\<C-y>", 'n')
  endif
endfunction

"
" render
"
function! s:render() abort
  " render lines
  let l:items = s:state.items[s:state.top : s:state.top + s:floatwin.max_height]
  let l:items = map(l:items, 's:normalize(v:val)')
  let l:abbr_len = max(map(copy(l:items), 'strlen(v:val.abbr)')) + 1
  let l:menu_len = max(map(copy(l:items), 'strlen(v:val.menu)')) + 1
  let l:kind_len = max(map(copy(l:items), 'strlen(v:val.kind)'))

  let s:floatwin.max_height = min([15, winheight(0) - (line('.') - line('w0'))])
  call s:floatwin.show(lamp#view#floatwin#screenpos(line('.'), s:state.startcol - 1), [{
  \   'lines': map(l:items, 's:padding(v:val.abbr, l:abbr_len) . s:padding(v:val.kind, l:kind_len) . s:padding(v:val.menu, l:menu_len)')
  \ }])

  " render signs
  call setbufvar(s:floatwin.bufnr, '&signcolumn', 'no')
  try
    call sign_unplace('CompeteMenuSelected', {
    \   'bufnr': s:floatwin.bufnr,
    \ })
    call sign_place(0, 'CompeteMenuSelected', 'CompeteMenuSelected', bufname(s:floatwin.bufnr), {
    \   'lnum': (s:state.cursor - s:state.top) + 1
    \ })
  catch /.*/
  endtry
endfunction

"
" normalize
"
function! s:normalize(item) abort
  let a:item.menu = get(a:item, 'menu', '')
  let a:item.kind = get(a:item, 'kind', '')
  let a:item.abbr = get(a:item, 'abbr', '')
  return a:item
endfunction

"
" padding
"
function! s:padding(text, len) abort
  return a:text . repeat(' ', a:len - strlen(a:text))
endfunction

