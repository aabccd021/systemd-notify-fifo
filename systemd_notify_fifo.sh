ready_fifo=$(mktemp -u)
mkfifo "$ready_fifo"

out_fifo="${1:-}"
if [ -z "$out_fifo" ]; then
  out_fifo="/tmp/$PPID-systemd-notify-fifo.fifo"
fi

systemd-notify-fifo-server \
  -ready "$ready_fifo" \
  -out "$out_fifo" \
  </dev/null >/dev/null &

echo "$!"

timeout 1 cat "$ready_fifo" || exit 1
