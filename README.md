# shortcut-virus-cleaner

A lightweight PowerShell utility to remove Windows shortcut worms (VBS/rundll32/DLL injection variants), restore hidden USB files directly to the drive root, and immunize against reinfection.

## Features

- Terminates malicious script hosts and injected background processes (svchost, rundll32).
- Removes rogue binary payloads from `C:\Windows\System32` (e.g., `u*.dll`).
- Cleans unauthorized exclusion paths added to Windows Defender.
- Cleans USB drives by deleting fake `sysvolume` directories and malicious `.lnk` shortcuts.
- Unwraps hidden directories created by the worm (such as folders matching the USB volume label) and restores all original files back to the drive root.
- Recursively strips hidden and system file attributes (`attrib -s -h -r`).
- Re-applies system protection to legitimate `System Volume Information` directories.
- Immunizes the operating system by reassociating `.vbs` files with Notepad and disabling the Windows Script Host engine.

## Usage

### 1. Interactive Menu (`menu.ps1`)

Recommended for administrators and technicians needing selective tasks (full cleanup, USB-only cleanup, diagnostic scan, or toggling script host settings).

Remote execution:
```powershell
irm https://napuiss.my.id/tools/menu.ps1 | iex
```

Local execution:
Run `run.bat` (automatically elevates to Administrator).

---

### 2. Express 1-Click Cleaner (`silent.ps1`)

Recommended for unattended remediation or end-users needing an immediate fix without interactive prompts.

Remote execution:
```powershell
irm https://napuiss.my.id/tools/silent.ps1 | iex
```

Local execution:
Run `run-silent.bat` (automatically elevates to Administrator).

---

## Repository Structure

```text
├── run.bat                 # Batch launcher for interactive menu
├── run-silent.bat          # Batch launcher for express 1-click cleaner
├── menu.ps1                # Interactive console utility
├── silent.ps1              # Unattended cleanup engine
├── docs/
│   └── technical-analysis.md # Reverse-engineering and technical analysis
├── README.md               # Documentation
├── LICENSE                 # MIT License
└── .gitignore              # Development exclusions
```

## Custom Domain Deployment

To serve the scripts from your own domain (such as `napuiss.my.id/tools`):
1. Place `menu.ps1` and `silent.ps1` into `/var/www/html/tools/`.
2. Ensure HTTPS is enabled.
3. Run directly from PowerShell:
   ```powershell
   irm https://napuiss.my.id/tools/silent.ps1 | iex
   ```

## License

MIT License. See [LICENSE](LICENSE) for details.

