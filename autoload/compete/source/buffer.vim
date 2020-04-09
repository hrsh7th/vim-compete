let s:insert_enter_timer_id = -1
let s:keywords = {}

"
" compete#source#buffer#register
"
function! compete#source#buffer#register() abort
  augroup compete#source#buffer#register
    autocmd!
    autocmd InsertEnter * call s:on_insert_enter()
  augroup END

  call compete#source#register({
  \   'name': 'buffer',
  \   'filetypes': ['*'],
  \   'priority': -1,
  \   'complete': function('s:complete'),
  \ })
endfunction


"
" complete
"
function! s:complete(context, callback) abort
  call a:callback({
  \   'items': map(keys(s:keywords), { _, keyword -> {
  \     'word': keyword,
  \     'abbr': keyword,
  \     'menu': '[b]'
  \   } })
  \ })
endfunction

"
" on_insert_enter
"
function! s:on_insert_enter() abort
  call timer_stop(s:insert_enter_timer_id)
  let s:insert_enter_timer_id = timer_start(100, function('s:cache'))
endfunction

"
" cache
"
function! s:cache(...) abort
  let l:lnum = line('.')
  let l:min_above = max([1, l:lnum - g:compete_keyword_range])
  let l:max_below = min([line('$'), l:lnum + g:compete_keyword_range + 1])

  let l:above = reverse(getline(l:min_above, l:lnum))
  let l:below = getline(l:lnum + 1, l:max_below)
  let l:lines = filter(l:above + l:below, 'strlen(v:val) < 200')

  let l:pattern = compete#pattern()

  let s:keywords = {}
  let l:index = 0
  for l:keyword in split((' ' . join(l:lines, ' ') . ' '), l:pattern . '\zs.\{-1,}\ze' . l:pattern)
    let l:keyword = trim(l:keyword)
    if len(l:keyword) > 2
      if has_key(s:keywords, l:keyword)
        continue
      endif

      let s:keywords[l:keyword] = l:index
      let l:index += 1
    endif
  endfor
endfunction
