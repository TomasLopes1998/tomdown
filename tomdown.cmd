@echo off
rem Windows shim for tomdown. Expects tomdown.py to live next to this file.
rem install.ps1 places both files together in %LOCALAPPDATA%\Programs\tomdown.
setlocal
"uv" run --script "%~dp0tomdown.py" %*
exit /b %ERRORLEVEL%
