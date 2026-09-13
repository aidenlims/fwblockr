# Windows Folder Firewall Blocker

A lightweight, zero-dependency Windows batch utility that scans a specified folder recursively for all executable types (`.exe`, `.bat`, `.cmd`, `.msi`, `.vbs`, `.ps1`, `.scr`, `.jar`) and blocks them from accessing the internet using Windows Firewall.

## Features
- **Recursive Scanning:** Automatically digs through deeply nested subdirectories.
- **Anti-Duplication:** Wipes out previous script-created rules for a folder before reapplying, ensuring zero clutter.
- **Robust Path Handling:** Safely processes long filenames, spaces, and complex folder structures (like `(x86)` strings) without crashing.
- **Typo Protection:** Strictly validates parameter input switches and flags errors immediately.

## Usage
Open a cmd.exe as **Administrator** and execute the script:

```cmd
fwblockr.bat "C:\Path\To\Folder" [-switch]
```

### Switches
- `-query` : Lists active firewall rules created for this folder path.
- `-dryrun`: Lists local executables found in the directory without making firewall changes.
- `-undo`  : Scans the firewall database directly and completely removes all rules pointing to this folder path.
