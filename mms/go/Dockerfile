# Build the manager binary
FROM golang:1.13 as builder

COPY . /build
WORKDIR /build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o /build/goapp ./cmd/goapp
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o /build/goappp ./cmd/goappp
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o /build/godatatypes ./cmd/godatatypes
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -o /build/gocqlxapp ./cmd/gocqlxapp

FROM alpine:3.10

COPY --from=builder /build/goapp /usr/local/bin/goapp
RUN chmod +x /usr/local/bin/goapp
COPY --from=builder /build/goappp /usr/local/bin/goappp
RUN chmod +x /usr/local/bin/goappp
RUN mkdir -p /usr/share/icons/mms
COPY --from=builder /build/cmd/godatatypes/*.jpg /usr/share/icons/mms/
COPY --from=builder /build/godatatypes /usr/local/bin/godatatypes
RUN chmod +x /usr/local/bin/godatatypes
COPY --from=builder /build/gocqlxapp /usr/local/bin/gocqlxapp
RUN chmod +x /usr/local/bin/gocqlxapp

CMD tail -f /dev/null
