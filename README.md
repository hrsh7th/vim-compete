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


#### `g:compete_throttle = 200`

Type: number

You can specify delay time to filter items.


#### `g:compete_fuzzy = v:true`

Type: boolean

You can disable fuzzy matching via this value.


#### `g:compete_item_count = 30`

Type: number

You can specify max item count.
`compete` does not sort and show items that over this value.

#### `g:compete_history_path = expand('~/.compete_history')`

Type: string

You can specify completion history file path.
This file will used to sort items.


#### `g:compete_patterns = { ... }`

Type: dict

You can specify keyword patterns per filetype.
The key is filetype and value is vim-regex.


# built-in source

#### buffer

Priority: -1

Keyword completion.

#### file

Priority: 100

Filepath completion.


# feature

#### Well handling multi sources
- multi sources support is easy but does not easy to support multi start position
  - `compete` aims to well handle it

#### Simple `locality` and `frequency` sorting.
- `compete` will sort items to prefer frequency or locality.

#### Async throttled filtering with no flicker
- auto completion plugin filter items but vim's native completion feature does it too
  - auto completion plugin should cancel vim's native completion feature to reduce flicker
  - for example, `compete` skips some user input to improve performance but screen does not flick

