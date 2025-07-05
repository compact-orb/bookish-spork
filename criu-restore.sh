export FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox"

sudo criu restore --ext-unix-sk --file-locks --images-dir /mnt/gentoo/var/lib/criu --shell-job &

pid=$!

sleep "600" &

sleep_pid=$!

wait -n "$pid" "$sleep_pid"

if sudo kill -0 $pid; then
    criu dump --ext-unix-sk --file-locks --images-dir /mnt/gentoo/var/lib/criu --shell-job --tree "$pid"

    exit 1
else
    rm --force --recursive /mnt/gentoo/var/lib/criu
fi
