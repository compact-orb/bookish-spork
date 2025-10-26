set -e

source ./variables.sh

mkdir --parents /opt/microsoft/powershell/7

curl --location --silent https://github.com/PowerShell/PowerShell/releases/download/v7.$POWERSHELL_7_VERSION/powershell-7.$POWERSHELL_7_VERSION-linux-$POWERSHELL_7_ARCHITECTURE.tar.gz | tar --directory=/opt/microsoft/powershell/7 --extract --file=- --gzip

chmod +x /opt/microsoft/powershell/7/pwsh

ln --symbolic /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
