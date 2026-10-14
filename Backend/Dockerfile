# Build backend stage
FROM golang:1.24 AS backend-builder

WORKDIR /workspace

# Copy gofyr_admin dependency package
COPY gofyr_admin/ ./gofyr_admin/

# Copy Backend module files
COPY Backend/go.mod Backend/go.sum ./Backend/

WORKDIR /workspace/Backend
RUN go mod download

# Copy Backend source
COPY Backend/ .

# Build statically-linked binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/main .

# Runtime stage
FROM debian:bookworm-slim

# Install CA certificates for outbound HTTPS requests (Bible APIs, S3, Resend)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=backend-builder /app/main .

# Create uploads directory for local media storage
RUN mkdir -p /app/uploads

EXPOSE 8080 8081

CMD ["./main"]
