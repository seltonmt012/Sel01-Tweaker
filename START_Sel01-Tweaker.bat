@echo off
title Sel01-Tweaker

:: --- Einmal als Administrator neu starten ---------------------------------
:: Arg-Guard "elevated" verhindert eine Endlosschleife. fltmc als Admin-Check
:: (haengt nicht am Server-Dienst LanmanServer wie das alte "net session").
if "%~1"=="elevated" goto run
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList 'elevated' -Verb RunAs"
    exit /b
)

:run
:: Das Menue, die Uebersicht und die Credits kommen aus dem PowerShell-Tool.
:: -ExecutionPolicy Bypass laeuft auch wenn Skripte sonst blockiert sind.
if not exist "%~dp0dist\Sel01Tweaker.ps1" (
    echo FEHLER: dist\Sel01Tweaker.ps1 fehlt. Bitte zuerst build.bat ausfuehren.
    pause
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dist\Sel01Tweaker.ps1"
