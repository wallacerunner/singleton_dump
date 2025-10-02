


$stack = [System.Collections.Stack]::new()
#$dictionary = [System.Collections.Generic.List[System.Tuple[string, int, scriptblock]]]::new()
$dictionary = @{}
$state = 0


function defcode {
	param (
		$word = ''
		, $definition = {{}}
		, $flags = 0
	)
	$dictionary[$word] = [System.Tuple]::Create($flags, $definition)
}

defcode 'drop' {
	$stack.pop() > $null
}

defcode 'swap' {
	$_temp1 = $stack.pop()
	$_temp2 = $stack.pop()
	$stack.push($_temp1)
	$stack.push($_temp2)
}

defcode 'dup' {
	$stack.push($stack.peek())
}

defcode 'over' {
	$_temp1 = $stack.GetEnumerator()
	$_temp1.MoveNext() > $null
	$_temp1.MoveNext() > $null
	$stack.push($_temp1.Current)
}

defcode 'rot' {
	$_temp1 = $stack.pop()
	$_temp2 = $stack.pop()
	$_temp3 = $stack.pop()
	$stack.push($_temp2)
	$stack.push($_temp1)
	$stack.push($_temp3)
}

defcode 'rot' {
	$_temp1 = $stack.pop()
	$_temp2 = $stack.pop()
	$_temp3 = $stack.pop()
	$stack.push($_temp1)
	$stack.push($_temp3)
	$stack.push($_temp2)
}

defcode '2drop' {
	$stack.pop() > $null
	$stack.pop() > $null
}

defcode '2dup' {
	$_temp1 = $stack.GetEnumerator()
	$_temp1.MoveNext() > $null
	$_temp2 = $_temp1.Current
	$_temp1.MoveNext() > $null
	$stack.push($_temp1.Current)
	$stack.push($_temp2)
}

defcode '2swap' {
	$_temp1 = $stack.pop()
	$_temp2 = $stack.pop()
	$_temp3 = $stack.pop()
	$_temp4 = $stack.pop()
	$stack.push($_temp2)
	$stack.push($_temp1)
	$stack.push($_temp4)
	$stack.push($_temp3)
}

defcode '?dup' {
	if ($stack.peek() -ne 0) { $stack.push($stack.peek()) }
}

defcode '1+' {
	$stack.push($stack.push() + 1)
}

defcode '1-' {
	$stack.push($stack.push() - 1)
}

defcode '4+' {
	$stack.push($stack.push() + 4)
}

defcode '4-' {
	$stack.push($stack.push() - 4)
}

defcode '+' {
	$stack.push($stack.pop() + $stack.pop())
}

defcode '-' {
	$_temp1 = $stack.pop()
	$stack.push($stack.pop() - $_temp1)
}

defcode '*' {
	$stack.push($stack.pop() * $stack.pop())
}

defcode '/mod' {
	$_temp1 = $stack.pop()
	$_temp2 = 0
	$_temp3 = [Math]::DivRem($stack.pop(), $_temp1, [ref]$_temp2)
	$stack.push($_temp2)
	$stack.push($_temp3)
}

defcode '=' {
	$stack.push( [int]($stack.pop() -eq $stack.pop()) )
}

defcode '<>' {
	$stack.push( [int]($stack.pop() -ne $stack.pop()) )
}

defcode '<' {
	$stack.push( [int]($stack.pop() -gt $stack.pop()) )
}

defcode '>' {
	$stack.push( [int]($stack.pop() -lt $stack.pop()) )
}

defcode '<=' {
	$stack.push( [int]($stack.pop() -ge $stack.pop()) )
}

defcode '>=' {
	$stack.push( [int]($stack.pop() -le $stack.pop()) )
}

defcode '0=' {
	$stack.push( [int]($stack.pop() -eq 0) )
}

defcode '0<>' {
	$stack.push( [int]($stack.pop() -ne 0) )
}

defcode '0<' {
	$stack.push( [int]($stack.pop() -lt 0) )
}

defcode '0>' {
	$stack.push( [int]($stack.pop() -gt 0) )
}

defcode '0<=' {
	$stack.push( [int]($stack.pop() -le 0) )
}

defcode '0>=' {
	$stack.push( [int]($stack.pop() -ge 0) )
}

defcode 'and' {
	$stack.push($stack.pop() -band $stack.pop())
}

defcode 'or' {
	$stack.push($stack.pop() -bor $stack.pop())
}

defcode 'xor' {
	$stack.push($stack.pop() -bxor $stack.pop())
}

defcode 'invert' {
	$stack.push(-bnot $stack.pop())
}

defcode '!' {
	Set-Item -Path Variable:($stack.pop()) -Value ($stack.pop())
}

defcode '@' {
	$stack.push( (Get-Item -Path Variable:($stack.pop())).Value )
}

