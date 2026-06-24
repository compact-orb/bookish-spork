<#
.SYNOPSIS
    Recursively uploads a local directory to Bunny Storage.

.DESCRIPTION
    This script recursively uploads all files from a specified local directory to a destination
    in Bunny Storage. It uses parallel processing to upload multiple files concurrently.

    The script relies on the following environment variables:
    - BUNNY_STORAGE_ENDPOINT_CDN: The endpoint for the storage zone.
    - BUNNY_STORAGE_ZONE_NAME: The name of the storage zone.
    - BUNNY_STORAGE_ACCESS_KEY: The access key for authentication.

.PARAMETER Path
    The local directory path to upload.

.PARAMETER Destination
    The destination path in Bunny Storage (relative to the zone root).

.PARAMETER ThrottleLimit
    The maximum number of concurrent threads to use for parallel operations. Default is 8.
#>
param(
    [string]$Path,
    [string]$Destination,
    [Int32]$ThrottleLimit = 8
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Read the Invoke-WithRetry.ps1 file content once to prevent redundant disk I/O in runspaces
$invokeWithRetryContent = [System.IO.File]::ReadAllText("$PSScriptRoot/Invoke-WithRetry.ps1")

# Track whiteouts across parallel threads
$whiteouts = [System.Collections.Concurrent.ConcurrentBag[string]]::new()

# Recursively find all files in the source path and upload them in parallel
Get-ChildItem -Path $Path -Recurse -Name -File | ForEach-Object -Parallel {
    if (-not (Test-Path Function:\Invoke-WithRetry)) {
        $invokeWithRetryScriptBlock = [scriptblock]::Create($using:invokeWithRetryContent)
        . $invokeWithRetryScriptBlock
    }
    $filePath = $_

    # OverlayFS whiteouts (char dev 0,0) mean the file was deleted — propagate to remote.
    $item = Get-Item "$using:Path/$filePath"
    if ($item.UnixStat -and $item.UnixStat.ItemType -eq "CharacterDevice") {
        ($using:whiteouts).Add($filePath)
        Invoke-WithRetry -ActionName "delete $filePath" -MaxRetries 3 -ScriptBlock {
            Invoke-RestMethod -Uri "https://$using:env:BUNNY_STORAGE_ENDPOINT_CDN/$using:env:BUNNY_STORAGE_ZONE_NAME$using:Destination/$filePath" -Headers @{"accept" = "application/json"; "accesskey" = $using:env:BUNNY_STORAGE_ACCESS_KEY } -Method DELETE | Out-Null
            Write-Output "Deleted $filePath from $using:Destination"
        }
        return
    }

    Invoke-WithRetry -ActionName "upload $filePath" -MaxRetries 3 -ScriptBlock {
        Invoke-RestMethod -Uri "https://$using:env:BUNNY_STORAGE_ENDPOINT_CDN/$using:env:BUNNY_STORAGE_ZONE_NAME$using:Destination/$filePath" -Headers @{"accept" = "application/json"; "accesskey" = $using:env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile "$using:Path/$filePath" | Out-Null

        Write-Output -InputObject "Uploaded $filePath to $using:Destination"
    }
} -ThrottleLimit $ThrottleLimit

if ($whiteouts.Count -gt 0) {
    Write-Error "OverlayFS whiteouts detected — these packages were deleted from the binary package repo and need rebuilding:`n$($whiteouts | ForEach-Object { "  $_" } | Out-String)"
}
