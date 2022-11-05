@echo off

if not exist "%DOTNET_ROOT%\dotnet.exe" (
    powershell -ExecutionPolicy ByPass -NoProfile -command "& '%~dp0scripts\dotnet-install.ps1' -InstallDir .\.dotnet\  %*"
)
