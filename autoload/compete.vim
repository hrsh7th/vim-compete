let s:error = 0
let s:timer_id = -1
let s:cache = {
\   'lnum': -1,
\   'start': -1,
\   'items': [],
\ }
let s:state = {
\   'changed': -1,
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
  \   'changed': -1,
  \   'matches': {},
  \ }
endfunction

"
" compete#on_change
"
function! compete#on_change() abort
  " error check.
  if s:error > 10
    return
  endif

  " changed check.
  if s:state.changed == b:changedtick
    return
  endif
  let s:state.changed = b:changedtick

  " ignore check.
  if s:ignore()
    return
  endif

  " process.
  try
    let l:context = s:context()
    for l:source in compete#source#find()
      call s:trigger(l:context, l:source)
    endfor
    call s:keep_pum(l:context)
    call s:filter(l:context)
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    let s:error += 1
  endtry
endfunction

"
" keep_pum
"
function! s:keep_pum(context) abort
  " no completion candidates.
  let l:matches = s:get_matches()
  if len(l:matches) == 0
    return
  endif

  " cancel vim's native filter behavior.
  let l:start = min(map(copy(l:matches), 'v:val.start'))
  if l:start == s:cache.start && a:context.lnum == s:cache.lnum
    call complete(s:cache.start, s:cache.items)
  endif
endfunction

"
" trigger
"
function! s:trigger(context, source) abort
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

  let l:input = matchstr(a:context.before_line, a:source.pattern . '$')
  let l:chars = s:find(a:source.trigger_chars, a:context.before_char, '')
  if l:input !=# ''
    let l:start = (strlen(a:context.before_line) - strlen(l:input)) + 1
  elseif l:chars !=# ''
    let l:start = strlen(a:context.before_line) + 1
  else
    " if input/chars doesn't match and position was changed, discard recent items.
    if l:match.start != strlen(a:context.before_line) + 1
      let l:match.status = 'waiting'
    endif
    return
  endif

  " avoid request when start position does not changed.
  if l:start == l:match.start && !l:match.incomplete
    return
  endif

  let l:match.id += 1
  let l:match.status = l:match.start == l:start ? 'completed' : 'processing'
  let l:match.lnum = a:context.lnum
  let l:match.start = l:start
  let l:match.items = []
  call a:source.complete(
  \   extend({
  \     'start': l:start,
  \     'input': l:input,
  \     'abort': s:create_abort_callback(a:context, a:source, l:match.id),
  \   }, a:context, 'keep'),
  \   s:create_complete_callback(a:context, a:source, l:match.id)
  \ )
endfunction

"
" filter
"
function! s:filter(context) abort
  let l:ctx = {}
  function! l:ctx.callback() abort
    let s:timer_id = -1

    if s:ignore()
      return
    endif

    " no completion candidates.
    let l:matches = s:get_matches()
    if len(l:matches) == 0
      return
    endif

    let l:context = s:context()
    let l:start = min(map(copy(l:matches), 'v:val.start'))
    let l:input = strpart(l:context.before_line, l:start - 1, strlen(l:context.before_line) - (l:start - 1))

    let l:prefix_items = []
    let l:fuzzy_items = []

    for l:match in l:matches
      let l:source = compete#source#get_by_name(l:match.name)
      let l:short = strpart(l:context.before_line, l:start - 1, l:match.start - l:start)

      let l:prefix = '^\V' . l:input
      let l:fuzzy = '^.*\V' . join(split(l:input, '\zs'), '\m.*\V')

      if strlen(l:input) >= 0
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
      else
        let l:prefix_items += l:match.items
      endif
    endfor

    let l:items = l:prefix_items + l:fuzzy_items

    " complete.
    call complete(l:start, l:items)
    let s:cache = {
    \   'lnum': l:context.lnum,
    \   'start': l:start,
    \   'items': l:items
    \ }
  endfunction

  " throttle.
  if s:timer_id != -1
    return
  endif
  let s:timer_id = timer_start(100, { -> l:ctx.callback() })
endfunction

"
" get_matches
"
function! s:get_matches() abort
  let l:matches = values(s:state.matches)
  let l:matches = filter(l:matches, 'v:val.status ==# "completed" || v:val.status ==# "processing"')
  let l:matches = sort(l:matches, { a, b -> get(b, 'priority', 0) - get(a, 'priority', 0) })
  return l:matches
endfunction

"
" context
"
function! s:context() abort
  return {
  \   'bufnr': bufnr('%'),
  \   'lnum': line('.'),
  \   'col': col('.'),
  \   'before_char': s:get_before_char(),
  \   'before_line': getline('.')[0 : col('.') - 2],
  \ }
endfunction

"
" create_complete_callback
"
function! s:create_complete_callback(context, source, id) abort
  let l:ctx = {}
  function! l:ctx.callback(context, source, id, match) abort
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

  return function(l:ctx.callback, [a:context, a:source, a:id])
endfunction

"
" create_abort_callback
"
function! s:create_abort_callback(context, source, id) abort
  let l:ctx = {}
  function! l:ctx.callback(context, source, id) abort
    let l:match = get(s:state.matches, a:source.name, {})
    if has_key(l:match, 'id')
      let l:match.id = a:id + 1
      let l:match.status = 'waiting'
    endif
  endfunction
  return function(l:ctx.callback, [a:context, a:source, a:id])
endfunction

"
" ignore
"
function! s:ignore() abort
  " mode check.
  if mode()[0] !=# 'i'
    return v:true
  endif

  " selected check.
  let l:complete_info = complete_info(['selected'])
  if l:complete_info.selected != -1
    return v:true
  endif

  return v:false
endfunction

"
" find
"
function! s:find(haystack, needle, ...) abort
  let l:def = get(a:000, 0, '')
  let l:index = index(a:haystack, a:needle)
  return l:index != -1 ? a:haystack[l:index] : l:def
endfunction

"
" get_before_char
"
function! s:get_before_char() abort
  let l:current_lnum = line('.')

  let l:lnum = l:current_lnum
  while l:lnum > 0
    if l:lnum == l:current_lnum
      let l:text = getline('.')[0 : col('.') - 2]
    else
      let l:text = getline(l:lnum)
    endif
    let l:match = matchlist(l:text, '\([^[:blank:]]\)\s*$')
    if get(l:match, 1, v:null) isnot v:null
      return l:match[1]
    endif
    let l:lnum -= 1
  endwhile

  return ''
endfunction

