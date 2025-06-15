param(
    [string]$Packages,

    [switch]$Emptytree,

    [switch]$KeepGoing,

    [switch]$Oneshot,

    [string]$UsepkgExclude,

    [switch]$Update,

    [switch]$Resume,

    [switch]$Deselect,

    [switch]$Sync,

    [switch]$Webrsync,

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
        if ($Sync) {
            emerge --sync
        } elseif ($Webrsync) {
            emerge-webrsync --revert=$portageSnapshotDate --quiet
        } elseif ($Deselect) {
            emerge --deselect ($Packages -split " ")
        } elseif ($Resume) {
            timeout 19800 emerge --resume

            emerge --depclean
        } elseif ($Update) {
            timeout 19800 emerge --deep --newuse --update "@world"

            emerge --depclean
        } else {
            $emptytreeOption = ""

            if ($Emptytree) {
                $emptytreeOption = " --emptytree"
            }

            $keepGoingOption = ""

            if ($KeepGoing) {
                $keepGoingOption = " --keep-going"
            }

            $oneshotOption = ""

            if ($Oneshot) {
                $oneshotOption = " --oneshot"
            }

            $usepkgExcludeOption = ""

            if ($UsepkgExclude) {
                $usepkgExcludeOption = " --usepkg-exclude '$UsepkgExclude'"
            }

            $emergeCommand = "timeout 19800 emerge$emptytreeOption$keepGoingOption$oneshotOption$usepkgExcludeOption $($Packages -split " ")"

            Write-Output -InputObject $emergeCommand

            Invoke-Expression -Command $emergeCommand

            emerge --depclean
        }
    }
}
