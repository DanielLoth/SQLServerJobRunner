@echo off

set DOTNET_ROOT=%~dp0.dotnet\
set SQLPACKAGE_ROOT=%~dp0.sqlpackage\

if not exist "%DOTNET_ROOT%\dotnet.exe" (
    powershell -ExecutionPolicy ByPass -NoProfile -command "& '%~dp0scripts\dotnet-install.ps1' -InstallDir .\.dotnet\  %*"
)

if not exist "%SQLPACKAGE_ROOT%\sqlpackage.exe" (
    powershell -ExecutionPolicy ByPass -NoProfile -command "& '%~dp0scripts\sqlpackage-install.ps1' -InstallRoot .\.sqlpackage %*"
)
