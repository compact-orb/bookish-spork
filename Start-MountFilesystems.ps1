<#
.SYNOPSIS
    Mounts or unmounts the necessary filesystems for a Gentoo chroot environment.

.DESCRIPTION
    This script prepares the Gentoo chroot environment located at /mnt/gentoo by mounting
    critical system filesystems (/proc, /sys, /dev, /run, /tmp). It also binds the current
    working directory to /mnt/gentoo/mnt to allow file access from within the chroot.
    
    If the -Unmount switch is provided, it tears down these mounts.

.PARAMETER Unmount
    If set, unmounts the filesystems instead of mounting them.
#>
param(
    [switch]$Unmount
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if ($Unmount) {
    # Lazy unmount all the filesystems we mounted.
    # --lazy allows unmounting even if the filesystem is busy (it will be cleaned up when no longer busy).
    umount --lazy /mnt/gentoo/dev /mnt/gentoo/proc /mnt/gentoo/run /mnt/gentoo/sys /mnt/gentoo/tmp /mnt/gentoo/mnt
}
else {
    # Mount /proc to allow process information access within the chroot.
    mount --types proc /proc /mnt/gentoo/proc
    # Recursively bind /sys to expose system information and kernel interfaces.
    mount --rbind /sys /mnt/gentoo/sys
    # Make the /sys mount a recursive slave to prevent propagation of mount events back to the host.
    mount --make-rslave /mnt/gentoo/sys
    # Recursively bind /dev to provide access to device nodes.
    mount --rbind /dev /mnt/gentoo/dev
    # Make the /dev mount a recursive slave.
    mount --make-rslave /mnt/gentoo/dev
    # Bind /run to share runtime data (like sockets and PIDs).
    mount --bind /run /mnt/gentoo/run
    # Make /run a slave mount.
    mount --make-slave /mnt/gentoo/run
    # Bind /tmp to share temporary files.
    mount --bind /tmp /mnt/gentoo/tmp
    # Make /tmp a slave mount.
    mount --make-slave /mnt/gentoo/tmp
    # Bind the current working directory to /mnt/gentoo/mnt.
    # This allows the chroot environment to access files from the directory where this script was run.
    mount --bind ./ /mnt/gentoo/mnt
}
