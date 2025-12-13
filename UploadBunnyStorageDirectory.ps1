# Simple script to upload a directory to Bunny Storage.

param(
    [string]$Path,

    [string]$Destination,

    [Int32]$ThrottleLimit = 50
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

Get-ChildItem -Path $Path -Recurse -Name -File | ForEach-Object -Parallel {
    Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME$Destination/$_" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile "$using:Path/$_" | Out-Null

    Write-Output -InputObject "Uploaded $_ to $using:Destination"
} -ThrottleLimit $ThrottleLimit
