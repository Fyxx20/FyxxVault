@echo off
title FyxxVault Installer
echo.
echo   Launching FyxxVault installer...
echo.
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Fyxx20/FyxxVault/main/windows/install.ps1 | iex"
echo.
echo   Press any key to close...
pause >nul
