let s:id = 0
let s:error_count = 0
let s:timer_id = 0
let s:state = {
\   'matches': {},
\ }

"
" on_clear
"
function! compete#on_clear() abort
  let s:state = {
  \   'matches': {},
  \ }
endfunction

"
" compete#on_change
"
function! compete#on_change() abort
  if s:error_count > 10
    return
  endif

  try
    let l:context = s:context()
    for l:source in compete#source#find()
      call s:update(l:context, l:source)
    endfor
    call s:filter(l:context)
  catch /.*/
    let s:error_count += 1
  endtry
endfunction

"
" update
"
function! s:update(context, source) abort
  if !has_key(s:state.matches, a:source.name)
    let s:state.matches[a:source.name] = {
    \   'id': 0,
    \   'name': a:source.name,
    \   'status': 'waiting',
    \   'start': -1,
    \   'items': [],
    \   'incomplete': v:false,
    \ }
  endif

  let l:match = s:state.matches[a:source.name]

  let l:chars = s:find(a:source.trigger_chars, a:context.before_char, '')
  let l:input = matchstr(a:context.before_line, a:source.pattern . '$')

  if l:chars !=# ''
    let l:start = strlen(a:context.before_line) + 2
  elseif l:input !=# ''
    let l:start = (strlen(a:context.before_line) - strlen(l:input)) + 1
  else
    " if input/chars doesn't match and position was changed, discard recent items.
    if l:match.start != strlen(a:context.before_line) + 1
      let l:match.status = 'waiting'
    endif
    return
  endif

  " avoid request when start position does not changed.
  if l:start == l:match.start && l:match.incomplete isnot v:true
    return
  endif

  let l:match.id += 1
  let l:match.status = l:match.start == l:start ? 'completed' : 'processing'
  let l:match.lnum = a:context.lnum
  let l:match.start = l:start
  call a:source.complete(
  \   extend({ 'start': l:start, 'input': l:input }, a:context, 'keep'),
  \   function('s:on_complete', [a:context, a:source, l:match.id])
  \ )
endfunction

"
" filter
"
function! s:filter(context) abort
  if complete_info(['selected']).selected != -1
    return
  endif

  let l:matches = filter(values(s:state.matches), { _, match -> index(['processing', 'completed'], match.status) != -1 })
  let l:start = min(map(copy(l:matches), { _, match -> match.start }))
  let l:matches = sort(l:matches, { a, b -> get(b, 'priority', 0) - get(a, 'priority', 0) })
  let l:matches = s:reduce(l:matches)

  " compute items.
  let l:items = []
  for l:match in l:matches
    let l:source = compete#source#get_by_name(l:match.name)
    let l:prefix = strpart(a:context.before_line, l:start - 1, l:match.start - l:start)
    let l:query = l:source.query(strpart(a:context.before_line, l:start - 1, strlen(a:context.before_line) - (l:start - 1)))
    for l:item in l:match.items
      let l:word = l:prefix . l:item.word
      if l:word =~ l:query
        call add(l:items, extend({
        \   'word': l:word
        \ }, l:item, 'keep'))
      endif
    endfor
  endfor

  " complete.
  if mode()[0] ==# 'i'
    call complete(l:start, l:items)
  endif
endfunction

"
" on_complete
"
function! s:on_complete(context, source, id, match) abort
  if a:context.bufnr != bufnr('%')
    return
  endif

  let l:match = get(s:state.matches, a:source.name, {})
  if a:id < l:match.id
    return
  endif

  let l:match.status = 'completed'
  let l:match.items = a:match.items
  let l:match.incomplete = get(a:match, 'incomplete', v:false)

  call timer_stop(s:timer_id)
  let s:timer_id = timer_start(200, { -> s:filter(a:context) })
endfunction

"
" reduce
"
function! s:reduce(matches) abort
  let l:processing = v:false
  let l:matches = []
  for l:match in a:matches
    if l:match.status ==# 'processing'
      let l:processing = v:true
    endif
    if !l:processing
      call add(l:matches, l:match)
    endif
  endfor
  return l:matches
endfunction

"
" context
"
function! s:context() abort
  let s:id += 1
  return {
  \   'id': s:id,
  \   'bufnr': bufnr('%'),
  \   'lnum': line('.'),
  \   'col': col('.'),
  \   'before_char': lamp#view#cursor#get_before_char_skip_white(),
  \   'before_line': getline('.')[0 : col('.') - 2],
  \ }
endfunction

"
" find
"
function! s:find(haystack, needle, ...) abort
  let l:def = get(a:000, 0, '')
  let l:index = index(a:haystack, a:needle)
  return l:index != -1 ? a:haystack[l:index] : l:def
endfunction

