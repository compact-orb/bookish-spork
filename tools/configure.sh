set -e

if [ -z "$1" ]; then
  exit 1
fi

source ./variables.sh

rm --force --recursive /etc/kernel/config.d /etc/portage/env /etc/portage/package.accept_keywords /etc/portage/package.env /etc/portage/package.unmask /etc/portage/package.use /etc/portage/patches /etc/portage/repos.conf

cp --force --recursive $1/* /

emerge --sync
