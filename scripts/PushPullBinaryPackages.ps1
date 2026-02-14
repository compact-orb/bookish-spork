<#
.SYNOPSIS
    Manages the synchronization of Gentoo binary packages between a local overlay filesystem and Bunny Storage.

.DESCRIPTION
    This script facilitates the caching of Gentoo binary packages by using an overlay filesystem.
    It supports two main operations:
    1. 'From': Prepares the environment by downloading existing binary packages from Bunny Storage to a "lower" directory
       and mounting an overlay filesystem. This allows the build process to read existing packages and write new ones
       to an "upper" directory without modifying the original cache.
    2. 'To': Finalizes the process by uploading the newly built packages (from the "upper" directory) back to Bunny Storage
       and cleaning up the overlay filesystem and temporary directories.

.PARAMETER From
    Switch to initiate the setup process (download and mount).

.PARAMETER To
    Switch to initiate the teardown process (upload and cleanup).

.PARAMETER NoOverlay
    Switch to bypass the overlay filesystem logic. When used with 'To', it assumes packages are directly in
    '/mnt/gentoo/var/cache/binpkgs' and cleans up that directory instead of unmounting.
#>
param(
    [switch]$From,
    [switch]$To,
    [switch]$NoOverlay
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

New-Item -Path "/var/tmp/bookish-spork" -ItemType "Directory" -Force | Out-Null

if ($From) {
    # Create the necessary directories for the overlay filesystem:
    # - lower: Read-only layer containing existing packages.
    # - upper: Writable layer for new packages.
    # - work: Working directory for overlayfs.
    New-Item -Path "/var/tmp/bookish-spork/binpkgs-store/lower", "/var/tmp/bookish-spork/binpkgs-store/upper", "/var/tmp/bookish-spork/binpkgs-store/work" -ItemType Directory -Force | Out-Null

    # Download existing binary packages from Bunny Storage to the read-only 'lower' directory.
    & "$PSScriptRoot/DownloadBunnyStorageDirectory.ps1" -Path "/$env:BUNNY_STORAGE_ZONE_NAME/$env:CONFIG_PREFIX" -Destination "/var/tmp/bookish-spork/binpkgs-store/lower"

    # Mount the overlay filesystem at the package cache location.
    # This merges 'lower' and 'upper' at '/mnt/gentoo/var/cache/binpkgs'.
    mount --types "overlay" "overlay" --options "lowerdir=/var/tmp/bookish-spork/binpkgs-store/lower,upperdir=/var/tmp/bookish-spork/binpkgs-store/upper,workdir=/var/tmp/bookish-spork/binpkgs-store/work" "/mnt/gentoo/var/cache/binpkgs"
}
elseif ($To) {
    # Determine the source path for uploading packages.
    if ($NoOverlay) {
        # If overlay is disabled, upload directly from the cache directory.
        $binpkgsPath = "/mnt/gentoo/var/cache/binpkgs"
    }
    else {
        # If overlay is enabled, only upload the new packages from the 'upper' directory.
        $binpkgsPath = "/var/tmp/bookish-spork/binpkgs-store/upper"
    }

    # Upload the packages to Bunny Storage.
    & "$PSScriptRoot/UploadBunnyStorageDirectory.ps1" -Path "$binpkgsPath" -Destination "/$env:CONFIG_PREFIX"

    # Perform cleanup operations.
    if ($NoOverlay) {
        # If overlay is disabled, clear the cache directory contents.
        Remove-Item -Path /mnt/gentoo/var/cache/binpkgs/* -Recurse
    }
    else {
        # If overlay is enabled, unmount the filesystem and remove the temporary store directories.
        umount /mnt/gentoo/var/cache/binpkgs

        Remove-Item -Path "/var/tmp/bookish-spork/binpkgs-store" -Recurse -Force
    }
}
else {
    exit 1
}
