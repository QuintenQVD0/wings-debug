# Stage 1 (Build)
FROM golang:1.24.7-alpine AS builder

ARG VERSION
RUN apk add --update --no-cache git make

# Install Delve (dlv) debugger
RUN go install github.com/go-delve/delve/cmd/dlv@latest

WORKDIR /app/
COPY go.mod go.sum /app/
RUN go mod download
COPY . /app/

# Build with debug flags (disable optimizations/inlining)
RUN CGO_ENABLED=0 go build \
    -gcflags="all=-N -l" \
    -ldflags="-X github.com/pelican-dev/wings/system.Version=$VERSION" \
    -o wings-debug \
    wings.go

RUN echo "ID=\"distroless\"" > /etc/os-release

# Stage 2 (Final Debug Image)
FROM alpine:3.22 AS debug

# copy os-release to make distroless-like base happy
COPY --from=builder /etc/os-release /etc/os-release

# Copy binary and dlv
COPY --from=builder /app/wings-debug /usr/bin/wings-debug
COPY --from=builder /go/bin/dlv /usr/bin/dlv

# Expose both the app and delve ports
EXPOSE 8080 40000

# Run wings under Delve in headless mode, waiting for remote debugger connection
# --listen=:40000 → Delve listens here for your IDE
# --api-version=2 → stable JSON-RPC protocol
# --headless → no interactive console
CMD ["dlv", "--listen=:40000", "--headless=true", "--api-version=2", "exec", "/usr/bin/wings-debug", "--", "--config", "/etc/pelican/config.yml"]
