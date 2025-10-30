@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: ==============================================================================
:: Project : freps (Find, REPlace, Search)
:: File    : freps.bat
:: Version : 1.2.0
:: Date    : 2025-10-30
:: Author  : Samuel Seijo (EIDO AUTOMATION SL)
:: License : MIT
:: ==============================================================================
:: Description:
::   A lightweight Windows batch utility to:
::     - Rename files and folders (find & replace in names).   [mode: r]
::     - Replace text within file contents.                    [mode: p]
::     - Search text inside files with flexible options.       [mode: s]
::
::   Legacy ordered arguments:
::     MODE FROM TO DIR [EXT...]
::
::   Optional flags:
::     /N    Dry-run (show actions, no changes)  — affects r/p
::     /V    Verbose/debug output
::     /B    Create .bak backup before writing   — affects p
::     /Q    Quiet mode (suppress info lines)
::
::   Search-specific flags:
::     /M    List files with matches only (no lines)
::     /CS   Case-sensitive search (default is case-insensitive)
::     /RX   Treat FROM as regex (default: literal via /c:"...")
::
:: Notes:
::   * MODE: r (rename), p (replace), s (search)
::   * In search mode, the TO parameter is ignored.
::   * EXT should include the dot, e.g. .txt .cfg .idf
::   * Content replacement in mode 'p' is case-sensitive (cmd limitation).
::
:: ======================== EXAMPLES ==================================
::   Rename files/folders:
::     freps r HC54 HC99 "C:\path\to\project"
::
::   Replace text inside files:
::     freps p HC54 HC99 "C:\path\to\project" .idf .ids /B /V
::
::   Search text (TO ignored):
::     freps s HC54 "" "C:\path\to\project" .idf .ids .txt
::     freps s HC54 "" "C:\path\to\project" .txt /M       (filenames only)
::     freps s ^\bHC54\b "" "C:\path\to\project" .txt /RX (regex word-boundary)
::     freps s HC54 "" "C:\path\to\project" .txt /CS      (case-sensitive)
:: ==============================================================================

REM -----------------------------------------------------
REM Help
REM -----------------------------------------------------
if /i "%~1"==""        goto :show_help
if /i "%~1"=="-h"      goto :show_help
if /i "%~1"=="--help"  goto :show_help
if /i "%~1"=="/?"      goto :show_help

REM -----------------------------------------------------
REM Required ordered params
REM -----------------------------------------------------
set "mode=%~1"
set "from=%~2"
set "to=%~3"
set "dir=%~4"

for /f "tokens=1" %%a in ("%mode%") do set "mode=%%a"
shift & shift & shift & shift

REM -----------------------------------------------------
REM Parse remaining tokens (extensions + flags)
REM -----------------------------------------------------
set "ext="
set "FLAG_DRYRUN=0"
set "FLAG_VERBOSE=0"
set "FLAG_BACKUP=0"
set "FLAG_QUIET=0"
set "FLAG_SEARCH_FILES_ONLY=0"   REM /M
set "FLAG_SEARCH_CASE_SENS=0"    REM /CS
set "FLAG_SEARCH_REGEX=0"        REM /RX

:readTail
if "%~1"=="" goto afterTail
set "tkn=%~1"
if "!tkn:~0,1!"=="/" (
    if /i "!tkn!"=="/N"  set "FLAG_DRYRUN=1"
    if /i "!tkn!"=="/V"  set "FLAG_VERBOSE=1"
    if /i "!tkn!"=="/B"  set "FLAG_BACKUP=1"
    if /i "!tkn!"=="/Q"  set "FLAG_QUIET=1"
    if /i "!tkn!"=="/M"  set "FLAG_SEARCH_FILES_ONLY=1"
    if /i "!tkn!"=="/CS" set "FLAG_SEARCH_CASE_SENS=1"
    if /i "!tkn!"=="/RX" set "FLAG_SEARCH_REGEX=1"
) else (
    if "!tkn:~0,1!"=="." (
        set "ext=!ext! !tkn!"
    ) else (
        set "ext=!ext! !tkn!"
    )
)
shift
goto :readTail

:afterTail
if defined ext set "ext=%ext:~1%"

REM -----------------------------------------------------
REM Banner / debug
REM -----------------------------------------------------
if "%FLAG_QUIET%"=="0" (
    echo.
    echo ================================================================
    echo freps ^| v1.2.0 ^| %DATE% %TIME%
    echo ================================================================
)

if "%FLAG_VERBOSE%"=="1" (
    echo [DEBUG] mode=[%mode%] from=[%from%] to=[%to%] dir=[%dir%]
    echo [DEBUG] ext=[%ext%]
    echo [DEBUG] flags: DRYRUN=%FLAG_DRYRUN% VERBOSE=%FLAG_VERBOSE% BACKUP=%FLAG_BACKUP% QUIET=%FLAG_QUIET%
    echo [DEBUG] search: FILES_ONLY=%FLAG_SEARCH_FILES_ONLY% CS=%FLAG_SEARCH_CASE_SENS% RX=%FLAG_SEARCH_REGEX%
    echo.
)

