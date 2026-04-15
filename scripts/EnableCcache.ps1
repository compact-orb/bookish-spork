<#
.SYNOPSIS
    Prepares ccache for the Portage environment inside the Gentoo chroot.
#>

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

New-Item -Path "/mnt/gentoo/var/cache/ccache" -ItemType Directory -Force | Out-Null
chroot /mnt/gentoo chown --recursive portage:portage /var/cache/ccache
