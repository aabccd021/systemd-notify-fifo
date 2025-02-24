NOTIFY_SOCKET=./notify.sock
export NOTIFY_SOCKET

timeout 1 systemd-notify-fifo ./notify.pipe 2>./actual.txt || true

echo "NOTIFY_SOCKET must be an absolute path, otherwise systemd-notify will throw Protocol error" >expected.txt
diff --unified --color expected.txt actual.txt
