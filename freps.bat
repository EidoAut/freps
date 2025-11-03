@echo off
setlocal EnableExtensions
:: ==============================================================================
:: Project : freps (Find, REPlace, Search)
:: File    : freps.bat
:: Version : 1.4.0
:: Date    : 2025-11-03
:: Author  : Samuel Seijo (EIDO AUTOMATION SL)
:: License : MIT
:: ==============================================================================
:: Description:
::   A lightweight Windows command-line utility for renaming, replacing,
::   and searching recursively inside files and folders.
::
::   Modes:
::     r : Rename files/folders (find & replace in names)
::     p : Replace text within file contents (literal by default)
::     s : Search text inside files (lines or filenames only)
::     l : List files by NAME that contain FROM
::     u : Undo replacements by restoring .bak files (from /B)
::     d : Delete files by NAME (safe by default, requires /F to apply)
::
::   Legacy ordered arguments:
::     MODE FROM TO DIR [EXT...]
::
::   Common flags:
::     /N    Dry-run (show actions, make no changes)                  [r,p,u]
::     /V    Verbose/debug output
::     /Q    Quiet (suppress info lines)
::     /DBG  Detailed internal debug trace
::
::   Replace-specific:
::     /B    Create .bak before writing (p)
::     /CI   Case-insensitive replace via PowerShell (escapes FROM as literal)
::
::   Search-specific:
::     /M    Filenames only (no matching lines)
::     /CS   Case-sensitive search (default is case-insensitive)
::     /RX   Treat FROM as regex (default: literal via /c:"...")
::
::   Delete-specific:
::     /F    Force deletion (required to actually delete files)       [d]
::
:: Notes:
::   * In search mode, TO is ignored.
::   * EXT should include the dot, e.g. .txt .cfg .idf
::   * Replacement in mode p is case-sensitive (cmd variable substitution),
::     unless /CI is used, which performs case-insensitive replacement via PowerShell.
::   * Delayed expansion is NOT enabled globally to avoid mangling lines with '!'.
:: ==============================================================================

:: --- HELP ---
if /i "%~1"==""        goto :show_help
if /i "%~1"=="-h"      goto :show_help
if /i "%~1"=="--help"  goto :show_help
if /i "%~1"=="/?"      goto :show_help

:: --- ORDERED PARAMS ---
set "mode=%~1"
set "from=%~2"
set "to=%~3"
set "dir=%~4"
for /f "tokens=1" %%a in ("%mode%") do set "mode=%%a"
shift & shift & shift & shift

:: --- FLAGS & EXTENSIONS ---
set "ext="
set "FLAG_DRYRUN=0"
set "FLAG_VERBOSE=0"
set "FLAG_BACKUP=0"
set "FLAG_QUIET=0"
set "FLAG_SEARCH_FILES_ONLY=0"   :: /M
set "FLAG_SEARCH_CASE_SENS=0"    :: /CS
set "FLAG_SEARCH_REGEX=0"        :: /RX
set "FLAG_DEBUG=0"               :: /DBG
set "FLAG_FORCE=0"               :: /F  (delete)
set "FLAG_REPLACE_CI=0"          :: /CI (PowerShell case-insensitive replace)

:readTail
if "%~1"=="" goto afterTail
set "tkn=%~1"
REM Usar %tkn% (no !) porque no hay delayed expansion global
if "%tkn:~0,1%"=="/" (
    if /i "%tkn%"=="/N"   set "FLAG_DRYRUN=1"
    if /i "%tkn%"=="/V"   set "FLAG_VERBOSE=1"
    if /i "%tkn%"=="/B"   set "FLAG_BACKUP=1"
    if /i "%tkn%"=="/Q"   set "FLAG_QUIET=1"
    if /i "%tkn%"=="/M"   set "FLAG_SEARCH_FILES_ONLY=1"
    if /i "%tkn%"=="/CS"  set "FLAG_SEARCH_CASE_SENS=1"
    if /i "%tkn%"=="/RX"  set "FLAG_SEARCH_REGEX=1"
    if /i "%tkn%"=="/DBG" set "FLAG_DEBUG=1"
    if /i "%tkn%"=="/F"   set "FLAG_FORCE=1"
    if /i "%tkn%"=="/CI"  set "FLAG_REPLACE_CI=1"
) else if "%tkn:~0,1%"=="." (
    set "ext=%ext% %tkn%"
) else (
    call :warn "Ignoring non-extension arg: %tkn% (expected like .txt)"
)
shift
goto :readTail

