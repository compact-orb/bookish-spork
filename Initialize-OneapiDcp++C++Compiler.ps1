$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

. ./Variables.ps1

aria2c --dir=/tmp --header="accept: */*" --header="accesskey: $env:BUNNY_STORAGE_ACCESS_KEY" https://registrationcenter-download.intel.com/akdlm/IRC_NAS/c4d2aef3-3123-475e-800c-7d66fd8da2a5/intel-dpcpp-cpp-compiler-($oneapiDcpppCppCompiler)_offline.sh

bash /tmp/intel-dpcpp-cpp-compiler-($oneapiDcpppCppCompiler)_offline.sh --silent -a --eula accept --ignore-errors --silent --install-dir /mnt/gentoo/opt/intel/oneapi

Remove-Item -Path /tmp/intel-dpcpp-cpp-compiler-($oneapiDcpppCppCompiler)_offline.sh
