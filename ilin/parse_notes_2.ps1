param (
    $folder = '.'
)
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
<#
* Чо хочу ваще.
** Даты хочу вставлять
*** походу только в редакторе
** чтоб теги работали
*** иметь определение для тега где-то, и чтоб подсасывалось хз
**** определение тега - это когда он в заголовке первого уровня - чтобы не иметь отдельный файл с определениями
*** чтоб собачки работали
**** тот же тег так-то
*** алиасы для тегов
** чтоб ТУДУ всякие можно было видеть
*** списки по статусам
*** списки по датам

* Refined goals
** list lines
*** based on date (today, any, week)
    Basically, agenda - to see what is scheduled to today, or to this week.
*** based on status (TODO, DOING, whatever)
    To see what I still need to finish.
*** based on tag(s)
    To retrieve specific data, f.e. "#vector #access" - to see how to connect to Vector.
*** combined lists (today+todo, tag+person, etc.)

* Implementation details
** line parsing
*** parse line status, timestamp, tags etc, then search via these properties
*** TODO how to deal with context?
**** make UIDs for lines, refer to context as path of those UIDs
*** TODO how to deal with multiple dates on single line?
**** suggestion: #start:[] #finish:[], date possible only at the start of line - equal to #timestamp:[]
** Folder parsing
*** DONE add autosaving marshalled VAULT to .vault
*** DONE update parts of .vault if mdate differs
*** TODO export/import to JSON for portability
** Search
*** TODO Incrementally combine search results for every search option provided
*** DOING search by date
*** DONE search by status
*** TODO search by tag value
#>

<#
'file_name' = @{
    content = [contents]
}
#>
# $VAULT = @{
#     'content' = @{}
#     'tags' = @{}
# }

function load_folder {
    param (
        $folder = ''
        , $force = $false
    )
    $VAULT = @{
        'content' = @{}
        'tags' = @{}
    }
    pushd $folder
    $vault_file_path = '.vault'
    $files_to_load = @()
    if (-not $force -and (Test-Path ($vault_file_path))) {
        # $VAULT = Get-Content $vault_file_path | ConvertFrom-Json
        $VAULT = Import-Clixml -Path $vault_file_path

        $VAULT['content'].Keys | % {
            $entry = $VAULT['content'][$_]
            # write-host $entry.content[0].line
            $file = Get-Item $entry['relative_path']
            if ($file.LastWriteTime -gt $entry.mtime) {
                $files_to_load += $file
            }
        }
        
    } else {
        $files_to_load = Get-ChildItem -Recurse -Path $folder -Exclude $vault_file_path
    }
    $files_to_load | % {
        $name = $_.Name
        $VAULT['content'][$name] = @{
            'filename' = $_.name
            'relative_path' = $_ | Resolve-Path -Relative
            'atime' = $_.LastAccessTime
            'mtime' = $_.LastWriteTime
            'ctime' = $_.CreationTime
            'content' = parse_file $_.FullName
        }
    }
    # $VAULT | ConvertTo-Json -Depth 100 -Compress > ($vault_file_path)
    $VAULT | Export-Clixml -Depth 100 -Path $vault_file_path
    $script:VAULT = $VAULT
    popd
}


