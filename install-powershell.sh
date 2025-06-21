# By default, this script downloads PowerShell with Invariant Globalization enabled. This is for Gentoo Stage 3s without ICU support.

set -e

source ./variables.sh

if [ "$1" = official ]; then
    aria2c --dir=/tmp https://github.com/PowerShell/PowerShell/releases/download/v7.$POWERSHELL_7_VERSION/powershell-7.$POWERSHELL_7_VERSION-linux-$POWERSHELL_7_ARCHITECTURE.tar.gz
else
    aria2c --dir=/tmp --header="accept: */*" --header="accesskey: $BUNNY_STORAGE_ACCESS_KEY" https://$BUNNY_STORAGE_ENDPOINT/$BUNNY_STORAGE_ZONE_NAME/powershell-7.$POWERSHELL_7_VERSION-linux-$POWERSHELL_7_ARCHITECTURE.tar.zst
fi

mkdir --parents /opt/microsoft/powershell/7

if [ "$1" = official ]; then
    tar --directory=/opt/microsoft/powershell/7 --extract --file=/tmp/powershell-7.$POWERSHELL_7_VERSION-linux-$POWERSHELL_7_ARCHITECTURE.tar.gz

    rm /tmp/powershell-7.$POWERSHELL_7_VERSION-linux-$POWERSHELL_7_ARCHITECTURE.tar.gz
else
    tar --directory=/opt/microsoft/powershell/7 --extract --file=/tmp/powershell-7.$POWERSHELL_7_VERSION-linux-$POWERSHELL_7_ARCHITECTURE.tar.zst --use-compress-program="zstd --long=31"

    rm /tmp/powershell-7.$POWERSHELL_7_VERSION-linux-$POWERSHELL_7_ARCHITECTURE.tar.zst
fi

chmod +x /opt/microsoft/powershell/7/pwsh

ln --symbolic /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
