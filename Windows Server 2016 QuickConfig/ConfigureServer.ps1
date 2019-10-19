# Quickly configure basic settings on Windows Server 2016.
# [Geared toward lab environments - make sure to update /files/variables.ps1 with your own details]
#
# Shane Sexton
# 10 15 2019
#
#

. (Join-Path $PSScriptRoot "\Files\Variables.ps1") 
. (Join-Path $PSScriptRoot "\Files\Functions.ps1")

#
# Change hostname
#
Write-Host `nChanging hostname -ForegroundColor Green
Set-Hostname $HOSTNAME
Write-Host `tDone.

#
# Change timezone
#
Write-Host `nSetting timezone -ForegroundColor Green
Set-NewTimeZone $TIMEZONE
Write-Host `tDone.

#
# Configure static IPs on nices
#
Write-Host `nConfiguring network. -ForegroundColor Green
Configure-Network $IPCONFIG
Write-Host `tDone.

#
# Switch to high-performance power plan
#
Write-Host `nSetting High Performance power plan -ForegroundColor Green
Set-HighPerformancePowerPlan
Write-Host `tDone.

#
# Disable unnecessary services
#
$services = Import-CsvToArray (Join-Path $PSScriptRoot "\Files\services.csv")
Write-Host Disabling unnecessary services. -ForegroundColor Green
foreach ($service in $services) {
  Disable-Service $service.Name $service.'Full Name'
  }

#
# Disable IE ESC
#
Write-Host Disabling IE Enhanced Security Configuration -Foregroundcolor Green
Disable-ieESC
Write-Host `tDone.
