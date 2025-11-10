# Downloads the contents of a Bunny Storage directory to a local destination.

param(
    [string]$Path,

    [string]$Destination,

    [Int32]$ThrottleLimit = 50
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

$directories = $Path

$files = @()

do {
    $directories = $directories | ForEach-Object -Parallel {
        $response = Invoke-RestMethod -StatusCodeVariable httpStatusCode -Uri "https://$using:env:BUNNY_STORAGE_ENDPOINT_CDN$_/" -Headers @{ "accept" = "application/json"; "accesskey" = $using:env:BUNNY_STORAGE_ACCESS_KEY } -Method GET

        $response | ForEach-Object {
            $Path = $_.Path

            if ($_.IsDirectory) {
                New-Item -Path "$using:Destination$($Path.Substring($using:Path.Length))$($_.ObjectName)" -ItemType Directory | Out-Null

                [PSCustomObject]@{
                    IsDirectory = $true;
                    Path        = "$($Path)$($_.ObjectName)"
                }
            } else {
                [PSCustomObject]@{
                    IsDirectory = $false;
                    Path        = "$($Path)$($_.ObjectName)"
                }
            }
        }
    } -ThrottleLimit $ThrottleLimit | ForEach-Object {
        if ($_.IsDirectory) {
            $_.Path
        }
        else {
            $files += $_.Path
        }
    }
} while (![string]::IsNullOrWhiteSpace($directories))

if (![string]::IsNullOrWhiteSpace($files)) {
    $files | ForEach-Object -Parallel {
        Write-Host -Object "Downloading $_ to $using:Destination$($_.Substring($using:Path.Length))"

        Invoke-WebRequest -Uri "https://$env:BUNNY_STORAGE_ENDPOINT$_" -Headers @{ accept='*/*'; accesskey=$using:env:BUNNY_STORAGE_ACCESS_KEY } -OutFile "$using:Destination$($_.Substring($using:Path.Length))"
    } -ThrottleLimit $ThrottleLimit
}
