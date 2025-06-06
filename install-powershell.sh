POWERSHELL_7_VERSION="5.1"

aria2c --dir=/mnt https://github.com/PowerShell/PowerShell/releases/download/v7.${POWERSHELL_7_VERSION}/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.gz

mkdir --parents /opt/microsoft/powershell/7

tar --directory=/opt/microsoft/powershell/7 --extract --file=/mnt/powershell-7.${POWERSHELL_7_VERSION}-linux-x64.tar.gz

chmod +x /opt/microsoft/powershell/7/pwsh

ln --symbolic /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
