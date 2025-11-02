param(
    [switch]$From,

    [switch]$To,

    [switch]$Temporary,

    [switch]$Bootstrap
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

if ($From) {
    if ($Bootstrap) {
        $fileName = "$env:CONFIG_PREFIX-bootstrap.tar.xz"
    } elseif ($Temporary) {
        $fileName = "$env:CONFIG_PREFIX-temporary.tar.zst"
    } else {
        $fileName = "$env:CONFIG_PREFIX.tar.zst"
    }

    New-Item -Path /mnt/gentoo -ItemType Directory

    if ($Bootstrap) {
        curl --header "accept: */*" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --silent "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" | tar --directory=/mnt/gentoo --extract --file=- --numeric-owner --preserve-permissions --xattrs-include="*.*" --xz
    } else {
        curl --header "accept: */*" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --silent "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" | tar --directory=/mnt/gentoo --extract --file=- --numeric-owner --preserve-permissions --use-compress-program="zstd --long=31" --xattrs-include="*.*"
    }

    Copy-Item -Path /etc/resolv.conf -Destination /mnt/gentoo/etc
} elseif ($To) {
    if ($Temporary) {
        $fileName = "$env:CONFIG_PREFIX-temporary.tar.zst"

        Remove-Item -Path /mnt/gentoo/etc/resolv.conf
    } else {
        $fileName = "$env:CONFIG_PREFIX.tar.zst"

        Remove-Item -Path /mnt/gentoo/etc/resolv.conf, /mnt/gentoo/var/cache/distfiles/*, /mnt/gentoo/var/tmp/* -Recurse -Force -ErrorAction SilentlyContinue
    }

    Measure-Command -Expression {
        tar --create --directory=/mnt/gentoo --file=/tmp/$fileName --numeric-owner --preserve-permissions --use-compress-program="zstd -9 -T8 --long=31" --xattrs-include="*.*" .
    }

    Measure-Command -Expression {
        Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method PUT -ContentType "application/octet-stream" -InFile /tmp/$fileName
    }
} else {
    exit 1
}
