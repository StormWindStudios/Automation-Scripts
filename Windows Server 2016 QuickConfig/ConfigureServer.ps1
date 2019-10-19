# Quickly configure basic settings on Windows Server 2016.
# [Geared toward lab environments - make sure to update /files/vars.ps1 with your own details]
#
# Shane Sexton
# 10 15 2019
#
#

. (Join-Path $PSScriptRoot "\Files\Variables.ps1") 
. (Join-Path $PSScriptRoot "\Files\Functions.ps1")


Write-Host `nChanging hostname -ForegroundColor Green
Set-Hostname $HOSTNAME
Write-Host `tDone.

Write-Host `nSetting timezone -ForegroundColor Green
Set-NewTimeZone $TIMEZONE
Write-Host `tDone.

Write-Host `nConfiguring network. -ForegroundColor Green
Configure-Network $IPCONFIG
Write-Host `tDone.

Write-Host `nSetting High Performance power plan -ForegroundColor Green
Set-HighPerformancePowerPlan
Write-Host `tDone.

$services = Import-CsvToArray (Join-Path $PSScriptRoot "\Files\services.csv")

Write-Host Disabling unnecessary services. -ForegroundColor Green
foreach ($service in $services) {
  Disable-Service $service.Name $service.'Full Name'
  }

Write-Host Disabling IE Enhanced Security Configuration -Foregroundcolor Green
Disable-ieESC
Write-Host `tDone.
