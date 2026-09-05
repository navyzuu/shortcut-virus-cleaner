<#
.SYNOPSIS
    Shortcut Virus Removal & USB Data Restorer (Interactive Menu)
.DESCRIPTION
    Comprehensive interactive toolkit for diagnosing, removing shortcut worms,
    unhiding USB contents, and managing system script security settings.
.LICENSE
    MIT License
#>

[CmdletBinding()]
param ()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    param ([string]$ActionName)
    if (-not (Test-IsAdmin)) {
        Write-Host "`n[!] The '$ActionName' operation requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "    Relaunching elevated console..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        $scriptPath = $PSCommandPath
        if ($scriptPath -and (Test-Path $scriptPath)) {
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        } else {
            $cmd = "iex (New-Object Net.WebClient).DownloadString('$($MyInvocation.MyCommand.Definition)')"
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        }
        return $false
    }
    return $true
}

function Show-Header {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "             SHORTCUT VIRUS REMOVAL & USB DATA RESTORER v4.2                    " -ForegroundColor Cyan
    Write-Host "        Automated Forensic, Cleaning, & Restoration Toolkit for Windows         " -ForegroundColor DarkCyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    $adminStatus = if (Test-IsAdmin) { "[ ADMINISTRATOR ]" } else { "[ STANDARD / NON-ADMIN ]" }
    $adminColor  = if (Test-IsAdmin) { "Green" } else { "Red" }
    
    Write-Host " Privilege : " -NoNewline
    Write-Host "$adminStatus" -ForegroundColor $adminColor -NoNewline
    Write-Host "  | Host : " -NoNewline
    Write-Host "$env:COMPUTERNAME" -ForegroundColor Yellow -NoNewline
    Write-Host "  | User : " -NoNewline
    Write-Host "$env:USERNAME" -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
}

