param(
    [switch]$Clean
)

switch ($Clean) {
    $true {
        umount /mnt/gentoo/mnt /mnt/gentoo/opt/microsoft

        Remove-Item -Path /mnt/gentoo/opt/microsoft
    }
    $false {
        New-Item -Path /mnt/gentoo/opt/microsoft -ItemType Directory

        mount --bind /opt/microsoft /mnt/gentoo/opt/microsoft

        mount --bind $(Get-Location).Path /mnt/gentoo/mnt
    }
    default {
        exit 1
    }
}
