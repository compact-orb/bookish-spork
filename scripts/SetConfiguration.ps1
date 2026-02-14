<#
.SYNOPSIS
    Configures the Gentoo environment by setting up Portage configuration and SSH access.

.DESCRIPTION
    This script prepares the Gentoo environment for use. It performs the following actions:
    1. Cleans up existing Portage configuration and SSH keys to ensure a clean state.
    2. Copies the new configuration from the directory specified by CONFIG_PREFIX.
    3. Optimizes make.conf for build nodes (non-Endpoint) by adjusting parallel jobs and emerge options.
    4. Sets up SSH keys and configuration for accessing GitHub.

.PARAMETER Endpoint
    If set, indicates that this is a final endpoint node.
    If not set (default), it treats the node as a build node and applies build-specific optimizations
    (e.g., higher job count, aggressive emerge options) to make.conf.
#>
param (
    [switch]$Endpoint
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# Clean up some configuration directories to ensure that they don't include deleted files.
# This removes old Portage configs, kernel configs, and SSH keys.
# The list of paths is maintained in cleanup-paths.txt, shared with tools/ConfigureSystem.sh.
$cleanupPaths = Get-Content -Path "$PSScriptRoot/../cleanup-paths.txt" | Where-Object { $_ -ne '' } | ForEach-Object { "/mnt/gentoo/$_" }
Remove-Item -Path $cleanupPaths -Recurse -Force -ErrorAction SilentlyContinue

# Copy the new configuration files from the CONFIG_PREFIX directory to the Gentoo environment.
Copy-Item -Path $env:CONFIG_PREFIX/* -Destination /mnt/gentoo -Recurse -Force

# If this is NOT an endpoint (i.e., it's a build node), optimize make.conf for building.
if (-not $Endpoint) {
    Set-Content -Path /mnt/gentoo/etc/portage/make.conf -Value (Get-Content -Path /mnt/gentoo/etc/portage/make.conf | ForEach-Object {
            if ($_ -match "^EMERGE_DEFAULT_OPTS=") {
                "# $_"
            }
            else {
                $_
            }
        })
    $signingKeyFingerprint = (Get-Content -Path "$PSScriptRoot/../keys/fingerprint.txt" -Raw).Trim()
    Add-Content -Path /mnt/gentoo/etc/portage/make.conf -Value @"

MAKEOPTS="--jobs=4"

EMERGE_DEFAULT_OPTS="--backtrack=1024 --buildpkg --quiet-build --usepkg --verbose --with-bdeps=y --keep-going"
BINPKG_COMPRESS="zstd"
BINPKG_COMPRESS_FLAGS="-19 -T4 --long"

FEATURES="binpkg-signing gpg-keepalive"
BINPKG_GPG_SIGNING_GPG_HOME="/root/.gnupg"
BINPKG_GPG_SIGNING_KEY="$signingKeyFingerprint"
"@
}

# Set up SSH access for the root user for the purpose of authenticating into private GitHub repositories.
# This involves creating the .ssh directory, setting permissions, and decoding the SSH key and known_hosts.
New-Item -Path "/mnt/gentoo/root/.ssh" -ItemType Directory -Force | Out-Null
chmod 700 "/mnt/gentoo/root/.ssh"
$env:REDESIGNED_BROCCOLI_SSH_KEY | base64 --decode | Set-Content -Path "/mnt/gentoo/root/.ssh/redesigned-broccoli"
chmod 600 "/mnt/gentoo/root/.ssh/redesigned-broccoli"
Set-Content -Path "/mnt/gentoo/root/.ssh/config" -Value @'
Host github.com
    IdentityFile ~/.ssh/redesigned-broccoli
    StrictHostKeyChecking no
'@
chmod 600 "/mnt/gentoo/root/.ssh/config"
