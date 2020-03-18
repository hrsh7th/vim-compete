let s:error = 0
let s:filter_timer_id = -1
let s:complete_timer_id = -1
let s:state = {
\   'changedtick': -1,
\   'start': -1,
\   'input': '',
\   'items': [],
\   'time': reltime(),
\   'matches': {},
\ }

"
" on_clear
"
function! compete#on_clear() abort
  let s:state = {
  \   'changedtick': -1,
  \   'start': -1,
  \   'input': '',
  \   'items': [],
  \   'time': reltime(),
  \   'matches': {},
  \ }
endfunction

"
" compete#pattern
"
function! compete#pattern(...) abort
  let l:pattern = get(get(a:000, 0, {}), 'pattern', 0)
  let l:pattern = (l:pattern is 0 ? get(g:compete_patterns, &filetype, 0) : l:pattern)
  let l:pattern = (l:pattern is 0 ? s:get_pattern() : l:pattern)
  return l:pattern
endfunction

"
" compete#on_change
"
function! compete#on_change() abort
  " error check.
  if s:error > 10
    return
  endif

  " changedtick check.
  if s:state.changedtick == b:changedtick
    return
  endif
  let s:state.changedtick = b:changedtick

  if complete_info(['selected']).selected != -1
    return
  endif

  " process.
  try
    let l:context = s:context()
    let l:starts = []
    for l:source in compete#source#find()
      let l:start = s:trigger(l:context, l:source)
      if l:start >= 1
        call add(l:starts, l:start)
      endif
    endfor
    if len(l:starts) > 0
      let s:state.start = min(l:starts)
      let s:state.input = strpart(l:context.before_line, s:state.start - 1, l:context.col - l:start + 1)
      call s:filter(l:context)
    else
      let s:state.start = -1
      let s:state.input = ''
    endif
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    let s:error += 1
  endtry
endfunction

