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


#### `g:compete_patterns = { ... }`

Type: dict

You can specify keyword patterns per filetype.
The key is filetype and value is vim-regex.

