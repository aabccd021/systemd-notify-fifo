# systemd-notify-fifo

Pipe systemd-notify messages to Unix FIFO.

You can use this to mock systemd-notify, log notified messages, or wait for a server to be ready.

## Usage

### Wait for server to be ready

```bash
export NOTIFY_SOCKET=$(realpath ./notify.sock)

# this will forward every message sent to NOTIFY_SOCKET to ./notify.pipe
pid=$(systemd-notify-fifo ./notify.pipe)

# this web server executed `systemd-notify --ready --no-block` when it's ready
run_web_server &

# read messages from the FIFO until we see "READY=1"
while true; do
  message=$(cat ./notify.pipe)
  if [ "$message" = "READY=1" ]; then
    break
  fi
done

echo "run_web_server is ready"

# `systemd-notify-fifo` runs a process in the background
# so we need to kill it when we're done
kill "$pid"
```

### Log systemd-notify messages

```bash
export NOTIFY_SOCKET=$(realpath ./notify.sock)

pid=$(systemd-notify-fifo ./notify.pipe)

run_web_server &

while true; do
  message=$(cat ./notify.pipe)
  echo "systemd-notify: $message"
done

kill "$pid"
```

### Manually wait for socket to be ready

`systemd-notify-fifo` will by default wait for the NOTIFY_SOCKET to be ready before the command exits.
This is why its safe to run any command after `systemd-notify-fifo`.

In some scenario, you might want to manually wait for the NOTIFY_SOCKET to be ready.
In this case, you can use the `systemd-notify-fifo-server` command.

```bash
export NOTIFY_SOCKET=$(realpath ./notify.sock)

ready_fifo=$(mktemp -u)
mkfifo "$ready_fifo"

# run the NOTIFY_SOCKET server in the background
systemd-notify-fifo-server -ready "$ready_fifo"  -out ./notify.pipe &
pid=$!

# wait for the NOTIFY_SOCKET to be ready
cat "$ready_fifo"

# now it's safe to run the web server, since the NOTIFY_SOCKET is ready
run_web_server &

# kill the NOTIFY_SOCKET server running in the background
kill "$pid"
```

Don't forget to always wait for the NOTIFY_SOCKET to be ready,
otherwise the behavior of scripts using `systemd-notify-fifo` might be flaky.

```bash
ready_fifo=$(mktemp -u)
mkfifo "$ready_fifo"

systemd-notify-fifo-server -ready "$ready_fifo"  -out ./notify.pipe &
pid=$!

# This might result in flaky behavior, e.g. `systemd-notify` executed before NOTIFY_SOCKET is ready.
run_web_server &
```
