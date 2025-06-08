param(
    [switch]$From,

    [switch]$To,

    [switch]$NoOverlay
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

if ($From) {
    New-Item -Path /mnt/gentoo/var/cache/binpkgs-lowerdir, /mnt/gentoo/var/cache/binpkgs-upperdir, /mnt/gentoo/var/cache/binpkgs-workdir -ItemType Directory

    ./Copy-BsDirectory.ps1 -Path "/$env:CONFIG_PREFIX" -Destination "/mnt/gentoo/var/cache/binpkgs-lowerdir" -FromBs -ThrottleLimit 8

    mount --types overlay overlay --options lowerdir=/mnt/gentoo/var/cache/binpkgs-lowerdir,upperdir=/mnt/gentoo/var/cache/binpkgs-upperdir,workdir=/mnt/gentoo/var/cache/binpkgs-workdir /mnt/gentoo/var/cache/binpkgs
} elseif ($To) {
    if ($NoOverlay) {
        $binpkgsPath = "/mnt/gentoo/var/cache/binpkgs"
    } else {
        $binpkgsPath = "/mnt/gentoo/var/cache/binpkgs-upperdir"
    }

    ./Copy-BsDirectory.ps1 -Path "$binpkgsPath" -Destination "/$env:CONFIG_PREFIX" -ToBs -ThrottleLimit 8

    if (-not $NoOverlay) {
        umount /mnt/gentoo/var/cache/binpkgs

        Remove-Item -Path /mnt/gentoo/var/cache/binpkgs-lowerdir, /mnt/gentoo/var/cache/binpkgs-upperdir, /mnt/gentoo/var/cache/binpkgs-workdir -Recurse -Force
    }
} else {
    exit 1
}
