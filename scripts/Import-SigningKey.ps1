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

function Set-GpgUltimateTrust {
    param (
        [Parameter(Mandatory=$true)]
        [string]$HomeDir,

        [string]$Message = ""
    )

    try {
        $gpgOutput = gpg --homedir "$HomeDir" --list-keys --with-colons
    } catch {
        throw "Failed to list GPG keys in $HomeDir. $($_.Exception.Message)"
    }

    $fingerprints = @($gpgOutput | Select-String "^fpr:" | ForEach-Object { ($_.Line -split ":")[9] })
    if ($fingerprints.Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($Message)) {
            Write-Output -InputObject $Message
        }
        try {
            @($fingerprints | ForEach-Object { "$($_):6:" }) | gpg --homedir "$HomeDir" --batch --import-ownertrust
        } catch {
            throw "Failed to import owner trust in $HomeDir. $($_.Exception.Message)"
        }
    }
}

if (-not $env:BINPKG_GPG_SIGNING_KEY_BASE64) {
    Write-Error -Message "BINPKG_GPG_SIGNING_KEY_BASE64 environment variable is not set."
}

$gpgHome = "/mnt/gentoo/root/.gnupg"

# Import the private signing key into the chroot's GnuPG keyring.
Write-Output -InputObject "Importing signing key..."
$env:BINPKG_GPG_SIGNING_KEY_BASE64 | base64 --decode | gpg --homedir "$gpgHome" --batch --import

# Mark the imported key as ultimately trusted.
# This retrieves all key fingerprints and sets trust level 6 (ultimate).
Set-GpgUltimateTrust -HomeDir "$gpgHome" -Message "Trusting imported keys..."

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
Set-GpgUltimateTrust -HomeDir "$portageGpgHome"
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

# Set up SSH access for the root user for the purpose of authenticating into private GitHub repositories.
# This involves creating the .ssh directory, setting permissions, decoding the SSH key, and writing GitHub's SSH host keys into known_hosts (using default strict host key checking).
# Use sh to safely create the directory and files with strict permissions from the start
# to avoid any TOCTOU (Time of Check to Time of Use) race conditions.
sh -c 'umask 077 && mkdir -p /mnt/gentoo/root/.ssh && touch /mnt/gentoo/root/.ssh/redesigned-broccoli /mnt/gentoo/root/.ssh/config /mnt/gentoo/root/.ssh/known_hosts'

if ([string]::IsNullOrWhiteSpace($env:REDESIGNED_BROCCOLI_SSH_KEY)) {
    throw "The REDESIGNED_BROCCOLI_SSH_KEY environment variable is missing or empty."
}

try {
    $decodedSshBytes = [System.Convert]::FromBase64String($env:REDESIGNED_BROCCOLI_SSH_KEY)
} catch {
    throw "Failed to decode the REDESIGNED_BROCCOLI_SSH_KEY environment variable as base64: $($_.Exception.Message)"
}

try {
    [System.IO.File]::WriteAllBytes("/mnt/gentoo/root/.ssh/redesigned-broccoli", $decodedSshBytes)
} catch {
    throw "Failed to write the decoded SSH key to disk: $($_.Exception.Message)"
}

Set-Content -Path "/mnt/gentoo/root/.ssh/known_hosts" -Value @'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
'@

Set-Content -Path "/mnt/gentoo/root/.ssh/config" -Value @'
Host github.com
    IdentityFile ~/.ssh/redesigned-broccoli
'@

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
