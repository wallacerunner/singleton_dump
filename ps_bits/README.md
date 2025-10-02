# `ps_bits`
Random PowerShell things that don't deserve their own folder.

## `check_toasts.ps1`
Plan was to pull notifications, then send them elsewhere. Turns out Windows doesn't have unified notifications stream, and different rogue agents use their own notification solutions (I'm looking at you, MS Teams).

## `croc.bat` and `croc.ps1`
How to launch croc utility on a device that is not guaranteed to have it? Make a script that first checks if the utility is present and of latest version, downloads latest release if not, then executes it with original parameters. And pack it into a '.bat' file so it can be double-clicked. Works, but only on more current Win's, and the target device had Win7 sadly.

## `form.ps1`
Just a snippet for creating a GUI window.

## `helpers.ps1`
Collection of sparsely tested functions that I deemed useful to try and write.

* `Hyper-Tee` - write input to file, to console and to pipe
* `For-*` - `foreach`, except parallelized to jobs or threads
* `get-deps`, `add_function_to_remote`, 'Remote-Exec' - sometimes you need to run a function on a remote host, but it can depend on some other functions. These help, though are not tested in wild.
* `SessionTable` class - Hashtable extention with in-built remote session creation for key misses.
* `Get-MaxNumber` - the fastest way to get max number in array in PS.
* `For-Line` - turns out `switch` is very fast when dealing with lines.
* `compress`, `decompress` - dependency-less compression functions I found somewhere.
* `gzip` - gzips given file. Should be relatively fast and low memory, as deals with streams.
* `Make-Randomfile` - you can't evaluate compression without having some 4G files of random data. Not exactly fast, as RNG gets exhausted fast, but does the job.
* `memsize` - some estimate of given variable's size. Not sure how accurate it is though.

## `pass_checker.ps1`
Checks with russian Ministry of Foreign Affairs website the status of a passport by set request ID. Creates a nice notification in Win10+.

## `ps1tobat.ps1`
Converts given PS script into a :bat:, because :bat: can be doubleclicked in windows.

## `reverse_string_profiling.ps1`
What is the fastest way to reverse a string in PS? Documents the variations and tests that I did to figure this out. Turns out the dumbest `for`-loop with `+-=`-ing a string is best - it is the fastest on cold starts and remains decent on long executions.

## `string_as_dataholder.ps1`
Experiment in using strings - the simplest data type in PS - as key-value data holder. Proved it is 5+ times as slow as hashtables and objects, but 10+ times smaller than either. Might be useful if processing gigs of data.

## `weather.ps1`
Experiment in drawing seemingly windowless text on screen, with added bonus of grabbing weather data from some nearby radio station.

