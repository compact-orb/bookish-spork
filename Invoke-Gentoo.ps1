param(
    [string]$Packages,

    [switch]$Resume,

    [Int32]$Bootstrap,

    [Int32]$PortageProfile,

    [switch]$EmergePerl
)

New-Item -Path /mnt/gentoo/opt/microsoft -ItemType Directory

mount --bind /opt/microsoft /mnt/gentoo/opt/microsoft

mount --bind $(Get-Location).Path /mnt/gentoo/mnt

$scriptPath = "/mnt/Invoke-GentooEmerge.ps1" + $(if ($Packages) { " -Packages $Packages" } else { "" }) + $(if ($Resume) { " -Resume" } else { "" }) + $(if ($Bootstrap) { " -Bootstrap" } else { "" }) + $(if ($PortageProfile) { " -PortageProfile $PortageProfile" } else { "" }) + $(if ($EmergePerl) { " -EmergePerl" } else { "" })

chroot /mnt/gentoo /opt/microsoft/powershell/7/pwsh -Command "$scriptPath"

umount /mnt/gentoo/mnt /mnt/gentoo/opt/microsoft

Remove-Item -Path /mnt/gentoo/opt/microsoft
