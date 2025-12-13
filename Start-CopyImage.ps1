param(
    [switch]$From,
    [switch]$To,
    [switch]$Temporary,
    [switch]$Bootstrap,
    [switch]$Overlay,
    [string]$LayerName,
    [switch]$ForceRebuild
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if ($From) {
    if ($Overlay) {
        if (-not $LayerName) {
            Write-Error -Message "LayerName is required when Overlay is specified."
        }

        $baseFileName = "$env:CONFIG_PREFIX.tar.zst"
        $layerFileName = "$env:CONFIG_PREFIX-$LayerName.tar.zst"

        # Prepare directories
        Write-Output -InputObject "Creating directories..."
        New-Item -Path /mnt/gentoo-lower, /mnt/gentoo-upper, /mnt/gentoo-work, /mnt/gentoo -ItemType Directory -Force | Out-Null

        # Download and extract Base Image to lowerdir
        Write-Output -InputObject "Downloading and extracting Base Image..."
        curl --header "accept: */*" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --silent "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$baseFileName" | tar --directory=/mnt/gentoo-lower --extract --file=- --numeric-owner --preserve-permissions --use-compress-program="zstd --long=31" --xattrs-include="*.*"

        # Handle Layer Image
        if ($ForceRebuild) {
            Write-Output -InputObject "ForceRebuild specified. Starting with empty layer."
        }
        else {
            Write-Output -InputObject "Downloading and extracting Layer Image..."

            curl --header "accept: */*" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --silent "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$layerFileName" | tar --directory=/mnt/gentoo-upper --extract --file=- --numeric-owner --preserve-permissions --use-compress-program="zstd --long=31" --xattrs-include="*.*"
        }

        # Mount Overlay
        Write-Output -InputObject "Mounting overlayfs..."
        mount -t overlay overlay -o "lowerdir=/mnt/gentoo-lower,upperdir=/mnt/gentoo-upper,workdir=/mnt/gentoo-work" /mnt/gentoo

        # Restore resolv.conf (writes to upper)
        Write-Output -InputObject "Restoring resolv.conf..."
        Copy-Item -Path /etc/resolv.conf -Destination /mnt/gentoo/etc -Force
    }
    else {
        if ($Bootstrap) {
            $fileName = "$env:CONFIG_PREFIX-bootstrap.tar.xz"
        }
        elseif ($Temporary) {
            $fileName = "$env:CONFIG_PREFIX-temporary.tar.zst"
        }
        else {
            $fileName = "$env:CONFIG_PREFIX.tar.zst"
        }

        Write-Output -InputObject "Creating directories..."
        New-Item -Path /mnt/gentoo -ItemType Directory -Force | Out-Null

        Write-Output -InputObject "Downloading and extracting Base Image..."
        if ($Bootstrap) {
            curl --header "accept: */*" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --silent "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" | tar --directory=/mnt/gentoo --extract --file=- --numeric-owner --preserve-permissions --xattrs-include="*.*" --xz
        }
        else {
            curl --header "accept: */*" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --silent "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" | tar --directory=/mnt/gentoo --extract --file=- --numeric-owner --preserve-permissions --use-compress-program="zstd --long=31" --xattrs-include="*.*"
        }

        Write-Output -InputObject "Restoring resolv.conf..."
        Copy-Item -Path /etc/resolv.conf -Destination /mnt/gentoo/etc
    }
}
elseif ($To) {
    if ($Overlay) {
        if (-not $LayerName) {
            Write-Error -Message "LayerName is required when Overlay is specified."
        }

        $fileName = "$env:CONFIG_PREFIX-$LayerName.tar.zst"
        $targetDir = "/mnt/gentoo-upper"
        $excludeParams = @(
            "--exclude=./var/cache/binpkgs",
            "--exclude=./var/cache/distfiles/*",
            "--exclude=./var/tmp/*",
            "--exclude=./tmp/*",
            "--exclude=./run/*",
            "--exclude=./etc/resolv.conf"
        )

        Write-Output -InputObject "Creating archive..."
        Measure-Command -Expression {
            tar --create --directory=$targetDir --file=/dev/shm/$fileName --numeric-owner --preserve-permissions --use-compress-program="zstd -9 -T8 --long=31" --xattrs-include="*.*" @excludeParams .
        }

        Write-Output -InputObject "Uploading archive..."
        Measure-Command -Expression {
            Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile /dev/shm/$fileName
        }
    }
    else {
        if ($Temporary) {
            $fileName = "$env:CONFIG_PREFIX-temporary.tar.zst"

            Remove-Item -Path /mnt/gentoo/etc/resolv.conf
        }
        else {
            $fileName = "$env:CONFIG_PREFIX.tar.zst"

            Remove-Item -Path /mnt/gentoo/etc/resolv.conf, /mnt/gentoo/var/cache/distfiles/*, /mnt/gentoo/var/tmp/* -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Output -InputObject "Creating archive..."
        Measure-Command -Expression {
            tar --create --directory=/mnt/gentoo --file=/mnt/$fileName --numeric-owner --preserve-permissions --use-compress-program="zstd -9 -T8 --long=31" --xattrs-include="*.*" .
        }

        Write-Output -InputObject "Uploading archive..."
        Measure-Command -Expression {
            Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY } -Method PUT -ContentType "application/octet-stream" -InFile /mnt/$fileName
        }
    }
}
else {
    exit 1
}
