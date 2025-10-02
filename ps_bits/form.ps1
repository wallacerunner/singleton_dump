Add-Type -AssemblyName System.Windows.Forms

$form = New-Object system.Windows.Forms.Form

$form.ClientSize         = '500,300'
$form.text               = "Запускатель бананов"

$label = New-Object System.Windows.Forms.Label
$label.Text = 'Бананы будут запущены вскоре'
$label.autosize = $true
$label.location = '20,115'

$form.controls.Add($label)

try {
    $label.text = 'Запускаем бананов'
    [void]$form.ShowDialog()
}
finally {
    echo 'cleaning up'
}