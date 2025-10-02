Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$temp = (((curl https://example.com).ParsedHtml.body.getElementsByTagName('tr') | select innertext | ? { $_ -like '*Temp*' } )[0] -split ':')[1].trimend('}')

$Form               = New-Object system.Windows.Forms.Form
$Form.StartPosition = 'CenterScreen'
$Form.AutoSize      = $true

#Important here to set the transparency key the same as the back colour.
$transKey               = "#c0c0c0"
$Form.BackColor         = $transKey # [Control]
$Form.TransparencyKey   = $transKey

$Form.Font              = [System.Drawing.Font]::New("Segoe UI", 50, [System.Drawing.FontStyle]::Regular) # Bold, Italic, Regular, Strikeout or Underline
$Form.ForeColor         = "White" # [ControlText]
$Form.FormBorderStyle   = [System.Windows.Forms.FormBorderStyle]::None
$Form.Text              = "Weather"

$Label                     = New-Object System.Windows.Forms.Label
$Label.AutoSize            = $True
$Label.Text                = $temp
$Form.Controls.Add($Label)

$Form.ShowDialog()
