param (
    [switch]$Endpoint
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

Remove-Item -Path /mnt/gentoo/etc/kernel/config.d, /mnt/gentoo/etc/portage/bashrc, /mnt/gentoo/etc/portage/binrepos.conf, /mnt/gentoo/etc/portage/env, /mnt/gentoo/etc/portage/package.accept_keywords, /mnt/gentoo/etc/portage/package.env, /mnt/gentoo/etc/portage/package.mask, /mnt/gentoo/etc/portage/package.unmask, /mnt/gentoo/etc/portage/package.use, /mnt/gentoo/etc/portage/patches, /mnt/gentoo/etc/portage/profile/use.mask, /mnt/gentoo/etc/portage/repos.conf, /mnt/gentoo/etc/python-exec/emerge.conf, /mnt/gentoo/root/.ssh -Recurse -Force -ErrorAction SilentlyContinue

Copy-Item -Path $env:CONFIG_PREFIX/* -Destination /mnt/gentoo -Recurse -Force

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

chroot /mnt/gentoo env-update
