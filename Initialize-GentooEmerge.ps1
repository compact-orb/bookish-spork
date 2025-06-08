param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

switch ($Clean) {
    $true {
        umount /mnt/gentoo/mnt /mnt/gentoo/opt/microsoft

        Remove-Item -Path /mnt/gentoo/opt/microsoft, /mnt/gentoo/usr/local/bin/pwsh
    }
    $false {
        New-Item -Path /mnt/gentoo/opt/microsoft -ItemType Directory

        mount --bind /opt/microsoft /mnt/gentoo/opt/microsoft

        New-Item -Path /mnt/gentoo/usr/local/bin/pwsh -ItemType SymbolicLink -Target /opt/microsoft/powershell/7/pwsh

        mount --bind $(Get-Location).Path /mnt/gentoo/mnt
    }
    default {
        exit 1
    }
}
