[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")

$ids = @{
	"Citizen 1" = 2000603010000000000000000
}


function Show-Notification {
    [cmdletbinding()]
    Param (
        [string]
        $ToastTitle,
        [string]
        [parameter(ValueFromPipeline)]
        $ToastText
		, $tag = "PowerShell"
		, $group = "PowerShell"
		, $timeout = 1
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
    ($RawXml.toast.visual.binding.text|where {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($ToastText)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = $tag
    $Toast.Group = $group
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes($timeout)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
    $Notifier.Show($Toast);
}


$ids.keys | ForEach-Object {
	$name = $_
	$id = $ids[$name]
	$data = curl.exe "https://info.midpass.ru/api/request/$id" | convertfrom-json
	
	$statuses = $data.passportStatus.name -join ', '
	$percent = $data.internalStatus.percent
	Show-Notification -ToastTitle "$name's pass is $percent % ready" -ToastText $statuses -timeout 600 -tag $name
	Start-Sleep 5
}



