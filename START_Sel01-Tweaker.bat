@echo off
title Sel01-Tweaker

:: --- Selbst EINMAL als Administrator neu starten ---------------------------
:: Arg-Guard "elevated" verhindert eine Endlosschleife. fltmc statt
:: "net session" als Admin-Check (haengt nicht am Server-Dienst LanmanServer).
if "%~1"=="elevated" goto admin
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elevated' -Verb RunAs"
    exit /b
)

:admin
chcp 65001 >nul

:menu
cls
echo ==========================================
echo           S E L 0 1 - T W E A K E R
echo      Windows 11 in 1 Klick optimieren
echo ==========================================
echo.
echo   [1]  GAMING   - empfohlen (Game Mode bleibt an)
echo   [2]  CLEAN    - maximales Debloat (Office/Allround)
echo   [3]  TESTLAUF - zeigt nur an, aendert NICHTS
echo   [4]  RUECKGAENGIG - macht letzten Lauf wieder weg
echo   [5]  Beenden
echo.
set "ARGS="
set /p "c=Deine Wahl (1-5) und Enter: "

if "%c%"=="1" set "ARGS=-Profile Gaming"
if "%c%"=="2" set "ARGS=-Profile Clean"
if "%c%"=="3" set "ARGS=-DryRun -Profile Gaming"
if "%c%"=="4" set "ARGS=-Revert"
if "%c%"=="5" exit /b

cls
echo Starte... bitte warten. Schliesse dieses Fenster NICHT.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dist\Sel01Tweaker.ps1" %ARGS%

echo.
echo ==========================================
echo   FERTIG. Ein Neustart wird empfohlen.
echo ==========================================
echo.
pause
goto menu
