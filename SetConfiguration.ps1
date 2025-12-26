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

# Clean up some configuration directories to ensure that they dont't include deleted files.
# This removes old Portage configs, kernel configs, and SSH keys.
# If you add or remove files and directories from your configuration, you may want to update the following line to make sure the image's configuration is as expected.
Remove-Item -Path /mnt/gentoo/etc/kernel/config.d, /mnt/gentoo/etc/portage/binrepos.conf, /mnt/gentoo/etc/portage/env, /mnt/gentoo/etc/portage/package.accept_keywords, /mnt/gentoo/etc/portage/package.env, /mnt/gentoo/etc/portage/package.mask, /mnt/gentoo/etc/portage/package.unmask, /mnt/gentoo/etc/portage/package.use, /mnt/gentoo/etc/portage/patches, /mnt/gentoo/etc/portage/repos.conf, /mnt/gentoo/root/.ssh -Recurse -Force -ErrorAction SilentlyContinue

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
    Add-Content -Path /mnt/gentoo/etc/portage/make.conf -Value @'

MAKEOPTS="--jobs=4"

EMERGE_DEFAULT_OPTS="--backtrack=1024 --buildpkg --quiet-build --usepkg --verbose --with-bdeps=y"
BINPKG_COMPRESS="zstd"
BINPKG_COMPRESS_FLAGS="-19 -T4 --long"
'@
}

# Set up SSH access for the root user for the purpose of authenticating into private GitHub repositories.
# This involves creating the .ssh directory, setting permissions, and decoding the SSH key and known_hosts.
New-Item -Path "/mnt/gentoo/root/.ssh" -ItemType Directory -Force | Out-Null
chmod 700 "/mnt/gentoo/root/.ssh"
$env:REDESIGNED_BROCCOLI_SSH_KEY | base64 --decode | Set-Content -Path "/mnt/gentoo/root/.ssh/redesigned-broccoli"
chmod 600 "/mnt/gentoo/root/.ssh/redesigned-broccoli"
$env:KNOWN_HOSTS | base64 --decode | Set-Content -Path "/mnt/gentoo/root/.ssh/known_hosts"
chmod 600 "/mnt/gentoo/root/.ssh/known_hosts"
Set-Content -Path "/mnt/gentoo/root/.ssh/config" -Value @'
Host github.com
    IdentityFile ~/.ssh/redesigned-broccoli
'@
chmod 600 "/mnt/gentoo/root/.ssh/config"
