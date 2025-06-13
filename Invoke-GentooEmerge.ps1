param(
    [string]$Packages,

    [switch]$Resume,

    [switch]$Update,

    [switch]$Oneshot,

    [switch]$Deselect,

    [string]$UsepkgExclude,

    [switch]$Webrsync,

    [switch]$Sync,

    [Int32]$Bootstrap,

    [Int32]$PortageProfile,

    [switch]$EmergePerl
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

. /mnt/Variables.ps1

switch ($Bootstrap) {
    1 {
        emerge-webrsync --revert=$portageSnapshotDate --quiet

        locale-gen --quiet

        eselect --brief locale set 6

        if ($PortageProfile) {
            eselect --brief profile set $PortageProfile
        }

        Set-Content -Path /etc/portage/package.env/bootstrap -Value "*/* gcc.conf"

        Set-Content -Path /etc/portage/package.use/bootstrap -Value "*/* -pgo"

        emerge llvm-core/clang

        Remove-Item -Path /etc/portage/package.env/bootstrap

        if ($EmergePerl) {
            emerge --buildpkg=n --oneshot dev-lang/perl
        }
    }
    2 {
        if ($Resume) {
            timeout 19800 emerge --buildpkg=n --emptytree --resume
        } else {
            timeout 19800 emerge --buildpkg=n --emptytree "@system"
        }

        Remove-Item -Path /etc/portage/package.use/bootstrap
    }
    3 {
        if ($Resume) {
            timeout 19800 emerge --emptytree --resume
        } else {
            timeout 19800 emerge --emptytree "@world"
        }

        emerge --depclean
    }
    default {
        if ($Update) {
            emerge --deep --newuse --update "@world"

            emerge --depclean
        } elseif ($Webrsync) {
            emerge-webrsync --revert=$portageSnapshotDate --quiet
        } elseif ($Sync) {
            emerge --sync
        } elseif ($Resume) {
            emerge --resume

            emerge --depclean
        } elseif ($Deselect) {
            emerge --deselect ($Packages -split " ")

            emerge --depclean
        } elseif ($Oneshot) {
            emerge --oneshot ($Packages -split " ")

            emerge --depclean
        } else {
            if ($UsepkgExclude) {
                emerge --usepkg-exclude $UsepkgExclude ($Packages -split " ")
            } else {
                emerge ($Packages -split " ")
            }

            emerge --depclean
        }
    }
}
