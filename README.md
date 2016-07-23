textadept-nim
===========
Nim language plugin for Textadept with autocompletion support

Warning! Work still in progress!

<img width=50% src=https://pp.vk.me/c631525/v631525076/3f04c/Nh4RlufUSyQ.jpg><img width=50% src=https://pp.vk.me/c628719/v628719076/21f0d/hMBieQIWaio.jpg>

## Features:
* Autocomplete via nimsuggest (default on Ctrl+Space or when "." is typed)
* Documentation helper on Ctrl+H
* Goto definition on Ctrl+Shift+G
* Error highlighting when file is saved or opened
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
