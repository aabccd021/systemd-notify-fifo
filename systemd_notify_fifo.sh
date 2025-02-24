ready_fifo=$(mktemp -u)
mkfifo "$ready_fifo"

systemd-notify-fifo-server \
  -ready "$ready_fifo" \
  -out "$1" \
  </dev/null >/dev/null &

echo "$!"

timeout 1 cat "$ready_fifo" || exit 1
