# Append to log
function Append-Log ($in, $logpath) {
  try {
    $LogEntry = "$(Get-Date -Format 'HH:MM:ss')" + " - $in"
    $LogEntry | Out-File -FilePath $logpath -Append -Encoding ascii
  } catch {
    write-host Unable to write log file. -ForegroundColor Yellow
  }
}

# Configure IP Addressing
function Configure-Network ($ipconf) {
#Grab information about current interfaces
$current_ints = Get-NetAdapter | select ifIndex, MacAddress, Name

  #Look through each existing interface
  foreach ($current_int in $current_ints) {

    #Compare existing interfaces with config info by MAC address, configure on matches
    foreach ($ipc in $ipconf) {
      $ipc[5] = Normalize-MacAddress $ipc[5]
      if ($current_int.MacAddress -eq $ipc[5]) {
        try {
          Rename-NetAdapter -Name $current_int.Name -NewName $ipc[6] 2>&1 >> $DLOGFILE
          Remove-NetIPAddress -InterfaceIndex $current_int.ifIndex -Confirm:$false 2>&1 >> $DLOGFILE

          # Only provide DG if not null
          if ($ipc[2]) {
            New-NetIPAddress -InterfaceIndex $current_int.ifIndex -IPAddress $ipc[0] -PrefixLength $ipc[1] -DefaultGateway $ipc[2] -ErrorAction Stop 2>&1 >> $DLOGFILE
          } else {
            New-NetIPAddress -InterfaceIndex $current_int.ifIndex -IPAddress $ipc[0] -PrefixLength $ipc[1] -ErrorAction Stop 2>&1 >> $DLOGFILE
          }       
               
          Set-DnsClientServerAddress -InterfaceIndex $current_ints.ifIndex -ServerAddresses $ipc[3],$ipc[4] -ErrorAction Stop 2>&1 >> $DLOGFILE
          Append-Log "Successfully configured interface." $SLOGFILE
        } catch {
          write-host Unable to configure adapter. -ForegroundColor Yellow  
          Append-Log "Failed to configure interface." $SLOGFILE
        }
        #If trusted interace, open firewall
        if ($ipc[7]) {
          try {
            New-NetFirewallRule -DisplayName "Opening firewall on trusted network." -InterfaceAlias $ipc[6] -RemoteAddress LocalSubnet -Protocol Any -Action Allow -ErrorAction Stop 2>&1 >> $DLOGFILE
          } catch {
            Write-Host Unable to configure firewall. -ForegroundColor Yellow
            Append-Log "Added firewall rule for trusted network." $SLOGFILE
          }
        }
      }
    }    
  }
} 

# Disable IE Enhanced Security Configuration
function Disable-ieESC () {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    try {
      Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -ErrorAction Stop
      Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -ErrorAction Stop
      Stop-Process -Name Explorer
      Write-Host "Done"
      Append-Log "Disable IE ESC." $SLOGFILE
    } catch {
      Write-Host `tUnable to disable IE ESC. -ForegroundColor Yellow.
      Append-Log "Unable to disable IE ESC." $SLOGFILE
    }
}

# Disable service
function Disable-Service ($svcid,$name) {
  try {
    Write-Host `tDisabling $name  -ForegroundColor Green
    Set-Service -Name $svcid -StartupType Disabled -ErrorAction Stop 2>&1 >> $DLOGFILE
    Stop-Service -Name $svcid -Force -ErrorAction Stop 2>&1 >> $DLOGFILE
    Write-Host `t"(done)"
    Append-Log "Disable $name." $SLOGFILE
  } catch {
    Write-Host `tUnable to Disable $name -ForegroundColor Yellow
    Append-Log "Failed to disable $name." $SLOGFILE
  }
}

# Import CSV file to array
function Import-CsvToArray ($filePath) {
  if(Test-Path -Path $filePath) {
    try { 
      return Import-Csv $filePath -ErrorAction Stop 
    } catch { 
      write-host `tUnable to import $filepath -ForegroundColor Yellow 
      Append-Log "Unable to import csv file." $SLOGFILE
    }
  } else {
      write-host `tUnable to find $filepath -ForegroundColor Yellow
      Append-Log "Failed to find csv file." $SLOGFILE
  }
}

# Convert MAC Addresses to standard format
function Normalize-MacAddress ($mac) {
  if ($mac -match '[G-Zg-z]') {
    write-host "`tInvalid characters in MAC address: $mac" -ForegroundColor Yellow
    Exit
  }
    
  $mac = $mac.replace('.','-').replace(':','-').replace('\s','').ToUpper()

  if ($mac -match '^([A-F0-9]{2}-){5}[A-F0-9]{2}$') {
    return $mac
  } else {
    Write-Host "`tInvalid MAC address: $mac" -ForegroundColor Yellow
  }
}

# Set a high performance power plan
function Set-HighPerformancePowerPlan () {
  $highPerfGUID = powercfg.exe /LIST | Select-String -Pattern "([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}).*(\(High Performance\))" | foreach { $_.Matches[0].Groups[1].Value }
  if($highPerfGUID) {
    powercfg.exe /SETACTIVE $highPerfGUID 2>&1 >> $DLOGFILE
    Append-Log "Changed power plan." $SLOGFILE
  } else {
      write-host `tUnable to configure High Performance power plan -ForegroundColor Yellow
      Append-Log "Unable to configure High Performance power plan." $SLOGFILE
    }
}

# Set hostname on system
function Set-Hostname ($name) {
  try {
    Rename-Computer -NewName $name -ErrorAction Stop 2>&1 >> $DLOGFILE
    Append-Log "Successfully changed hostname." $SLOGFILE
  } catch {
    Write-Host `tUnable to change hostname. -ForegroundColor Yellow
    Append-Log "Failed to change hostname." $SLOGFILE

  }
}

# Set system timezone
function Set-NewTimeZone ($zone) {
  try {
    Set-TimeZone -Id $zone -ErrorAction Stop
    Append-Log "Successfully configured timezone." $SLOGFILE
  } catch {
    Write-Host `tUnable to change timezone. -ForegroundColor Yellow
    Append-Log "Failed to configure timezone." $SLOGFILE
  }
}