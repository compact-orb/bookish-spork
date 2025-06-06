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
    } else {
        $fileName = "$env:CONFIG_PREFIX.tar.zst"
    }

    aria2c --dir=/tmp --header="AccessKey: $env:BUNNY_STORAGE_ACCESS_KEY" --header="accept: */*" https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName

    New-Item -Path /mnt/gentoo -ItemType Directory

    if ($Bootstrap) {
        tar --directory=/mnt/gentoo --extract --file=/tmp/$fileName --numeric-owner --preserve-permissions --xattrs-include="*.*"
    } else {
        tar --directory=/mnt/gentoo --extract --file=/tmp/$fileName --numeric-owner --preserve-permissions --use-compress-program="zstd --long=31" --xattrs-include="*.*"
    }

    Remove-Item -Path /tmp/$fileName

    Copy-Item -Path /etc/resolv.conf -Destination /mnt/gentoo/etc
} elseif ($To) {
    if ($Temporary) {
        $fileName = "$env:CONFIG_PREFIX-temporary.tar.zst"
    } else {
        $fileName = "$env:CONFIG_PREFIX.tar.zst"
    }

    Remove-Item -Path /mnt/gentoo/etc/resolv.conf, /mnt/gentoo/var/cache/distfiles/*, /mnt/gentoo/var/db/repos/*, /mnt/gentoo/var/tmp/* -Recurse -Force

    Measure-Command -Expression {
        tar --create --directory=/mnt/gentoo --file=/tmp/$fileName --numeric-owner --preserve-permissions --use-compress-program="zstd -9 -T8 --long=31" --xattrs-include="*.*" .
    }

    Measure-Command -Expression {
        Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method PUT -ContentType "application/octet-stream" -InFile /tmp/$fileName
    }
} else {
    exit 1
}