defcode '+!' {
	$_temp1 = $stack.pop()
	Set-Item -Path Variable:($_temp1) -Value ( (Get-Item -Path Variable:($_temp1)).Value + $Stack.pop() )
}

defcode '-!' {
	$_temp1 = $stack.pop()
	Set-Item -Path Variable:($_temp1) -Value ( (Get-Item -Path Variable:($_temp1)).Value - $Stack.pop() )
}

defcode '[' {
	$state = 1
}, $F_IMMED

defcode ']' {
	$state = 0
}


defcode '.' {
	_write " $($stack.pop())"
}

defcode 'bye' {
	exit
}


function compile {
	param (
		[string] $definition
	)
	$compiled_definition = $definition.split(' ') | interpret
}

filter interpret {
	if ($dictionary.ContainsKey($_)) {
		"`$dictionary[$($_)].Item2.Invoke();"
	} elseif ($_ -as [int]) {
		"`$stack.push($($_));"
	} else {
		#TODO: error
	}
}

function _key {
	[System.Console]::ReadKey($true)
}

defcode 'key' {
	$stack.Push( (_key) )
}

function _word {
	$word = ''
	$skipping = $false
	while ($true) {
		$key = _key
		if (-not [System.Console]::ReadKey().KeyChar) { continue }
		if ((-not $skipping) -and ($key -eq '\')) { $skipping = $true }
		if ($skipping -and ($key -eq "`n")) { $skipping = $false; continue }
		if ($skipping) { continue }
		if ($key -match '\s') { break }
		$word += $key
	}
	return $word
}

function _line {
	$line = ''
	$skipping = $false
	while ($true) {
		$key = _key
		if ((-not $skipping) -and ($key -eq '\')) { $skipping = $true }
		if ($skipping -and ($key.Key -eq 'ENTER')) { $skipping = $false; continue }
		if ($skipping) { continue }
		if ($key.Key -eq 'ENTER') { break }
		$line += $key.KeyChar
		_write $key.KeyChar
	}
	return $line
}

defcode 'word' {
	$stack.Push( (_word) )
}

function _number ($num) {
	if ( $num -as [int] ) {
		return [int]$num
	} else {
		return $null
	}
}

function interpret {
	
	while ($true) {
		
		$_temp1 = _word
		$definition = ''
		
		if ( $dictionary.ContainsKey($_temp1) ) {
			# word is defined in dictionary
			if ( $dictionary[$_temp1][0] -band $F_IMMED ) {
				$dictionary[$_temp1][1].Invoke()
			} else {
				if ( $state -eq 1 ) {
					# execution mode
					$dictionary[$_temp1][1].Invoke()
				} else {
					# compiling mode
					$definition += $dictionary[$_temp1][1].ToString() + ';'
				}
			}
		} elseif ( _number($_temp1) ) {
			# word is a literal number
			$num = _number($_temp1)
			if ( $state -eq 1 ) {
				# execution mode
				$stack.push($num)
			} else {
				# compiling mode
				$definition += "`$stack.push($num);"
			}
		} else {
			# word can't be parsed
			Write-Host "PARSE ERROR: $_temp1"
		}
	}
}


function repl($input) {
	$tokens = $input -split ' '
	#foreach ($token in $tokens) {
	for ($i=0; $i -lt $tokens.Count; $i++){
		if (-not $tokens[$i]) { continue }
		$token = $tokens[$i]
		if ($defining) {
			if ($token -eq ';') {
				$script:dictionary[$newWord] = [System.Tuple]::Create( 0, [scriptblock]::Create($newWordBody -join '; ') )
				$defining = $false
				$newWord = ""
				$newWordBody = @()
			} else {
				try {
					$newWordBody += $script:dictionary[$token].Item2.ToString()
				}
				catch {
					_write "Error: $_"
					$newWord = ""
					$newWordBody = @()
					$defining = $false
					
				}
			}
		} elseif ($token -eq ':') {
			$defining = $true
			$i++
			$newWord = $tokens[$i]
		} elseif ($script:dictionary.ContainsKey($token)) {
			try {
				$script:dictionary[$token].Item2.Invoke()
			}
			catch {
				_write "Error: $_"
			}
		} elseif ($token -match '^\d+$') {
			$script:stack.push([int]$token)
		} else {
			_write " undefined word: $token"
		}
	}
}

function _write ($text) {
	[System.Console]::Write($text)
}

$F_IMMED = 0x80
$F_HIDDEN = 0x20

<#
$test.split(' ') | ForEach-Object {
	if ( -not $_ ) { return }
	$word = $_
	$dictionary[$word].Item2.Invoke()
}
#>

$test = ': double dup + ;'
$test | repl
#$dictionary['double']

while ($true) {
	_write '> '
	_line | repl
	_write " ok`r`n"
}