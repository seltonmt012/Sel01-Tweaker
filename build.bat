@echo off
title Sel01-Tweaker - Build
:: Baut dist\Sel01Tweaker.ps1 aus src\. -ExecutionPolicy Bypass umgeht die
:: "Skripte sind deaktiviert"-Sperre und die Mark-of-the-Web-Blockade bei
:: aus dem Internet geladenen Dateien (haeufige Ursache fuer build-Fehler).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
echo.
pause
