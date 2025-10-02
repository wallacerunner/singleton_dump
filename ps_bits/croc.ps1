if (Test-Path 'croc.exe' -PathType Leaf) {
    $v = croc.exe --version
    $local_version = [System.Version]$v.Split(' ')[2].Split('-')[0].Substring(1)
    if (((Get-Date) - $(Get-Item croc.exe).LastWriteTime).Days -gt 7) {
        $check_update = $true
    } else {
        $check_update = $false
    }
} else {
    $local_version = [System.Version]'0.0.0'
    $check_update = $true
}

if ($check_update) {
    $github = 'https://github.com'
    $releases = Invoke-WebRequest "$($github)/schollz/croc/releases/latest"
    
    $remote_version = [System.Version]$releases.BaseResponse.ResponseUri.Segments[-1].Substring(1)
    
    if ($remote_version -gt $local_version) {
        $win_releases = $releases.links | Where-Object -Property innerText -Value '*win*64*' -like
        Invoke-WebRequest "$($github)$($win_releases[0].href)" -OutFile 'croc.zip'
        Expand-Archive 'croc.zip'
        Remove-Item 'croc.exe' -ErrorAction SilentlyContinue -Force
        Copy-Item 'croc/croc.exe' .
        Remove-Item ('croc.zip', 'croc') -Force -Recurse
    }   
}


