# Build backend
FROM golang:1.23 AS backend-builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main .

# Final stage
FROM debian:bookworm-slim

# 🛠️ Install CA certs to fix TLS errors
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=backend-builder /app/main .

EXPOSE 8080
CMD ["./main"]

