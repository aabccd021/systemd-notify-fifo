package main

import (
	"flag"
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
	readyPath := flag.String("ready", "", "Path to the ready file")
	outPath := flag.String("out", "", "Path to the pipe file")
	flag.Parse()

	if *outPath == "" {
		log.Fatal("Usage: server -out /path/to/pipe")
	}

	notifySocket := os.Getenv("NOTIFY_SOCKET")
	if !filepath.IsAbs(notifySocket) {
		log.Fatalf("NOTIFY_SOCKET must be an absolute path, otherwise systemd-notify will throw Protocol error")
	}

	err := syscall.Mkfifo(*outPath, 0666)
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

	if *readyPath != "" {
		if err := write(*readyPath, []byte{}); err != nil {
			log.Fatalf("Ready path is not writable: %v", err)
		}
	}

	buf := make([]byte, 65536)
	for {
		n, _, err := conn.ReadFromUnix(buf)
		if err != nil {
			log.Fatalf("Error reading from socket: %v", err)
			continue
		}

		if err := write(*outPath, buf[:n]); err != nil {
			log.Fatalf("Error writing to pipe: %v", err)
			continue
		}
	}
}
