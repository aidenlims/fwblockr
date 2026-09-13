@echo off
setlocal enabledelayedexpansion

:: 1. Read input variables upfront
set "TARGET_FOLDER=%~1"
set "SWITCH_PARAM=%~2"

if "%TARGET_FOLDER%"=="" goto :ShowHelp
if /i "%TARGET_FOLDER%"=="-help" goto :ShowHelp

:: Validate the switch safely using delayed expansion to avoid parsing traps
if not "!SWITCH_PARAM!"=="" (
    set "VALID_SWITCH=0"
    if /i "!SWITCH_PARAM!"=="-query"  set "VALID_SWITCH=1"
    if /i "!SWITCH_PARAM!"=="-undo"   set "VALID_SWITCH=1"
    if /i "!SWITCH_PARAM!"=="-dryrun" set "VALID_SWITCH=1"
    
    if "!VALID_SWITCH!"=="0" (
        echo [ERROR] Invalid switch provided: "!SWITCH_PARAM!"
        echo.
        goto :ShowHelp
    )
)

:: 2. Enforce Administrator Validation
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script must be run as Administrator.
    pause
    exit /b
)

:: 3. Format target directory strings safely
set "CHECK_PATH=%TARGET_FOLDER%"
if not "!CHECK_PATH:~-1!"=="\" set "CHECK_PATH=!CHECK_PATH!\"

:: 4. Branch choices using stable labels
if /i "%SWITCH_PARAM%"=="-query" goto :ExecuteQuery
if /i "%SWITCH_PARAM%"=="-undo"  goto :ExecuteUndo
if /i "%SWITCH_PARAM%"=="-dryrun" goto :ExecuteDryRun
goto :ExecuteEnforce

:ExecuteQuery
echo === QUERY MODE: Querying Windows Firewall database... ===
echo Searching for active rules pointing inside: "!CHECK_PATH!"
echo.
powershell -NoProfile -Command "$p = $env:CHECK_PATH; $r = Get-NetFirewallApplicationFilter -All | Where-Object { $_.AppPath -like ($p + '*') } | Get-NetFirewallRule | Where-Object { $_.Description -eq 'Blocked via automated folder script' }; if (-not $r) { Write-Host 'No matching firewall rules found.' -ForegroundColor Yellow } else { foreach ($rule in $r) { Write-Host ($rule.Direction.ToString() + ' - ' + $rule.DisplayName) -ForegroundColor Green }; Write-Host ('Total rules found: ' + $r.Count) -ForegroundColor Cyan }"
goto :EOF

:ExecuteUndo
echo === UNDO MODE: Querying Windows Firewall database... ===
echo Removing any rule pointing inside: "!CHECK_PATH!"
powershell -NoProfile -Command "$p = $env:CHECK_PATH; Get-NetFirewallApplicationFilter -All | Where-Object { $_.AppPath -like ($p + '*') } | Get-NetFirewallRule | Where-Object { $_.Description -eq 'Blocked via automated folder script' } | ForEach-Object { Remove-NetFirewallRule -Name $_.Name; Write-Host ('Removed Rule: ' + $_.DisplayName) }"
echo Undo operation complete.
goto :EOF

:ExecuteDryRun
echo === DRY RUN: Executables found in nested directories ===
set "fileCount=0"
for /R "%TARGET_FOLDER%" %%F in (*) do (
    set "ext=%%~xF"
    for %%E in (.exe .bat .cmd .vbs .jar) do (
        if /i "!ext!"=="%%E" (
            echo [Found] %%F
            set /a fileCount+=1
        )
    )
)
echo.
echo Total files found: !fileCount!
goto :EOF

:ExecuteEnforce
echo === ENFORCING FIREWALL BLOCKS ===
set "fileCount=0"
for /R "%TARGET_FOLDER%" %%F in (*) do (
    set "ext=%%~xF"
    for %%E in (.exe .bat .cmd .vbs .jar) do (
        if /i "!ext!"=="%%E" (
            set /a fileCount+=1
        )
    )
)

if !fileCount! equ 0 (
    echo No files found to block.
    goto :EOF
)

if !fileCount! gtr 100 (
    echo WARNING: Found !fileCount! executables. Creating rules for this many files could clutter your firewall database.
    set /p "choice=Do you want to continue blocking all !fileCount! files? (Y/N): "
    if /i "!choice!" neq "Y" (
        echo Operation cancelled by user.
        goto :EOF
    )
)

echo Cleaning up old firewall entries for this folder to prevent duplication...
powershell -NoProfile -Command "$p = $env:CHECK_PATH; Get-NetFirewallApplicationFilter -All | Where-Object { $_.AppPath -like ($p + '*') } | Get-NetFirewallRule | Where-Object { $_.Description -eq 'Blocked via automated folder script' } | ForEach-Object { Remove-NetFirewallRule -Name $_.Name }"

for /R "%TARGET_FOLDER%" %%F in (*) do (
    set "ext=%%~xF"
    for %%E in (.exe .bat .cmd .vbs .jar) do (
        if /i "!ext!"=="%%E" (
            set "filePath=%%F"
            set "fileName=%%~nxF"
            
            netsh advfirewall firewall add rule name="Block Outbound - !fileName!" dir=out action=block program="!filePath!" description="Blocked via automated folder script" enable=yes profile=any >nul 2>&1
            netsh advfirewall firewall add rule name="Block Inbound - !fileName!" dir=in action=block program="!filePath!" description="Blocked via automated folder script" enable=yes profile=any >nul 2>&1
            
            echo Blocked: !fileName!
        )
    )
)
echo.
echo Successfully applied blocks to !fileCount! files.
goto :EOF

:ShowHelp
echo === FOLDER FIREWALL BLOCKER HELP ===
echo Scans a folder recursively for executables and block them all from accessing the Internet in Windows Firewall. 
echo Must be run in Administrator mode.
echo.
echo Usage:
echo   fwblockr.bat "C:\Path\To\Folder" [-switch]
echo.
echo Switches (Optional 2nd parameter):
echo   -query     Lists active firewall rules created for this folder path.
echo   -dryrun    Lists local executables found in the directory without modifying rules.
echo   -undo      Scans the firewall database and removes all rules pointing to this folder path.
exit /b
