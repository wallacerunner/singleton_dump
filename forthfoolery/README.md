# forthfoolery
What happens when you work in PowerShell and discover JonesForth

## forth.ps1
First attempt. Tried to follow the original to the letter, rewriting assembly instructions in PS. Forth constantly jumps between memory locations, and I couldn't figure how to elegantly do this in PS.

## forth2.ps1
Tried more abstract approach. Added per-char I/O. Main goal was loading library that would be written in plain Forth. Stumbled comma definition, but other defined words kinda work.

## forth3.ps1
Almost a success. Switched I/O to standard I/O, it allows including files seamlessly. Defined few basic words, the rest are included from `std.f3ps`. Stumbled on conditionals - Forth does some low level trickery again.

## std.f3ps
Some basic Forth words defined in inline PS. `if` doesn't work.

