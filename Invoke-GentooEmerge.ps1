param(
    [string]$Packages,

    [switch]$Resume,

    [Int32]$Bootstrap,

    [Int32]$PortageProfile,

    [switch]$EmergePerl
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

. /mnt/Variables.ps1

emerge-webrsync --revert=$portageSnapshotDate --quiet

switch ($Bootstrap) {
    0 {
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
    1 {
        if ($Resume) {
            timeout 19800 emerge --buildpkg=n --emptytree --resume
        } else {
            timeout 19800 emerge --buildpkg=n --emptytree "@system"
        }

        Remove-Item -Path /etc/portage/package.use/bootstrap
    }
    2 {
        if ($Resume) {
            timeout 19800 emerge --emptytree --resume
        } else {
            timeout 19800 emerge --emptytree "@world"
        }
    }
    default {
        if ($Resume) {
            emerge --resume
        } else {
            emerge "$Packages"
        }
    }
}
