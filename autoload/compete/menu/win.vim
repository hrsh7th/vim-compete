"
" compete#menu#win#do
"
function! compete#menu#win#do(winid, callback) abort
  let l:winnr = winnr()
  try
    execute printf('noautocmd keepalt keepjumps %swincmd w', win_id2win(a:winid))
    call a:callback()
  catch /.*/
  endtry
  execute printf('noautocmd keepalt keepjumps %swincmd w', l:winnr)
endfunction

