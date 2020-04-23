let s:error = 0
let s:history = {}
let s:filter_timer_id = -1
let s:completed_timer_id = -1
let s:complete_queue = []
let s:insert_char = ''

let s:state = {
\   'changedtick': -1,
\   'start': -1,
\   'items': [],
\   'filter_reltime': reltime(),
\   'matches': {},
\   'input': '',
\   'revision': 0,
\   '_input': '',
\   '_revision': 0,
\ }

"
" on_clear
"
function! compete#on_clear() abort
  let s:state = {
  \   'changedtick': -1,
  \   'start': -1,
  \   'items': [],
  \   'filter_reltime': reltime(),
  \   'matches': {},
  \   'input': '',
  \   'revision': 0,
  \   '_input': '',
  \   '_revision': 0,
  \ }
endfunction

"
" compete#add_history
"
function! compete#add_history(word) abort
  let s:history[a:word] = get(s:history, a:word, 0) + 1
endfunction

"
" compete#set_insert_char
"
function! compete#set_insert_char(char) abort
  let s:insert_char = a:char
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
" compete#refresh
"
function! compete#refresh() abort
  call s:on_change(v:true)
  return ''
endfunction

"
" compete#close
"
function! compete#close(...) abort
  let l:option = get(a:000, 0, { 'confirm': v:true })

  for l:match in values(s:state.matches)
    let l:match.items = []
  endfor
  return l:option.confirm ? "\<C-y>" : "\<C-e>"
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

  " Stop when normal-mode.
  if mode()[0] !=# 'i'
    return ''
  endif

  " Stop when selecting item.
  if s:selected()
    return ''
  endif

  call s:on_change(v:false)

  return ''
endfunction

"
" on_change
"
function! s:on_change(force) abort

  try
    let l:context = s:context()

    call s:log(' ')
    call s:log(printf('before_line: `%s`', l:context.before_line))
    call s:log('on_change')

    let l:starts = []
    let l:trigger = v:false
    for l:source in compete#source#find()
      let [l:start, l:t] = s:trigger(l:context, l:source, a:force)
      let l:trigger = l:trigger || l:t
      if l:start >= 1
        call add(l:starts, l:start)
      endif
    endfor

    let l:start = min(l:starts)
    if len(l:starts) == 0 || l:start != s:state.start
      let s:state.start = -1
      let s:state.input = ''
      let s:state.items = []
      let s:state.filter_reltime = reltime()
    endif

    if len(l:starts) > 0
      let s:state.start = l:start
      let s:state.input = strpart(l:context.before_line, s:state.start - 1, l:context.col - l:start)
      if !l:trigger
        call s:filter()
      endif
    endif
  catch /.*/
    echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
    let s:error += 1
  endtry

  return ''
endfunction

