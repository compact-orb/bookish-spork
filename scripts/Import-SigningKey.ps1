<#
.SYNOPSIS
    Imports the GPG signing key for binary package signing.

.DESCRIPTION
    This script imports a base64-encoded GPG private key from an environment variable
    into the chroot's GnuPG keyring. The key is used by Portage's binpkg-signing feature
    to sign binary packages during builds.

    The script also imports the public key into Portage's verification keyring at
    /etc/portage/gnupg so that the build system can verify its own signed packages.
#>

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if (-not $env:BINPKG_GPG_SIGNING_KEY_BASE64) {
    Write-Error -Message "BINPKG_GPG_SIGNING_KEY_BASE64 environment variable is not set."
}

$gpgHome = "/mnt/gentoo/root/.gnupg"

# Import the private signing key into the chroot's GnuPG keyring.
Write-Output -InputObject "Importing signing key..."
$env:BINPKG_GPG_SIGNING_KEY_BASE64 | base64 --decode | gpg --homedir "$gpgHome" --batch --import

# Mark the imported key as ultimately trusted.
# This retrieves all key fingerprints and sets trust level 6 (ultimate).
$fingerprints = @(gpg --homedir "$gpgHome" --list-keys --with-colons | Select-String "^fpr:" | ForEach-Object { ($_ -split ":")[9] })
if ($fingerprints.Count -gt 0) {
    Write-Output -InputObject "Trusting imported keys..."
    @($fingerprints | ForEach-Object { "$($_):6:" }) | gpg --homedir "$gpgHome" --batch --import-ownertrust
}

# Also set up Portage's verification keyring so the build system can verify packages.
# Remove any pre-existing keyring first — the base image may have a differently-owned
# keyring from getuto.
$portageGpgHome = "/mnt/gentoo/etc/portage/gnupg"
Remove-Item -Path "$portageGpgHome" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path "$portageGpgHome" -ItemType Directory -Force | Out-Null
chmod 700 "$portageGpgHome"

# Export the public key and import it into the Portage verification keyring.
gpg --homedir "$gpgHome" --export | gpg --homedir "$portageGpgHome" --batch --import

# Trust the signing key in the Portage keyring.
$fingerprints = @(gpg --homedir "$portageGpgHome" --list-keys --with-colons | Select-String "^fpr:" | ForEach-Object { ($_ -split ":")[9] })
if ($fingerprints.Count -gt 0) {
    @($fingerprints | ForEach-Object { "$($_):6:" }) | gpg --homedir "$portageGpgHome" --batch --import-ownertrust
}
gpg --homedir "$portageGpgHome" --check-trustdb

# Portage drops GPG verification to the nobody user (GPG_VERIFY_USER_DROP defaults to
# "nobody" in gpkg.py). The verification keyring must be owned by nobody:nogroup so
# the dropped process can read keys and create lock/temp files.
# nobody=65534, nogroup=65533 on Gentoo; using numeric IDs since we run on the host.
chown --recursive 65534:65533 "$portageGpgHome"

Write-Output -InputObject "Signing key imported and trusted."

# Import Secure Boot signing key and certificate into the chroot.
# These are used by Portage's secureboot and modules-sign USE flags to sign
# EFI binaries and kernel modules during builds.
$sbDir = "/mnt/gentoo/root/secureboot"
New-Item -Path $sbDir -ItemType Directory -Force | Out-Null

# Use FileStreamOptions to natively and securely create the key files with strict permissions
# in a single operation, avoiding shell command interpolation and TOCTOU race conditions.
function Write-SecureFile {
    param (
        [string]$Path,
        [byte[]]$Content,
        [System.IO.UnixFileMode]$UnixMode
    )
    $options = [System.IO.FileStreamOptions]::new()
    $options.Mode = [System.IO.FileMode]::Create
    $options.Access = [System.IO.FileAccess]::Write
    $options.UnixCreateMode = $UnixMode

    $stream = $null
    try {
        $stream = [System.IO.File]::Open($Path, $options)
        $stream.Write($Content, 0, $Content.Length)
    } finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}

if ([string]::IsNullOrWhiteSpace($env:SECUREBOOT_DB_KEY_BASE64)) {
    Write-Error -Message "SECUREBOOT_DB_KEY_BASE64 environment variable is not set or empty."
}

if ([string]::IsNullOrWhiteSpace($env:SECUREBOOT_DB_CERT_BASE64)) {
    Write-Error -Message "SECUREBOOT_DB_CERT_BASE64 environment variable is not set or empty."
}

try {
    $keyBytes = [System.Convert]::FromBase64String($env:SECUREBOOT_DB_KEY_BASE64)
} catch {
    Write-Error -Message "Failed to decode SECUREBOOT_DB_KEY_BASE64: $_"
}

try {
    $certBytes = [System.Convert]::FromBase64String($env:SECUREBOOT_DB_CERT_BASE64)
} catch {
    Write-Error -Message "Failed to decode SECUREBOOT_DB_CERT_BASE64: $_"
}

Write-SecureFile -Path "$sbDir/db.key" -Content $keyBytes -UnixMode ([System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite)
Write-SecureFile -Path "$sbDir/db.pem" -Content $certBytes -UnixMode ([System.IO.UnixFileMode]::UserRead -bor [System.IO.UnixFileMode]::UserWrite -bor [System.IO.UnixFileMode]::GroupRead -bor [System.IO.UnixFileMode]::OtherRead)

Write-Output -InputObject "Secure Boot signing key imported."
