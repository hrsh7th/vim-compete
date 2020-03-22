let s:error = 0
let s:keywords = []
let s:filter_timer_id = -1
let s:state = {
\   'changedtick': -1,
\   'start': -1,
\   'input': '',
\   'items': [],
\   'times': [],
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
  \   'times': [],
  \   'matches': {},
  \ }
endfunction

"
" compete#on_insert_enter
"
function! compete#on_insert_enter() abort
  let l:lnum = line('.')
  let l:min_above = max([1, l:lnum - g:compete_keyword_range])
  let l:max_below = min([line('$'), l:lnum + g:compete_keyword_range + 1])

  let l:above = reverse(getline(l:min_above, l:lnum))
  let l:below = getline(l:lnum + 1, l:max_below)

  let l:above_len = len(l:above)
  let l:below_len = len(l:below)
  let l:min_len = min([l:above_len, l:below_len])

  let l:lines = []
  for l:i in range(0, l:min_len - 1)
    if strlen(l:above[l:i]) < 200
      call add(l:lines, l:above[l:i])
    endif
    if strlen(l:below[l:i]) < 200
      call add(l:lines, l:below[l:i])
    endif
  endfor

  if l:above_len > l:min_len
    let l:lines += filter(l:above[l:min_len : -1], 'strlen(v:val) < 200')
  endif
  if l:below_len > l:min_len
    let l:lines += filter(l:below[l:min_len : -1], 'strlen(v:val) < 200')
  endif

  let l:pattern = compete#pattern()

  let l:unique = {}
  let s:keywords = []
  for l:keyword in split(' ' . join(l:lines, ' ') . ' ', l:pattern . '\zs.\{-}\ze' . l:pattern)
    let l:keyword = trim(l:keyword)
    if len(l:keyword) > 2 && !has_key(l:unique, l:keyword)
      if !has_key(l:unique, l:keyword)

        let l:unique[l:keyword] =  1
        call add(s:keywords, l:keyword)
      endif
    endif
  endfor
endfunction