"
" trigger
"
function! s:trigger(context, source) abort
  if !has_key(s:state.matches, a:source.name)
    let s:state.matches[a:source.name] = {
    \   'id': 0,
    \   'source': a:source,
    \   'status': 'waiting',
    \   'lnum': -1,
    \   'start': -1,
    \   'items': [],
    \   'incomplete': v:false,
    \ }
  endif
  let l:match = s:state.matches[a:source.name]

  let l:input = matchstr(a:context.before_line, compete#pattern(a:source) . '$')
  let l:chars = s:find(a:source.trigger_chars, a:context.before_char, '')
  if l:chars !=# ''
    let l:start = a:context.col
  elseif l:input !=# ''
    let l:start = a:context.col - strlen(l:input)
  else
    " if input/chars doesn't match and position was changed, discard recent items.
    if l:match.start != a:context.col
      let l:match.id += 1
      let l:match.status = 'waiting'
      let l:match.items = []
      let l:match.lnum = -1
      let l:match.start = -1
      let l:match.incomplete = v:false
      return -1
    endif
    return l:match.start
  endif

  " avoid request when start position does not changed.
  if l:start == l:match.start && !l:match.incomplete
    return l:start
  endif

  let l:match.id += 1
  let l:match.lnum = a:context.lnum
  let l:match.status = l:match.start == l:start ? 'completed' : 'processing'
  let l:match.items = l:match.start == l:start ? l:match.items : []
  let l:match.start = l:start
  call a:source.complete(
  \   extend({
  \     'start': l:start,
  \     'input': l:input,
  \     'abort': s:create_abort_callback(a:context, a:source, l:match.id),
  \   }, a:context, 'keep'),
  \   s:create_complete_callback(a:context, a:source, l:match.id)
  \ )
  return l:match.start
endfunction

"
" filter
"
function! s:filter(context) abort
  let l:ctx = {}
  function! l:ctx.callback() abort
    if s:state.start == -1
      return
    endif

    let l:context = s:context()
    let l:prefix_items = []
    let l:fuzzy_items = []
    let l:item_count = 0

    for l:match in filter(s:get_matches(), { _, match -> match.status ==# 'completed' })
      let l:short = strpart(l:context.before_line, s:state.start - 1, l:match.start - s:state.start)
      let l:fuzzy = '^\V' . l:short . join(split(s:state.input[strlen(l:short) : -1], '\zs'), '\m.\{-}\V') . '\m.\{-}\V'

      for l:item in l:match.items
        let l:word = stridx(l:item.word, l:short) == 0 ? l:item.word : l:short . l:item.word

        " pass through
        if strlen(s:state.input) == 0
          let l:item_count += 1
          call add(l:prefix_items, extend({
          \   'word': l:word,
          \   'abbr': get(l:item, 'abbr', l:item.word),
          \ }, l:item, 'keep'))

        " match prefix.
        elseif stridx(l:word, s:state.input) == 0
          let l:item_count += 1
          call add(l:prefix_items, extend({
          \   'word': l:word,
          \   'abbr': get(l:item, 'abbr', l:item.word),
          \ }, l:item, 'keep'))

          " match fuzzy.
        elseif g:compete_fuzzy && l:word =~ l:fuzzy
          let l:item_count += 1
          call add(l:fuzzy_items, extend({
          \   'word': l:word,
          \   'abbr': get(l:item, 'abbr', l:item.word),
          \ }, l:item, 'keep'))
        endif

        if l:item_count >= g:compete_item_count
          break
        endif
      endfor
    endfor

    let s:state.time = reltime()
    let s:state.items = l:prefix_items + l:fuzzy_items

    " complete.
    call complete(s:state.start, s:state.items)
  endfunction

  " keep current pum.
  if len(s:state.items) > 0
    call complete(s:state.start, s:state.items)
  endif

  " clear recent debounce timer.
  call timer_stop(s:filter_timer_id)

  let l:time = len(s:state.time) == 0 ? g:compete_throttle : reltimefloat(reltime(s:state.time)) * 1000
  if l:time >= g:compete_throttle
    call l:ctx.callback()
  else
    let s:filter_timer_id = timer_start(g:compete_throttle, { -> l:ctx.callback() })
  endif
endfunction

"
" get_matches
"
function! s:get_matches() abort
  let l:matches = values(s:state.matches)
  let l:matches = filter(l:matches, 'v:val.status ==# "completed" || v:val.status ==# "processing"')
  let l:matches = sort(l:matches, { a, b -> get(b.source, 'priority', 0) - get(a.source, 'priority', 0) })
  return l:matches
endfunction

"
" create_complete_callback
"
function! s:create_complete_callback(context, source, id) abort
  let l:ctx = {}
  function! l:ctx.callback(context, source, id, match) abort
    let l:match = get(s:state.matches, a:source.name, {})
    if !has_key(l:match, 'id') || a:id < l:match.id
      return
    endif

    let l:context = s:context()
    if l:context.bufnr != a:context.bufnr || l:context.lnum != a:context.lnum
      return
    endif

    let l:match.status = 'completed'
    let l:match.lnum = a:context.lnum
    let l:match.items = a:match.items
    let l:match.incomplete = get(a:match, 'incomplete', v:false)

    call timer_stop(s:complete_timer_id)
    let s:complete_timer_id = timer_start(50, { -> s:filter(a:context) })
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
" context
"
function! s:context() abort
  let l:lnum = line('.')
  let l:col = col('.')
  let l:before_line = getline('.')[0 : l:col - 2]
  return {
  \   'bufnr': bufnr('%'),
  \   'lnum': l:lnum,
  \   'col': l:col,
  \   'before_char': s:get_before_char(l:lnum, l:before_line),
  \   'before_line': l:before_line,
  \ }
endfunction

"
" get_before_char
"
function! s:get_before_char(lnum, before_line) abort
  let l:lnum = a:lnum
  while l:lnum > 0
    if l:lnum == a:lnum
      let l:text = a:before_line
    else
      let l:text = getline(l:lnum)
    endif
    let l:char = matchstr(l:text, '\([^[:blank:]]\)\ze\s*$')
    if l:char !=# ''
      return l:char
    endif
    let l:lnum -= 1
  endwhile

  return ''
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
" get_pattern
"
let s:patterns = {}
function! s:get_pattern() abort
  if has_key(s:patterns, &iskeyword)
    return s:patterns[&iskeyword]
  endif

  let l:keywords = split(&iskeyword, ',')
  let l:keywords = filter(l:keywords, { _, k -> match(k, '\d\+-\d\+') == -1 })
  let l:keywords = filter(l:keywords, { _, k -> k !=# '@' })
  let l:pattern = '\%(' . join(map(l:keywords, { _, v -> '\V' . escape(v, '\') . '\m' }), '\|') . '\|\w\)*'
  let s:patterns[&iskeyword] = l:pattern
  return l:pattern
endfunction

