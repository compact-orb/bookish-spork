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
$cleanupPaths = @("/mnt/gentoo/etc/portage/env", "/mnt/gentoo/etc/portage/binrepos.conf", "/mnt/gentoo/root/.ssh") + @(
    Get-Content -Path "$PSScriptRoot/../cleanup-paths.txt" `
    | Where-Object -FilterScript { $_ -ne '' } `
    | ForEach-Object -Process { "/mnt/gentoo/$_" }
)
Remove-Item -Path $cleanupPaths -Recurse -Force -ErrorAction SilentlyContinue

# Copy the new configuration files from the CONFIG_PREFIX directory to the Gentoo environment.
Copy-Item -Path $env:CONFIG_PREFIX/* -Destination /mnt/gentoo -Recurse -Force

# If this is NOT an endpoint (i.e., it's a build node), optimize make.conf for building.
if (-not $Endpoint) {
    Set-Content -Path /mnt/gentoo/etc/portage/make.conf -Value ((Get-Content -Path /mnt/gentoo/etc/portage/make.conf -Raw) -replace '(?m)^(EMERGE_DEFAULT_OPTS=.*)', '# $1') -NoNewline
    $signingKeyFingerprint = (Get-Content -Path "$PSScriptRoot/../keys/fingerprint.txt" -Raw).Trim()
    Add-Content -Path /mnt/gentoo/etc/portage/make.conf -Value @"

MAKEOPTS="--jobs=4"

EMERGE_DEFAULT_OPTS="--backtrack=1024 --buildpkg --quiet-build --usepkg --verbose --with-bdeps=y --keep-going"
BINPKG_COMPRESS="zstd"
BINPKG_COMPRESS_FLAGS="-19 -T4 --long"

FEATURES="binpkg-signing gpg-keepalive"
BINPKG_GPG_SIGNING_GPG_HOME="/root/.gnupg"
BINPKG_GPG_SIGNING_KEY="$signingKeyFingerprint"

INSTALL_MASK="/boot"
"@
}

# Set up SSH access for the root user for the purpose of authenticating into private GitHub repositories.
# This involves creating the .ssh directory, setting permissions, decoding the SSH key, and writing GitHub's SSH host keys into known_hosts (using default strict host key checking).
# Use sh to safely create the directory and files with strict permissions from the start
# to avoid any TOCTOU (Time of Check to Time of Use) race conditions.
sh -c 'umask 077 && mkdir -p /mnt/gentoo/root/.ssh && touch /mnt/gentoo/root/.ssh/redesigned-broccoli /mnt/gentoo/root/.ssh/config /mnt/gentoo/root/.ssh/known_hosts'

$env:REDESIGNED_BROCCOLI_SSH_KEY | base64 --decode | Set-Content -Path "/mnt/gentoo/root/.ssh/redesigned-broccoli"

Set-Content -Path "/mnt/gentoo/root/.ssh/known_hosts" -Value @'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
'@

Set-Content -Path "/mnt/gentoo/root/.ssh/config" -Value @'
Host github.com
    IdentityFile ~/.ssh/redesigned-broccoli
'@
