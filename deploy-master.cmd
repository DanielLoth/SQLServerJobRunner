@echo off

set SQLPACKAGE_ROOT=%~dp0.sqlpackage\
set PATH=%SQLPACKAGE_ROOT%;%PATH%
set TARGET_SERVER=localhost
set DATABASE_NAME=master
set SOURCE_FILE=.\src\MasterDB.Build\bin\Release\netstandard2.0\MasterDB.dacpac

if not exist "%SQLPACKAGE_ROOT%\sqlpackage.exe" (
    call restore.cmd
)

echo Target server^: %TARGET_SERVER%
echo Target database^: %DATABASE_NAME%

sqlpackage.exe ^
/Action:Publish ^
/SourceFile:%SOURCE_FILE% ^
/DeployScriptPath:%DATABASE_NAME%.deployscript.sql ^
/DeployReportPath:%DATABASE_NAME%.deployreport.xml ^
/OverwriteFiles:True ^
/TargetServerName:%TARGET_SERVER% ^
/TargetDatabaseName:%DATABASE_NAME% ^
/TargetEncryptConnection:True ^
/TargetTrustServerCertificate:True ^
/p:IgnoreWhitespace=True ^
/p:IgnoreSemicolonBetweenStatements=True ^
/v:CategoryName="Database Maintenance" ^
/v:OwnerLoginName="sa" ^
/v:ReplicatorJobName="JobRunner job replicator" ^
/v:ServerName="(local)" ^
/v:ScheduleName="JobRunner job replicator schedule" ^
/v:RecurringSecondsInterval=10

if %errorlevel% neq 0 (
    echo An error occurred while running sqlpackage.exe
    goto :error
)

:end
exit /b 0

:error
exit /b 1
