if exists('g:loaded_compete')
  finish
endif
let g:loaded_compete = v:true

let g:compete_enable = get(g:, 'compete_enable', v:true)
let g:compete_keyword_range = get(g:, 'compete_keyword_cache', 1000)
let g:compete_throttle = get(g:, 'compete_throttle', 100)
let g:compete_fuzzy = get(g:, 'compete_fuzzy', v:true)
let g:compete_item_count = get(g:, 'complete_item_count', 30)
let g:compete_patterns = extend(get(g:, 'compete_patterns', {}), {
\   'vim': '\%(a:\|l:\|s:\|b:\|w:\|t:\|g:\|v:\|&\|\w\)\%(\w\|#\|\.\)*',
\   'php': '\%(\$\|\w\)\%(\w\|\->\)*',
\ }, 'keep')

imap <silent> <Plug>(compete-on-change) <C-r>=CompeteOnChange()<CR>

augroup compete
  autocmd!
  autocmd InsertEnter * call timer_start(0, { -> s:on_insert_enter() })
  autocmd InsertLeave * call s:on_insert_leave()
  autocmd InsertCharPre * call s:on_insert_char_pre()
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
" on_insert_char_pre
"
function! s:on_insert_char_pre() abort
  if g:compete_enable
    noautocmd call feedkeys("\<Plug>(compete-on-change)", 't')
  endif
endfunction

"
" on_insert_char_pre
"
function! CompeteOnChange() abort
  call compete#on_change()
  return ''
endfunction

call compete#source#buffer#register()
call compete#source#file#register()