function Invoke-FullCleanup {
    if (-not (Ensure-Admin "Full Cleanup")) { return }
    
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Red
    Write-Host "                 [1] EXECUTING COMPLETE SYSTEM & USB CLEANUP                    " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Red
    
    # 1. Terminate processes
    Write-Host "`n[1/6] Terminating rogue processes and memory modules..." -ForegroundColor Yellow
    $killed = 0
    Get-Process -Name wscript, cscript -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        Write-Host "  [X] Stopped script engine: $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Red
        $killed++
    }
    Get-CimInstance Win32_Process -Filter "Name = 'rundll32.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.CommandLine -like "*u*.dll*" -or $_.CommandLine -like "*sysvolume*" -or $_.CommandLine -like "*IdllEntryX*") {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "  [X] Stopped rogue rundll32: PID $($_.ProcessId)" -ForegroundColor Red
            $killed++
        }
    }
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $p = $_
        try {
            foreach ($m in $p.Modules) {
                if ($m.FileName -match "\\System32\\u\d{5,8}\.dll" -or $m.FileName -like "*sysvolume*") {
                    if ($p.ProcessName -notmatch "^(system|csrss)$") {
                        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                        Write-Host "  [X] Stopped locking process: $($p.ProcessName) (PID: $($p.Id))" -ForegroundColor Red
                        $killed++
                    }
                }
            }
        } catch {}
    }
    if ($killed -eq 0) {
        Write-Host "  [OK] No active malware processes found." -ForegroundColor Green
    }
    
    # 2. Delete rogue DLLs
    Write-Host "`n[2/6] Deleting rogue DLL files in System32..." -ForegroundColor Yellow
    $rogueDlls = Get-ChildItem "C:\Windows\System32\u*.dll" -File -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "^u\d{5,8}\.dll$"
    }
    $del = 0
    foreach ($f in $rogueDlls) {
        try {
            cmd.exe /c "takeown /f `"$($f.FullName)`" /a >nul 2>&1"
            cmd.exe /c "icacls `"$($f.FullName)`" /grant Administrators:F >nul 2>&1"
            Remove-Item -Path $f.FullName -Force -ErrorAction Stop
            Write-Host "  [+] Deleted: $($f.FullName) ($([math]::Round($f.Length/1MB,2)) MB)" -ForegroundColor Green
            $del++
        } catch {
            $bak = "$($f.FullName).deleted"
            Rename-Item -Path $f.FullName -NewName $bak -Force -ErrorAction SilentlyContinue
            Write-Host "  [!] Renamed and neutralized: $bak" -ForegroundColor Yellow
            $del++
        }
    }
    if ($del -eq 0) {
        Write-Host "  [OK] C:\Windows\System32 is clean." -ForegroundColor Green
    }
    
    # 3. Refresh Explorer
    Write-Host "`n[3/6] Refreshing Windows Explorer shell..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
    Write-Host "  [OK] Explorer restarted without injected threads." -ForegroundColor Green
    
    # 4. Clean Defender Exclusions
    Write-Host "`n[4/6] Cleaning Defender exclusion list..." -ForegroundColor Yellow
    try {
        $pref = Get-MpPreference -ErrorAction SilentlyContinue
        if ($pref.ExclusionPath) {
            foreach ($ep in $pref.ExclusionPath) {
                if ($ep -like "*System32*" -or $ep -like "*sysvolume*" -or $ep -match "^[A-Z]:\\") {
                    Remove-MpPreference -ExclusionPath $ep -ErrorAction SilentlyContinue
                    Write-Host "  [+] Removed exclusion: $ep" -ForegroundColor Green
                }
            }
        }
        Write-Host "  [OK] Defender preferences restored." -ForegroundColor Green
    } catch {}
    
    # 5. Clean USB Drives & Restore Files to Root
    Write-Host "`n[5/6] Cleaning USB storage devices and restoring files..." -ForegroundColor Yellow
    $usbDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 2 }
    if ($usbDrives) {
        foreach ($d in $usbDrives) {
            $letter = "$($d.DeviceID)\"
            $volName = $d.VolumeName
            Write-Host "`n  >>> Processing Drive: $letter ($volName) <<<" -ForegroundColor Cyan
            
            # Remove sysvolume folder
            $sysVol = Join-Path $letter "sysvolume"
            if (Test-Path $sysVol) {
                cmd.exe /c "takeown /f `"$sysVol`" /r /d y >nul 2>&1"
                cmd.exe /c "icacls `"$sysVol`" /grant Administrators:F /t >nul 2>&1"
                cmd.exe /c "rd /s /q `"$sysVol`""
                Write-Host "    [+] Removed rogue directory: $sysVol" -ForegroundColor Green
            }
            
            # Remove shortcuts
            $lnks = Get-ChildItem -Path $letter -Filter "*.lnk" -Force -ErrorAction SilentlyContinue
            foreach ($lnk in $lnks) {
                Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "    [+] Removed shortcut: $($lnk.Name)" -ForegroundColor Green
            }
            
            # Unwrap files from volume-named folder
            if ($volName -and $volName.Trim() -ne "" -and $volName -notmatch "^(System Volume Information|\$RECYCLE\.BIN)$") {
                $volFolder = Join-Path $letter $volName
                if (Test-Path $volFolder) {
                    Write-Host "    [*] Unwrapping files from folder '$volName' back to root..." -ForegroundColor Yellow
                    cmd.exe /c "attrib -s -h -r `"$volFolder`" >nul 2>&1"
                    
                    $items = Get-ChildItem -Path $volFolder -Force -ErrorAction SilentlyContinue
                    foreach ($it in $items) {
                        $dest = Join-Path $letter $it.Name
                        if (-not (Test-Path $dest)) {
                            Move-Item -Path $it.FullName -Destination $letter -Force -ErrorAction SilentlyContinue
                        } else {
                            if ($it.PSIsContainer) {
                                Get-ChildItem -Path $it.FullName -Force -ErrorAction SilentlyContinue | ForEach-Object {
                                    $subDest = Join-Path $dest $_.Name
                                    if (-not (Test-Path $subDest)) {
                                        Move-Item -Path $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
                                    }
                                }
                            }
                        }
                    }
                    $rem = (Get-ChildItem -Path $volFolder -Force -ErrorAction SilentlyContinue).Count
                    if ($rem -eq 0) {
                        Remove-Item -Path $volFolder -Force -Recurse -ErrorAction SilentlyContinue
                        Write-Host "    [+] Container folder '$volName' removed. Files restored to root!" -ForegroundColor Green
                    }
                }
            }
            
            # Unhide everything
            Write-Host "    [*] Restoring file visibility..." -ForegroundColor Yellow
            cmd.exe /c "attrib -s -h -r /s /d `"$letter*.*`""
            
            # Protect official Windows system volume folder
            $legit = Join-Path $letter "System Volume Information"
            if (Test-Path $legit) {
                cmd.exe /c "attrib +s +h `"$legit`""
            }
            Write-Host "    [+] Drive $letter restored to original clean state!" -ForegroundColor Green
        }
    } else {
        Write-Host "  [i] No USB drives currently connected." -ForegroundColor Gray
    }
    
    # 6. Apply Immunization
    Write-Host "`n[6/6] Applying system immunization..." -ForegroundColor Yellow
    Apply-ImmunizationSilent
    Write-Host "  [OK] Immunization enabled: VBS script execution disabled." -ForegroundColor Green
    
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "   >>> CLEANUP COMPLETE: SYSTEM & USB STORAGE NORMALIZED <<<                    " -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "`nPress ENTER to return to menu..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
}

