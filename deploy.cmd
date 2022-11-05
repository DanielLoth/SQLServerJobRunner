@echo off

set SQLPACKAGE_ROOT=%~dp0.sqlpackage\
set PATH=%SQLPACKAGE_ROOT%;%PATH%
set TARGET_SERVER=localhost
set DATABASE_NAME=JobRunnerExample

echo Deploy with demo data? (y/n)
set /p flag=
if /i "%flag%" == "y" goto demo
if /i "%flag%" == "n" goto empty

echo Option not recognised. Please specify y/n.
goto :error

:empty
set SOURCE_FILE=.\src\JobRunner.Build\bin\Release\netstandard2.0\JobRunner.dacpac
goto deploy

:demo
set SOURCE_FILE=.\src\JobRunnerWithDemoData.Build\bin\Release\netstandard2.0\JobRunnerWithDemoData.dacpac
goto deploy

:deploy

sqlpackage.exe ^
/Action:Publish ^
/SourceFile:%SOURCE_FILE% ^
/DeployScriptPath:%DATABASE_NAME%.deployscript.sql ^
/DeployReportPath:%DATABASE_NAME%.deployreport.xml ^
/OverwriteFiles:True ^
/TargetServerName:%TARGET_SERVER% ^
/TargetDatabaseName:%DATABASE_NAME% ^
/p:CreateNewDatabase=True ^
/p:IgnoreWhitespace=True ^
/p:IgnoreSemicolonBetweenStatements=True

if %errorlevel% neq 0 (
    echo An error occurred while running sqlpackage.exe
    goto :error
)

:end
exit /b 0

:error
exit /b 1
