textadept-nim
===========
Nim language plugin for Textadept with autocompletion support

Warning! Work still in progress!

<img width=50% src=https://pp.vk.me/c631525/v631525076/3f04c/Nh4RlufUSyQ.jpg /><img width=50% src=https://pp.vk.me/c628719/v628719076/21f0d/hMBieQIWaio.jpg />

## Features:
* Autocomplete via nimsuggest (default on Ctrl+Space or when "." is typed)
* Documentation helper (on Ctrl+H by default)
* Goto definition (on Ctrl+Shift+G by default)
* Error highlighting when file is saved or opened
* CallTip popups when brace is opened
* Project build support
* Smart replacing of both var/proc/... definition and usages (on Ctrl+G by default)
* Compile command depends on backend defined in related nimble file
* All source files from project involved to suggestion generation

## Requirements
* nimsuggest 
* nim compiller (for compilation support)
* nimble (for project building)

## Installation
Clone this repository to "\~/.textadept/modules/" and put following line into your "\~/.textadept/init.lua":
``` lua
require "textadept-nim"
```
It's possible to change default key bindings by editing "~/.textadept/modules/init.lua"

## Autocompletion icon meanings
### Compile-time related objects
Compile-time related objects have a orange background color

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skConditional.svg /> - Conditional argument

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skMacro.svg /> - Macro

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skTemplate.svg /> - Template

### Containers
Containers have a cyan background color and sometimes are enclosed into a brackets

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skConst.svg /> - Constant value

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skEnumField.svg /> - Enum field

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skForVar.svg /> - Temporary variable inside a "for" cycle

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skField.svg /> - Object field

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skGenericParam.svg /> - Generic parameter

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skLet.svg /> - Immutable value introduced with "let" keyword

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skParam.svg /> - Procedure/method/(or other executable object) parameter

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skResult.svg /> - Implict result variable

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skTemp.svg /> - Temporary variable

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skVar.svg /> - Just a variable introduced with "var" keyword

### Executable objects
Executable objects have a green background color and brackets after the letter

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skConverter.svg /> - Converter

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skIterator.svg /> - Iterator

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skMethod.svg /> - Method

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skProc.svg /> - Procedure

### Other objects
Other objects have a purple background color and some of them should never apear, but it has been added thougth.

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skAlias.svg /> - Alias

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skDynLib.svg /> - Dynamic library

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skLabel.svg /> - Label

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skModule.svg /> - Module

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skPackage.svg /> - Package

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skStub.svg /> - Stub

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skType.svg /> - Type

<img width=2% src=https://rawgit.com/xomachine/textadept-nim/master/images/skUnknown.svg /> - Unknown object
