# Citrix License Server Certificate Installer
# 
# Shane Sexton
# 10 19 2019
#
# Install your exported .pfx file directly to the license server
#

# Citrix Directories
$LSDIR = "C:\Program Files (x86)\Citrix\Licensing\LS\conf"
$WSLDIR = "C:\Program Files (x86)\Citrix\Licensing\WebServicesForLicensing\Apache\conf"

# Where openssl.zip and where it's going
$OPENSSL_ARCHIVE = Join-Path $PSScriptRoot "OpenSSL.zip"
$OPENSSL_DEST = Join-Path $PSScriptRoot "OpenSSL\"

# Directory for new cert and key, and another directory for backups
$NEW_DIR = Join-Path $PSScriptRoot "New"
$BACKUP_DIR = Join-Path $PSScriptRoot "Backup"

# Back up certificates and keys
function Backup-Certs ($LSPath, $BUPath, $type) {
  $time = Get-Date -UFormat "%b%d%Y%H%M%S"
  $CertPath = Join-Path $LSPath "server.crt"
  $KeyPath = Join-Path $LSPath "server.key"
  $KeyBackupPath = Join-Path $BUPath "$type.key$time.bak"
  $CertBackupPath = Join-Path $BUPath "$type.cert$time.bak"

  # Attempt to create backup directory if none exists
  if (!(Test-Path $BUPath)) {
    try {
      Write-Host "Creating backup directory"
      $null = New-Item -Path "$BUPath" -ItemType Directory -ErrorAction Stop 
    } Catch {
      Write-Host "`t ==> Unable to create backup directory." -ForegroundColor Yellow
      Return $false
    }
  }

  # Try to back up the key
  try {
    Write-Host "Backing up $type key."
    Move-Item -Path "$KeyPath" -Destination "$KeyBackupPath" -ErrorAction Stop
    Write-Host "`t==> Done. ($BUPath)" -ForegroundColor Cyan
  } catch {
    Write-Host "`t==> Failed. Attempting to continue without backup." -ForegroundColor Yellow
    Return $True
  }
  Start-Sleep 1

  # Try to back up the cert
  try {
    Write-Host "Backing up $type cert."
    Move-Item -Path "$CertPath" -Destination "$CertBackupPath" -ErrorAction Stop
    Write-Host "`t==> Done. ($BUPath)" -ForegroundColor Cyan
  } catch {
    Write-Host "`t==> Failed." -ForegroundColor Yellow
    Return $false
  }
  Start-Sleep 1
  Return $True
}

# Clean up
function Clean-Up ($OSSLDest, $BUDest) {
  
  # Attempt to remove the extracted OpenSSL Files
  try {
  Write-Host Removing extracted OpenSSL files. 
  Remove-Item $OSSLDEST -Recurse -ErrorAction Stop
  Write-Host "`t==> Done." -ForegroundColor Cyan
  } catch {
  Write-Host "`t==> Failed to remove." -ForegroundColor Yellow
  }

  # Remove backup directory if it's empty
  if ((Get-ChildItem $BUDest | Measure-Object).Count -eq 0) {
    try {
      Write-Host Backup directory is empty. Removing. 
      Remove-Item $BUDest -ErrorAction Stop
      Write-Host "`t==> Done." -ForegroundColor Cyan
    } catch {
      Write-Host "`t==> Failed to remove." -ForegroundColor Yellow
    }
  }
}

# Decompress OpenSSL
function Decompress-OpenSSL ($OSSLPath, $OSSLDest) {
  
  # Try to extract the OpenSSL .zip
  try {
    Write-Host Decompressing OpenSSL.zip
    Expand-Archive -Path $OSSLPath -DestinationPath $OSSLDest -ErrorAction Stop
  } Catch [System.IO.IOException] {
    Write-Host "`t==> Unable to decompress (already present?)" -ForegroundColor Yellow
    Return $False
  } Catch [System.InvalidOperationException] {
    Write-Host "`t==> Unable to open OpenSSL.zip" -ForegroundColor Yellow
    Return $False
  } Catch {
    Write-Host "`t==> Unknown error." -ForegroundColor Yellow
    Return $False
  }
  Write-Host "`t==> Done." -ForegroundColor Cyan
  Return $True
}

