set -e

if [ -z "$1" ]; then
    echo "Please specify a configuration prefix."

    exit 1
fi

source ./variables.sh

rm --force --recursive /etc/kernel/config.d /etc/portage/env /etc/portage/package.accept_keywords /etc/portage/package.env /etc/portage/package.unmask /etc/portage/package.use /etc/portage/patches /etc/portage/repos.conf /etc/python-exec/emerge.conf

cp --force --recursive $1/* /

emerge --sync
