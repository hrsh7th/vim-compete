# vim-compete

auto completion engine.


# status

Works but not documented.


# install

### vim-plug
```viml
Plug 'hrsh7th/vim-compete'
```

# mapping

#### `<Plug>(compete-force-refresh)`

Invoke completion ignoring `g: compete_min_length`.

You can mapping as following to confirm or cancel completion with `<CR>`/`<Esc>`.

```viml
imap <expr><CR>  pumvisible() ? compete#close({ 'confirm': v:true })  : "\<CR>"
imap <expr><Esc> pumvisible() ? compete#close({ 'confirm': v:false }) : "\<Esc>"

" or

imap <expr><CR>  complete_info(['selected']).selected != -1 ? compete#close({ 'confirm': v:true })  : "\<CR>"
imap <expr><Esc> complete_info(['selected']).selected != -1 ? compete#close({ 'confirm': v:false }) : "\<Esc>"
```

If you using pear-tree or lexima.vim, You should care about it.

```viml
" For lexima.vim
imap <expr><CR> pumvisible() ? compete#close({ 'confirm': v:true }) : lexima#expand('<LT>CR>', 'i')

" For pear-tree
imap <expr><CR> pumvisible() ? compete#close({ 'confirm': v:true }) : "<Plug>(PearTreeExpand)"
```


# config

### `g:compete_enable = v:true`

Type: boolean

You can disable compete via this value.


### `g:compete_completeopt= 'menu,menuone,noinsert'`

Type: string

You can choose `completeopt` option value


### `g:compete_throttle_time = 200`

Type: number

You can specify delay time to filter items.


### `g:compete_source_wait_time = 200`

Type: number

You can specify delay time to wait incomplete sources.


### `g:compete_linewise_chars = [',', '{']`

Type: string[]

You can specify trigger chars thats will be searched in the current or above lines.


### `g:compete_fuzzy = v:true`

Type: boolean

You can disable fuzzy matching via this value.


### `g:compete_patterns = { ... }`

Type: dict

You can specify keyword patterns per filetype.
The key is filetype and value is vim-regex.


### `g:compete_min_length = 1`

Type: number

You can specify the length to starting auto-completion.


# built-in source

### buffer

Priority: -1

Keyword completion.


##### `g:compete_source_buffer_cache_range = 1000`

Type: number

You can specify range to cache keywordss.
If you specify 100, `compete` will cache lines thats in the range of `line('.') - 100` ~ `line('.') + 100`.


### file

Priority: 100

Filepath completion.


# feature

### Well handling multi start position
- Multi sources support is easy but does not easy to support multi start positions
    - `compete` supports `complete start position` `word pattern position` and `trigger character position`.

### Simple fuzzy matching
- `abcde` -> `^\Va\m.\{-}\Vb\m.\{-}\Vc\m.\{-}\Vd\m.\{-}\Ve`

### Simple frequency sorting
- Sort frequently selected items.


# TODO
- Use golang for filter/sort.

