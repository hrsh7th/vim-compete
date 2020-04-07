if exists('g:loaded_compete')
  finish
endif
let g:loaded_compete = v:true

let g:compete_enable = get(g:, 'compete_enable', v:true)
let g:compete_debug = get(g:, 'compete_debug', v:false)
let g:compete_keyword_range = get(g:, 'compete_keyword_cache', 1000)
let g:compete_throttle_time = get(g:, 'compete_throttle_time', 200)
let g:compete_source_wait_time = get(g:, 'compete_source_wait_time', 100)
let g:compete_fuzzy = get(g:, 'compete_fuzzy', v:true)
let g:compete_linewise_chars = get(g:, 'compete_linewise_chars', [',', '{'])
let g:compete_min_length = get(g:, 'compete_min_length', 1)
let g:compete_patterns = extend(get(g:, 'compete_patterns', {}), {
\   'vim': '\%(a:\|l:\|s:\|b:\|w:\|t:\|g:\|v:\|\&\|\h\)\%(\w\|#\|\.\)*',
\   'php': '\%(\$\|\h\)\%(\w\)*',
\ }, 'keep')

let s:state = {
\   'insert_enter_timer_id': -1,
\ }

augroup compete
  autocmd!
  autocmd InsertEnter * call s:on_insert_enter()
  autocmd InsertLeave * call s:on_insert_leave()
  autocmd CompleteDone * call s:on_complete_done()
  autocmd InsertCharPre * call s:on_insert_char_pre()
augroup END

"
" on_insert_enter
"
function! s:on_insert_enter() abort
  if g:compete_enable
    let l:ctx = {}
    function! l:ctx.callback() abort
      if mode()[0] ==# 'i'
        call compete#on_insert_enter()
        call compete#on_change()
      endif
    endfunction
    call timer_stop(s:state.insert_enter_timer_id)
    let s:state.insert_enter_timer_id = timer_start(200, { -> l:ctx.callback() })
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
    call compete#add_history(v:completed_item.word)
  endif
endfunction

"
" on_insert_char_pre
"
inoremap <silent> <Plug>(compete-on-change) <C-r>=compete#on_change()<CR>
function! s:on_insert_char_pre() abort
  if g:compete_enable
    call feedkeys("\<Plug>(compete-on-change)", '')
  endif
endfunction

call compete#source#buffer#register()
call compete#source#file#register()