function Invoke-CleanUsbOnly {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "           [2] CLEAN USB STORAGE & RESTORE DATA TO ROOT                         " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    $usbDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 2 }
    if (-not $usbDrives) {
        Write-Host "`n[!] No USB storage devices detected." -ForegroundColor Red
        Write-Host "    Please connect your drive and try again." -ForegroundColor Yellow
        Write-Host "`nPress ENTER to return to menu..." -ForegroundColor Gray
        [void][System.Console]::ReadLine()
        return
    }
    
    Write-Host "`nConnected USB Devices:" -ForegroundColor Cyan
    $idx = 1
    foreach ($d in $usbDrives) {
        $sizeGB = [math]::Round($d.Size / 1GB, 2)
        $freeGB = [math]::Round($d.FreeSpace / 1GB, 2)
        Write-Host "  [$idx] Drive $($d.DeviceID) | Label: $($d.VolumeName) | Size: $sizeGB GB ($freeGB GB Free)" -ForegroundColor White
        $idx++
    }
    Write-Host "  [A] Clean ALL connected USB drives" -ForegroundColor Green
    Write-Host "  [B] Back to Menu" -ForegroundColor Gray
    
    $sel = Read-Host "`nSelect drive number or [A] for all"
    if ($sel -match "^[bB]$") { return }
    
    $targets = @()
    if ($sel -match "^[aA]$") {
        $targets = $usbDrives
    } elseif ($sel -match "^\d+$" -and [int]$sel -le $usbDrives.Count -and [int]$sel -ge 1) {
        $targets = @($usbDrives[[int]$sel - 1])
    } else {
        Write-Host "Invalid selection." -ForegroundColor Red
        Start-Sleep -Seconds 1
        return
    }
    
    foreach ($d in $targets) {
        $letter = "$($d.DeviceID)\"
        $volName = $d.VolumeName
        Write-Host "`n----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "Processing: $letter ($volName)" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
        
        # Remove sysvolume folder
        $sysVol = Join-Path $letter "sysvolume"
        if (Test-Path $sysVol) {
            cmd.exe /c "takeown /f `"$sysVol`" /r /d y >nul 2>&1"
            cmd.exe /c "icacls `"$sysVol`" /grant Administrators:F /t >nul 2>&1"
            cmd.exe /c "rd /s /q `"$sysVol`""
            Write-Host "  [+] Removed rogue sysvolume folder." -ForegroundColor Green
        }
        
        # Remove shortcuts
        $lnks = Get-ChildItem -Path $letter -Filter "*.lnk" -Force -ErrorAction SilentlyContinue
        foreach ($lnk in $lnks) {
            Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "  [+] Removed shortcut: $($lnk.Name)" -ForegroundColor Green
        }
        
        # Unwrap files from volume folder
        if ($volName -and $volName.Trim() -ne "" -and $volName -notmatch "^(System Volume Information|\$RECYCLE\.BIN)$") {
            $volFolder = Join-Path $letter $volName
            if (Test-Path $volFolder) {
                Write-Host "  [*] Restoring files from folder '$volName' to root..." -ForegroundColor Yellow
                cmd.exe /c "attrib -s -h -r `"$volFolder`" >nul 2>&1"
                
                $items = Get-ChildItem -Path $volFolder -Force -ErrorAction SilentlyContinue
                foreach ($it in $items) {
                    $dest = Join-Path $letter $it.Name
                    if (-not (Test-Path $dest)) {
                        Move-Item -Path $it.FullName -Destination $letter -Force -ErrorAction SilentlyContinue
                    }
                }
                $rem = (Get-ChildItem -Path $volFolder -Force -ErrorAction SilentlyContinue).Count
                if ($rem -eq 0) {
                    Remove-Item -Path $volFolder -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Host "  [+] Container folder '$volName' removed." -ForegroundColor Green
                }
            }
        }
        
        # Unhide
        Write-Host "  [*] Unhiding files..." -ForegroundColor Yellow
        cmd.exe /c "attrib -s -h -r /s /d `"$letter*.*`""
        
        # Re-protect legitimate System Volume Information
        $legit = Join-Path $letter "System Volume Information"
        if (Test-Path $legit) {
            cmd.exe /c "attrib +s +h `"$legit`""
        }
        Write-Host "  [OK] Drive $letter cleaned and restored to root." -ForegroundColor Green
    }
    
    Write-Host "`nPress ENTER to return to menu..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
}

