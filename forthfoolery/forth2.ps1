$stack = [System.Collections.Stack]::new()
$dictionary = [ordered]@{}
$dict_entry_model = @{code=$null; flags=0x0}
$compiling = $false
$last_word = ''
$flag_immediate = 0x80

$dict_file_name = '.dict'

function load_dictionary {
	if (Test-Path $file_name) {
		$script:dictionary = Import-Clixml $dict_file_name
	}
}

function save_dictionary {
	$script:dictionary | Export-Clixml -Depth 100 -Path $dict_file_name
}

function _write ($text) {
	[System.Console]::Write($text)
}

function _key {
	[int]([System.Console]::ReadKey()).KeyChar
}

function _word {
	$word = ''
	
	while ($true) {
		$key = _key
		if ($key -eq 32) { continue }
		elseif ($key -eq 92) { do { $key = _key } until ($key -eq 13) }
		else { break }
	}
	
	do {
		$word += [char]$key
		$key = _key
	} while ($key -notin (13, 32))
	
}

function _line {
	$line = ''
	$key = ''
	while ($key -ne 13) {
		_write([char]$key)
		$line += [char]$key
		$key = _key
	}
	
	return $line
}

function _interpret {
	$args[0].split(' ') | % {
		$token = $_
		
		if ($script:dictionary.ContainsKey($token)) {
			
			if ($compiling -and -not ($dictionary[$token].flags -band $flag_immediate)) {
				$dictionary[$last_word].code += $token
			} else {
				$dictionary[$token].code.Invoke()
			}
			
		} elseif ($token -as [int]) {
			$script:stack.push([int]$token)
			
		} else {
			_write " undefined word: $token"
		}
		
		_write " ok`r`n"
	}
}

function repl {
	while ($true) {
		_line | _interpret
		
	}
}

function defcode {
	param (
		$word = ''
		, $definition = {{}}
		, $flags = 0x0
	)
	$dictionary[$word] = @{
		code = $definition
		flags = $flags
	}
}

function docol {
	for( $i = 0; $i -lt $args.count; $i ++) {
		if ($args[$i] -eq 'lit') {
			$i ++
			$script:stack.push($args[$i])
		} elseif () {}
		$script:dictionary[$args[$i]].code.Invoke()
	}
}

defcode 'bye' {
	save_dictionary
	exit
}

defcode ':' {
	$compiling = $true
	$new_word = _word
	$script:dictionary[$new_word] = $dict_entry_model.Clone()
	$last_word = $new_word
	$script:dictionary[$new_word].code = 'docol '
}

defcode ';' {
	$compiling = $false
	$script:dictionary[$last_word].code = [scriptblock]$script:dictionary[$last_word].code
}, $flag_immediate

defcode '[' {
	$compiling = $false
}

defcode ']' {
	$compiling = $true
}

defcode 'immediate' {
	$dictionary[$last_word].flags = $dictionary[$last_word].flags -bor $flag_immediate
}

defcode 'lit' {
	# $stack.push([int](_word))
}

defcode "'" {
	$word = _word
	if ($dictionary.ContainsKey($word)) {
		$stack.push( _word )
	} else {
		throw
	}
}

defcode ',' {
	
}


load_dictionary
$last_word = ([array]$dictionary.Keys)[-1]
repl
