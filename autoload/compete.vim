let s:error = 0
let s:timer_id = -1
let s:cache = {
\   'start': -1,
\   'items': [],
\ }
let s:state = {
\   'matches': {},
\ }

"
" on_clear
"
function! compete#on_clear() abort
  let s:cache = {
  \   'lnum': -1,
  \   'start': -1,
  \   'items': [],
  \ }
  let s:state = {
  \   'matches': {},
  \ }
endfunction

"
" compete#on_change
"
function! compete#on_change() abort
  if s:error > 10
    return
  endif

  try
    let l:context = s:context()
    for l:source in compete#source#find()
      call s:update(l:context, l:source)
    endfor
    call s:filter(l:context)
  catch /.*/
    let s:error += 1
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
    \   'lnum': -1,
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
  let l:match.items = []
  call a:source.complete(
  \   extend({ 'start': l:start, 'input': l:input }, a:context, 'keep'),
  \   s:create_callback(a:context, a:source, l:match.id)
  \ )
endfunction

"
" filter
"
function! s:filter(context) abort
  " selected check.
  if pumvisible() && !empty(v:completed_item)
    call timer_stop(s:timer_id)
    let s:timer_id = -1
    return
  endif

  let l:ctx = {}
  function! l:ctx.callback(context, matches, start) abort
    let s:timer_id = -1

    " compute items.
    let l:input = strpart(a:context.before_line, a:start - 1, strlen(a:context.before_line) - (a:start - 1))

    let l:prefix_items = []
    let l:fuzzy_items = []
    for l:match in a:matches
      let l:source = compete#source#get_by_name(l:match.name)
      let l:short = strpart(a:context.before_line, a:start - 1, l:match.start - a:start)

      let l:prefix = '^\V' . l:input
      let l:fuzzy = '^.*\V' . join(split(l:input, '\zs'), '\m.*\V')

      for l:item in l:match.items
        let l:word = l:short . l:item.word
        if l:word =~ l:prefix
          call add(l:prefix_items, extend({
          \   'word': l:word,
          \   'abbr': get(l:item, 'abbr', l:item.word),
          \ }, l:item, 'keep'))
        elseif l:word =~ l:fuzzy
          call add(l:fuzzy_items, extend({
          \   'word': l:word,
          \   'abbr': get(l:item, 'abbr', l:item.word),
          \ }, l:item, 'keep'))
        endif
      endfor
    endfor

    let l:items = l:prefix_items + l:fuzzy_items

    " complete.
    if mode()[0] ==# 'i'
      call complete(a:start, l:items)
      let s:cache = {
      \   'start': a:start,
      \   'items': l:items
      \ }
    endif
  endfunction

  " no completion candidates.
  let l:matches = s:get_matches()
  if len(l:matches) == 0
    call timer_stop(s:timer_id)
    let s:timer_id = -1
    return
  endif

  " avoid screen flicker.
  let l:start = min(map(copy(l:matches), { _, match -> match.start }))
  if l:start == s:cache.start
    call complete(s:cache.start, s:cache.items)
    redraw
  endif

  " throttle.
  if s:timer_id != -1
    return
  endif

  let s:timer_id = timer_start(
  \   l:start != s:cache.start ? 80 : 160,
  \   { -> l:ctx.callback(a:context, l:matches, l:start) }
  \ )
endfunction

"
" get_matches
"
function! s:get_matches() abort
  let l:matches = values(s:state.matches)
  let l:matches = filter(l:matches, { _, match -> match.status ==# 'completed' || match.status ==# 'processing' })
  let l:matches = sort(l:matches, { a, b -> get(b, 'priority', 0) - get(a, 'priority', 0) })

  let l:i = 0
  for l:match in l:matches
    if l:match.status !=# 'completed'
      break
    endif
    let l:i += 1
  endfor
  return l:matches[0 : l:i - 1]
endfunction

"
" context
"
function! s:context() abort
  return {
  \   'bufnr': bufnr('%'),
  \   'lnum': line('.'),
  \   'col': col('.'),
  \   'before_char': lamp#view#cursor#get_before_char_skip_white(),
  \   'before_line': getline('.')[0 : col('.') - 2],
  \ }
endfunction

"
" create_callback
"
function! s:create_callback(context, source, id) abort
  let l:ctx = {}

  " callback.
  function! l:ctx.callback(context, source, id, matches) abort
    call s:on_complete(a:context, a:source, a:id, a:matches)
  endfunction

  return function(l:ctx.callback, [a:context, a:source, a:id], l:ctx)
endfunction

"
" on_complete
"
function! s:on_complete(context, source, id, match) abort
  let l:context = s:context()
  if l:context.bufnr != a:context.bufnr || l:context.lnum != a:context.lnum
    return
  endif

  let l:match = get(s:state.matches, a:source.name, {})
  if !has_key(l:match, 'id') || a:id < l:match.id
    return
  endif

  let l:match.status = 'completed'
  let l:match.lnum = a:context.lnum
  let l:match.items = a:match.items
  let l:match.incomplete = get(a:match, 'incomplete', v:false)

  call s:filter(a:context)
endfunction

"
" find
"
function! s:find(haystack, needle, ...) abort
  let l:def = get(a:000, 0, '')
  let l:index = index(a:haystack, a:needle)
  return l:index != -1 ? a:haystack[l:index] : l:def
endfunction

