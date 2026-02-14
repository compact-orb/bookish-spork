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
$fingerprints = gpg --homedir "$gpgHome" --list-keys --with-colons | Select-String "^fpr:" | ForEach-Object { ($_ -split ":")[9] }
foreach ($fpr in $fingerprints) {
    Write-Output -InputObject "Trusting key $fpr..."
    "$($fpr):6:" | gpg --homedir "$gpgHome" --batch --import-ownertrust
}

# Also set up Portage's verification keyring so the build system can verify packages.
# Remove any pre-existing keyring first — the base image may have a portage-owned keyring
# from getuto, but GPG verification runs as root and requires root ownership.
$portageGpgHome = "/mnt/gentoo/etc/portage/gnupg"
Remove-Item -Path "$portageGpgHome" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path "$portageGpgHome" -ItemType Directory -Force | Out-Null
chmod 700 "$portageGpgHome"

# Export the public key and import it into the Portage verification keyring.
gpg --homedir "$gpgHome" --export | gpg --homedir "$portageGpgHome" --batch --import

# Trust the signing key in the Portage keyring.
$fingerprints = gpg --homedir "$portageGpgHome" --list-keys --with-colons | Select-String "^fpr:" | ForEach-Object { ($_ -split ":")[9] }
foreach ($fpr in $fingerprints) {
    "$($fpr):6:" | gpg --homedir "$portageGpgHome" --batch --import-ownertrust
}

Write-Output -InputObject "Signing key imported and trusted."

# Import Secure Boot signing key and certificate into the chroot.
# These are used by Portage's secureboot and modules-sign USE flags to sign
# EFI binaries and kernel modules during builds.
$sbDir = "/mnt/gentoo/root/secureboot"
New-Item -Path $sbDir -ItemType Directory -Force | Out-Null
bash -c "echo '$env:SECUREBOOT_DB_KEY_BASE64' | base64 --decode > '$sbDir/db.key'"
bash -c "echo '$env:SECUREBOOT_DB_CERT_BASE64' | base64 --decode > '$sbDir/db.pem'"
chmod 600 "$sbDir/db.key"
Write-Output -InputObject "Secure Boot signing key imported."