REM -----------------------------------------------------
REM Validation
REM -----------------------------------------------------
if "%mode%"==""      call :err "Missing mode: r, p, or s" & goto :eof
if "%from%"==""      call :err "Missing 'from' value" & goto :eof
if "%dir%"==""       call :err "Missing target directory" & goto :eof
if not exist "%dir%" call :err "Target directory does not exist: %dir%" & goto :eof
if /i "%mode%"=="p" if "%to%"=="" call :err "Missing 'to' for replace mode (p)" & goto :eof
if /i "%mode%"=="r" if "%to%"=="" call :err "Missing 'to' for rename mode (r)"  & goto :eof

REM -----------------------------------------------------
REM Dispatch
REM -----------------------------------------------------
if /i "%mode%"=="r"  goto :RenameFiles
if /i "%mode%"=="p"  goto :ReplaceFiles
if /i "%mode%"=="s"  goto :SearchFiles

call :err "Unknown mode: %mode%"
goto :eof


:: ==============================================================================
:: RENAME
:: ==============================================================================
:RenameFiles
if "%FLAG_QUIET%"=="0" echo [INFO] Renaming "%from%" → "%to%" under "%dir%"
for /r "%dir%" %%f in (*%from%*) do (
    set "filename=%%~nxf"
    set "newname=!filename:%from%=%to%!"
    if not "!filename!"=="!newname!" (
        if "%FLAG_DRYRUN%"=="1" (
            echo [DRYRUN] REN "%%f" "!newname!"
        ) else (
            ren "%%f" "!newname!" 2>nul
            if errorlevel 1 call :warn "Could not rename: %%f"
        )
    ) else if "%FLAG_VERBOSE%"=="1" (
        echo [DEBUG] Unchanged: %%f
    )
)
for /f "delims=" %%d in ('dir /ad /b /s "%dir%" ^| sort /r') do (
    set "foldername=%%~nxd"
    set "newfolder=!foldername:%from%=%to%!"
    if not "!foldername!"=="!newfolder!" (
        if "%FLAG_DRYRUN%"=="1" (
            echo [DRYRUN] REN "%%d" "!newfolder!"
        ) else (
            ren "%%d" "!newfolder!" 2>nul
            if errorlevel 1 call :warn "Could not rename folder: %%d"
        )
    ) else if "%FLAG_VERBOSE%"=="1" (
        echo [DEBUG] Unchanged folder: %%d
    )
)
if "%FLAG_QUIET%"=="0" echo [DONE] Rename complete.
goto :eof


:: ==============================================================================
:: REPLACE (content)
:: ==============================================================================
:ReplaceFiles
if "%ext%"=="" (
    call :err "Missing file extensions for replace (e.g. .txt .cfg)"
    goto :eof
)
if "%FLAG_QUIET%"=="0" (
    echo [INFO] Replacing "%from%" → "%to%" in "%dir%" for: %ext%
    if "%FLAG_DRYRUN%"=="1" echo [INFO] DRY-RUN: no changes will be made.
    if "%FLAG_BACKUP%"=="1" echo [INFO] Backups enabled (.bak).
)
for %%x in (%ext%) do (
    if "%FLAG_VERBOSE%"=="1" echo [DEBUG] Ext: %%x
    for /r "%dir%" %%f in (*%%x) do call :ReplaceInFile "%%~ff"
)
if "%FLAG_QUIET%"=="0" echo [DONE] Content replacement complete.
goto :eof

