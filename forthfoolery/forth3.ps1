$stack = [System.Collections.Stack]::new()
class Word {
	[string] $name
	[int] $flags = 0x0
	[scriptblock] $code
}
$dictionary = [System.Collections.Generic.List[Word]]::new()
$compiling = $false

$instream = [system.console]::OpenStandardInput()
$outstream = [system.console]::OpenStandardOutput()

$flag_immediate = 0x80


function _emit ($char) {
	$script:outstream.writebyte($char)
}

function _key {
	return $script:instream.readByte()
}

function _word {
	$word = ''
	
	while ($true) {
		$key = _key
		if ($key -in (10, 13, 32)) { continue }
		elseif ($key -eq 92) { do { $key = _key } until ($key -eq 13) }
		else { break }
	}
	
	do {
		$word += [char]$key
		$key = _key
	} while ($key -notin (10, 13, 32))
	
	#write-host "_word: $word"
	return $word
}

function _write ($text) {
	for ($i = 0; $i -lt $text.length; $i ++) { _emit $text[$i] }
}

function defcode {
	param (
		$word = ''
		, $definition = {{}}
		, $flags = 0x0
	)
	$dictionary.Add([Word]@{
		name = $word
		flags = $flags
		code = $definition
	})
}

function _find ($name) {
	for($i = $script:dictionary.count -1; $i -ge 0; $i --) {
		#write-host "$($script:dictionary[$i].name) -eq $name"
		if ($script:dictionary[$i].name -eq $name) {
			#write-host 'true'
			return $i
		}
	}
	return -1
}

function docol {
	for( $i = 0; $i -lt $args.count; $i ++) {
		$script:dictionary[$args[$i]].code.Invoke()
	}
}

defcode 'find' {
	$stack.push( (_find ($stack.pop())) )
}

defcode 'code' {
	$code = ''
	$length = 0
	$name = _word
	do {
		$code += [char](_key)
		$length ++
	} while (($length -lt 7) -or ( $code.Substring($length - 7) -ne 'endcode'))
	$code = [scriptblock]::Create($code.Substring(0, $length - 7))
	defcode $name $code
}

defcode 'interpret' {
	$word = _word
	$pointer = _find($word)
	if ($pointer -ne -1) {
		if ($compiling -and -not ($dictionary[$pointer].flags -band $flag_immediate)) {
				$dictionary[-1].code = $dictionary[-1].code.ToString(), $pointer -join ' '
		} else {
			$dictionary[$pointer].code.Invoke()
		}
			
	} elseif ($word -as [int]) {
		$script:stack.push([int]$word)
		
	} else {
		_write " undefined word: $word`r`n"
	}
}

defcode 'repl' {
	$interpret = _find 'interpret'
	while ($true) {
		$dictionary[$interpret].code.invoke()
	}
}

defcode "'" {
	$string = ''
	do {
		$string += [char](_key)
	} while ($string[-1] -ne "'")
	$stack.push( $string.Substring(0, $string.length -2 ) )
}

defcode 'include' {
	$io_bak = $script:instream
	$file = Get-Item ($stack.pop())
	$script:instream = [System.IO.File]::Open($file, 'Open')
	$interpret = _find 'interpret'
	while ($script:instream.Position -lt $script:instream.Length) { 
		#write-host $script:instream.Position
		$dictionary[$interpret].code.invoke()
	}
	$script:instream.close()
	$script:instream = $io_bak
}

$stack.push('std.f3ps')
docol (_find 'include') (_find 'repl' )