let g:compete_source_buffer_max = 1000

let s:keywords = {}

function! compete#source#buffer#register() abort
  augroup compete#source#buffer#register
    autocmd!
    autocmd InsertEnter * call s:cache()
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
  \   'items': map(copy(s:keywords[a:context.bufnr]), { _, keyword -> {
  \     'word': keyword,
  \     'abbr': keyword,
  \     'menu': '[b]'
  \   } })
  \ })
endfunction

"
" cache
"
function! s:cache() abort
  let l:lnum = line('.')
  let l:min_above = max([1, l:lnum - g:compete_source_buffer_max])
  let l:max_below = min([line('$'), l:lnum + g:compete_source_buffer_max + 1])

  let l:above = reverse(getline(l:min_above, l:lnum))
  let l:below = getline(l:lnum + 1, l:max_below)

  let l:above_len = len(l:above)
  let l:below_len = len(l:below)
  let l:min_len = min([l:above_len, l:below_len])

  let l:lines = []
  for l:i in range(0, l:min_len - 1)
    call add(l:lines, l:above[l:i])
    call add(l:lines, l:below[l:i])
  endfor

  if l:above_len > l:min_len
    let l:lines += l:above[l:min_len : -1]
  endif
  if l:below_len > l:min_len
    let l:lines += l:below[l:min_len : -1]
  endif

  let l:bufnr = bufnr('%')
  let l:unique = {}

  let l:pattern = compete#pattern()
  let s:keywords[l:bufnr] = []
  for l:keyword in split(' ' . join(l:lines, ' ') . ' ', l:pattern . '\zs.\{-}\ze' . l:pattern)
    let l:keyword = trim(l:keyword)
    if len(l:keyword) > 2 && !has_key(l:unique, l:keyword)
      if !has_key(l:unique, l:keyword)

        let l:unique[l:keyword] =  1
        let s:keywords[l:bufnr] += [l:keyword]
      endif
    endif
  endfor
endfunction