:ReplaceInFile
set "filepath=%~1"
if not exist "%filepath%" (
    if "%FLAG_VERBOSE%"=="1" echo [DEBUG] Skipping non-existing: %filepath%
    goto :eof
)
set "tempfile=%filepath%.tmp"
break > "%tempfile%"
for /f "usebackq delims=" %%L in ("%filepath%") do (
    set "line=%%L"
    setlocal enabledelayedexpansion
    set "newline=!line:%from%=%to%!"
    >>"%tempfile%" echo(!newline!
    endlocal
)
fc /b "%filepath%" "%tempfile%" >nul 2>&1
if errorlevel 1 (
    if "%FLAG_DRYRUN%"=="1" (
        echo [DRYRUN] Would modify: %filepath%
        del /q "%tempfile%" >nul 2>&1
    ) else (
        if "%FLAG_BACKUP%"=="1" (
            copy /y "%filepath%" "%filepath%.bak" >nul 2>&1
            if errorlevel 1 call :warn "Failed to create backup: %filepath%.bak"
        )
        move /y "%tempfile%" "%filepath%" >nul
        if errorlevel 1 (
            call :err "Failed to write: %filepath%"
            del /q "%tempfile%" >nul 2>&1
        ) else if "%FLAG_VERBOSE%"=="1" (
            echo [OK] Updated: %filepath%
        )
    )
) else (
    del /q "%tempfile%" >nul 2>&1
    if "%FLAG_VERBOSE%"=="1" echo [DEBUG] No changes: %filepath%
)
goto :eof


:: ==============================================================================
:: SEARCH
:: ==============================================================================
:SearchFiles
set /a files_scanned=0
set /a matches_total=0

REM Build findstr options:
REM - default: /n (line numbers) + /i (case-insensitive) + /c:"literal"
set "FINDSTR_OPTS=/n /i"
set "FINDSTR_PATTERN=/c:""%from%"""
if "%FLAG_SEARCH_CASE_SENS%"=="1" (
    REM remove /i
    set "FINDSTR_OPTS=/n"
)
if "%FLAG_SEARCH_REGEX%"=="1" (
    REM regex mode: drop /c:"", use raw pattern
    set "FINDSTR_PATTERN=%from%"
)

if "%ext%"=="" (
    if "%FLAG_QUIET%"=="0" (
        if "%FLAG_SEARCH_FILES_ONLY%"=="1" (
            echo [INFO] Searching "%from%" (files only) in ALL files under "%dir%"
        ) else (
            echo [INFO] Searching "%from%" in ALL files under "%dir%"
        )
    )
    for /r "%dir%" %%f in (*) do call :SearchInFile "%%~ff"
) else (
    if "%FLAG_QUIET%"=="0" (
        if "%FLAG_SEARCH_FILES_ONLY%"=="1" (
            echo [INFO] Searching "%from%" (files only) in extensions: %ext% under "%dir%"
        ) else (
            echo [INFO] Searching "%from%" in extensions: %ext% under "%dir%"
        )
    )
    for %%x in (%ext%) do (
        if "%FLAG_VERBOSE%"=="1" echo [DEBUG] Ext: %%x
        for /r "%dir%" %%f in (*%%x) do call :SearchInFile "%%~ff"
    )
)

if "%FLAG_QUIET%"=="0" (
    echo.
    echo [SUMMARY] Files scanned : !files_scanned!
    echo [SUMMARY] Matches found : !matches_total!
)
goto :eof

:SearchInFile
set "filepath=%~1"
set /a files_scanned+=1

if "%FLAG_SEARCH_FILES_ONLY%"=="1" (
    REM /m lists filenames with matches only; do not combine with /n
    for /f "usebackq delims=" %%M in (`
        cmd /v:on /c ^"findstr /m %FINDSTR_OPTS: /n=% %FINDSTR_PATTERN% "%filepath%" 2^>nul^"
    `) do (
        echo %%~fM
        set /a matches_total+=1
    )
) else (
    for /f "usebackq delims=" %%M in (`
        cmd /v:on /c ^"findstr %FINDSTR_OPTS% %FINDSTR_PATTERN% "%filepath%" 2^>nul^"
    `) do (
        set "line=%%M"
        set /a matches_total+=1
        if "%FLAG_QUIET%"=="1" (
            echo !filepath!:!line!
        ) else (
            echo [HIT] !filepath!:!line!
        )
    )
)
goto :eof


:: ==============================================================================
:: Message helpers
:: ==============================================================================
:err
>&2 echo [ERROR] %~1
goto :eof

:warn
>&2 echo [WARN] %~1
goto :eof


:: ==============================================================================
:: HELP
:: ==============================================================================
:show_help
echo.
echo freps  v1.2.0  ^(MIT^)  ^|  2025-10-30
echo --------------------------------------
echo Usage:
echo   freps MODE FROM TO DIR [EXT...] [/N] [/V] [/B] [/Q] [/M] [/CS] [/RX]
echo.
echo MODE: r ^(rename^) ^| p ^(replace^) ^| s ^(search^)
echo FROM: text to find
echo TO  : replacement text ^(ignored in s^)
echo DIR : base directory
echo EXT : extensions like .txt .cfg .idf
echo.
echo Flags:
echo   /N   Dry-run ^(show actions, do not modify^)  [r,p]
echo   /V   Verbose / debug
echo   /B   Create .bak backups before write         [p]
echo   /Q   Quiet mode
echo   /M   Search: list matching filenames only
echo   /CS  Search: case-sensitive
echo   /RX  Search: treat FROM as regex
echo.
echo Examples:
echo   freps r HC54 HC99 "C:\project"
echo   freps p HC54 HC99 "C:\project" .idf .ids /B /V
echo   freps s HC54 "" "C:\project" .txt .cfg
echo   freps s HC54 "" "C:\project" .txt /M
echo   freps s ^\bHC54\b "" "C:\project" .txt /RX
echo   freps s HC54 "" "C:\project" .txt /CS
echo.
exit /b 0
