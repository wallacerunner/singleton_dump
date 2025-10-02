#10kb, 50kb, 100kb | % {$guids[$_] = 0..$_ | %{New-Guid} }
$guids = @{}
10, 16, 100, 1000 | % {$guids[$_] = 1..$_ | %{[string](New-Guid)} }

$tests = @{
    'reverse_lambda' = {
        $f = {
			param($s);
			if($s.length -gt 0){ 
				-join @($s[-1]) + $f.invokereturnasis( $s.substring(0, $s.length - 1) ) 
			} else {
				''
			}
		}
		$f.invokereturnasis($args[0])
    }
    'reverse_lambda_2' = {
        $f = {
			param($s);
			if($s.length -gt 1){ 
				-join($s[-1], $f.invokereturnasis( $s.substring(0, $s.length - 1) ) )
			} else {
				$s
			}
		}
		$f.invokereturnasis($args[0])
    }
    'reverse_foreach' = {
		$str = $args[0]
		( ( ($str.Length -1)..0 ) | % {
			$str[$_]
		} ) -join ''
    }
    'reverse_oneliner' = {
		$string = $args[0]
		[string]::Join('', $string[-1..-($string.Length)])
    }
    'reverse_oneliner_2' = {
		[string]::Join('', $args[0][-1..-($args[0].Length)])
    }
    'reverse_forloop' = {
		$originalString = $args[0]
		$reversedString = ''
		for ($i = $originalString.Length - 1; $i -ge 0; $i--) {
			$reversedString += $originalString[$i]
		}
		$reversedString
    }
    'reverse_forloop_arr' = {
		$originalString = $args[0]
		$reversedString = [System.Collections.Generic.List[char]]::new()
		for ($i = $originalString.Length - 1; $i -ge 0; $i--) {
			$reversedString.add($originalString[$i])
		}
		-join($reversedString)
    }
    'reverse_array' = {
		$arr = $args[0] -split ''
		[array]::Reverse($arr)
		$arr -join ''
    }
    'reverse_array_2' = {
		$arr = $args[0].ToCharArray()
		[array]::Reverse($arr)
		-join($arr)
    }
	'reverse_regex' = {
		([regex]::Matches($args[0],'.','RightToLeft') | ForEach {$_.value}) -join ''
	}
}

$chars = '1234567890-=qwertyuiop[]asdfghjkl;zxcvbnm,./`~!@#$%^&*()_+QWERTYUIOP{}ASDFGHJKL:ZXCVBNM<>?'.ToCharArray()

1..10 | % { $str = -join($chars | Get-Random -Count 1000000000); $tests.GetEnumerator() | % { [pscustomobject]@{name=$_.Name; time=(Measure-Command {& $_.Value $str}).TotalMilliseconds }; [gc]::Collect(); [GC]::WaitForPendingFinalizers()  } } | group name | select name, @{l='time'; e={ ($_.group | measure-object time -sum).sum / $_.group.count }} | sort time


1..10 | % { $str = -join($chars | Get-Random -Count (Get-Random -Minimum 2 -Maximum 2000)); $tests.GetEnumerator() | % { [pscustomobject]@{name=$_.Name; time=(Measure-Command {& $_.Value $str}).TotalMilliseconds }; [gc]::Collect(); [GC]::WaitForPendingFinalizers()  } } | group name | select name, @{l='time'; e={ ($_.group | measure-object time -sum).sum / $_.group.count }} | sort time

$guids.GetEnumerator() | sort name | % { $size = $_.Name; write-host "processing $size"; $_.Value } | ForEach-Object {
	$val = $_
	foreach ($test in $tests.GetEnumerator()) {
		[pscustomobject]@{
			size = $size
			test = $test.Key
			time = (Measure-Command { & $test.Value $val }).TotalMilliseconds
		}
		
		[GC]::Collect()
        [GC]::WaitForPendingFinalizers()
	}
} | group test, size | select @{l='name'; e={($_.name -split ', ')[0]}}, @{l='time'; e={ [Math]::Round( (($_.group | Measure-Object time -sum).sum / $_.group.count) , 2) } }, @{l='size'; e={ ($_.name -split ', ')[1] }} | sort size,time,name



10kb, 50kb, 100kb | ForEach-Object {
	$val = [string]$_
    $groupResult = foreach ($test in $tests.GetEnumerator()) {
        $ms = (Measure-Command { & $test.Value $val }).TotalMilliseconds

		[pscustomobject]@{
            Iterations        = $size
            Test              = $test.Key
            TotalMilliseconds = [Math]::Round($ms, 2)
        }

		[GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }

	$groupResult = $groupResult | Sort-Object TotalMilliseconds
    $groupResult | Select-Object *, @{
        Name       = 'RelativeSpeed'
        Expression = {
            $relativeSpeed = $_.TotalMilliseconds / $groupResult[0].TotalMilliseconds
            [Math]::Round($relativeSpeed, 2).ToString() + 'x'
        }
    }
}



processing 10
processing 1000
processing 3
processing 100

name             time size
----             ---- ----
reverse_forloop  0.37 10
reverse_array_2  0.43 10
reverse_oneliner 0.44 10
reverse_array    0.48 10
reverse_foreach  1.07 10
reverse_regex    1.25 10
reverse_lambda   1.68 10
reverse_lambda_2 1.71 10

reverse_oneliner 0.15 100
reverse_forloop  0.17 100
reverse_array_2  0.22 100
reverse_array    0.28 100
reverse_foreach  0.76 100
reverse_regex    0.84 100
reverse_lambda_2 1.27 100
reverse_lambda   1.31 100

reverse_oneliner 0.15 1000
reverse_forloop  0.17 1000
reverse_array_2  0.23 1000
reverse_array    0.26 1000
reverse_foreach  0.74 1000
reverse_regex     0.8 1000
reverse_lambda_2 1.24 1000
reverse_lambda   1.28 1000

reverse_forloop  0.16 3
reverse_oneliner 0.16 3
reverse_array_2  0.24 3
reverse_array    0.28 3
reverse_foreach  0.81 3
reverse_regex    0.84 3
reverse_lambda_2 1.32 3
reverse_lambda   1.46 3