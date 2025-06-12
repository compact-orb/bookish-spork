$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

aria2c --dir=/tmp https://registrationcenter-download.intel.com/akdlm/IRC_NAS/c4d2aef3-3123-475e-800c-7d66fd8da2a5/intel-dpcpp-cpp-compiler-2025.1.1.9_offline.sh

bash /tmp/intel-dpcpp-cpp-compiler-2025.1.1.9_offline.sh --silent -a --eula accept --ignore-errors --silent --install-dir /mnt/gentoo/opt/intel/oneapi

Remove-Item -Path /tmp/intel-dpcpp-cpp-compiler-2025.1.1.9_offline.sh
