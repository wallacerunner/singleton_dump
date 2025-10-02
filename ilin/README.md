# ilin
Experiments in plaintext orgmode-like notes processing.

## ilin.ps1
"Insanely LInked Notes". Simple UI that should allow writing notes and at the same time searching all existing notes with what is being written. UI and search kinda work, but I wanted to redesign how search results are shown to make them clickable.

## `parse_notes.ps1`
Tried composing some crazy regexes to parse the whole line in one go.

## `parse_notes2.ps1`
Started with design list this time. This thing parses the whole set of notes into internal representation, then does search requests against this representation. Proved to be slow and consume more space than the actual notes.

## `parse_notes_txt.ps1`
Why parse anything if I can search plaintext directly? Also, why define six similar functions in code if I can create them at runtime? Didn't figure how to make it more usable beyond just a set of processing functions though.

