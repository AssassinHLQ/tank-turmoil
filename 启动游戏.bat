@echo off
cd /d "%~dp0"
set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64.exe"
if exist "%GODOT_EXE%" goto launch
where godot.exe >nul 2>nul
if not errorlevel 1 set "GODOT_EXE=godot.exe"
if not defined GODOT_EXE goto missing
:launch
start "" "%GODOT_EXE%" --path "%CD%"
exit /b 0
:missing
echo Godot 4 was not found.
pause
