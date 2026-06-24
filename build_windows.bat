@echo off
rem Builds PhotoSorter.exe — run this once on a Windows PC.
rem Output: dist\PhotoSorter.exe  (single standalone exe, no install needed)
rem Requires Python 3 from python.org (check "Add Python to PATH" during install)
rem Drop icon.ico in this folder for a custom icon.
cd /d "%~dp0"

set "PYTHON="
where python >nul 2>&1  && set "PYTHON=python"
if not defined PYTHON (where python3 >nul 2>&1 && set "PYTHON=python3")
if not defined PYTHON (where py     >nul 2>&1 && set "PYTHON=py")
if not defined PYTHON (
    echo Python not found. Install from https://python.org
    pause & exit /b 1
)

echo Creating build environment...
%PYTHON% -m venv .venv
call .venv\Scripts\activate.bat

echo Installing PyInstaller...
pip install --quiet pyinstaller

set "ICON_FLAG="
if exist "icon.ico" set "ICON_FLAG=--icon icon.ico"

echo Building PhotoSorter.exe...
pyinstaller --noconfirm --onefile --windowed --name PhotoSorter --hidden-import tkinter.scrolledtext %ICON_FLAG% PhotoSorter.py

call deactivate
rmdir /s /q .venv  2>nul
rmdir /s /q build  2>nul
del PhotoSorter.spec 2>nul

echo.
echo Done: dist\PhotoSorter.exe
echo.
echo For GPS-based sorting, download exiftool.exe from https://exiftool.org
echo and place it in the same folder as PhotoSorter.exe.
pause
