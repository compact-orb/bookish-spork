param (
    [Parameter(Mandatory = $true)]
    [string]$Prefix
)

$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

Remove-Item -Path /etc/kernel/config.d, /etc/portage/env, /etc/portage/package.env, /etc/portage/package.use -Recurse -Force -ErrorAction SilentlyContinue

Copy-Item -Path $Prefix/* -Destination / -Recurse -Force
