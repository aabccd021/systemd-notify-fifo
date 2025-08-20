export NOTIFY_SOCKET="/tmp/systemd-notify.sock"

systemd-notify-server-prepare

systemd-notify-server &
server_pid=$!

systemd-notify-server-wait

systemd-notify --ready --no-block &
notify_pid=$!

systemd-notify-wait

kill "$server_pid" >/dev/null 2>&1 || true
kill "$notify_pid" >/dev/null 2>&1 || true
wait "$server_pid"
wait "$notify_pid"
