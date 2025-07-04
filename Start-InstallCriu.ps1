$ErrorActionPreference = "Stop"

$PSNativeCommandUseErrorActionPreference = $true

add-apt-repository ppa:criu/ppa

apt install criu
