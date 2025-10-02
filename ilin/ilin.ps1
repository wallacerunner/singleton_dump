param (
    $notes_folder = './notes'
)
# I Lazy in Norvegia
Add-Type -AssemblyName System.Windows.Forms

$notes = @{}
function load_notes_from_folder($folder='./notes') {
    Get-ChildItem -Recurse $folder | % { $Script:notes[$_.Name] = parse_note(Get-Content $_.FullName -Encoding UTF8) }
}

function parse_note($raw_note='') {
    if ($raw_note.Trim()[0] -eq '#') {
        $lines = $raw_note -split "`r`n"
        $title = $lines[0].TrimStart('#').Trim()
        $text = $lines[1..$lines.length] -join "`r`n"
    } else {
        $title = $null
        $text = $raw_note
    }
    return @{'title' = $title; 'text' = $text}
}

function find_definition($string='') {
    $Script:notes.GetEnumerator() | ? { $_.Value.title -eq $string }
}

function find_mentions($string='') {
    # Write-Host $string
    ($Script:notes.GetEnumerator() | ? { $_.Value.text -like "* $string *" } ).value.text -join "`r`n`r`n"
}

function find_fuzzy_match($string='') {
    $pattern = ($string -split ' ') -join '*'
    $Script:notes.GetEnumerator() | ? { $_.Value.text -like "*$pattern*" }
}

function update_autosearch() {
    $text = $script:note_field.Text
    $last_word = ($text -split ' ')[-1]
    $script:autosearch_field.Text = $null
    
    $script:autosearch_field.AppendText("definition: `r`n" + $(find_definition($last_word)) + "`r`n")
    $script:autosearch_field.AppendText("mentions: `r`n" + $(find_mentions($last_word)) + "`r`n")
    $script:autosearch_field.AppendText("fuzzy match: `r`n" + $(find_fuzzy_match($text)) + "`r`n")
}

function resize {
    $width = $script:Form.Width
    $height = $script:Form.Height
    $middle_top = [int](($width / 2))
    $fitted_width = [int](($width)/ 2) - 20
    $fitted_height = ($height - 58)
    $script:note_field.Size = $script:autosearch_field.Size = "$fitted_width,$fitted_height"
    $script:note_field.Location = '10,10'
    $script:autosearch_field.Location = "$middle_top,10"
}

function make_link {
    param(

    )
    # $para = New-Object 
    $Textlink = New-Object System.Windows.Forms.LinkLabel
    $Textlink.Text = 'text'
    $Textlink.Name = 'name'
    # $Textlink.Location = 'location'
    $Textlink.Add_LinkClicked({ $_.Link.Name | write-host})
    return $Textlink
}

$Form = New-Object Windows.Forms.Form
$Form.Text = "ILiN"
$Form.Width = 550
$Form.Height = 350
$Form.Add_Resize({resize})

$note_field = New-Object System.Windows.Forms.richtextbox
$note_field.Text = ""
# $note_field.Focused = $true
$note_field.Multiline = $true
$note_field.WordWrap = $true
$note_field.Add_TextChanged({update_autosearch})
$note_field.Add_Keydown({
    if ($_.Control -and $_.KeyCode -eq 'Enter') {
        $_.Handled = $true
        $note_field.Text | Write-Host
    }
})

$current_note_filename = New-Guid

$autosearch_field = New-Object Windows.Forms.RichTextBox
$autosearch_field.ReadOnly = $true
$autosearch_field.Text = ""
$autosearch_field.Multiline = $true
$autosearch_field.WordWrap = $true
$autosearch_field.DetectUrls = $true

# $autosearch_field.Controls.Add((make_link))
# $autosearch_field.Add_LinkClicked({write-host $_.linktext})


$Form.Controls.add($note_field)
$Form.Controls.add($autosearch_field)
resize
load_notes_from_folder($notes_folder)
$Form.ShowDialog()