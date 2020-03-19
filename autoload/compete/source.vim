let s:id = 0
let s:sources = {}

"
" compete#source#register
"
function! compete#source#register(source) abort
  if !has_key(a:source, 'name')
    throw 'source.name is required.'
  endif
  if !has_key(a:source, 'complete')
    throw 'source.complete is required.'
  endif

  let s:id += 1
  let a:source.filetypes = get(a:source, 'filetypes', ['*'])
  let a:source.trigger_chars = get(a:source, 'trigger_chars', [])
  let a:source.min_length = get(a:source, 'min_length', 1)
  let s:sources[s:id] = a:source
  return s:id
endfunction

"
" compete#source#unregister
"
function! compete#source#unregister(source_id) abort
  call remove(s:sources, a:source_id)
endfunction

"
" compete#source#get_by_name
"
function! compete#source#get_by_name(name) abort
  return get(filter(values(s:sources), { _, source -> source.name == a:name }), 0, v:null)
endfunction

"
" compete#source#find
"
function! compete#source#find() abort
  return filter(values(s:sources), 'index(v:val.filetypes, &filetype) != -1 || index(v:val.filetypes, "*") != -1')
endfunction

