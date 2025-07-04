export FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"

sudo criu restore --file-locks --images-dir /mnt/gentoo/var/lib/criu --shell-job &

pid=$!

sleep "310" &

sleep_pid=$!

wait -n "$pid" "$sleep_pid"

if sudo kill -0 $pid; then
    criu dump --file-locks --images-dir /mnt/gentoo/var/lib/criu --shell-job --tree "$pid"

    exit 1
else
    rm --force --recursive /mnt/gentoo/var/lib/criu
fi