function Invoke-ForensicDiagnosis {
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                 [3] SYSTEM DIAGNOSTIC & FORENSIC SCAN                          " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    Write-Host "`n[1] Checking C:\Windows\System32:" -ForegroundColor Cyan
    $rogueDlls = Get-ChildItem "C:\Windows\System32\u*.dll" -File -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match "^u\d{5,8}\.dll$"
    }
    if ($rogueDlls) {
        foreach ($rd in $rogueDlls) {
            Write-Host "  [!] WARNING: Rogue DLL detected -> $($rd.FullName) ($([math]::Round($rd.Length/1MB, 2)) MB)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [OK] System32 directory is clean." -ForegroundColor Green
    }
    
    Write-Host "`n[2] Checking Process Modules & Memory Injections:" -ForegroundColor Cyan
    $injected = $false
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        $p = $_
        try {
            foreach ($m in $p.Modules) {
                if ($m.FileName -match "\\System32\\u\d{5,8}\.dll" -or $m.FileName -like "*sysvolume*") {
                    Write-Host "  [!] ALERT: PID $($p.Id) ($($p.ProcessName)) holds rogue module -> $($m.FileName)" -ForegroundColor Red
                    $injected = $true
                }
            }
        } catch {}
    }
    if (-not $injected) {
        Write-Host "  [OK] No processes holding known rogue modules." -ForegroundColor Green
    }
    
    Write-Host "`n[3] Checking Immunization State:" -ForegroundColor Cyan
    $wshEnabled = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
    if ($wshEnabled -eq 0) {
        Write-Host "  [OK] Immunization ACTIVE: Windows Script Host is disabled." -ForegroundColor Green
    } else {
        Write-Host "  [i] Immunization INACTIVE: Windows Script Host is enabled." -ForegroundColor Yellow
    }
    
    Write-Host "`n[4] Checking USB Storage Devices:" -ForegroundColor Cyan
    $usbDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 2 }
    if ($usbDrives) {
        foreach ($d in $usbDrives) {
            $letter = "$($d.DeviceID)\"
            $hasSysVol = Test-Path (Join-Path $letter "sysvolume")
            $lnkCount = (Get-ChildItem -Path $letter -Filter "*.lnk" -Force -ErrorAction SilentlyContinue).Count
            if ($hasSysVol -or $lnkCount -gt 0) {
                Write-Host "  [!] INFECTION DETECTED on $letter : sysvolume present ($hasSysVol), $lnkCount shortcut(s) found." -ForegroundColor Red
            } else {
                Write-Host "  [OK] Drive $letter is clean." -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  [i] No USB drives connected." -ForegroundColor Gray
    }
    
    Write-Host "`nPress ENTER to return to menu..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
}

function Apply-ImmunizationSilent {
    try {
        cmd.exe /c "assoc .vbs=txtfile >nul 2>&1"
        cmd.exe /c "ftype vbsfile=`"%SystemRoot%\System32\notepad.exe`" `"%1`" >nul 2>&1"
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Invoke-ApplyImmunization {
    if (-not (Ensure-Admin "Immunization")) { return }
    
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "                 [4] APPLY PERMANENT SYSTEM IMMUNIZATION                        " -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    Apply-ImmunizationSilent
    Write-Host "`n  [+] Associated .vbs extension with Notepad." -ForegroundColor Green
    Write-Host "  [+] Disabled Windows Script Host engine via Registry." -ForegroundColor Green
    Write-Host "`n[SUCCESS] System is now protected against VBScript-based shortcut worms." -ForegroundColor Green
    
    Write-Host "`nPress ENTER to return to menu..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
}

function Invoke-RollbackImmunization {
    if (-not (Ensure-Admin "Rollback")) { return }
    
    Clear-Host
    Write-Host "================================================================================" -ForegroundColor Yellow
    Write-Host "              [5] RESTORE DEFAULT WINDOWS SCRIPT HOST SETTINGS                  " -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Yellow
    
    Write-Host "`nNote: Use this only if you need to run official Microsoft administrative scripts" -ForegroundColor Gray
    Write-Host "(e.g., Office activation script OSPP.VBS).`n" -ForegroundColor Gray
    
    $confirm = Read-Host "Are you sure you want to re-enable Windows Script Host? (y/n)"
    if ($confirm -notmatch "^[yY]$") { return }
    
    try {
        cmd.exe /c "assoc .vbs=VBSFile >nul 2>&1"
        cmd.exe /c "ftype VBSFile=`"%SystemRoot%\System32\WScript.exe`" `"%1`" %* >nul 2>&1"
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "`n[SUCCESS] Windows Script Host default associations restored." -ForegroundColor Green
    } catch {
        Write-Host "`n[!] Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress ENTER to return to menu..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
}

while ($true) {
    Show-Header
    Write-Host ""
    Write-Host " [1] FULL SYSTEM & USB CLEANUP (Recommended)" -ForegroundColor Green
    Write-Host "     -> Kills malware, deletes System32 DLL, resets Defender," -ForegroundColor Gray
    Write-Host "        removes sysvolume, unwraps data to root, and immunizes OS." -ForegroundColor Gray
    Write-Host ""
    Write-Host " [2] CLEAN USB STORAGE ONLY" -ForegroundColor Yellow
    Write-Host "     -> Cleans sysvolume & .lnk files, restores data back to root." -ForegroundColor Gray
    Write-Host ""
    Write-Host " [3] DIAGNOSTIC & FORENSIC SCAN" -ForegroundColor Cyan
    Write-Host "     -> Read-only inspection of memory, System32, and USB devices." -ForegroundColor Gray
    Write-Host ""
    Write-Host " [4] IMMUNIZE SYSTEM (Block VBS / WSH)" -ForegroundColor Magenta
    Write-Host "     -> Permanently protect against script-based worms." -ForegroundColor Gray
    Write-Host ""
    Write-Host " [5] RESTORE DEFAULT VBS ENGINE" -ForegroundColor DarkYellow
    Write-Host "     -> Re-enable WSH for administrative scripts (e.g. Office OSPP)." -ForegroundColor Gray
    Write-Host ""
    Write-Host " [6] EXIT" -ForegroundColor Red
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    $opt = Read-Host "Select an option [1-6]"
    switch ($opt.Trim()) {
        "1" { Invoke-FullCleanup }
        "2" { Invoke-CleanUsbOnly }
        "3" { Invoke-ForensicDiagnosis }
        "4" { Invoke-ApplyImmunization }
        "5" { Invoke-RollbackImmunization }
        "6" { 
            Write-Host "`nExiting. Stay safe!" -ForegroundColor Green
            Start-Sleep -Seconds 1
            exit 
        }
        default {
            Write-Host "Invalid option. Please enter 1-6." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
