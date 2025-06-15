$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

. ./Variables.ps1

Remove-Item -Path /mnt/gentoo/opt/intel/oneapi -Recurse -Force -ErrorAction SilentlyContinue

aria2c --dir=/tmp --header="accept: */*" --header="accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" https://$env:BUNNY_STORAGE_ENDPOINT/$env:BUNNY_STORAGE_ZONE_NAME/intel-dpcpp-cpp-compiler-$($oneapiDcpppCppCompiler)_offline.sh

bash /tmp/intel-dpcpp-cpp-compiler-$($oneapiDcpppCppCompiler)_offline.sh --silent -a --eula accept --ignore-errors --silent --install-dir /mnt/gentoo/opt/intel/oneapi

Remove-Item -Path /tmp/intel-dpcpp-cpp-compiler-$($oneapiDcpppCppCompiler)_offline.sh

chroot /mnt/gentoo env-update
