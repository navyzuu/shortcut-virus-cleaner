# Modern Shortcut Worm & DLL Injection Analysis

## Overview
Recent Windows shortcut worm variants (often spread through bundled media downloads) combine VBScript elevation with compiled binary DLL injection:

1. **Initial Vector**:
   * Masquerades as media files (`.mp3.vbs` or `.mp4.vbs`).
   * On execution, elevates silently using `ShellExecute(..., "runas")` and calls an obfuscated batch launcher.

2. **Persistence & Evasion**:
   * Disables Windows Defender alerts by adding exclusion paths:
     `Add-MpPreference -ExclusionPath "C:\Windows\System32"`
     `Add-MpPreference -ExclusionPath "<Drive>:\sysvolume"`
   * Drops a compiled ~6-12 MB DLL into `C:\Windows\System32\u[random_id].dll`.
   * Executes the entry point via `rundll32.exe C:\Windows\System32\u[random_id].dll,IdllEntryX 1`.

3. **Memory Injection & USB Propagation**:
   * The binary injects a background thread into long-running system processes (such as `svchost.exe` or `explorer.exe`).
   * The thread registers for Windows `WM_DEVICECHANGE` (`DBT_DEVICEARRIVAL`) notifications.
   * Whenever a USB storage device is inserted:
     - Creates a hidden folder named `sysvolume` containing the dropper payload.
     - Creates a folder with the USB volume label and moves all genuine files inside.
     - Hides the genuine folder (`attrib +s +h`).
     - Generates `.lnk` shortcut files pointing back to `sysvolume\u*.vbs`.

## Mitigation Strategy
* **Memory**: Terminate locking instances of `svchost.exe` or `rundll32.exe` hosting the module, and refresh `explorer.exe`.
* **Filesystem**: Take ownership and delete `C:\Windows\System32\u*.dll` and the USB `sysvolume` folder.
* **Storage Restoration**: Detect folders matching the volume label, unwrap all files directly back to the root of the USB drive, and recursively strip `Hidden` and `System` attributes.
* **Immunization**: Null-route `.vbs` to `notepad.exe` and disable the Windows Script Host engine in the Registry (`HKLM/HKCU\Software\Microsoft\Windows Script Host\Settings\Enabled = 0`).