# Extract certificates
function Extract-Certificates ($OSSLDir, $PFPath, $NewPath) {
  
  # Request extraction key and convert to correct form.
  Write-Host "Extracting certificate and key from .pfx file."
  $SecurePass = Read-Host -Prompt "Enter password for .pfx file" -AsSecureString
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
  $Pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  
  # If directory for extract key and cert not present, make one
  if (!(Test-Path $NewPath)) {
    try {
      Write-Host "Creating directory for extracted files."
      $null = New-Item -Path "$NewPath" -ItemType Directory -ErrorAction Stop 
    } Catch {
      Write-Host "`t ==> Unable to create New directory." -ForegroundColor Yellow
      Return $false
    }
  }

  # Construct commands
  $OpenSSLExe = $OSSLDir.replace(' ','` ') + "OpenSSL.exe"
  $PFXDest = $NewPath.replace(' ','` ')
  $CertExtractionCommand = $OpenSSLExe + " pkcs12 -in $PFPath -password pass:`"$Pass`" -out $PFXDest\server.crt -nokeys 2>&1"
  $KeyExtractionCommand = $OpenSSLExe + " pkcs12  -in $PFPath -password pass:`"$Pass`" -out $PFXDest\server.key -nocerts -nodes 2>&1"

  # Run commands
  $Result1 = Invoke-Expression $CertExtractionCommand
  $Result2 = Invoke-Expression $KeyExtractionCommand

  # Verify commands worked
  if ($Result1 -match ".*verified.*" -and $Result2 -match ".*verified.*") {
    Write-Host "`t==> Done." -ForegroundColor Cyan
    Return $True
    } else {
    Write-Host "`t==> Unknown error." -ForegroundColor Yellow
    Return $False
  }
}

# Verify and return directories
function Get-LSDirs ($LSPath) {
  
  # Verify that the license server directories are accessible
  try {
    Write-Host Checking: $LSPath
    $LSDir = Get-Item $LSPath -ErrorAction Stop
  } catch [System.Management.Automation.ItemNotFoundException],[System.IO.IOException] {
    Write-Host "`t==> Not found." -ForegroundColor Yellow
    Return $False
  } catch {
    Write-Host "`t==> Unknown error." -ForegroundColor Yellow
    Return $False
  }
  Write-Host "`t==> Found." -ForegroundColor Cyan
  Return $LSPath
}

# Move keys
function Move-Keys ($CtrxDir, $NewDir) {
  
  # Construct source and destination paths
  $CertDest = (Join-Path $CtrxDir "server.crt")
  $KeyDest = (Join-Path $CtrxDir "server.key")
  $CertPath = (Join-Path $NewDir "server.crt")
  $KeyPath = (Join-Path $NewDir "server.key")
  
  #Attempt to copy items
  try {
    Copy-Item -Path $CertPath -Destination $CertDest -ErrorAction Stop
    Write-Host "`t==> Done." -ForegroundColor Cyan
    Copy-Item -Path $KeyPath -Destination $KeyDest -ErrorAction Stop
    Write-Host "`t==> Done." -ForegroundColor Cyan
  } catch {
    Write-Host "`t==> Unable to move files to server directory." -ForegroundColor Yellow
    Return $false
  }
  Return $true
}

# Restart affected services
function Restart-CitrixLicensing () {
  
  # Restart Citrix licensing service
  try {
    Write-Host Restarting Citrix Licensing
    $Rslt1 = Restart-Service -Name "Citrix Licensing" -WarningAction SilentlyContinue
    Write-Host "`t==> Done." -ForegroundColor Cyan
  } catch {
    Write-Host "`t==> Error restarting Citrix Licensing." -ForegroundColor Yellow
    Return $False
  }

  # Restart CitrixWebServicesforLicensing
  try {
    Write-Host Restarting CitrixWebServicesforLicensing
    $Rslt1 = Restart-Service -Name "CitrixWebServicesforLicensing" -WarningAction SilentlyContinue
    Write-Host "`t==> Done." -ForegroundColor Cyan
  } catch {
    Write-Host "`t==> Error restarting CitrixWebServicesforLicensing." -ForegroundColor Yellow
    Return $False
  }
  Return $True
}

