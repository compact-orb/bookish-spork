<#
.SYNOPSIS
    Prepares /mnt as a BTRFS filesystem with zstd compression enabled.
.DESCRIPTION
    This script is designed to run in a GitHub Actions runner environment.
    It errors out if a separate drive is already mounted at /mnt,
    installs btrfs-progs if missing, creates a sparse file to act as the BTRFS image,
    formats it with BTRFS (single metadata profile), and mounts it to /mnt with zstd
    compression and noatime enabled.
#>

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# 1. Check if /mnt is already mounted
$isMounted = $false
try {
    if (Test-Path "/proc/mounts") {
        $mounts = Get-Content /proc/mounts -ErrorAction SilentlyContinue
        foreach ($line in $mounts) {
            if ($line -match "\s+/mnt\s+") {
                $isMounted = $true
                break
            }
        }
    }
} catch {
    $isMounted = (Start-Process -FilePath "mountpoint" -ArgumentList "-q", "/mnt" -PassThru -Wait).ExitCode -eq 0
}

if ($isMounted) {
    Write-Error -Message "Error: A separate drive is already mounted at /mnt! Exiting."
}

# Ensure the mount point directory /mnt exists
if (-not (Test-Path "/mnt")) {
    Write-Output "Creating /mnt directory..."
    New-Item -Path "/mnt" -ItemType Directory -Force | Out-Null
}

# 2. Install btrfs-progs if missing
if (-not (Get-Command "mkfs.btrfs" -ErrorAction SilentlyContinue)) {
    Write-Output "btrfs-progs is missing. Installing..."
    $env:DEBIAN_FRONTEND = "noninteractive"
    apt update
    apt install -y btrfs-progs
}

# 3. Create the sparse BTRFS image file on the root filesystem /
$imagePath = "/mnt.btrfs"

# Dynamically calculate the image size based on available free space on the root drive.
# We multiply the physical free space by 3 to maximize the virtual capacity (since BTRFS
# will compress files with zstd), ensuring a minimum size of 100GB.
$rootFreeSpace = [System.IO.DriveInfo]::new("/").AvailableFreeSpace
$targetSizeGB = [Math]::Max(100, [Math]::Floor(($rootFreeSpace * 3) / 1GB))
$imageSize = "${targetSizeGB}G"

if (Test-Path $imagePath) {
    Write-Output "Removing existing image at $imagePath"
    Remove-Item -Path $imagePath -Force
}

Write-Output "Creating sparse file at $imagePath with size $imageSize ($([Math]::Round($rootFreeSpace / 1GB, 2)) GB physical free space on root)..."
truncate -s $imageSize $imagePath

# 4. Format with BTRFS using single metadata profile
Write-Output "Formatting BTRFS image..."
mkfs.btrfs -f -m single $imagePath

# 5. Mount BTRFS image onto /mnt with loop, zstd compression, and noatime
Write-Output "Mounting BTRFS image onto /mnt..."
mount -o loop,compress=zstd,noatime $imagePath /mnt

# 6. Verify and display disk space
Write-Output "Mount successful. Disk space at /mnt:"
df -h /mnt
