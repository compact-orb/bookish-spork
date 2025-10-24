param (
    [switch]$Endpoint
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

Remove-Item -Path /mnt/gentoo/etc/kernel/config.d, /mnt/gentoo/etc/portage/binrepos.conf, /mnt/gentoo/etc/portage/env, /mnt/gentoo/etc/portage/package.env, /mnt/gentoo/etc/portage/package.use, /mnt/gentoo/etc/portage/patches, /mnt/gentoo/etc/portage/repos.conf -Recurse -Force -ErrorAction SilentlyContinue

Copy-Item -Path $env:CONFIG_PREFIX/* -Destination /mnt/gentoo -Recurse -Force

if (-not $Endpoint) {
    Set-Content -Path /mnt/gentoo/etc/portage/make.conf -Value (Get-Content -Path /mnt/gentoo/etc/portage/make.conf | ForEach-Object {
        if ($_ -match "^EMERGE_DEFAULT_OPTS=") {
            "# $_"
        } else {
            $_
        }
    })

    Add-Content -Path /mnt/gentoo/etc/portage/make.conf -Value @'

MAKEOPTS="--jobs=8 --load-average=9"

EMERGE_DEFAULT_OPTS="--backtrack=1024 --buildpkg --quiet-build --usepkg --with-bdeps=y"
BINPKG_COMPRESS="zstd"
BINPKG_COMPRESS_FLAGS="-19 -T8 --long"
'@

    New-Item -Path /mnt/gentoo/etc/portage/repos.conf -ItemType Directory

    Set-Content -Path /mnt/gentoo/etc/portage/repos.conf/gentoo.conf -Value @"
[gentoo]
sync-uri = rsync://$env:RSYNC_MIRROR/gentoo-portage
"@
}

chroot /mnt/gentoo env-update
