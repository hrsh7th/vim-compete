let s:Floatwin = lamp#view#floatwin#import()
let s:floatwin = s:Floatwin.new({ 'fix': v:false, 'max_height': 15 })
let s:state = {
\   'startcol': -1,
\   'items': [],
\   'selected': -1,
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
  let s:state.selected = -1
  call compete#menu#select(0)
  if len(a:items) >  0
    call s:floatwin.show(lamp#view#floatwin#screenpos(line('.'), a:startcol - 1), [{
    \   'lines': map(copy(a:items), 'v:val.word')
    \ }])
  else
    call compete#menu#hide()
  endif
  call setbufvar(s:floatwin.bufnr, '&signcolumn', 'no')
endfunction

"
" compete#menu#hide
"
function! compete#menu#hide() abort
  call s:floatwin.hide()
endfunction

"
" compete#menu#select
"
function! compete#menu#select(offset) abort
  try
    call sign_unplace('CompeteMenuSelected', {
    \   'bufnr': s:floatwin.bufnr,
    \ })
  catch /.*/
  endtry

  let s:state.selected += a:offset
  let s:state.selected = s:state.selected % len(s:state.items)
  if s:state.selected > -1
    call sign_place(0, 'CompeteMenuSelected', 'CompeteMenuSelected', bufname(s:floatwin.bufnr), {
    \   'lnum': s:state.selected + 1
    \ })
    let l:line = getline('.')
    let l:before = strpart(l:line, 0, s:state.startcol - 1)
    let l:after = strpart(l:line, col('.') - 1, strlen(l:line) - col('.') - 1)
    call setline('.', l:before . s:state.items[s:state.selected].word . l:after)
  endif

  " let l:offset = s:state.selected - winheight(win_id2win(s:floatwin.winid()))
  " if l:offset > 0
  "   call win_execute(s:floatwin.winid, printf("call winrestview({ 'topline': %s })", l:offset))
  " endif

endfunction

"
" compete#menu#confirm
"
function! compete#menu#confirm(offset) abort
  let l:item = get(s:state.items, s:state.selected, v:null)
  if !empty(l:item)
    call complete(s:state.startcol, [l:item])
    call feedkeys("\<C-n>\<C-y>", 'n')
  endif
endfunction

