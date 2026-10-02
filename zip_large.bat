@echo off
setlocal

rem ---- Settings ----
set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
set "PASSWORD=arkh91"
set "MINSIZE=52428800"  rem 50 MB in bytes

rem Loop over every file in the current folder
for %%F in (*) do (
    rem Only files > 50MB, skip existing .zip files and this script itself
    if %%~zF GTR %MINSIZE% if /I not "%%~xF"==".zip" if /I not "%%~nxF"=="%~nx0" (
        call :ZipFile "%%F"
    )
)

echo Done.
endlocal
exit /b

rem ------------------------------------------------------------
rem Function: ZipFile
rem Usage:    call :ZipFile "filename.ext"
rem Effect:   creates filename.zip (same base name), password-protected
rem ------------------------------------------------------------
:ZipFile
echo Zipping %~1 ...
"%SEVENZIP%" a -tzip -p%PASSWORD% "%~n1.zip" "%~1"
exit /b
