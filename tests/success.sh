NOTIFY_SOCKET=$(realpath ./notify.sock)
export NOTIFY_SOCKET

pid=$(systemd-notify-fifo ./notify.pipe)

systemd-notify --ready --no-block

output=$(cat ./notify.pipe)

if [ "$output" != "READY=1" ]; then
  echo "Expected: READY=1"
  echo "Got: $output"
  exit 1
fi

kill "$pid"
