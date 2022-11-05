[CmdletBinding()]
param (
    [string]$FeedCredential,
    [string]$ProxyAddress,
    [int]$DownloadTimeout = 1200,
    [string]$InstallRoot
)

#requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Url = "https://aka.ms/sqlpackage-windows"
$ZipPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())

function Load-Assembly([string] $Assembly) {
    try {
        Add-Type -Assembly $Assembly | Out-Null
    }
    catch {
        # On Nano Server, Powershell Core Edition is used.  Add-Type is unable to resolve base class assemblies because they are not GAC'd.
        # Loading the base class assemblies is not unnecessary as the types will automatically get resolved.
    }
}

function SafeRemoveFile($Path) {
    try {
        if (Test-Path $Path) {
            Remove-Item $Path
            Write-Verbose "The temporary file `"$Path`" was removed."
        }
        else
        {
            Write-Verbose "The temporary file `"$Path`" does not exist, therefore is not removed."
        }
    }
    catch
    {
        Write-Warning "Failed to remove the temporary file: `"$Path`", remove it manually."
    }
}

function DownloadFile($Source, [string]$OutPath) {
    if ($Source -notlike "http*") {
        #  Using System.IO.Path.GetFullPath to get the current directory
        #    does not work in this context - $pwd gives the current directory
        if (![System.IO.Path]::IsPathRooted($Source)) {
            $Source = $(Join-Path -Path $pwd -ChildPath $Source)
        }
        $Source = Get-Absolute-Path $Source
        Say "Copying file from $Source to $OutPath"
        Copy-Item $Source $OutPath
        return
    }

    $Stream = $null

    try {
        $Response = GetHTTPResponse -Uri $Source
        $Stream = $Response.Content.ReadAsStreamAsync().Result
        $File = [System.IO.File]::Create($OutPath)
        $Stream.CopyTo($File)
        $File.Close()
    }
    finally {
        if ($null -ne $Stream) {
            $Stream.Dispose()
        }
    }
}

function GetHTTPResponse([Uri] $Uri, [bool]$HeaderOnly, [bool]$DisableRedirect, [bool]$DisableFeedCredential)
{
    $cts = New-Object System.Threading.CancellationTokenSource

    $downloadScript = {

        $HttpClient = $null

        try {
            # HttpClient is used vs Invoke-WebRequest in order to support Nano Server which doesn't support the Invoke-WebRequest cmdlet.
            Load-Assembly -Assembly System.Net.Http

            if(-not $ProxyAddress) {
                try {
                    # Despite no proxy being explicitly specified, we may still be behind a default proxy
                    $DefaultProxy = [System.Net.WebRequest]::DefaultWebProxy;
                    if($DefaultProxy -and (-not $DefaultProxy.IsBypassed($Uri))) {
                        if ($null -ne $DefaultProxy.GetProxy($Uri)) {
                            $ProxyAddress = $DefaultProxy.GetProxy($Uri).OriginalString
                        } else {
                            $ProxyAddress = $null
                        }
                        $ProxyUseDefaultCredentials = $true
                    }
                } catch {
                    # Eat the exception and move forward as the above code is an attempt
                    #    at resolving the DefaultProxy that may not have been a problem.
                    $ProxyAddress = $null
                    Say-Verbose("Exception ignored: $_.Exception.Message - moving forward...")
                }
            }

            $HttpClientHandler = New-Object System.Net.Http.HttpClientHandler
            if($ProxyAddress) {
                $HttpClientHandler.Proxy =  New-Object System.Net.WebProxy -Property @{
                    Address=$ProxyAddress;
                    UseDefaultCredentials=$ProxyUseDefaultCredentials;
                    BypassList = $ProxyBypassList;
                }
            }       
            if ($DisableRedirect)
            {
                $HttpClientHandler.AllowAutoRedirect = $false
            }
            $HttpClient = New-Object System.Net.Http.HttpClient -ArgumentList $HttpClientHandler

            # Default timeout for HttpClient is 100s.  For a 50 MB download this assumes 500 KB/s average, any less will time out
            # Defaulting to 20 minutes allows it to work over much slower connections.
            $HttpClient.Timeout = New-TimeSpan -Seconds $DownloadTimeout

            if ($HeaderOnly){
                $completionOption = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
            }
            else {
                $completionOption = [System.Net.Http.HttpCompletionOption]::ResponseContentRead
            }

            if ($DisableFeedCredential) {
                $UriWithCredential = $Uri
            }
            else {
                $UriWithCredential = "${Uri}${FeedCredential}"
            }

            $Task = $HttpClient.GetAsync("$UriWithCredential", $completionOption).ConfigureAwait("false");
            $Response = $Task.GetAwaiter().GetResult();

            if (($null -eq $Response) -or ((-not $HeaderOnly) -and (-not ($Response.IsSuccessStatusCode)))) {
                # The feed credential is potentially sensitive info. Do not log FeedCredential to console output.
                $DownloadException = [System.Exception] "Unable to download $Uri."

                if ($null -ne $Response) {
                    $DownloadException.Data["StatusCode"] = [int] $Response.StatusCode
                    $DownloadException.Data["ErrorMessage"] = "Unable to download $Uri. Returned HTTP status code: " + $DownloadException.Data["StatusCode"]

                    if (404 -eq [int] $Response.StatusCode)
                    {
                        $cts.Cancel()
                    }
                }

                throw $DownloadException
            }

            return $Response
        }
        catch [System.Net.Http.HttpRequestException] {
            $DownloadException = [System.Exception] "Unable to download $Uri."

            # Pick up the exception message and inner exceptions' messages if they exist
            $CurrentException = $PSItem.Exception
            $ErrorMsg = $CurrentException.Message + "`r`n"
            while ($CurrentException.InnerException) {
              $CurrentException = $CurrentException.InnerException
              $ErrorMsg += $CurrentException.Message + "`r`n"
            }

            # Check if there is an issue concerning TLS.
            if ($ErrorMsg -like "*SSL/TLS*") {
                $ErrorMsg += "Ensure that TLS 1.2 or higher is enabled to use this script.`r`n"
            }

            $DownloadException.Data["ErrorMessage"] = $ErrorMsg
            throw $DownloadException
        }
        finally {
             if ($null -ne $HttpClient) {
                $HttpClient.Dispose()
            }
        }
    }

    try {
        return Invoke-With-Retry $downloadScript $cts.Token
    }
    finally
    {
        if ($null -ne $cts)
        {
            $cts.Dispose()
        }
    }
}

function Invoke-With-Retry([ScriptBlock]$ScriptBlock, [System.Threading.CancellationToken]$cancellationToken = [System.Threading.CancellationToken]::None, [int]$MaxAttempts = 3, [int]$SecondsBetweenAttempts = 1) {
    $Attempts = 0
    $local:startTime = $(get-date)

    while ($true) {
        try {
            return & $ScriptBlock
        }
        catch {
            $Attempts++
            if (($Attempts -lt $MaxAttempts) -and -not $cancellationToken.IsCancellationRequested) {
                Start-Sleep $SecondsBetweenAttempts
            }
            else {
                $local:elapsedTime = $(get-date) - $local:startTime
                if (($local:elapsedTime.TotalSeconds - $DownloadTimeout) -gt 0 -and -not $cancellationToken.IsCancellationRequested) {
                    throw New-Object System.TimeoutException("Failed to reach the server: connection timeout: default timeout is $DownloadTimeout second(s)");
                }
                throw;
            }
        }
    }
}

Load-Assembly -Assembly System.Net.Http
Load-Assembly -Assembly System.IO.Compression.FileSystem

DownloadFile -Source $Url -OutPath $ZipPath
Expand-Archive -Path $ZipPath -DestinationPath $InstallRoot
SafeRemoveFile -Path $ZipPath
