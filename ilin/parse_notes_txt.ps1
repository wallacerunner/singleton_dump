param (
	$notes_location = '.'
	, $excluded_files = (,'.vault')
)

function _this_function_name { (Get-PSCallStack)[-2].Command }

function files {
	if (-not $args) {
		Get-ChildItem -Recurse -Exclude $excluded_files $notes_location
	} else {
		$args
	}
}

function status {
	param (
		$status = ''
		, $lines
	)
	(files $lines) | select-string -SimpleMatch " $status "
}

@('TODO', 'DOING', 'DONE', 'LATER', 'NEVER', 'WAITING') | % {
	Set-Item -Path function:global:$_ -Value {
		param([Parameter(ValueFromPipeline=$true)] $input)
		status -status (_this_function_name) -lines $input 
	}
}

function timestamps {
	files | select-string -Pattern '\[\d\d\d\d-\d\d-\d\d(?: \d\d:\d\d|)\]'
}

function on_date {
	param (
		$date = '1970-01-01'
	)
	if ($date.gettype() -ne [datetime]) {
		$date = [datetime]$date
	}
	timestamps | ? { (get-date $_.Matches[0].Value.substring(1,10)) -eq $date }
}

function today {
	$today = (Get-Date).Date
	#timestamps | ? { (get-date $_.Matches[0].Value.substring(1,10)) -eq $today }
	on_date -date $today
}

function between_dates {
	param ($after, $before)
	
	timestamps | ? { $t = (get-date $_.Matches[0].Value.substring(1,10)); ($t -ge $after) -and ($t -le $before)}
}

function this_week {
	$today = (Get-Date).Date
	$adjust = @(-6, 0, -1, -2, -3, -4, -5)
	$after = $today.AddDays($adjust[$today.DayOfWeek.value__]).Date
	$before = $after.AddDays(6)
	between_dates -before $before -after $after
}

function next_week {
	$today = (Get-Date).Date
	$adjust = @(-6, 0, -1, -2, -3, -4, -5)
	$after = $today.AddDays($adjust[$today.DayOfWeek.value__] + 7).Date
	$before = $after.AddDays(6)
	between_dates -before $before -after $after
}

function last_week {
	$today = (Get-Date).Date
	$adjust = @(-6, 0, -1, -2, -3, -4, -5)
	$after = $today.AddDays($adjust[$today.DayOfWeek.value__] - 7).Date
	$before = $after.AddDays(6)
	between_dates -before $before -after $after
}

function tag ($query) {
	$query_exp = expand_tag -query $query
	files | select-string -Pattern $query_exp
}

function expand_tag ($query) {
	#$query = '#nil'
	if ( $query[0] -in @('#', '@') ) { 
		'#(' + ((files | select-string "^$($query[0])" | Select-String -Pattern $query.Substring(1, $query.Length - 1) | % { $_.Line.Split(' ') | Select-Object -Skip 1 }) -join '|') + ')'
	} else {
		$query
	}
}

#files | select-string -Pattern '\[2025-02-27\]' .\* | % {
filter with_context {
	$match = $_
	$file = [System.IO.File]::ReadAllLines($match.Path)
	$line = $match.Line
	
	$line_with_context = [System.Collections.Generic.List[string]]::new()
	$line_with_context.Add($line)

	$level = $line.split(' ', 2)[0].Length
	$line_num = $match.LineNumber - 1
	while ( ($level -gt 0) -and ($line_num -ge 0) ) {
		$line_num --
		$current_line = $file[$line_num].TrimStart()
		if ( (-not $current_line.StartsWith('*')) -or 
			( $current_line.split(' ', 2)[0].Length -ge $level ) -or 
			(-not $current_line)) {
			continue
		} else {
			$line_with_context.Insert(0, $file[$line_num])
			$level --
		}
	}
	
	$line_num = $match.LineNumber - 1
	$level = $line.split(' ', 2)[0].Length
	while ( $line_num -lt ($file.Count - 1) ) {
		$line_num ++
		$current_line = $file[$line_num].TrimStart()
		if ( $current_line.StartsWith('*') ) {
			if ( $current_line.split(' ', 2)[0].Length -le $level ) {
				break
			} else {
				$line_with_context.Add($file[$line_num])
			}
		} elseif ( -not $current_line ) {
			continue
		} else {
			$line_with_context.Add($file[$line_num])
		}
	}
	
	$line_with_context.Add('')
	$line_with_context
}