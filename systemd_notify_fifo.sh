ready_fifo=$(mktemp -u)
mkfifo "$ready_fifo"

nohup systemd-notify-fifo-server \
  -ready "$ready_fifo" \
  -out "$1" \
  </dev/null >/dev/null &

echo "$!"

cat "$ready_fifo"
