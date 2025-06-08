$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

umount --lazy /mnt/gentoo/dev /mnt/gentoo/proc /mnt/gentoo/run /mnt/gentoo/sys /mnt/gentoo/tmp
