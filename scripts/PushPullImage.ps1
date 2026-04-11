<#
.SYNOPSIS
    Handles the downloading (restoring) and uploading (backing up) of Gentoo system images.

.DESCRIPTION
    This script is responsible for managing the lifecycle of Gentoo system images in a CI/CD environment.
    It supports two main modes:
    1.  From (Download): Restores a system image from object storage to the local filesystem.
    2.  To (Upload): Creates an archive of the current system and uploads it to object storage.

    It handles different image types:
    - Base: The core system image.
    - Bootstrap: A minimal bootstrap image.
    - Temporary: A temporary image for intermediate steps.
    - Overlay: An overlay layer on top of a base image, using OverlayFS.

.PARAMETER From
    Switch to enable "Download/Restore" mode. Fetches images from storage and extracts them.

.PARAMETER To
    Switch to enable "Upload/Backup" mode. Archives the current system and uploads to storage.

.PARAMETER Temporary
    Indicates that the operation applies to a temporary image.

.PARAMETER Bootstrap
    Indicates that the operation applies to a bootstrap image.

.PARAMETER Overlay
    Indicates that the operation involves an OverlayFS layer. Requires -LayerName.

.PARAMETER LayerName
    The name of the specific layer when using -Overlay.

.PARAMETER ForceRebuild
    When downloading an overlay, this flag forces starting with an empty layer instead of downloading an existing one.
