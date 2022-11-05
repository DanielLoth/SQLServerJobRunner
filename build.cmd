@echo off

set DOTNET_ROOT=%~dp0.dotnet\
set DOTNET_MULTILEVEL_LOOKUP=0
set PATH=%DOTNET_ROOT%;%PATH%
@REM set sln=%1
set sln=DotnetCoreProjects.slnf

if not exist "%DOTNET_ROOT%\dotnet.exe" (
    call restore.cmd
)

dotnet build %sln% -c Release
