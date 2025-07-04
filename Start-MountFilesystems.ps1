param(
    [switch]$Unmount
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

if ($Unmount) {
    umount --lazy /mnt/gentoo/dev /mnt/gentoo/proc /mnt/gentoo/run /mnt/gentoo/sys /mnt/gentoo/tmp /mnt/gentoo/mnt
} else {
    mount --types proc /proc /mnt/gentoo/proc

    mount --rbind /sys /mnt/gentoo/sys

    mount --make-rslave /mnt/gentoo/sys

    mount --rbind /dev /mnt/gentoo/dev

    mount --make-rslave /mnt/gentoo/dev

    mount --bind /run /mnt/gentoo/run

    mount --make-slave /mnt/gentoo/run

    mount --bind /tmp /mnt/gentoo/tmp

    mount --make-slave /mnt/gentoo/tmp

    mount --bind ./ /mnt/gentoo/mnt
}