#>
param(
    [switch]$From,
    [switch]$To,
    [switch]$Temporary,
    [switch]$Bootstrap,
    [switch]$Overlay,
    [string]$LayerName,
    [switch]$ForceRebuild
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

. "$PSScriptRoot/Invoke-WithRetry.ps1"

function Receive-FromStorage {
    param(
        [Parameter(Mandatory)]
        [string]$FileName,
        [Parameter(Mandatory)]
        [string]$TargetDirectory,
        [switch]$Bootstrap
    )

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
            }
            finally {
                $headerFileWriter.Dispose()
            }
        }
        finally {
            if ($null -ne $headerFileStream) {
                $headerFileStream.Dispose()
            }
        }

        # Pass the header securely via file to prevent exposure in process lists (ps)
        Invoke-WithRetry -ActionName "download $FileName" -MaxRetries 3 -ScriptBlock {
            if ($Bootstrap) {
                # Bootstrap images use .xz compression
                curl --header "accept: */*" --header "@$headerFile" --silent --fail --show-error "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$FileName" | tar --directory="$TargetDirectory" --extract --file=- --numeric-owner --preserve-permissions --xattrs-include="*.*" --xz
            }
            else {
                # Standard images use .zst (Zstandard) compression
                curl --header "accept: */*" --header "@$headerFile" --silent --fail --show-error "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$FileName" | tar --directory="$TargetDirectory" --extract --file=- --numeric-owner --preserve-permissions --use-compress-program="zstd --long=31" --xattrs-include="*.*"
            }
        }
    }
    finally {
        if (Test-Path -Path $headerFile) {
            Remove-Item -Path $headerFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Publish-SystemArchive {
    param(
        [Parameter(Mandatory)]
        [string]$TargetDirectory,
        [Parameter(Mandatory)]
        [string]$FileName,
        [string[]]$ExcludeParams = @()
    )

    Write-Output -InputObject "Creating archive..."
    Measure-Command -Expression {
        tar --create --directory="$TargetDirectory" --file="/var/tmp/bookish-spork/$FileName" --numeric-owner --preserve-permissions --use-compress-program="zstd -9 -T8 --long=31" --xattrs-include="*.*" @ExcludeParams .
    }

    Send-ToStorage -FileName $FileName
}

function Send-ToStorage {
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    Write-Output -InputObject "Uploading archive..."
    Measure-Command -Expression {
        Invoke-WithRetry -ActionName "upload $FileName" -MaxRetries 3 -ScriptBlock {
            Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$FileName" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile "/var/tmp/bookish-spork/$FileName"

            Remove-Item -Path "/var/tmp/bookish-spork/$FileName"
        }
    }
}

New-Item -Path "/var/tmp/bookish-spork" -ItemType "Directory" -Force | Out-Null

# MODE: FROM (Download / Restore)
# This block handles downloading images from storage and setting up the filesystem.
if ($From) {
    # Sub-mode: Overlay
    # Sets up an OverlayFS environment with a read-only base and a writable upper layer.
    if ($Overlay) {
        if (-not $LayerName) {
            Write-Error -Message "LayerName is required when Overlay is specified."
        }

        $baseFileName = "$env:CONFIG_PREFIX.tar.zst"
        $layerFileName = "$env:CONFIG_PREFIX-$LayerName.tar.zst"

        # Prepare directories for OverlayFS
        # - lower: Read-only base image
        # - upper: Writable layer
        # - work: OverlayFS internal work directory
        # - gentoo: The merged mount point
        Write-Output -InputObject "Creating directories..."
        New-Item -Path /mnt/gentoo-lower, /mnt/gentoo-upper, /mnt/gentoo-work, /mnt/gentoo -ItemType Directory -Force | Out-Null

        # Download and extract Base Image to lowerdir (Read-Only)
        Write-Output -InputObject "Downloading and extracting Base Image..."
        Receive-FromStorage -FileName $baseFileName -TargetDirectory "/mnt/gentoo-lower"

        # Handle Layer Image (Upper Dir)
        if ($ForceRebuild) {
            # If rebuilding, start with a fresh empty upper layer
            Write-Output -InputObject "ForceRebuild specified. Starting with empty layer."
        }
        else {
            # Otherwise, try to download the existing layer to resume or update it
            Write-Output -InputObject "Downloading and extracting Layer Image..."
            Receive-FromStorage -FileName $layerFileName -TargetDirectory "/mnt/gentoo-upper"
        }

        # Mount OverlayFS
        # Combines lower (base) and upper (layer) into /mnt/gentoo
        Write-Output -InputObject "Mounting overlayfs..."
        mount -t overlay overlay -o "lowerdir=/mnt/gentoo-lower,upperdir=/mnt/gentoo-upper,workdir=/mnt/gentoo-work" /mnt/gentoo

        # Restore resolv.conf (writes to upper layer effectively)
        # This ensures networking works within the chroot
        Write-Output -InputObject "Restoring resolv.conf..."
        Copy-Item -Path /etc/resolv.conf -Destination /mnt/gentoo/etc -Force
    }
    else {
        # Sub-mode: Standard (Non-Overlay)
        # Handles Bootstrap, Temporary, or Base images directly.

        if ($Bootstrap) {
            $fileName = "$env:CONFIG_PREFIX-bootstrap.tar.xz"
        }
        elseif ($Temporary) {
            $fileName = "$env:CONFIG_PREFIX-temporary.tar.zst"
        }
        else {
            $fileName = "$env:CONFIG_PREFIX.tar.zst"
        }

        Write-Output -InputObject "Creating directories..."
        New-Item -Path /mnt/gentoo -ItemType Directory -Force | Out-Null

        Write-Output -InputObject "Downloading and extracting Base Image..."
        Receive-FromStorage -FileName $fileName -TargetDirectory "/mnt/gentoo" -Bootstrap:$Bootstrap

        Write-Output -InputObject "Restoring resolv.conf..."
        Copy-Item -Path /etc/resolv.conf -Destination /mnt/gentoo/etc
    }
}
# MODE: TO (Upload / Backup)
# This block handles archiving the filesystem and uploading it to storage.
elseif ($To) {
    # Sub-mode: Overlay
    # Archives only the upper layer (changes made on top of the base).
    if ($Overlay) {
        if (-not $LayerName) {
            Write-Error -Message "LayerName is required when Overlay is specified."
        }

        if ($Temporary) {
            $fileName = "$env:CONFIG_PREFIX-$LayerName-temporary.tar.zst"
        }
        else {
            $fileName = "$env:CONFIG_PREFIX-$LayerName.tar.zst"
        }
        $targetDir = "/mnt/gentoo-upper"
        # Exclude cache files from the layer archive
        # When -Temporary is specified, include /tmp and /var/tmp
        $excludeParams = @(
            "--exclude=./root/.gnupg",
            "--exclude=./root/secureboot",
            "--exclude=./var/cache/binpkgs",
            "--exclude=./var/cache/distfiles/*",
            "--exclude=./run/*",
            "--exclude=./etc/resolv.conf"
        )
        if (-not $Temporary) {
            $excludeParams += @(
                "--exclude=./var/tmp/*",
                "--exclude=./tmp/*"
            )
        }

        Publish-SystemArchive -TargetDirectory $targetDir -FileName $fileName -ExcludeParams $excludeParams
    }
    else {
        # Sub-mode: Standard (Non-Overlay)
        # Archives the entire /mnt/gentoo directory.

        if ($Temporary) {
            $fileName = "$env:CONFIG_PREFIX-temporary.tar.zst"

            # Clean up before archiving
            Remove-Item -Path /mnt/gentoo/etc/resolv.conf
        }
        else {
            $fileName = "$env:CONFIG_PREFIX.tar.zst"

            # Aggressive cleanup for base images
            Remove-Item -Path /mnt/gentoo/etc/resolv.conf, /mnt/gentoo/var/cache/distfiles/*, /mnt/gentoo/var/tmp/* -Recurse -Force -ErrorAction SilentlyContinue
        }

        $excludeParams = @(
            "--exclude=./root/.gnupg",
            "--exclude=./root/secureboot"
        )
        Publish-SystemArchive -TargetDirectory "/mnt/gentoo" -FileName $fileName -ExcludeParams $excludeParams
    }
}
else {
    exit 1
}
