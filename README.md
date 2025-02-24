# systemd-notify-fifo

Pipe systemd-notify messages to Unix FIFO.

You can use this to mock systemd-notify, log notified messages, or wait for a server to be ready.

This repo includes two commands:

- `systemd-notify-fifo`: Pipe systemd-notify messages to Unix FIFO.
- `systemd-notify-fifo-server`: Same as `systemd-notify-fifo`, but we need to manually wait for the NOTIFY_SOCKET to be ready.

## Usage

### Wait for server to be ready

```bash
export NOTIFY_SOCKET=$(realpath ./notify.sock)

# this will forward every message sent to NOTIFY_SOCKET to ./notify.pipe
notify_pid=$(systemd-notify-fifo ./notify.pipe)

# example web server that executes `systemd-notify --ready --no-block` when it's ready
run_web_server &

# read messages from the FIFO until we see "READY=1",
# which is sent by `systemd-notify --ready --no-block` command
while true; do
 message=$(cat ./notify.pipe)
 if [ "$message" = "READY=1" ]; then
  break
 fi
done

echo "run_web_server is ready"

# example command that has to run only after the web server is ready
run_tests

kill "$web_server_pid"

# `systemd-notify-fifo` runs a process in the background, so we need to kill it when we're done
kill "$notify_pid"
```

### Log systemd-notify messages

```bash
export NOTIFY_SOCKET=$(realpath ./notify.sock)

notify_pid=$(systemd-notify-fifo ./notify.pipe)

run_web_server &
web_server_pid=$!

# read messages from the FIFO and log them
while true; do
 message=$(cat ./notify.pipe)
 echo "message received on systemd-notify: $message"
done

# run server for 10 seconds and see the messages logged
sleep 10

kill "$web_server_pid"
kill "$notify_pid"
```

### Manually wait for socket to be ready

`systemd-notify-fifo` will by default wait for the NOTIFY_SOCKET to be ready before the command exits.
This is why its safe to run any command after `systemd-notify-fifo`.

In some scenario, you might want to manually wait for the NOTIFY_SOCKET to be ready.
In this case, you can use the `systemd-notify-fifo-server` command.

The command accepts `-ready` argument, which is a path to a FIFO file that will be written to when the NOTIFY_SOCKET is ready.
The `-out` argument is the same thing as the argument passed to `systemd-notify-fifo`.

```bash
export NOTIFY_SOCKET=$(realpath ./notify.sock)

ready_fifo=$(mktemp -u)
mkfifo "$ready_fifo"

# run the NOTIFY_SOCKET server in the background
systemd-notify-fifo-server -ready "$ready_fifo" -out ./notify.pipe &
notify_pid=$!

# wait for the NOTIFY_SOCKET to be ready
cat "$ready_fifo"

# now it's safe to run the web server
run_web_server &

# kill the NOTIFY_SOCKET server running in the background
kill "$notify_pid"
```

Don't forget to always wait for the NOTIFY_SOCKET to be ready, otherwise the behavior might be flaky.

```bash
ready_fifo=$(mktemp -u)
mkfifo "$ready_fifo"

systemd-notify-fifo-server -ready "$ready_fifo" -out ./notify.pipe &
notify_pid=$!

# This might result in flaky behavior, e.g. `systemd-notify --ready` executed before NOTIFY_SOCKET is ready.
run_web_server &
```
