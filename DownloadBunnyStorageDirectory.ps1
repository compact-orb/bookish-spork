# Downloads the contents of a Bunny Storage directory to a local destination.

param(
    [string]$Path,

    [string]$Destination,

    [Int32]$ThrottleLimit = 50
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

$currentPaths = $Path

do {
    $currentPaths = $currentPaths | ForEach-Object -Parallel {
        $response = Invoke-RestMethod -StatusCodeVariable httpStatusCode -Uri "https://$using:env:BUNNY_STORAGE_ENDPOINT_CDN$_/" -Headers @{ "accept" = "application/json"; "accesskey" = $using:env:BUNNY_STORAGE_ACCESS_KEY } -Method GET

        $response | ForEach-Object {
            $Path = $_.Path

            if ($_.IsDirectory) {
                New-Item -Path "$using:Destination$($Path.Substring($using:Path.Length))$($_.ObjectName)" -ItemType Directory | Out-Null

                "$($Path)$($_.ObjectName)"
            } else {
                Write-Host -Object "Downloading $($_.Path)$($_.ObjectName) to $using:Destination$($Path.Substring($using:Path.Length))$($_.ObjectName)"

                Invoke-WebRequest -Uri "https://$env:BUNNY_STORAGE_ENDPOINT/$($_.Path)$($_.ObjectName)" -Headers @{ accept='*/*'; accesskey=$using:env:BUNNY_STORAGE_ACCESS_KEY } -OutFile "$using:Destination$($Path.Substring($using:Path.Length))$($_.ObjectName)"
            }
        }
    } -ThrottleLimit $ThrottleLimit
} while (![string]::IsNullOrWhiteSpace($currentPaths))
