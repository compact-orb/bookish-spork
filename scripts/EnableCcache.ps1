<#
.SYNOPSIS
    Enables ccache for the Portage environment inside the Gentoo chroot.
#>

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$makeConfPath = "/mnt/gentoo/etc/portage/make.conf"

$makeConfContent = Get-Content -Path $makeConfPath -Raw
if ($makeConfContent -notmatch 'FEATURES="\S*ccache\S*"') {
    Add-Content -Path $makeConfPath -Value @(
        'FEATURES="${FEATURES} ccache"'
        'CCACHE_DIR="/var/cache/ccache"'
    )
}

New-Item -Path "/mnt/gentoo/var/cache/ccache" -ItemType Directory -Force | Out-Null
chroot /mnt/gentoo chown --recursive portage:portage /var/cache/ccache
