# Simple script to copy a directory to and from Bunny Storage.

param(
    [string]$SourcePath,

    [string]$DestinationPath,

    [switch]$FromBs,

    [switch]$ToBs,

    [Int32]$MaximumRetryCount = 4,

    [Int32]$RetryIntervalSec = 4,

    [Int32]$ThrottleLimit = 1,

    [switch]$NoExecute
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

function FromBs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $attempt = 0

    while ($attempt -lt $MaximumRetryCount) {
        try {
            $httpResponse = Invoke-RestMethod -StatusCodeVariable httpStatusCode -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$SourcePath/" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method GET

            $httpResponse | ForEach-Object -Parallel {
                . $using:PSCommandPath -SourcePath $using:SourcePath -DestinationPath $using:DestinationPath -FromBs -MaximumRetryCount $using:MaximumRetryCount -RetryIntervalSec $using:RetryIntervalSec -ThrottleLimit $using:ThrottleLimit -NoExecute

                if ($_.IsDirectory) {
                    FromBs -SourcePath "$SourcePath/$($_.ObjectName)" -DestinationPath "$DestinationPath/$($_.ObjectName)"
                } else {
                    try {
                        aria2c --dir=$DestinationPath --header="accept: */*" --header="accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --max-tries=$MaximumRetryCount --quiet --retry-wait=$RetryIntervalSec https://$env:BUNNY_STORAGE_ENDPOINT/$SourcePath/$($_.ObjectName)

                        Write-Host -Object "Copied $($_.ObjectName)"
                    } catch {
                        Write-Host -Object "Failed to copy $($_.ObjectName)"
                    }
                }
            } -ThrottleLimit $ThrottleLimit

            break
        } catch {
            if ($httpStatusCode -eq 404) {
                Write-Host "$SourcePath not found"

                exit 1
            }
            Write-Host "[$($attempt + 1)/$MaximumRetryCount] Failed to retrieve directory listing for $SourcePath. Status code: $httpStatusCode"

            Start-Sleep -Seconds $RetryIntervalSec

            $attempt++
        }
    }
}

function ToBs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    Get-ChildItem -Path $SourcePath -Recurse -Name -File | ForEach-Object -Parallel {
        $attempt = 0

        while ($attempt -lt $using:MaximumRetryCount) {
            try {
                Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT/$using:DestinationPath/$_" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method PUT -ContentType "application/octet-stream" -InFile "$($_.FullName)"

                Write-Host -Object "Copied $_"
                break
            } catch {
                Write-Host "[$($attempt + 1)/$using:MaximumRetryCount] Failed to copy $_. Status code: $($_.StatusCode)"

                Start-Sleep -Seconds $using:RetryIntervalSec

                $attempt++
            }
        }
    } -ThrottleLimit $ThrottleLimit
}

if (-not $NoExecute) {
    if ($FromBs -and $ToBs) {
        exit 1
    } elseif ($FromBs) {
        FromBs -SourcePath "$env:BUNNY_STORAGE_ZONE_NAME$SourcePath" -DestinationPath "$DestinationPath"
    } elseif ($ToBs) {
        ToBs -SourcePath "$SourcePath" -DestinationPath "$env:BUNNY_STORAGE_ZONE_NAME$DestinationPath"
    } else {
        exit 1
    }
}
