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
        curl --header "accept: */*" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --silent "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" | tar --directory=/mnt/gentoo --extract --file=- --numeric-owner --preserve-permissions --xattrs-include="*.*"
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

    tar --create --directory=/mnt/gentoo --file=- --numeric-owner --preserve-permissions --use-compress-program="zstd -9 -T8 --long=31" --xattrs-include="*.*" . | curl --data-binary `@- --fail --header "accept: application/json" --header "accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" --header "content-type: application/octet-stream" --request PUT --show-error --silent "https://$env:BUNNY_STORAGE_ENDPOINT_CDN/$env:BUNNY_STORAGE_ZONE_NAME/$fileName"
} else {
    exit 1
}
