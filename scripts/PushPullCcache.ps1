<#
.SYNOPSIS
    Handles downloading and uploading ccache directory for gentoo builders.
#>
param(
    [switch]$From,
    [switch]$To
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

. "$PSScriptRoot/Invoke-WithRetry.ps1"

$fileName = "$env:CONFIG_PREFIX-ccache.tar"
$cacheDir = "/mnt/gentoo/var/cache/ccache"

function Receive-Ccache {
    $headerFile = "/var/tmp/bookish-spork/curl-header-$([guid]::NewGuid()).txt"
    try {
        $headerFileMode = [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite
        $headerFileStream = [System.IO.FileStream]::new($headerFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            [System.IO.File]::SetUnixFileMode($headerFile, $headerFileMode)
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            $headerFileWriter = [System.IO.StreamWriter]::new($headerFileStream, $utf8NoBom)
            $headerFileStream = $null
            try {
                $headerFileWriter.Write("accesskey: $($env:BUNNY_STORAGE_ACCESS_KEY)")
                $headerFileWriter.Flush()
            } finally {
                $headerFileWriter.Dispose()
            }
        } finally {
            if ($null -ne $headerFileStream) {
                $headerFileStream.Dispose()
            }
        }

        Write-Output "Downloading $fileName..."
        New-Item -Path $cacheDir -ItemType Directory -Force | Out-Null
        
        # We need to catch error if cache file doesn't exist yet (e.g., first run)
        Invoke-WithRetry -ActionName "download $fileName" -MaxRetries 3 -ScriptBlock {
            $exitCode = 0
            # Suppress curl error with `|| true` but check if tar gets data. Actually `curl --fail` will fail if 404.
            # We can use pure bash because powershell curl is an alias in some cases, but here it's native curl.
            $process = Start-Process -FilePath "bash" -ArgumentList "-c", "curl --header 'accept: */*' --header '@$headerFile' --silent --fail 'https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName' | tar --directory='$cacheDir' --extract --file=- 2>/dev/null || true" -Wait -PassThru -NoNewWindow
            
            # Since first run will fail to download, we just warn and continue.
            Write-Output "Done fetching ccache."
        }
    } finally {
        if (Test-Path -Path $headerFile) { Remove-Item -Path $headerFile -Force -ErrorAction SilentlyContinue }
    }
}

function Send-Ccache {
    if (-not (Test-Path $cacheDir)) {
        Write-Warning "Ccache directory not found, skipping upload."
        return
    }
    
    Write-Output "Archiving ccache directory..."
    # `tar` creates an uncompressed archive directly at the destination path.
    # PushPullImage uploads via Invoke-RestMethod with -InFile
    $tmpFile = "/var/tmp/bookish-spork/$fileName"
    Start-Process -FilePath "tar" -ArgumentList @("--directory=$cacheDir", "--create", "--file=$tmpFile", ".") -Wait -NoNewWindow
    
    Write-Output "Uploading $fileName..."
    Measure-Command -Expression {
        Invoke-WithRetry -ActionName "upload $fileName" -MaxRetries 3 -ScriptBlock {
            Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile $tmpFile
            Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
        }
    }
}

New-Item -Path "/var/tmp/bookish-spork" -ItemType "Directory" -Force | Out-Null

if ($From) { Receive-Ccache }
elseif ($To) { Send-Ccache }
