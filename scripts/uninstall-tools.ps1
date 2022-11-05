#requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$WorkingDir = $(Get-Location)

$DotnetFolderPath = Join-Path -Path $WorkingDir -ChildPath ".dotnet"
$DotnetExePath = Join-Path -Path $DotnetFolderPath -ChildPath "dotnet.exe"

$SqlPackageFolderPath = Join-Path -Path $WorkingDir -ChildPath ".sqlpackage"
$SqlPackageExePath = Join-Path -Path $SqlPackageFolderPath -ChildPath "sqlpackage.exe"

(Get-Process -Name dotnet -ErrorAction SilentlyContinue) | Where-Object -Property Path -eq -Value $DotnetExePath | Stop-Process -Force -ErrorAction SilentlyContinue

(Get-Process -Name dotnet -ErrorAction SilentlyContinue) | Where-Object -Property Path -eq -Value $SqlPackageExePath | Stop-Process -Force -ErrorAction SilentlyContinue

function SafeRemoveFile($Path) {
    try {
        if (Test-Path $Path) {
            Remove-Item $Path -Force -Recurse
            Write-Host "The path `"$Path`" was removed."
        }
        else
        {
            Write-Host "The path `"$Path`" does not exist, therefore is not removed."
        }
    }
    catch
    {
        Write-Warning "Failed to remove the path: `"$Path`", remove it manually."
    }
}

SafeRemoveFile($SqlPackageFolderPath)
SafeRemoveFile($DotnetFolderPath)
