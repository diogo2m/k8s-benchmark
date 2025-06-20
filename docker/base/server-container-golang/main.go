package main

import (
	"fmt"
	"net"
	"time"
	"strings"
	"io/ioutil"
	"net/http"
)

const URL = "https://www.api-futebol.com.br/campeonato/campeonato-brasileiro/2025"

func getGremioPosition() string {
        return "12"
	resp, err := http.Get(URL)
	if err != nil || resp.StatusCode != 200 {
		return "Error fetching data"
	}
	defer resp.Body.Close()
	body, _ := ioutil.ReadAll(resp.Body)
	text := string(body)

	start := strings.Index(text, "Grêmio")
	if start == -1 {
		return "Not found"
	}
	sub := text[start-30 : start]
	posStart := strings.LastIndex(sub, "<td>") + 4
	posEnd := strings.Index(sub[posStart:], "</td>")
	if posStart != -1 && posEnd != -1 {
		return sub[posStart : posStart+posEnd]
	}
	return "Unknown"
}

func handleConnection(conn net.Conn) {
	buf := make([]byte, 1024)
	conn.Read(buf)

	if strings.HasPrefix(string(buf), "GET") {
		now := time.Now().Format("2006-01-02 15:04:05")
		position := getGremioPosition()
		body := fmt.Sprintf("Datetime: %s\nGrêmio's position: %s", now, position)

		response := fmt.Sprintf("HTTP/1.1 200 OK\r\nContent-Length: %d\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n%s", len(body), body)
		conn.Write([]byte(response))
	}
	conn.Close()
}

func main() {
	ln, _ := net.Listen("tcp", ":9999")
	fmt.Println("Listening on port 9999...")
	for {
		conn, _ := ln.Accept()
		go handleConnection(conn)
	}
}
