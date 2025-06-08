set -e

source ./variables.sh

if [ $1 = "official" ]; then
    aria2c --dir=/tmp https://github.com/PowerShell/PowerShell/releases/download/v7.${POWERSHELL_7_VERSION}/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.gz
else
    aria2c --dir=/tmp --header="AccessKey: $env:BUNNY_STORAGE_ACCESS_KEY" --header="accept: */*" https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.zst
fi

mkdir --parents /opt/microsoft/powershell/7

if [ $1 = "official" ]; then
    tar --directory=/opt/microsoft/powershell/7 --extract --file=/tmp/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.gz
else
    tar --directory=/opt/microsoft/powershell/7 --extract --file=/tmp/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.zst --use-compress-program="zstd --long=31"
fi

tar --directory=/opt/microsoft/powershell/7 --extract --file=/tmp/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.gz

rm /tmp/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.gz

if [ $1 = "official" ]; then
    rm /tmp/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.gz
else
    rm /tmp/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.zst
fi

chmod +x /opt/microsoft/powershell/7/pwsh

ln --symbolic /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
