# Before you can run this script, you will need to set the following environment variables:
# BUNNY_STORAGE_ACCESS_KEY
# BUNNY_STORAGE_CDN
# BUNNY_STORAGE_ENDPOINT
# BUNNY_STORAGE_ENDPOINT_CDN
# BUNNY_STORAGE_ZONE_NAME
# CONFIG_PREFIX
# POWERSHELL_7_ARCHITECTURE

set -e

# Install PowerShell
sudo --preserve-env bash ./install-powershell.sh

# Set Up Gentoo
sudo --preserve-env pwsh -File ./Start-CopyImage.ps1 -From

# Set Up Binary Packages
sudo --preserve-env pwsh -File ./Start-CopyBinaryPackages.ps1 -From

# Mount Filesystems
sudo --preserve-env pwsh -File ./Start-MountFilesystems.ps1

echo 'Run "sudo chroot /mnt/gentoo" to enter the Gentoo environment'
