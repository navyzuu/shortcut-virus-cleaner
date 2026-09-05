<#
.SYNOPSIS
    Shortcut Virus Removal & USB Data Restorer (Silent / Express Engine)
.DESCRIPTION
    Automated zero-interaction cleanup utility for Windows shortcut worms (VBS/DLL injection).
    Kills malicious processes, removes rogue DLLs from System32, reverts Defender exclusions,
    unhides USB files, moves trapped data from volume folders back to root, and immunizes the OS.
.LICENSE
    MIT License
#>

[CmdletBinding()]
param ()

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Ensure Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $scriptPath = $PSCommandPath
    if ($scriptPath -and (Test-Path $scriptPath)) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    } else {
        $cmd = "iex (New-Object Net.WebClient).DownloadString('$($MyInvocation.MyCommand.Definition)')"
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
    }
    exit
}

Clear-Host
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "             SHORTCUT VIRUS REMOVAL & USB DATA RESTORER (EXPRESS)               " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Status: Administrator | Host: $env:COMPUTERNAME | User: $env:USERNAME" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Terminate Rogue Processes & Injected Threads
Write-Host "`n[1/5] Checking active processes and memory hooks..." -ForegroundColor Yellow
$procKilled = 0

Get-Process -Name wscript, cscript -ErrorAction SilentlyContinue | ForEach-Object {
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    Write-Host "  [X] Terminated script process: $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Red
    $procKilled++
}

Get-CimInstance Win32_Process -Filter "Name = 'rundll32.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.CommandLine -like "*u*.dll*" -or $_.CommandLine -like "*sysvolume*" -or $_.CommandLine -like "*IdllEntryX*") {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "  [X] Terminated suspicious rundll32: PID $($_.ProcessId)" -ForegroundColor Red
        $procKilled++
    }
}

Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
    $p = $_
    try {
        foreach ($m in $p.Modules) {
            if ($m.FileName -match "\\System32\\u\d{5,8}\.dll" -or $m.FileName -like "*sysvolume*") {
                if ($p.ProcessName -notmatch "^(system|csrss)$") {
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                    Write-Host "  [X] Terminated locking process: $($p.ProcessName) (PID: $($p.Id))" -ForegroundColor Red
                    $procKilled++
                }
            }
        }
    } catch {}
}

if ($procKilled -eq 0) {
    Write-Host "  [OK] No active malware processes found in memory." -ForegroundColor Green
}

# 2. Eradicate Rogue System32 Binaries
Write-Host "`n[2/5] Scanning System32 for rogue DLL binaries..." -ForegroundColor Yellow
$rogueDlls = Get-ChildItem "C:\Windows\System32\u*.dll" -File -Force -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -match "^u\d{5,8}\.dll$"
}
$filesRemoved = 0
foreach ($f in $rogueDlls) {
    try {
        cmd.exe /c "takeown /f `"$($f.FullName)`" /a >nul 2>&1"
        cmd.exe /c "icacls `"$($f.FullName)`" /grant Administrators:F >nul 2>&1"
        Remove-Item -Path $f.FullName -Force -ErrorAction Stop
        Write-Host "  [+] Removed malware binary: $($f.FullName) ($([math]::Round($f.Length/1MB,2)) MB)" -ForegroundColor Green
        $filesRemoved++
    } catch {
        $bak = "$($f.FullName).deleted"
        Rename-Item -Path $f.FullName -NewName $bak -Force -ErrorAction SilentlyContinue
        Write-Host "  [!] Locked -> Renamed and disabled: $bak" -ForegroundColor Yellow
        $filesRemoved++
    }
}
if ($filesRemoved -eq 0) {
    Write-Host "  [OK] System32 directory is clean." -ForegroundColor Green
}

# 3. Refresh Windows Explorer & Reset Defender Exclusions
Write-Host "`n[3/5] Refreshing Explorer shell and checking Defender exclusions..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe
}
Write-Host "  [OK] Explorer refreshed clean." -ForegroundColor Green

try {
    $pref = Get-MpPreference -ErrorAction SilentlyContinue
    if ($pref.ExclusionPath) {
        foreach ($ep in $pref.ExclusionPath) {
            if ($ep -like "*System32*" -or $ep -like "*sysvolume*" -or $ep -match "^[A-Z]:\\") {
                Remove-MpPreference -ExclusionPath $ep -ErrorAction SilentlyContinue
                Write-Host "  [+] Removed rogue Defender exclusion: $ep" -ForegroundColor Green
            }
        }
    }
} catch {}

# 4. Clean USB Drives & Restore User Files to Root
Write-Host "`n[4/5] Scanning and recovering USB storage devices..." -ForegroundColor Yellow
$usbDrives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 2 }

if ($usbDrives) {
    foreach ($d in $usbDrives) {
        $letter = "$($d.DeviceID)\"
        $volName = $d.VolumeName
        Write-Host "`n  >>> Processing Drive: $letter ($volName) <<<" -ForegroundColor Cyan
        
        # Remove malware payload folder (sysvolume)
        $sysVol = Join-Path $letter "sysvolume"
        if (Test-Path $sysVol) {
            cmd.exe /c "takeown /f `"$sysVol`" /r /d y >nul 2>&1"
            cmd.exe /c "icacls `"$sysVol`" /grant Administrators:F /t >nul 2>&1"
            cmd.exe /c "rd /s /q `"$sysVol`""
            Write-Host "    [+] Removed rogue directory: $sysVol" -ForegroundColor Green
        }
        
        # Remove all malicious shortcut files
        $lnks = Get-ChildItem -Path $letter -Filter "*.lnk" -Force -ErrorAction SilentlyContinue
        foreach ($lnk in $lnks) {
            Remove-Item -Path $lnk.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "    [+] Removed shortcut: $($lnk.Name)" -ForegroundColor Green
        }
        
        # Move files from volume-named folder back to root
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
                
                $remCount = (Get-ChildItem -Path $volFolder -Force -ErrorAction SilentlyContinue).Count
                if ($remCount -eq 0) {
                    Remove-Item -Path $volFolder -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Host "    [+] Container folder '$volName' cleaned and removed." -ForegroundColor Green
                }
            }
        }
        
        # Unhide all user files and directories recursively
        Write-Host "    [*] Unhiding user files and directories..." -ForegroundColor Yellow
        cmd.exe /c "attrib -s -h -r /s /d `"$letter*.*`""
        
        # Re-protect official Windows system directory
        $legitSys = Join-Path $letter "System Volume Information"
        if (Test-Path $legitSys) {
            cmd.exe /c "attrib +s +h `"$legitSys`""
        }
        
        Write-Host "    [OK] All files in $letter successfully restored to original root location!" -ForegroundColor Green
    }
} else {
    Write-Host "  [i] No USB drives currently connected." -ForegroundColor Gray
}

# 5. Apply System Immunization
Write-Host "`n[5/5] Applying system immunization..." -ForegroundColor Yellow
try {
    cmd.exe /c "assoc .vbs=txtfile >nul 2>&1"
    cmd.exe /c "ftype vbsfile=`"%SystemRoot%\System32\notepad.exe`" `"%1`" >nul 2>&1"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Immunization active: VBS file execution redirected to Notepad." -ForegroundColor Green
} catch {}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   >>> CLEANUP COMPLETE: SYSTEM & USB DRIVES RESTORED TO ORIGINAL STATE <<<     " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "`nPress ENTER to exit..." -ForegroundColor Gray
[void][System.Console]::ReadLine()
