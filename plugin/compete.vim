if exists('g:loaded_compete')
  finish
endif
let g:loaded_compete = v:true

let g:compete_enable = get(g:, 'compete_enable', v:true)
let g:compete_throttle = get(g:, 'compete_throttle', 200)
let g:compete_fuzzy = get(g:, 'compete_fuzzy', v:true)
let g:compete_patterns = extend(get(g:, 'compete_patterns', {}), {
\   'vim': '\%(a:\|l:\|s:\|b:\|w:\|t:\|g:\|v:\|&\|\w\)\%(\w\|#\)*',
\   'php': '\%(\$\|\w\)\%(\w\|\->\)*',
\ }, 'keep')

inoremap <Plug>(compete-select-next) <C-r>=<SID>select(+1)<CR>
inoremap <Plug>(compete-select-prev) <C-r>=<SID>select(-1)<CR>
function! s:select(offset) abort
  call compete#menu#select(a:offset)
  return ''
endfunction

imap <C-n> <Plug>(compete-select-next)
imap <C-p> <Plug>(compete-select-prev)

augroup compete
  autocmd!
  autocmd InsertLeave * call s:on_insert_leave()
  autocmd InsertEnter * call timer_start(0, { -> s:on_text_changed() })
  autocmd TextChangedI,TextChangedP * call s:on_text_changed()
augroup END

"
" on_insert_leave
"
function! s:on_insert_leave() abort
  if g:compete_enable
    call compete#on_clear()
  endif
endfunction

"
" on_text_changed
"
function! s:on_text_changed() abort
  if g:compete_enable
    call compete#on_change()
  endif
endfunction

call compete#source#buffer#register()
call compete#source#file#register()

