NOTIFY_SOCKET=./notify.sock
export NOTIFY_SOCKET

exit_code=0
systemd-notify-fifo ./notify.pipe 2>./actual.txt || exit_code=$?

if [ "$exit_code" -ne 1 ]; then
  echo "Expected: 1"
  echo "Got: $exit_code"
  exit 1
fi

echo "NOTIFY_SOCKET must be an absolute path, otherwise systemd-notify will throw Protocol error" >expected.txt
diff --unified --color expected.txt actual.txt