:afterTail
if defined ext set "ext=%ext:~1%"

:: --- DEBUG SETUP ---
if "%FLAG_DEBUG%"=="1" (echo on) else (echo off)
call :dbg "== START =="
call :dbg "ARGS: mode=[%mode%] from=[%from%] to=[%to%] dir=[%dir%]"
call :dbg "EXT=[%ext%] FLAGS: N=%FLAG_DRYRUN% V=%FLAG_VERBOSE% B=%FLAG_BACKUP% Q=%FLAG_QUIET% M=%FLAG_SEARCH_FILES_ONLY% CS=%FLAG_SEARCH_CASE_SENS% RX=%FLAG_SEARCH_REGEX% F=%FLAG_FORCE% CI=%FLAG_REPLACE_CI% DBG=%FLAG_DEBUG%"

:: --- HEADER OUTPUT ---
if "%FLAG_QUIET%"=="0" (
    echo.
    echo ================================================================
    echo freps ^| v1.4.0 ^| %DATE% %TIME%
    echo ================================================================
)

:: --- VALIDATION ---
if "%mode%"==""      call :err "Missing mode: r, p, s, l, u, or d" & goto :eof
if /i not "%mode%"=="u" if /i not "%mode%"=="d" if "%from%"=="" call :err "Missing 'from' value" & goto :eof
if "%dir%"==""       call :err "Missing target directory" & goto :eof
if not exist "%dir%" call :err "Target directory does not exist: %dir%" & goto :eof
if /i "%mode%"=="p" if "%to%"=="" call :err "Missing 'to' for replace mode (p)" & goto :eof
if /i "%mode%"=="r" if "%to%"=="" call :err "Missing 'to' for rename mode (r)"  & goto :eof

:: --- DISPATCH ---
call :dbg "Dispatching to mode [%mode%]"
if /i "%mode%"=="r"  goto :RenameFiles
if /i "%mode%"=="p"  goto :ReplaceFiles
if /i "%mode%"=="s"  goto :SearchFiles
if /i "%mode%"=="l"  goto :ListByName
if /i "%mode%"=="u"  goto :UndoBackups
if /i "%mode%"=="d"  goto :DeleteByName
call :err "Unknown mode: %mode%" & goto :eof

:: ==============================================================================
:: MODE R: RENAME FILES AND FOLDERS (with long-path prefixing)
:: ==============================================================================
:RenameFiles
call :dbg "Enter :RenameFiles"
if "%FLAG_QUIET%"=="0" echo [INFO] Renaming "%from%" ^> "%to%" under "%dir%"

:: We enable delayed expansion only within the rename block.
setlocal EnableDelayedExpansion

call :dbg "Looping through files..."
for /r "%dir%" %%f in (*%from%*) do (
    set "filename=%%~nxf"
    set "newname=!filename:%from%=%to%!"
    call :dbg "Check file: %%f | old=!filename! | new=!newname!"
    if not "!filename!"=="!newname!" (
        set "p=%%~ff"
        if "!p:~1,1!"==":" set "p=\\?\!p!"
        if "%FLAG_DRYRUN%"=="1" (
            echo [DRYRUN] REN "!p!" "!newname!"
        ) else (
            ren "!p!" "!newname!" 2>nul
            if errorlevel 1 (
                for %%E in (5 32) do if errorlevel %%E if not errorlevel %%E+1 call :warn "Could not rename (code %%E): %%f"
                if errorlevel 1 call :warn "Could not rename: %%f"
            )
        )
    ) else if "%FLAG_VERBOSE%"=="1" (
        echo [DEBUG] Unchanged: %%f
    )
)

call :dbg "Looping through folders (deepest first)..."
for /f "delims=" %%d in ('dir /ad /b /s "%dir%" ^| sort /r') do (
    set "foldername=%%~nxd"
    set "newfolder=!foldername:%from%=%to%!"
    call :dbg "Check folder: %%d | old=!foldername! | new=!newfolder!"
    if not "!foldername!"=="!newfolder!" (
        set "p=%%~fd"
        if "!p:~1,1!"==":" set "p=\\?\!p!"
        if "%FLAG_DRYRUN%"=="1" (
            echo [DRYRUN] REN "!p!" "!newfolder!"
        ) else (
            ren "!p!" "!newfolder!" 2>nul
            if errorlevel 1 (
                for %%E in (5 32) do if errorlevel %%E if not errorlevel %%E+1 call :warn "Could not rename folder (code %%E): %%d"
                if errorlevel 1 call :warn "Could not rename folder: %%d"
            )
        )
    ) else if "%FLAG_VERBOSE%"=="1" (
        echo [DEBUG] Unchanged folder: %%d
    )
)

