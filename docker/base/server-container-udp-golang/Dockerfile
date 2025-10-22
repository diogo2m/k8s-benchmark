FROM golang:1.20

WORKDIR /app

COPY main.go .

EXPOSE 9999/udp

RUN go mod init socket-server && \
    go mod tidy

RUN go build -o server .

CMD ["./server"]
