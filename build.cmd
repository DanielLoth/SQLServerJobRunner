@echo off

set DOTNET_ROOT=%~dp0.dotnet\
set DOTNET_MULTILEVEL_LOOKUP=0
set PATH=%DOTNET_ROOT%;%PATH%
set sln=%1

dotnet build %sln% -c Release