endlocal

if "%FLAG_QUIET%"=="0" echo [DONE] Rename complete.
call :dbg "Exit :RenameFiles"
goto :eof

:: ==============================================================================
:: MODE P: REPLACE TEXT INSIDE FILES
:: - Literal, case-sensitive replacement using CMD expansion
:: - /CI uses PowerShell for case-insensitive literal replacement
:: - Skips likely binary files; preserves blank lines and '!' safely
:: ==============================================================================
:ReplaceFiles
call :dbg "Enter :ReplaceFiles"

:: --- VALIDATION (/DBG-safe) ---
if defined ext goto :RF_Info
call :err "Missing file extensions for replace (e.g. .txt .cfg)"
goto :eof

:RF_Info
:: --- Messages without blocks () to avoid parser issues ---
if "%FLAG_QUIET%"=="1" goto :RF_Loop
echo [INFO] Replacing "%from%" ^> "%to%" in "%dir%" for: %ext%
if "%FLAG_DRYRUN%"=="1" echo [INFO] DRY-RUN: no changes will be made.
if "%FLAG_BACKUP%"=="1" echo [INFO] Backups enabled (.bak).

:RF_Loop
:: robust loop over extensions; quote pattern as "*%%x"
for %%x in (%ext%) do (
    call :dbg "Extension loop: %%x"
    for /r "%dir%" %%f in ("*%%x") do (
        call :ReplaceInFile "%%~ff"
    )
)

if "%FLAG_QUIET%"=="0" echo [DONE] Content replacement complete.
call :dbg "Exit :ReplaceFiles"
goto :eof

:ReplaceInFile
call :dbg "Enter :ReplaceInFile %~1"
set "filepath=%~1"
if not exist "%filepath%" ( call :dbg "Skip non-existing: %filepath%" & goto :eof )

:: --- Skip binary files quickly ---
:: findstr /P /M marks as text only if printable characters are present
set "isText="
for /f "delims=" %%B in ('findstr /P /M /R "." "%filepath%" 2^>nul') do set "isText=1"
if not defined isText (
    call :dbg "Binary or unreadable; skip: %filepath%"
    goto :eof
)

set "tempfile=%filepath%.tmp"
break > "%tempfile%"

