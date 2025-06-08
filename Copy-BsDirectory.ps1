# Simple script to copy a directory to and from Bunny Storage.

param(
    [string]$Path,

    [string]$Destination,

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
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $attempt = 0

    while ($attempt -lt $MaximumRetryCount) {
        try {
            $httpResponse = Invoke-RestMethod -StatusCodeVariable httpStatusCode -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$Path/" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method GET

            $httpResponse | ForEach-Object -Parallel {
                . $using:PSCommandPath -Path $using:Path -Destination $using:Destination -FromBs -MaximumRetryCount $using:MaximumRetryCount -RetryIntervalSec $using:RetryIntervalSec -ThrottleLimit $using:ThrottleLimit -NoExecute

                if ($_.IsDirectory) {
                    FromBs -Path "$Path/$($_.ObjectName)" -Destination "$Destination/$($_.ObjectName)"
                } else {
                    try {
                        aria2c --dir=$Destination --header="accept: */*" --header="accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --max-tries=$MaximumRetryCount --quiet --retry-wait=$RetryIntervalSec https://$env:BUNNY_STORAGE_ENDPOINT/$Path/$($_.ObjectName)

                        Write-Host -Object "Copied $($_.ObjectName)"
                    } catch {
                        Write-Host -Object "Failed to copy $($_.ObjectName)"
                    }
                }
            } -ThrottleLimit $ThrottleLimit

            break
        } catch {
            if ($httpStatusCode -eq 404) {
                Write-Host "$Path not found"

                exit 1
            }
            Write-Host "[$($attempt + 1)/$MaximumRetryCount] Failed to retrieve directory listing for $Path. Status code: $httpStatusCode"

            Start-Sleep -Seconds $RetryIntervalSec

            $attempt++
        }
    }
}

function ToBs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Get-ChildItem -Path $Path -Recurse -Name -File | ForEach-Object -Parallel {
        $attempt = 0

        while ($attempt -lt $using:MaximumRetryCount) {
            try {
                Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT/$using:Destination/$_" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method PUT -ContentType "application/octet-stream" -InFile "$($_.FullName)"

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
        FromBs -Path "$env:BUNNY_STORAGE_ZONE_NAME$Path" -Destination "$Destination"
    } elseif ($ToBs) {
        ToBs -Path "$Path" -Destination "$env:BUNNY_STORAGE_ZONE_NAME$Destination"
    } else {
        exit 1
    }
}
