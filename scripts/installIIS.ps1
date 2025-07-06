Install-WindowsFeature -Name Web-Server -IncludeManagementTools
$hostName = $env:COMPUTERNAME
$html = @"
<!DOCTYPE html>
<html>
  <head><title>IIS on $hostName</title></head>
  <body>
    <h1>Served by: $hostName</h1>
  </body>
</html>
"@
$html | Out-File -FilePath 'C:\inetpub\wwwroot\default.htm' -Encoding utf8