:: --- Read lines without using backticks or embedded commands ---
:: Delayed expansion OFF while reading to preserve literal "!" and blanks per line.
setlocal DisableDelayedExpansion
for /f "usebackq delims=" %%L in ("%filepath%") do (
    set "line=%%L"
    setlocal EnableDelayedExpansion
    set "newline=!line:%from%=%to%!"
    >>"%tempfile%" echo(!newline!
    endlocal
)
endlocal

:: --- Compare and replace if different ---
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
call :dbg "Exit :ReplaceInFile %~1"
goto :eof

:: ==============================================================================
:: MODE S: SEARCH IN FILES
:: ==============================================================================
:SearchFiles
call :dbg "Enter :SearchFiles"
set /a files_scanned=0
set /a matches_total=0

set "OPTS_LINES=/n /P"
set "OPTS_FILES=/m /P"
if "%FLAG_SEARCH_CASE_SENS%"=="0" (
    set "OPTS_LINES=%OPTS_LINES% /i"
    set "OPTS_FILES=%OPTS_FILES% /i"
)
if "%FLAG_SEARCH_REGEX%"=="1" ( set "PATTERN=%from%" ) else ( set "PATTERN=/c:""%from%""" )

call :dbg "Search opts: LINES=[%OPTS_LINES%] FILES=[%OPTS_FILES%] PATTERN=[%PATTERN%]"

if "%FLAG_QUIET%"=="0" (
    set "MSG_MODE="
    if "%FLAG_SEARCH_FILES_ONLY%"=="1" set "MSG_MODE=files only "
    set "MSG_SCOPE=in ALL files"
    if defined ext set "MSG_SCOPE=in extensions: %ext%"
    echo [INFO] Searching "%from%" %MSG_MODE%%MSG_SCOPE% under "%dir%"
)

if "%ext%"=="" (
    call :dbg "Search all files recursively"
    for /r "%dir%" %%f in (*) do call :SearchInFile "%%~ff"
) else (
    for %%x in (%ext%) do (
        call :dbg "Search ext loop: %%x"
        for /r "%dir%" %%f in ("*%%x") do call :SearchInFile "%%~ff"
    )
)

if "%FLAG_QUIET%"=="0" (
    echo.
    echo [SUMMARY] Files scanned : %files_scanned%
	echo [SUMMARY] Matches found : %matches_total%
)
call :dbg "Exit :SearchFiles"
goto :eof

:SearchInFile
set "filepath=%~1"
set /a files_scanned+=1
call :dbg "Enter :SearchInFile file=[%filepath%]"

if "%FLAG_SEARCH_FILES_ONLY%"=="1" (
    call :dbg "RUN: findstr %OPTS_FILES% %PATTERN% "%filepath%""
    for /f "delims=" %%M in ('findstr %OPTS_FILES% %PATTERN% "%filepath%" 2^>nul') do (
        echo %%~fM
        set /a matches_total+=1
        call :dbg "Match filename only -> %%~fM"
        goto :eof
    )
) else (
    call :dbg "RUN: findstr %OPTS_LINES% %PATTERN% "%filepath%""
    for /f "delims=" %%M in ('findstr %OPTS_LINES% %PATTERN% "%filepath%" 2^>nul') do (
        set /a matches_total+=1
        if "%FLAG_QUIET%"=="1" (
            echo %filepath%:%%M
        ) else (
            echo [HIT] %filepath%:%%M
        )
        if "%FLAG_DEBUG%"=="1" echo [DBG] LINE: %%M
    )
)

call :dbg "Exit :SearchInFile file=[%filepath%]"
goto :eof

:: ==============================================================================
:: MODE L: LIST FILES BY NAME MATCH
:: ==============================================================================
:ListByName
call :dbg "Enter :ListByName"
set /a list_count=0

if "%FLAG_QUIET%"=="0" (
    if "%ext%"=="" (
        echo [INFO] Listing files containing "%from%" under "%dir%"
    ) else (
        echo [INFO] Listing files containing "%from%" with EXT: %ext% under "%dir%"
    )
)

if "%ext%"=="" (
    for /r "%dir%" %%f in (*) do (
        set "name=%%~nxf"
        setlocal enabledelayedexpansion
        set "match=!name!"
        if /i not "!match:%from%=!"=="!match!" (
            endlocal & echo %%~ff & set /a list_count+=1
        ) else (
            endlocal
        )
    )
) else (
    for %%x in (%ext%) do (
        for /r "%dir%" %%f in ("*%%x") do (
            set "name=%%~nxf"
            setlocal enabledelayedexpansion
            set "match=!name!"
            if /i not "!match:%from%=!"=="!match!" (
                endlocal & echo %%~ff & set /a list_count+=1
            ) else (
                endlocal
            )
        )
    )
)

if "%FLAG_QUIET%"=="0" (
    echo.
    echo [SUMMARY] Listed files : %list_count%
)
call :dbg "Exit :ListByName"
goto :eof

:: ==============================================================================
:: MODE U: UNDO FROM .BAK
:: ==============================================================================
:UndoBackups
call :dbg "Enter :UndoBackups"
set /a restored=0
if "%FLAG_QUIET%"=="0" (
    if "%FLAG_DRYRUN%"=="1" (echo [INFO] DRY-RUN undo mode.) else (echo [INFO] Restoring from .bak backups.)
)

for /r "%dir%" %%f in (*.bak) do (
    set "bak=%%~ff"
    set "orig=%%~dpnxf"
    setlocal enabledelayedexpansion
    set "orig=!orig:~0,-4!"
    if "%FLAG_DRYRUN%"=="1" (
        endlocal & echo [DRYRUN] MOVE "%%~ff" "!orig!" & set /a restored+=1
    ) else (
        endlocal & move /y "%%~ff" "!orig!" >nul
        if errorlevel 1 (
            call :warn "Failed to restore: %%~ff"
        ) else (
            if "%FLAG_VERBOSE%"=="1" echo [OK] Restored: !orig!
            set /a restored+=1
        )
    )
)

if "%FLAG_QUIET%"=="0" (
    echo.
    echo [SUMMARY] Restored files : %restored%
)
call :dbg "Exit :UndoBackups"
goto :eof

:: ==============================================================================
:: MODE D: DELETE FILES BY NAME (SAFE BY DEFAULT; /F to apply)
:: ==============================================================================
:DeleteByName
call :dbg "Enter :DeleteByName"
set /a del_count=0
if "%FLAG_QUIET%"=="0" (
    if "%FLAG_FORCE%"=="1" (echo [INFO] DELETE mode FORCE.) else (echo [INFO] DELETE mode dry-run. Use /F to apply.)
)

if "%ext%"=="" (
    for /r "%dir%" %%f in (*) do (
        set "name=%%~nxf"
        setlocal enabledelayedexpansion
        set "match=!name!"
        if /i not "!match:%from%=!"=="!match!" (
            if "%FLAG_FORCE%"=="1" (
                endlocal & del /q "%%~ff" 2>nul
                if errorlevel 1 (call :warn "Failed to delete: %%~ff") else (
                    if "%FLAG_VERBOSE%"=="1" echo [DEL] %%~ff
                    set /a del_count+=1
                )
            ) else (
                endlocal & echo [DRYRUN] DEL "%%~ff" & set /a del_count+=1
            )
        ) else (
            endlocal
        )
    )
) else (
    for %%x in (%ext%) do (
        for /r "%dir%" %%f in ("*%%x") do (
            set "name=%%~nxf"
            setlocal enabledelayedexpansion
            set "match=!name!"
            if /i not "!match:%from%=!"=="!match!" (
                if "%FLAG_FORCE%"=="1" (
                    endlocal & del /q "%%~ff" 2>nul
                    if errorlevel 1 (call :warn "Failed to delete: %%~ff") else (
                        if "%FLAG_VERBOSE%"=="1" echo [DEL] %%~ff
                        set /a del_count+=1
                    )
                ) else (
                    endlocal & echo [DRYRUN] DEL "%%~ff" & set /a del_count+=1
                )
            ) else (
                endlocal
            )
        )
    )
)

if "%FLAG_QUIET%"=="0" (
    echo.
    echo [SUMMARY] Files matched : %del_count%
    if "%FLAG_FORCE%"=="0" echo [HINT] Use /F to actually delete matched files.
)
call :dbg "Exit :DeleteByName"
goto :eof

:: ==============================================================================
:: MESSAGE HELPERS
:: ==============================================================================
:err
>&2 echo [ERROR] %~1
goto :eof

:warn
>&2 echo [WARN] %~1
goto :eof

:dbg
if "%FLAG_DEBUG%"=="1" echo [DBG] %~1
goto :eof

:: ==============================================================================
:: HELP / USAGE
:: ==============================================================================
:show_help
echo.
echo freps  v1.4.0  ^(MIT^)  ^|  %DATE%
echo --------------------------------------
echo Usage:
echo   freps MODE FROM TO DIR [EXT...] [/N] [/V] [/B] [/Q] [/M] [/CS] [/RX] [/F] [/CI] [/DBG]
echo.
echo MODE:
echo   r  Rename files/folders (find and replace in names)
echo   p  Replace text within file contents
echo   s  Search text inside files
echo   l  List files by NAME that contain FROM
echo   u  Undo: restore .bak files to original
echo   d  Delete files by NAME (requires /F to apply)
echo.
echo ARGS:
echo   FROM  text to find   (ignored only in u)
echo   TO    replacement    (ignored in s, l, u, d)
echo   DIR   base directory (searched recursively)
echo   EXT   optional extensions like .txt .cfg .idf
echo.
echo Flags:
echo   /N   Dry-run (show actions, do not modify)              [r,p,u]
echo   /V   Verbose/debug output
echo   /B   Create .bak backups before write                   [p]
echo   /Q   Quiet mode
echo   /M   Search: list matching filenames only               [s]
echo   /CS  Search: case-sensitive                             [s]
echo   /RX  Search: treat FROM as regex                        [s]
echo   /F   Force deletion (required to actually delete)       [d]
echo   /CI  Replace: case-insensitive via PowerShell           [p]
echo   /DBG Print detailed debug trace
echo.
echo Examples:
echo   freps r old new "C:\project"
echo   freps p token TOKEN "C:\project" .cfg .txt /B /V
echo   freps p foo bar "C:\project" .txt /CI
echo   freps s ERROR "" "C:\logs" .log /M
echo   freps l draft "" "C:\project"
echo   freps u "" "" "C:\project" /N
echo   freps d temp "" "C:\project" .tmp .bak /F
echo.
exit /b 0
