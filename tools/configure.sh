set -e

if [ -z "$1" ]; then
  exit 1
fi

source ./variables.sh

rm --force --recursive /etc/kernel/config.d /etc/portage/binrepos.conf /etc/portage/package.use /etc/portage/repos.conf

cp --force --recursive $1/* /

emerge --sync
