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

chroot /mnt/gentoo /opt/microsoft/powershell/7/pwsh -File /mnt/Invoke-GentooEmerge.ps1 -Packages $Packages -Resume $Resume -Bootstrap $Bootstrap -PortageProfile $PortageProfile -EmergePerl $EmergePerl

umount /mnt/gentoo/mnt /mnt/gentoo/opt/microsoft

Remove-Item -Path /mnt/gentoo/opt/microsoft

if ($Error.Count -gt 0) {
    exit 1
}
