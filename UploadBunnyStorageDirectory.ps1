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
    The maximum number of concurrent threads to use for parallel operations. Default is 50.
#>
param(
    [string]$Path,
    [string]$Destination,
    [Int32]$ThrottleLimit = 50
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Recursively find all files in the source path and upload them in parallel
Get-ChildItem -Path $Path -Recurse -Name -File | ForEach-Object -Parallel {
    # Upload the file using the Bunny Storage API
    Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME$Destination/$_" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile "$using:Path/$_" | Out-Null

    Write-Output -InputObject "Uploaded $_ to $using:Destination"
} -ThrottleLimit $ThrottleLimit
