textadept-nim
===========
Nim language plugin for Textadept with autocompletion support

Warning! Work still in progress!

## Features:
* Autocomplete via nimsuggest (default on Ctrl+Space or when "." is typed)
* Documentation helper on Ctrl+H
* CallTip popups when brace is opened
* Project build support
* Compile command depends on backend defined in related nimble file
* All source files from project involved to suggestion generation

## Requirements
* nimsuggest 
* nim compiller (for compilation support)
* nimble (for project building)

## Installation
Clone this repository to "~/.textadept/modules/" and put following line into your "~/.textadept/init.lua":
``` lua
require "textadept-nim"
```
