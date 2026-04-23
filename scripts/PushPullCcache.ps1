<#
.SYNOPSIS
    Handles downloading and uploading ccache directory for gentoo builders.
#>
param(
    [switch]$From,
    [switch]$To,
    [string]$LayerName
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

. "$PSScriptRoot/Invoke-WithRetry.ps1"

if ($LayerName) {
    $fileName = "$env:CONFIG_PREFIX-$LayerName-ccache.tar"
} else {
    $fileName = "$env:CONFIG_PREFIX-ccache.tar"
}
$cacheDir = "/mnt/gentoo/var/cache/ccache"

function Receive-Ccache {
    $headerFile = "/var/tmp/bookish-spork/curl-header-$([guid]::NewGuid()).txt"
    try {
        $headerFileMode = [System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite
        $options = [System.IO.FileStreamOptions]::new()
        $options.Mode = [System.IO.FileMode]::Create
        $options.Access = [System.IO.FileAccess]::Write
        $options.Share = [System.IO.FileShare]::None
        $options.UnixCreateMode = $headerFileMode
        
        $headerFileStream = [System.IO.FileStream]::new($headerFile, $options)
        try {
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
            # Check the remote archive status first
            $url = "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$fileName"
            $bashScriptHead = "curl --head -o /dev/null -s -w '%{http_code}' --header 'accept: */*' --header ""@`$1"" ""`$2"""
            $httpStatus = bash -c $bashScriptHead "_" $headerFile $url
            
            if ($httpStatus -eq '404') {
                Write-Warning "Cache not found (HTTP 404). Expected if this is the first cache push."
                return
            }

            if ($httpStatus -match '^4' -or $httpStatus -match '^5') {
                throw "HTTP error $httpStatus from storage endpoint."
            }

            Get-ChildItem -LiteralPath $cacheDir -Force | Remove-Item -Recurse -Force

            # If it exists, download and extract. pipefail accurately halts execution on curl failures
            $bashScript = 'set -o pipefail; curl --header "accept: */*" --header "@$1" --silent --fail --show-error "$2" | tar --directory="$3" --extract --file=- --numeric-owner --preserve-permissions --xattrs-include="*.*"'
            $url = "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName"

            bash -c $bashScript "_" $headerFile $url $cacheDir
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to download ccache archive. bash exited with code $LASTEXITCODE."
            }
            
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
    
    try {
        $process = Start-Process -FilePath "tar" -ArgumentList @("--directory=$cacheDir", "--create", "--file=$tmpFile", "--numeric-owner", '--xattrs-include=*.*', ".") -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            throw "Failed to archive ccache directory. tar exited with code $($process.ExitCode)."
        }
        
        Write-Output "Uploading $fileName..."
        Measure-Command -Expression {
            Invoke-WithRetry -ActionName "upload $fileName" -MaxRetries 3 -ScriptBlock {
                Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile $tmpFile
            }
        }
    } finally {
        Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
    }
}

New-Item -Path "/var/tmp/bookish-spork" -ItemType "Directory" -Force | Out-Null

if ($From) { 
    Receive-Ccache 
} elseif ($To) { 
    Send-Ccache 
} else {
    Write-Error "Either -From or -To must be specified."
    exit 1
}
