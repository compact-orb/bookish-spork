export FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox"

sudo --preserve-env chroot /mnt/gentoo bash /mnt/emerge.sh $@ &

pid=$!

sleep "600" &

sleep_pid=$!

wait -n "$pid" "$sleep_pid"

if sudo kill -0 $pid; then
    mkdir /mnt/gentoo/var/lib/criu

    criu dump --ext-unix-sk --file-locks --images-dir /mnt/gentoo/var/lib/criu --shell-job --tree "$pid"

    exit 1
fi
