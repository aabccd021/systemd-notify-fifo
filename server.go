package main

import (
	"fmt"
	"log"
	"net"
	"os"
	"path/filepath"
	"syscall"
)

func write(path string, data []byte) error {
	file, err := os.OpenFile(path, os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	_, err = file.Write(data)
	file.Close()
	return err
}

func main() {
	log.SetFlags(0)
	notifySocket := os.Getenv("NOTIFY_SOCKET")
	if !filepath.IsAbs(notifySocket) {
		log.Fatalf("NOTIFY_SOCKET must be an absolute path, otherwise systemd-notify will throw Protocol error")
	}

	ppid := os.Getppid()

	outPath := fmt.Sprintf("/tmp/%d-systemd-notify.fifo", ppid)
	err := syscall.Mkfifo(outPath, 0666)
	if err != nil {
		log.Fatalf("Failed to create pipe: %v", err)
	}

	conn, err := net.ListenUnixgram("unixgram", &net.UnixAddr{
		Name: notifySocket,
		Net:  "unixgram",
	})
	if err != nil {
		log.Fatalf("Failed to create Unix domain socket: %v", err)
	}
	defer conn.Close()

	readyPath := fmt.Sprintf("/tmp/%d-systemd-notify-server.fifo", ppid)
	if err := write(readyPath, []byte{}); err != nil {
		log.Fatalf("Ready path is not writable: %v", err)
	}

	buf := make([]byte, 65536)
	for {
		n, _, err := conn.ReadFromUnix(buf)
		if err != nil {
			log.Fatalf("Error reading from socket: %v", err)
			continue
		}

		if err := write(outPath, buf[:n]); err != nil {
			log.Fatalf("Error writing to pipe: %v", err)
			continue
		}
	}
}
