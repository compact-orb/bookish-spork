# This script builds PowerShell with Invariant Globalization enabled. This is for Gentoo Stage 3s without ICU support.

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

. ./Variables.ps1

git clone --branch=v7.$powerShell7Version https://github.com/PowerShell/PowerShell.git /mnt/PowerShell

Set-Content -Path /mnt/PowerShell/src/powershell-unix/powershell-unix.csproj -Value (Get-Content -Path /mnt/PowerShell/src/powershell-unix/powershell-unix.csproj | ForEach-Object {
    if ($_.Contains("</PropertyGroup>")) {
        "    <InvariantGlobalization>true</InvariantGlobalization>"
    }
    $_
})

Set-Location -Path /mnt/PowerShell

Import-Module ./build.psm1

Start-PSBootstrap -Scenario Both

Start-PSBuild -UseNuGetOrg -Configuration Release -ReleaseTag v7.$powerShell7Version

tar --create --directory=/mnt/PowerShell/src/powershell-unix/bin/Release/net9.0/linux-x64 --file=/tmp/powershell-7.$powerShell7Version-linux-x64.tar.zst --numeric-owner --preserve-permissions --use-compress-program="zstd -22 -T8 --long=31 --ultra" --xattrs-include="*.*" .

Invoke-RestMethod -Uri "https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/powershell-7.$powerShell7Version-linux-x64.tar.zst" -Headers @{"accept" = "application/json"; "accesskey" = $env:BUNNY_STORAGE_ACCESS_KEY} -Method PUT -ContentType "application/octet-stream" -InFile /tmp/powershell-7.$powerShell7Version-linux-x64.tar.zst
