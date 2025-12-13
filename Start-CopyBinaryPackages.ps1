param(
    [switch]$From,

    [switch]$To,

    [switch]$NoOverlay
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

if ($From) {
    New-Item -Path /mnt/binpkgs-store/lower, /mnt/binpkgs-store/upper, /mnt/binpkgs-store/work -ItemType Directory -Force | Out-Null

    ./DownloadBunnyStorageDirectory.ps1 -Path "/$env:BUNNY_STORAGE_ZONE_NAME/$env:CONFIG_PREFIX" -Destination "/mnt/binpkgs-store/lower"

    mount --types overlay overlay --options "lowerdir=/mnt/binpkgs-store/lower,upperdir=/mnt/binpkgs-store/upper,workdir=/mnt/binpkgs-store/work" /mnt/gentoo/var/cache/binpkgs
}
elseif ($To) {
    if ($NoOverlay) {
        $binpkgsPath = "/mnt/gentoo/var/cache/binpkgs"
    }
    else {
        $binpkgsPath = "/mnt/binpkgs-store/upper"
    }

    ./UploadBunnyStorageDirectory.ps1 -Path "$binpkgsPath" -Destination "/$env:CONFIG_PREFIX"

    if ($NoOverlay) {
        Remove-Item -Path /mnt/gentoo/var/cache/binpkgs/* -Recurse
    }
    else {
        umount /mnt/gentoo/var/cache/binpkgs

        Remove-Item -Path /mnt/binpkgs-store -Recurse -Force
    }
}
else {
    exit 1
}