$statuses = @('TODO', 'DOING', 'DONE', 'LATER', 'NEVER', 'WAITING')
$bits_re = [regex]'(?<tag>#[\p{L}\w\-]+:?(?(?=\[)\[\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2})?\]|\S+))|(?<addr>@[\p{L}\w\-]+)'
# TODO: date and state must be at the beginning of line only
$state_re = [regex]"(?<date>\[\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2})?\])|^\*+ (?<status>$($statuses -join '|'))"
$bits_re_2 = [regex]"(?<tag>#[\p{L}\w\-]+:?(?(?=\[)\[\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2})?\]|\S+))|(?<addr>@[\p{L}\w\-]+)|(?<date>\[\d{4}-\d{2}-\d{2}(?: \d{2}:\d{2})?\])|^\*+ (?<status>$($statuses -join '|'))"
function parse_file {
    param (
        $file
    )
    $lines = @()
    $context_index = 0
    $index = 0
    # $lines = (
    [System.IO.File]::ReadAllLines( ( Resolve-Path $file ), [System.Text.Encoding]::UTF8 ) | % {
    # foreach ($line in (Get-Content "$file")) {
        $line = $_
        $first_symbol = ($line.TrimStart())[0]
        $line_trimmed = $line.TrimStart().TrimStart('@*#').TrimStart()
        switch ($first_symbol) {
            '*' { $line_type = 'regular' }
            '#' { $line_type = 'tag' }
            '@' { $line_type = 'addr'}
            default { $line_type = 'note' }
        }
        
        $properties = @{}

        <#
        # processing tags and addrs
        ($bits_re.Matches($line_trimmed)).Groups | ? { $_.Success -eq $true -and $_.Name -ne 0} | % {
            $token = $_
            $token_trimmed = $token.Value.TrimStart('@#')
            $token_split = $token_trimmed -split ':'
            $token_name = $token_split[0]
            $token_value = $true
            if ($token_split.Count -gt 1) {
                $token_value = $token_split[1]
                if ($token_value -like '`[*`]') {
                    try {
                        $token_value = get-date ($token_value.Substring(1,($token_value.Length - 2)))
                    } catch {
                        # nothing to do here I think
                    }
                }
            }
            $properties[$token_name] = @{
                'value' = $token_value
                'type' = $token.Name
            }
        }
        
        # processing date and status
        ($state_re.Matches($line_trimmed)).Groups | ? { $_.Success -eq $true -and $_.Name -ne 0} | % {
            $token = $_
            $token_value = $token.Value
            if ($token.Value -like '`[*`]') {
                try {
                    $token_value = get-date ($token.Value.Substring(1, ($token.Value.Length - 2)))
                } catch {
                    # nothing to do here I think
                }
            }
            $properties[$token.Name] = @{
                'value' = $token_value
                'type' = $token.Name
            }
        }
        #>

        ($bits_re_2.Matches($line)).Groups | ? { $_.Success -eq $true -and $_.Name -ne 0} | % {
            $token = $_
            write-host $token
            $token_type = $token.Name

            switch ($token_type) {
                'tag' {
                    $token_trimmed = $token.Value.TrimStart('#')
                    $token_split = $token_trimmed -split ':'
                    $token_name = $token_split[0]
                    $token_value = $true
                    if ($token_split.Count -gt 1) {
                        $token_value = $token_split[1]
                    }
                }
                'addr' {
                    $token_name = $token.Value.TrimStart('@')
                    $token_value = $true
                }
                'date' {
                    $token_name = 'date'
                    $token_value = $token.Value
                }
                'status' {
                    $token_name = 'status'
                    $token_value = $token.Value
                }
            }

            if ($token_value -like '`[*`]') {
                try {
                    $token_value = get-date ($token_value.Substring(1,($token_value.Length - 2)))
                } catch {
                    # nothing to do here I think
                }
            }

            $properties[$token_name] = @{
                'value' = $token_value
                'type' = $token_type
            }
        }


        # processing notes
        if ($line_type -eq 'note') {
            $lines[$context_index]['note'] += $line.TrimStart()
            $lines[$context_index]['properties'] += $properties
        } else {
            # processing tags definitions
            if ($line_type -in @('tag', 'addr')) {
                $line_split = $line_trimmed -split ' '
                $properties[$line_split[0]] = @{
                    'value' = $true
                    'type' = $line_type
                }
                # TODO: more fields for tags?
                $line_split | % {
                    $VAULT['tags'][$_] = @{
                        'alias' = $line_split
                    }
                }
            }

            # generic processing
            $context_index = $index
            $lines += @{
                'line' = $line
                'properties' = $properties
                'note' = ''
            }
            $index ++
        }

    }
    return $lines
}


function search_tag {
    param(
        $tag = ''
    )
    $aliases = @($tag)
    if ($tag -in $VAULT['tags'].Keys) {
        $aliases += $VAULT['tags'][$tag]['alias']
    } 
    $VAULT['content'].Keys | %{
        $section = $VAULT['content'][$_]
        # write-host ($section.content | ConvertTo-Json)
        # if ($null -eq $section['content']) { return }
        $found_lines = $section['content'] | ? {
            ($_['properties'].GetEnumerator() | ? { $_.Value.type -eq 'tag' -and $_.Name -in $aliases } ).Count -gt 0
        }
        if ($found_lines.Count -gt 0) {
            @{
                'file' = $section['relative_path']
                'lines' = $found_lines
            }
        }
    }
}


