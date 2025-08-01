set -e

if [ -z "$1" ]; then
  exit 1
fi

source ./variables.sh

rm --force --recursive /etc/kernel/config.d /etc/portage/env /etc/portage/package.env /etc/portage/package.use

cp --force --recursive $1/* /

emerge --sync
