##
## Citrix Delivery Controller
## Certificate Binder
##
## Shane Sexton
## 10 18 2019
##
## 

##############################
#                            #
#  FUNCTIONS (alphabetical)  #
#                            #
##############################

# Check netsh success
function Check-NetshSuccess ($rslt) {
  if ($rslt -match 'SSL Certificate successfully added') {
    Write-Host ("`t" + $rslt) -ForegroundColor Green
  } else {
    Write-Host ("`t" + $rslt) -ForegroundColor Red
  }
}

# Check return values
function Check-ReturnValue ($rtrn) {
  if (!$rtrn) { 
    Write-Host "`tExiting..." -ForegroundColor Red; Exit 
  } else { 
    Write-Host "`tDone." 
  }
}

# Confirm command before running
function Confirm-Command ($CommandStr) {

  # PromptForChoice Arguments
  $Title = "Execute the following netsh command?"
  $Choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Run", "&Cancel")
  
  # Prompt for the choice 
  $Choice = $host.UI.PromptForChoice($Title, $CommandStr, $Choices, 1)

  switch($Choice)
  {
      0 { Return $True}
      1 { Check-ReturnValue $false }
  }
}

# Acquire App ID
function Get-AppID () {
  
  # Search for ID matching "Citrix Broker Service
  try {
    $raw_id = @(Get-ItemProperty -Path HKLM:\SOFTWARE\Classes\Installer\Products\* -ErrorAction Stop | 
               Where-Object { $_.ProductName -eq "Citrix Broker Service" } | 
               Select-Object -Property ProductName, PSChildName)
  } catch [System.Management.Automation.ItemNotFoundException] {
    Write-Host "`tError finding application ID (item not found)." -ForegroundColor Yellow
    Return $False
  } catch {
    Write-Host "`tUnknown error." -ForegroundColor Yellow
    Return $False
  }

  # Format ID properly
  $clean_id = $raw_id.PSChildname.Insert(8,'-').Insert(13,'-').Insert(18,'-').Insert(23,'-')

  # Ensure it matches the correct formate
  if ($clean_id -match '^[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}$') 
    {
      Return $clean_id
    } else {
      Write-Host "`tUnknown error: `"$clean_id`" doesn't appear correctly formatted." -ForegroundColor Yellow
    }

}

# Acquire certificate fingerprint
function Get-CertificateFingerprint () {

  # List computer certificates; allow user to select appropriate certificate.
  try {
    $Certificate = @(Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction Stop | 
                     Out-GridView -Title "Select Certificate" -PassThru | 
                     Select-Object -Property ThumbPrint)
  } catch [System.Management.Automation.ItemNotFoundException] {
    Write-Host "`tError listing certificates (item not found)." -ForegroundColor Yellow
    Return $False
  } catch {
    Write-Host "`tUnknown error." -ForegroundColor Yellow
    Return $False
  }

  # Verify only one certificate is selected
  if ($Certificate.Count -ne 1) {
    Write-Host "`tPlease select a single certificate." -ForegroundColor Yellow
    Return $False
  }

  Return $Certificate.ThumbPrint
}

# Acquire IP address
function Get-IPAddress () {
  # List IP addresses; allow user to select appropriate address.
  try {
    $NetInfo = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop| Select-Object -Property InterfaceAlias,IPAddress,PrefixLength| Out-GridView -Title "Select IP Address" -PassThru) 
  } catch {
    Write-Host "`tError determining IP address." -ForegroundColor Yellow
    Return $False
  }

  # Verify only one IP address is selected
  if ($NetInfo.Count -ne 1) {
    Write-Host "`tPlease select a single IP address." -ForegroundColor Yellow
    Return $False
  }

  Return $NetInfo.IPAddress
}

# Request port number 
function Request-Port () {
  $portNum = Read-Host 
  if ($portNum -eq '') {
      Return 443
  } 

  if ($portNum -as [int] -ge 1 -and $portNum -as [int] -le 65535) {
    Return $portNum
  } else {
    Write-Host `tPlease verify port is between 1 and 65535 -ForegroundColor Yellow
    Return $False
  }
}


############
##        ##
##  MAIN  ##
##        ##
############


Write-Host "Delivery Controller Certificate Binder" -ForegroundColor Cyan
Write-Host "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-`n" -ForegroundColor DarkCyan

# Grab information, failing on errors
Write-Host "Press [Enter] to begin." -ForegroundColor Cyan -NoNewline
Read-Host

Write-Host "`n`nSelecting certificate." -ForegroundColor Cyan
$CertHash = Get-CertificateFingerprint
Check-ReturnValue $CertHash 

Write-Host "Selecting IP address." -ForegroundColor Cyan
$IPAdd = Get-IPAddress
Check-ReturnValue $IPAdd

Write-Host "Please enter a port number [443]: " -ForegroundColor Cyan -NoNewline
$Port = Request-Port
Check-ReturnValue $Port

Write-Host "Finding Application ID." -ForegroundColor Cyan
$App = Get-AppID
Check-ReturnValue $App

# Concatenate IP address and port
$IPPort = ($IPAdd + ":" + $Port)

# Display gathered information
Write-Host "`n`n`nThe following information was gathered:" -ForegroundColor Cyan
Write-Host "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-" -ForegroundColor DarkCyan -NoNewline
New-Object -TypeName PSObject -Property @{
  "Certificate Hash" = $CertHash
  "IP Address" = $IPPort
  "Application ID" = $App
  }  | Format-List 

# Show generated command (formatted for console)
Write-Host "Netsh command generated" -ForegroundColor Cyan
Write-Host "-=-=-=-=-=-=-=-=-=-=-=-" -ForegroundColor DarkCyan
Write-Host "netsh http add sslcert ipport=$IPPort `n`tcerthash=$CertHash `n`tappid={$App}"

# Actual command string
$NetshCommand = "netsh http add sslcert ipport=$IPPort certhash=$CertHash appid='{$App}'"

# If user confirms, run command
if (Confirm-Command $NetshCommand) {
  $result = (Invoke-Expression -Command $NetshCommand)
  Check-NetshSuccess $result
}
