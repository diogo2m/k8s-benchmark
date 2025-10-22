package main

import (
	"fmt"
	"net"
	"time"
	"strings"
)

func getGremioPosition() string {
	return "12"
}

func main() {
	addr, _ := net.ResolveUDPAddr("udp", ":9999")
	conn, _ := net.ListenUDP("udp", addr)
	defer conn.Close()
	fmt.Println("Listening on UDP port 9999...")

	buf := make([]byte, 1024)
	for {
		n, clientAddr, _ := conn.ReadFromUDP(buf)
		data := string(buf[:n])

		if strings.HasPrefix(data, "GET") {
			now := time.Now().Format("2006-01-02 15:04:05")
			position := getGremioPosition()
			body := fmt.Sprintf("Datetime: %s\nGrêmio's position: %s", now, position)

			response := fmt.Sprintf("HTTP/1.1 200 OK\r\nContent-Length: %d\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n%s", len(body), body)
			conn.WriteToUDP([]byte(response), clientAddr)
		}
	}
}