"
" compete#on_change
"
function! compete#on_change() abort
  " error check.
  if s:error > 10
    return ''
  endif

  " changedtick check.
  if s:state.changedtick == b:changedtick
    return ''
  endif
  let s:state.changedtick = b:changedtick

  if mode()[0] !=# 'i' || s:selected()
    return ''
  endif

  call s:on_change()

  return ''
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
" on_change
"
function! s:on_change(...) abort
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

    let l:start = min(l:starts)
    if len(l:starts) == 0 || l:start != s:state.start
      let s:state.start = -1
      let s:state.input = ''
      let s:state.items = []
      let s:state.times = []
      call timer_stop(s:filter_timer_id)
    endif

    if len(l:starts) > 0
      let s:state.start = l:start
      let s:state.input = strpart(l:context.before_line, s:state.start - 1, l:context.col - l:start)
      call s:filter()
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

  let [l:input, l:input_start, l:_] = matchstrpos(a:context.before_line, compete#pattern(a:source) . '$')
  let l:chars = s:find(a:source.trigger_chars, a:context.before_char, '')
  if l:chars !=# ''
    let l:start = a:context.col
  elseif l:input_start != -1 && (l:input_start + a:source.min_length + 1) <= a:context.col
    let l:start = l:input_start + 1
  else
    let l:match.id += 1
    let l:match.status = 'waiting'
    let l:match.items = []
    let l:match.lnum = -1
    let l:match.start = -1
    let l:match.incomplete = v:false
    return -1
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
function! s:filter(...) abort
  let l:time = len(s:state.times) == 0 ? g:compete_throttle : reltimefloat(reltime(s:state.times)) * 1000
  if l:time >= g:compete_throttle
    call s:on_filter()
  else
    call timer_stop(s:filter_timer_id)
    let s:filter_timer_id = timer_start(g:compete_throttle, function('s:on_change'))
  endif
endfunction

"
" on_filter
"
function! s:on_filter(...) abort
  if mode()[0] !=# 'i' || s:selected()
    return
  endif

  if s:state.start == -1
    return
  endif

  let l:context = s:context()
  let l:matches = filter(s:get_matches(), { _, match -> match.status ==# 'completed' })
  let l:prefix_items = []
  let l:prefix_icase_items = []
  let l:contain_items = []
  let l:fuzzy_items = []
  let l:item_count = 0

  for l:match in l:matches
    let l:short = strpart(l:context.before_line, s:state.start - 1, l:match.start - s:state.start)
    let l:unique = {}

    " search just prefix items.
    if l:item_count < g:compete_item_count
      let l:items = copy(l:match.items)
      let l:next_items = []
      for l:item in l:items
        if l:item_count >= g:compete_item_count
          break
        endif

        let l:item._word = stridx(l:item.word, l:short) == 0 ? l:item.word : l:short . l:item.word
        if has_key(l:unique, l:item._word)
          continue
        endif

        if l:item._word =~? '^\V' . s:state.input
          let l:item_count += 1
          let l:unique[l:item._word] = 1
          call add(l:prefix_items, extend({
          \   'word': l:item._word,
          \   'abbr': get(l:item, 'abbr', l:item.word),
          \   'equal': 1,
          \   '_priority': 1,
          \   '_just': stridx(l:item._word, s:state.input) == 0,
          \   '_source_priority': l:match.source.priority,
          \ }, l:item, 'keep'))
        else
          call add(l:next_items, l:item)
        endif
      endfor
    endif

    " search fuzzy items.
    if l:item_count < g:compete_item_count
      let l:items = l:next_items
      let l:next_items = []
      let l:fuzzy = '^\V' . l:short . join(split(s:state.input[strlen(l:short) : -1], '\zs'), '\m.\{-}\V') . '\m.\{-}\V'
      for l:item in l:items
        if l:item_count >= g:compete_item_count
          break
        endif
        if has_key(l:unique, l:item._word)
          continue
        endif

        if l:item._word =~? l:fuzzy
          let l:item_count += 1
          let l:unique[l:item._word] = 1
          call add(l:fuzzy_items, extend({
          \   'word': l:item._word,
          \   'abbr': get(l:item, 'abbr', l:item.word),
          \   'equal': 1,
          \   '_priority': 4,
          \   '_just': v:false,
          \   '_source_priority': l:match.source.priority,
          \ }, l:item, 'keep'))
        else
          call add(l:next_items, l:item)
        endif
      endfor
    endif
  endfor

  " complete.
  let s:state.times = reltime()
  let s:state.items = sort(l:prefix_items + l:fuzzy_items, function('s:compare', [l:context]))
  call complete(s:state.start, s:state.items)
endfunction

"
" get_matches
"
function! s:get_matches() abort
  let l:matches = values(s:state.matches)
  let l:matches = filter(l:matches, 'v:val.status ==# "completed" || v:val.status ==# "processing"')
  let l:matches = sort(l:matches, { a, b -> b.source.priority - a.source.priority })
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

    call timer_stop(s:filter_timer_id)
    let s:filter_timer_id = timer_start(g:compete_throttle, function('s:on_change'))
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
      let l:match.id += 1
      let l:match.status = 'waiting'
      let l:match.items = []
      let l:match.lnum = -1
      let l:match.start = -1
      let l:match.incomplete = v:false
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
  \   'keywords': copy(s:keywords),
  \ }
endfunction

"
" get_before_char
"
function! s:get_before_char(lnum, before_line) abort
  let l:lnum = a:lnum
  while l:lnum > 0
    let l:line = l:lnum == a:lnum ? a:before_line : getline(l:lnum)
    let l:char = matchstr(l:line, '\([^[:blank:]]\)\ze\s*$')
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

"
" compare
"
function! s:compare(context, item1, item2) abort
  if a:item1._source_priority != a:item2._source_priority
    return a:item2._source_priority - a:item1._source_priority
  endif

  if a:item1._just != a:item2._just
    return a:item1._just ? -1 : 1
  endif

  if a:item1._priority != a:item2._priority
    return a:item1._priority - a:item2._priority
  endif

  let l:has_user_data1 = has_key(a:item1, 'user_data')
  if l:has_user_data1 != has_key(a:item2, 'user_data')
    return l:has_user_data1 ? -1 : 1
  endif

  let l:idx1 = index(a:context.keywords, a:item1.word)
  let l:idx2 = index(a:context.keywords, a:item2.word)
  if l:idx1 != -1 && l:idx2 == -1
    return -1
  endif
  if l:idx1 == -1 && l:idx2 != -1
    return 1
  endif
  return l:idx1 - l:idx2
endfunction

"
" selected
"
function! s:selected() abort
  return complete_info(['selected']).selected != -1 && !empty(v:completed_item) && strlen(get(v:completed_item, 'word')) > 0
endfunction