# Open PFX file
function Select-PFXFile () {
  
  #Pause
  Read-Host -Prompt "Press [Enter] to select certificate"
  [System.Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”)

  # Open file browser for user to select pfx file
  $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
      InitialDirectory = [Environment]::GetFolderPath('Desktop') 
      Filter = 'Personal Information Exchange (*.pfx)|*.pfx|All Files (*.*)|*.*'
      Title = "Select Certificate File to Use" }
  
  # Was file successfully selected?
  if ($FileBrowser.ShowDialog() -eq "OK") {
    Write-Host "`t==> Done." -ForegroundColor Cyan
    Return $FileBrowser.FileName
  } else {
    Write-Host "`t==> No file selected." -ForegroundColor Yellow
    Return $False
  }
}

# Test TLS connection
function Test-LSConnection () {
  # Use a compatible TLS version
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  
  # Determine FQDN
  $FQDN = ([system.net.dns]::GetHostByName("localhost")).hostname

  # List possible ports associated with web management console
  $PortList = (Get-NetTCPConnection -State Listen -OwningProcess (Get-Process -ProcessName lmadmin).id).LocalPort

  # Test each possible port
  foreach ($port in $PortList) {
    Write-Host "Testing possible web management port: $FQDN`:$Port"
    try {
      $test_connection = (Invoke-WebRequest -ErrorAction SilentlyContinue -Uri "https://$FQDN`:$Port").StatusDescription
      Write-Host "`t==> Successfully connected." -ForegroundColor Cyan
    } catch {
      Write-Host "`t==> Not this one." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 1.5
  }
}

Write-Host "`nCitrix License Server Certificate Installer." -ForegroundColor Cyan
Write-Host "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-`n`n" -ForegroundColor DarkCyan

# Check LS dir existence
Start-Sleep -Seconds 1.5
$LicenseServerDir = Get-LSDirs $LSDIR
if (!$LicenseServerDir) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit }

# Check WSL dir existence
Start-Sleep -Seconds 1.5
$WebServicesDir = Get-LSDirs $WSLDIR
if (!$WebServicesDir) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit }

# Decompress openssl.zip
Start-Sleep -Seconds 1.5
$DOResult = Decompress-OpenSSL $OPENSSL_ARCHIVE $OPENSSL_DEST
if (!$DOResult) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}

# Select PFX file
Start-Sleep -Seconds 1.5
$PFXFileInfo = Select-PFXFile
if (!$PFXFileInfo[2]) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}

# Extract key and cert from pfx file
Start-Sleep -Seconds 1.5
$ExtractResult = Extract-Certificates $OPENSSL_DEST $PFXFileInfo[2] $NEW_DIR
if (!$ExtractResult) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}

# Back up old files (LS then WSL)
Start-Sleep -Seconds 1.5
$BUResult1 = Backup-Certs $LSDIR $BACKUP_DIR "LS"
if (!$BUResult1) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}
$BUResult1 = Backup-Certs $WSLDIR $BACKUP_DIR "WSL"
if (!$BUResult1) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}

# Copy first key/cert set to LS
Start-Sleep -Seconds 1.5
Write-Host "Moving keys and certificates to server directories (set 1)."
$LSResult = Move-Keys $LSDIR $NEW_DIR
if (!$LSResult) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}

# Copy second key/cert set to WSL
Start-Sleep -Seconds 1.5
Write-Host "Moving keys and certificates to server directories (set 2)."
$WSLResult = Move-Keys $WSLDIR $NEW_DIR
if (!$WSLResult) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}

# Restart processes
Start-Sleep -Seconds 1.5
$RSResult = Restart-CitrixLicensing
if (!$RSResult) { Write-Host "`t==> Exiting." -ForegroundColor Red; Exit}

# Clean up
Start-Sleep -Seconds 1.5
Clean-Up $OPENSSL_DEST $BACKUP_DIR

# Test connection to web management console
Start-Sleep -Seconds 1.5
Test-LSConnection