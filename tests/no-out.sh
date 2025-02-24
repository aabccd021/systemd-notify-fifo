exit_code=0
systemd-notify-fifo-server 2>./actual.txt || exit_code=$?

if [ "$exit_code" -ne 1 ]; then
  echo "Expected: 1"
  echo "Got: $exit_code"
  exit 1
fi

echo "Usage: server -out /path/to/pipe" >expected.txt
diff --unified --color=always expected.txt actual.txt
