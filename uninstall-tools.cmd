@echo off

echo Deleting .dotnet and .sqlpackage folders ...

powershell -ExecutionPolicy ByPass -NoProfile -command "& '%~dp0scripts\uninstall-tools.ps1' %*"
