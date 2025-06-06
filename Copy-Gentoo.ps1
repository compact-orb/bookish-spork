param(
    [switch]$From,

    [switch]$To,

    [switch]$Bootstrap
)

$ErrorActionPreference = "Stop"

if ($From) {
    if ($Bootstrap) {
        $fileName = "$env:CONFIG_PREFIX-bootstrap.tar.xz"
    } else {
        $fileName = "$env:CONFIG_PREFIX.tar.zstd"
    }

    aria2c --dir=/tmp --header="AccessKey: $env:BUNNY_STORAGE_ACCESS_KEY" --header="accept: */*" https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/$fileName

    New-Item -Path /mnt/gentoo -ItemType Directory

    tar --directory=/mnt/gentoo --extract --file=/tmp/$fileName --numeric-owner --preserve-permissions --xattrs-include="*.*"

    Remove-Item -Path /tmp/$fileName

    Copy-Item -Path /etc/resolv.conf -Destination /mnt/gentoo/etc
} elseif ($To) {
    Remove-Item -Path /mnt/gentoo/etc/resolv.conf, /mnt/gentoo/var/cache/distfiles/*, /mnt/gentoo/var/db/repos/*, /mnt/gentoo/var/tmp/* -Recurse

    Measure-Command -Expression {
        tar --create --directory=/mnt/gentoo --file=/tmp/$env:CONFIG_PREFIX.tar.zst --numeric-owner --preserve-permissions --use-compress-program="zstd -9 -T8 --long=31" --xattrs-include="*.*" .
    }

    Measure-Command -Expression {
        Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT/$env:STORAGE_ZONE_NAME/$env:CONFIG_PREFIX.tar.zst" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method PUT -ContentType "application/octet-stream" -InFile /tmp/$env:CONFIG_PREFIX.tar.zst
    }
} else {
    exit 1
}
