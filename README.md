# Mugwriter

Mugwriter is a standard for generating AutoHotkey files give the keyword a series of hotkey sets for typing special characters. Each layout consists of a series of `Alt + <key>` or `Alt + Shift + <key>` hotkeys that can be swapped between by switching into the "menu" layout and selecting a new layout. Each layout also comes with a "plus" layout that replacing the normal key-presses with the special characters instead of needing to use the `Alt` hotkeys.

This repo includes Ruby scripts for generating Mugwriter AutoHotkey files from both JSON files and the headers of AutoHotkey files.

## Standard

The AutoHotkey files generated by Mugwriter tools contain four sections:
* Header
* Tables
* Prepend
* Body

Mugwriter tools can generate AutoHotkey files from any file that contains properly formatted Tables and Prepend section with the Header section being optional and the body section being ignored.

### Header

The header section consists of a comment or series of comments containing information about the AutoHotkey script. The entire Header section consists of blank lines and AutoHotkey comments starting with a `;`. No line in the header should start with three or more `;` in succession.

### Tables

The Tables section consists of several Table comment blocks. The first line of each table should start with three `;` followed by the name of the table. A space is optional between the `;;;` and the table name. The rest of the lines of each table should consist of a `;` followed by a single space, followed by a single ASCII character, followed by another space, followed by either a single unicode character, or a line of AutoHotkey Code. A value containing a single unicode character is identical to the AutoHotkey code, `Send '<character>'`.

Example:
```ahk
;;; tableName
; a ඞ
;   mode := 'space'

;;; another table
; l ❣
```

There are two special tables, `_default` and `_menu`. The `_default` table defines a set of hotkey that occur in every layout unless they are overridden for that layout. The `_menu` table is treated normally, except that Mugwriter treats the table as if there is a second `_menu_Plus` table that treats each `mode` definition as using the `_Plus` form of that layout.

Consider the following `_menu` table:
```ahk
;;; _menu
; 1 menu := 'lorem'
; 2 menu := 'ipsum'
```

Mugwriter would treat this as if the following `_menu_Plus` table also existed:
```ahk
;;; _menu_Plus
; 1 menu := 'lorem_Plus'
; 2 menu := 'ipsum_Plus'
```

`_Plus` layouts have the string `_Plus` appended to their layout name and define a layout that accesses its defined special characters with normal key presses rather than `Alt` hotkeys.

### Prepend

The prepend should contain a line defining the default state of the `mode` variable, followed by any additional AutoHotkey code. The first line of the Prepend should not be a comment, and the Prepend should not contain any hotkey definitions.

Example:
```ahk
mode := '_default'
```

### Body

The body is ignored by and generated by Mugwriter tools. It contains a number of hotkey definitions with if/else statements inside them.

Example:
```ahk
!x:: {
  If (mode = 'sinhala') {
    Send '෴'
  } Else If (mode = '_menu')
    mode = 'someMode'
}
```
