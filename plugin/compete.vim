if exists('g:loaded_compete')
  finish
endif
let g:loaded_compete = v:true

let g:compete_enable = get(g:, 'compete_enable', v:true)
let g:compete_keyword_range = get(g:, 'compete_keyword_cache', 1000)
let g:compete_throttle = get(g:, 'compete_throttle', 200)
let g:compete_fuzzy = get(g:, 'compete_fuzzy', v:true)
let g:compete_item_count = get(g:, 'complete_item_count', 30)
let g:compete_history_path = get(g:, 'compete_history_path', expand('~/.compete_history'))
let g:compete_patterns = extend(get(g:, 'compete_patterns', {}), {
\   'vim': '\%(a:\|l:\|s:\|b:\|w:\|t:\|g:\|v:\|&\|\w\)\%(\w\|#\|\.\)*',
\   'php': '\%(\$\|\w\)\%(\w\)*',
\ }, 'keep')

augroup compete
  autocmd!
  autocmd InsertEnter * call timer_start(0, { -> s:on_insert_enter() })
  autocmd InsertLeave * call s:on_insert_leave()
  autocmd CompleteDone * call s:on_complete_done()
  autocmd InsertCharPre * call s:on_insert_char_pre()
  autocmd VimLeavePre * call s:on_vim_leave_pre()
augroup END

"
" on_insert_enter
"
function! s:on_insert_enter() abort
  if g:compete_enable
    call compete#on_insert_enter()
    call compete#on_change()
  endif
endfunction

"
" on_insert_leave
"
function! s:on_insert_leave() abort
  if g:compete_enable
    call compete#on_clear()
  endif
endfunction

"
" s:on_complete_done
"
function! s:on_complete_done() abort
  if !empty(v:completed_item)
    call compete#add_history(get(v:completed_item, 'word', ''))
  endif
endfunction

"
" on_change
"
inoremap <silent><nowait> <Plug>(compete-on-change) <C-r>=compete#on_change()<CR>
function! s:on_insert_char_pre() abort
  if g:compete_enable
    noautocmd call feedkeys("\<Plug>(compete-on-change)", '')
  endif
endfunction

"
" on_vim_leave_pre
"
function! s:on_vim_leave_pre() abort
  if g:compete_enable
    call compete#store_history()
  endif
endfunction

if strlen(g:compete_history_path) > 0
  call compete#restore_history()
endif

call compete#source#buffer#register()
call compete#source#file#register()

