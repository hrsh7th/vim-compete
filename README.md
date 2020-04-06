# vim-compete

auto completion engine.


# status

Works but not documented.


# install

#### vim-plug
```viml
Plug 'hrsh7th/vim-compete'
```


# config

#### `g:compete_enable = v:true`

Type: boolean

You can disable compete via this value.


#### `g:compete_keyword_range = 1000`

Type: number

You can specify range to cache keywordss.
If you specify 100, `compete` will cache lines thats in the range of `line('.') - 100` ~ `line('.') + 100`.


#### `g:compete_throttle_time = 200`

Type: number

You can specify delay time to filter items.


#### `g:compete_source_wait_time = 200`

Type: number

You can specify delay time to wait incomplete sources.


#### `g:compete_linewise_chars = [',', '{']`

Type: string[]

You can specify trigger chars thats will be searched in the current or above lines.


#### `g:compete_fuzzy = v:true`

Type: boolean

You can disable fuzzy matching via this value.


#### `g:compete_patterns = { ... }`

Type: dict

You can specify keyword patterns per filetype.
The key is filetype and value is vim-regex.


#### `g:compete_min_length = 1`

Type: number

You can specify the length to starting auto-completion.


# built-in source

#### buffer

Priority: -1

Keyword completion.

#### file

Priority: 100

Filepath completion.


# feature

#### Well handling multi start position
- multi sources support is easy but does not easy to support multi start position
    - `compete` supports `complete start position` `word pattern position` and `trigger character position`.

#### Simple `locality` and `frequency` sorting.
- `compete` will sort items to prefer frequency or locality.

#### Async throttled filtering with no flicker
- auto completion plugin filter items but vim's native completion feature does it too
  - auto completion plugin should cancel vim's native completion feature to reduce flicker
  - for example, `compete` skips some user input to improve performance but screen does not flick