"
" trigger
"
function! s:trigger(context, source, force) abort
  if !has_key(s:state.matches, a:source.name)
    let s:state.matches[a:source.name] = {
    \   'id': 0,
    \   'source': a:source,
    \   'status': 'waiting',
    \   'lnum': -1,
    \   'start': -1,
    \   'char_start': -1,
    \   'items': [],
    \   'incomplete': v:false,
    \ }
  endif
  let l:match = s:state.matches[a:source.name]

  " Get complete start col for chars and patterns.
  let l:chars = s:find(a:source.trigger_chars, a:context.before_char, '')
  let [l:input, l:input_start, l:_] = matchstrpos(a:context.before_line, compete#pattern(a:source) . '$')

  " If source state is incomplete, we should force re-complete.
  let l:force_refresh = l:match.incomplete || a:force

  let l:start = a:context.col

  " If matched trigger chars, we should force re-complete.
  let l:char_start = -1
  if l:chars !=# ''
    let l:force_refresh = v:true
    let l:char_start = a:context.col
    let l:start = l:char_start
  endif

  " If matched patterns, we should start complete.
  if l:input_start != -1
    let l:start = l:input_start + 1
  endif

  if !l:force_refresh
    " 1. pattern does not matched.
    " 2. input text does not provided.
    if l:start == -1 || l:start == a:context.col
      let l:match.id += 1
      let l:match.status = 'waiting'
      let l:match.items = []
      let l:match.lnum = -1
      let l:match.start = -1
      let l:match.char_start = -1
      let l:match.incomplete = v:false
      return [-1, v:false]
    endif

    " Avoid request when input text does not enough for min length.
    if l:start + g:compete_min_length > a:context.col
      return [l:match.start, v:false]
    endif

    " Avoid request when start position does not changed.
    if l:start == l:match.start
      return [l:match.start, v:false]
    endif
  endif

  call s:log(printf('complete: %s', a:source.name))

  let l:match.id += 1
  let l:match.lnum = a:context.lnum
  let l:match.status = l:match.start == l:start ? 'completed' : 'processing'
  let l:match.items = l:match.start == l:start ? l:match.items : []
  let l:match.start = l:start
  let l:match.char_start = l:char_start
  call a:source.complete(
  \   extend({
  \     'start': l:start,
  \     'input': l:input,
  \     'abort': function('s:abort_callback', [a:context, a:source, l:match.id]),
  \   }, a:context, 'keep'),
  \   function('s:complete_callback', [a:context, a:source, l:match.id])
  \ )
  return [l:match.start, v:true]
endfunction

"
" filter
"
function! s:filter(...) abort
  call timer_stop(s:filter_timer_id)

  let l:filter_time = reltimefloat(reltime(s:state.filter_reltime)) * 1000
  if l:filter_time >= g:compete_throttle_time || get(a:000, 0, v:false)
    call s:on_filter()
  else
    let s:filter_timer_id = timer_start(g:compete_throttle_time, function('s:on_filter'))
  endif
endfunction

"
" on_filter
"
function! s:on_filter(...) abort
  if mode()[0] !=# 'i'
    call s:log('on_filter: skip mode()[0] !=# i')
    return
  endif

  if s:selected()
    call s:log('on_filter: skip selected')
    return
  endif

  " No matching source found.
  if s:state.start == -1
    call s:log('on_filter: skip s:state.start is -1')
    return
  endif

  " Check recently completed condition.
  if s:state.revision == s:state._revision && s:state.input ==# s:state._input
    call s:log('on_filter: skip duplicate filter')
    return
  endif
  let s:state._revision = s:state.revision
  let s:state._input = s:state.input

  call s:log('>>>>> filter')

  let l:context = s:context()
  let l:prefix_just_items = []
  let l:prefix_icase_items = []
  let l:fuzzy_items = []

  for l:match in s:get_matches(['completed'])
    " We should fix word for three kind of complete start col.
    " 1. actual... s:state.start
    " 2. pattern... l:match.start
    " 3. trigger... l:match.char_start
    let l:short = strpart(l:context.before_line, s:state.start - 1, l:match.start - s:state.start)
    if l:match.char_start != -1
      let l:short .= strpart(l:context.before_line, l:match.start - 1, l:match.char_start - l:match.start)
    endif

    " Create fuzzy pattern.
    if g:compete_fuzzy
      let l:fuzzy = '^\V' . l:short . join(split(s:state.input[strlen(l:short) : -1], '\zs'), '\m.\{-}\V')
    endif

    let l:unique = {}
    for l:item in l:match.items
      let l:word = stridx(l:item.word, l:short) == 0 ? l:item.word : l:short . l:item.word
      if has_key(l:unique, l:word)
        continue
      endif
      let l:unique[l:word] = 1

      " Check first character for performance.
      if l:word[0] !~? s:state.input[0]
        continue
      endif

      if stridx(l:word, s:state.input) == 0
        call add(l:prefix_just_items, extend({
        \   'word': l:word,
        \   'equal': 1,
        \   '_as_is': stridx(l:item.abbr, l:word) == 0,
        \   '_priority': 1,
        \ }, l:item, 'keep'))
      elseif l:word =~? '^\V' . s:state.input
        call add(l:prefix_icase_items, extend({
        \   'word': l:word,
        \   'equal': 1,
        \   '_as_is': stridx(l:item.abbr, l:word) == 0,
        \   '_priority': 2,
        \ }, l:item, 'keep'))
      elseif g:compete_fuzzy
        if l:word =~? l:fuzzy
          call add(l:fuzzy_items, extend({
          \   'word': l:word,
          \   'equal': 1,
          \   '_as_is': stridx(l:item.abbr, l:word) == 0,
          \   '_priority': 3,
          \ }, l:item, 'keep'))
        endif
      endif
    endfor
  endfor

  " Priority order sort for match kind.
  let l:items = l:prefix_just_items + l:prefix_icase_items + l:fuzzy_items

  " complete.
  let s:state.filter_reltime = reltime()
  let s:state.items = sort(l:items, function('s:compare'))
  let l:completeopt = &completeopt
  set completeopt=menu,menuone,noselect
  call complete(s:state.start, s:state.items)
  let &completeopt = l:completeopt
endfunction

"
" get_matches
"
function! s:get_matches(statuses) abort
  let l:matches = values(s:state.matches)
  let l:matches = filter(l:matches, 'index(a:statuses, v:val.status) >= 0')
  let l:matches = sort(l:matches, { a, b -> b.source.priority - a.source.priority })
  return l:matches
endfunction

"
" complete_callback
"
function! s:complete_callback(context, source, id, data) abort
  let l:match = get(s:state.matches, a:source.name, {})
  if !has_key(l:match, 'id') || a:id != l:match.id
    call s:log('complete_callback: skip outdated request')
    return
  endif
  let l:match.status = 'retrieved'

  let l:context = s:context()
  if l:context.bufnr != a:context.bufnr || l:context.lnum != a:context.lnum
    call s:log('complete_callback: skip context changes')
    return
  endif

  let l:ctx = {}
  function! l:ctx.callback(context, source, id, data, match, ...) abort
    if !has_key(a:match, 'id') || a:id != a:match.id
      call s:log('complete_callback: skip outdated async')
      return
    endif

    let l:context = s:context()
    if l:context.bufnr != a:context.bufnr || l:context.lnum != a:context.lnum
      call s:log('complete_callback: skip context changes async')
      return
    endif

    let a:match.status = 'completed'
    let a:match.lnum = a:context.lnum
    let a:match.items = map(a:data.items, function('s:normalize_item', [a:source]))
    let a:match.incomplete = get(a:data, 'incomplete', v:false)
    let s:state.revision += 1
  endfunction
  call add(s:complete_queue, function(l:ctx.callback, [a:context, a:source, a:id, a:data, l:match]))

  call timer_stop(s:completed_timer_id)
  let s:completed_timer_id = timer_start(g:compete_source_wait_time, function('s:completed'))
endfunction

"
" abort_callback
"
function! s:abort_callback(context, source, id) abort
  let l:match = get(s:state.matches, a:source.name, {})
  if has_key(l:match, 'id')
    " Increment l:match.id to abort completion.
    let l:match.id += 1
    let l:match.status = 'waiting'
    let l:match.items = []
    let l:match.lnum = -1
    let l:match.start = -1
    let l:match.incomplete = v:false
  endif
endfunction

"
" completed
"
function! s:completed(...) abort
  let s:completed_timer_id = -1
  if len(s:complete_queue) > 0
    call s:log('completed')
    for l:i in range(0, len(s:complete_queue) - 1)
      call s:complete_queue[l:i]()
    endfor
    let s:complete_queue = []

    call s:filter(v:true)
  endif
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
    let l:line = l:lnum == a:lnum ? a:before_line : getline(l:lnum)
    let l:char = matchstr(l:line, '\([^[:blank:]]\)\ze\s*$')
    if l:char !=# ''
      if index(g:compete_linewise_chars, l:char) >= 0
        return l:char
      endif
      break
    endif
    let l:lnum -= 1
  endwhile

  return s:insert_char
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
" s:normalize_item
"
function! s:normalize_item(source, idx, item) abort
  let a:item.abbr = get(a:item, 'abbr', a:item.word)
  let a:item.user_data = get(a:item, 'user_data', '')
  let a:item._source_priority = a:source.priority
  let a:item._text_length = strlen(a:item.abbr)
  return a:item
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
  let l:keywords += ['_', '-']
  let l:pattern = '\%(' . join(map(l:keywords, { _, v -> '\V' . escape(v, '\') . '\m' }), '\|') . '\|\w\)\+'
  let s:patterns[&iskeyword] = l:pattern
  return l:pattern
endfunction

"
" compare
"
function! s:compare(item1, item2) abort
  if a:item1._source_priority != a:item2._source_priority
    return a:item2._source_priority - a:item1._source_priority
  endif

  if a:item1._priority != a:item2._priority
    return a:item1._priority - a:item2._priority
  endif

  if has_key(a:item1, '_sort_text') && has_key(a:item2, '_sort_text') && a:item1._sort_text !=# a:item2._sort_text
    return a:item1._sort_text - a:item2._sort_text
  endif

  if a:item1._as_is != a:item2._as_is
    return a:item2._as_is - a:item1._as_is
  endif

  if a:item1.user_data !=# '' && a:item2.user_data ==# ''
    return -1
  elseif a:item1.user_data ==# '' && a:item2.user_data !=# ''
    return 1
  endif

  if has_key(s:history, a:item1.word) || has_key(s:history, a:item2.word)
    let l:frequency1 = get(s:history, a:item1.word, -1)
    let l:frequency2 = get(s:history, a:item2.word, -1)
    if l:frequency1 != l:frequency2
      return l:frequency2 - l:frequency1
    endif
  endif

  return a:item1._text_length - a:item2._text_length
endfunction

"
" selected
"
function! s:selected() abort
  return complete_info(['selected']).selected != -1
endfunction

"
" log
"
function! s:log(...) abort
  if g:compete_debug
    echomsg join(a:000, "\t")
  endif
endfunction

