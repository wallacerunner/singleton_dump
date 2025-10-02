$general_re = '^(?:(?<timestamp>\[\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?\])\s*(?<status>(?:TODO|DOING|DONE|LATER|NEVER)(\:\[\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?\])?)?)?\s?(?<text>.*$)'

function parse_line($line) {
	(([regex]$re).Matches($line) | select groups).Groups | ? { $_.Success -eq $true -and $_.Name -ne 0} | % { 
		$token = $_
		switch $token.Name {
			'timestamp' {}
			'status' {}
			'text' { parse_line_text($token.Value) }
		}
	}
}

$special_bits_re = '(?<key>[a-zA-Z0-9\-_]+:(?(?=\[)\[\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2}:\d{2})?\]|\S+))|(?<tag>#\w+)|(?<addr>@\w+)'

function parse_line_text($text) {
	(([regex]$special_bits_re).Matches($text) | select groups).Groups | ? { $_.Success -eq $true -and $_.Name -ne 0} | % {
		$token = $_
		switch $token.Name {
			'tag' {}
			'addr' {}
			'key' {}
		}
	}
}