function search_property {
    param(
        $type = ''
        , $name = ''
        , $value = $true
    )
    $aliases = @($name)
    if ($name -in $VAULT['tags'].Keys) {
        $aliases += $VAULT['tags'][$name]['alias']
    } 
    $VAULT['content'].Keys | %{
        $section = $VAULT['content'][$_]
        # if ($null -eq $section['content']) { return }
        $found_lines = $section['content'] | ? {
            ($_['properties'].GetEnumerator() | ? { $_.Value.type -eq $type -and $_.Name -in $aliases -and $_.Value.value -eq $value } ).Count -gt 0
        }
        if ($found_lines.Count -gt 0) {
            @{
                'file' = $section['relative_path']
                'lines' = $found_lines
            }
        }
    }
}


function search_date {
    param (
        $date
        , $precise = $false
    )
    $VAULT['content'].Keys | % {
        $section = $VAULT['content'][$_]
        $found_lines = $section['content'] | ? {
            (
                $_['properties'].GetEnumerator() | ? { $_.Value.value.GetType() -eq [datetime]  } | ? {
                    ($_.Value.value - $date).TotalDays -lt 1
                }
            ).Count -gt 0
        }
        if ($found_lines.Count -gt 0) {
            @{
                'file' = $section['relative_path']
                'lines' = $found_lines
            }
        }
    }
}


function search {
    param (
        [ValidateSet('tag', 'addr', 'date', 'status', 'text')] $type
        , $token = ''
        , $value = ''
        , [ValidateSet('access')]$sort_by = 'access'
        , [ValidateSet('ascending', 'descending')]$order = 'descending'
    )
    $raw_result = @{}
    switch ($type) {
        # 'tag' { $raw_result = search_tag -tag $token }
        'tag' { $raw_result = search_property -type 'tag' -name $token }
        'addr' { $raw_result = search_property -type 'addr' -name $token }
        'status' { $raw_result = search_property -type 'status' -name 'status' -value $token }
        'date' { 
            $date = [datetime]$token
            # $raw_result = search_property -type 'date' -name 'date' -value $date 
            $raw_result = search_date -date $date
        }
    }
    $raw_result | Sort-Object -Property { $_['file']['atime'] } -Descending | % {
        Write-Output $_['file']#['relative_path']
        Write-Output ($_['lines'].line -join "`r`n")
    }
}



function find_token {
    param(
        $token = ''
        , [ValidateSetAttribute('tag', 'addr', 'key', 'status', 'text')] $type
        , [ValidateSetAttribute('access')]$order_by = 'access'
    )
    $re = ''
    switch ($type) {
        'tag' { $re = "#$token" }
        'addr' { $re = "@$token" }
        'key' { $re = "#${$token}:" }
        'status' { $re = "${$token}" }
        'text' { $re = "${$token}" }
    }
    $re = [regex]$re
    $VAULT['content'].Keys | % {
        $notebook = $VAULT['content'][$_]
        for ($n = 0; $n -lt $notebook.content.Length; $n++) {
            if ($notebook.content[$n].line -match $re) {
                @($notebook.filename, $n, $notebook.content[$n])
            }
        }
    }
}


function main {

    $cmd = (Read-Host -Prompt '#> ') -split ' '
    try {

        switch ($cmd[0]) {
            'load' { load_folder $cmd[1] $cmd[2] }
            'search' { search $cmd[1] $cmd[2] $cmd[3] }
            'exit' { $script:running = $false }
            'vault' { $VAULT | ConvertTo-Json -Depth 100}
        }
    } catch {
        $_
    }
}

$lock_file = "$env:TEMP\.noteparser.lock"


if (-not (Test-Path $lock_file)) {
    $null = New-Item -Type File -Path $lock_file

    $running = $true
    $self = Get-Item $PSCommandPath
    $mtime = $self.LastWriteTime
    while ($running) {
        if ($mtime -lt (get-item $self).LastWriteTime){
            . $self
        }
        #load_folder '../notes'
        main
    }

    Remove-Item -Force $lock_file
}
