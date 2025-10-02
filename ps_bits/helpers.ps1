function Hyper-Tee {
	param ($input, $file=$null)
	$input.ForEach({
		Write-Host $_
		if ($file) { $_ >> $file }
		$_
	})
}

function For-Jobbed {
	param ([scriptblock]$process, $threads=8)
	$jobs = [System.Collections.Generic.List[object]]::new()
	for () {
		while ((($jobs.State | ? { $_ -eq 'Running' }).Count -lt $threads) -and $input.MoveNext()) {
			$jobs.Add( (Start-Job -scriptblock $process -argumentlist $input.Current) )
		}
		
		$jobs | ? { $_.State -eq 'Completed' } | % {
			Receive-Job $_
		}
		
		if ( ($null -eq $input.Current) -and (($jobs.State | ? { $_ -eq 'Running' }).Count -eq 0) ) {
			$jobs | Remove-Job
			break
		}
	}
}

function For-Threaded {
	param ([scriptblock]$process, $threads=8)
	$iss   = [initialsessionstate]::CreateDefault2()
	$pool  = [runspacefactory]::CreateRunspacePool(1, $threads, $iss, $Host)
	$pool.ThreadOptions = [Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
	$pool.Open()

	$tasks  = foreach ($i in $input) {
		$ps = [powershell]::Create().AddScript($process).AddArgument($i)
		$ps.RunspacePool = $pool

		@{ Instance = $ps; AsyncResult = $ps.BeginInvoke() }
	}

	foreach($task in $tasks) {
		$task['Instance'].EndInvoke($task['AsyncResult'])
		$task['Instance'].Dispose()
	}
	$pool.Dispose()
}

function get-deps {
	param ($name)
	$ret = [System.Collections.Generic.List[object]]::new()
	$command = Get-Command $name
	if ($command.CommandType -eq 'Alias') { $command = $command.ReferencedCommand }
	if (-not $command.ScriptBlock) { return }
	$ret.Insert(0, $command)
	$ast = $command.ScriptBlock.Ast
	$ast.findall({$args[0] -is [System.Management.Automation.Language.CommandAst]}, $true) | % { $_.commandelements[0].value } | sort -Unique | % { $ret.Insert(0, (get-deps $_)) }
	return $ret
}

function add_function_to_remote {
	param(
		$name
		, $session
	)
	$set = get-deps $name
	
	Invoke-Command -Session $session -ScriptBlock { 
		$using:set | % {
			$cmd = $_
			$remote_commands = (Get-Command -ListImported -all).Name
			if ($cmd.Name -notin $remote_commands) {
				$null = New-Item -Path function: -name $cmd -Value $cmd.ScriptBlock
			}
		}
	}
}


Class SessionsTable : Hashtable {
	GetConnection ([string]$server) {
		if(-not $this.ContainsKey($server)) {
			$this[$server] = New-PSSession -ComputerName $server
		}
		$this[$server]
	}
}
$sessions = [SessionsTable]::new()

function Remote-Exec {
	param(
		$server
		, $function
	)
	$session = $script:sessions.GetConnection($server)
	add_function_to_remote -name $function -session $session
	Invoke-Command -Session $session -ScriptBlock { $using:function }
}

function Get-MaxNumber {
	param (
		[int[]]Numbers
	)
	$MaxValue = $Numbers[0]
	foreach($num in $Numbers){
		$MaxValue = [System.Math]::Max($MaxValue,$num)
	}
	return $MaxValue
}

function For-Line {
	param ($File, $ScriptBlock)
	
	switch -File ($File){
		Default {
			$ScriptBlock.Invoke($_)
		}
	}
}

function compress {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string] $string
	)
	process {
		$inputBytes = [System.Text.Encoding]::UTF8.GetBytes($string)
		$outputBytes = New-Object byte[] ($inputBytes.Length)
		$memoryStream = New-Object IO.MemoryStream
		$gzipStream = New-Object IO.Compression.GZipStream($memoryStream, [IO.Compression.CompressionMode]::Compress)
		$gzipStream.Write($inputBytes, 0, $inputBytes.Length)
		$gzipStream.Close()

		return [Convert]::ToBase64String($memoryStream.ToArray())
	}
}

function decompress {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string] $compressedString
	)
	process {
		$inputBytes = [Convert]::FromBase64String($compressedString)
		$memoryStream = New-Object IO.MemoryStream($inputBytes, 0, $inputBytes.Length)
		$gzipStream = New-Object IO.Compression.GZipStream($memoryStream, [IO.Compression.CompressionMode]::Decompress)
		$reader = New-Object IO.StreamReader($gzipStream)
		return $reader.ReadToEnd()
	}
}

function gzip {
	param($input_file)
	$input_file = Get-Item $input_file
	$o_name = $input_file.FullName + '.gz'
	$i_name = $input_file.FullName
	$o = [System.IO.File]::Open($o_name, 'Append')
	$gz = [IO.Compression.GZipStream]::new($o, [IO.Compression.CompressionMode]::Compress)
	[system.io.file]::OpenRead($i_name).CopyTo($gz)
	$gz.Dispose()
	$o.Dispose()
}

function Make-Randomfile {
	param (
		$name
		, $size = 4GB
	)
	$buffer = [byte[]]::new(4KB)
	$rng = [System.Random]::new()
	$out = new-item -Type file -Name $name
	$ostr = $out.OpenWrite()
	do {
		$rng.NextBytes($buffer); $ostr.Write($buffer, 0, $buffer.Length)
	} while ($ostr.Length -lt $size)
	$ostr.Dispose()
	$rng.Dispose()
}


# rough estimate of memory usage in bytes by given variable
function memsize ($obj) {
	$memStream = [System.IO.MemoryStream]::new()
	$formatter = [System.Runtime.Serialization.Formatters.Binary.BinaryFormatter]::new()
	$formatter.Serialize($memStream, $obj)
	$memStream.Position = 0
	$memStream.Length
}