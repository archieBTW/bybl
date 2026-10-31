# ==============================================================================
# bybl Backend Runtime Container
# Binary is pre-compiled locally with Go 1.27 to eliminate server CPU/RAM load
# ==============================================================================
FROM debian:bookworm-slim

# Install CA certificates for outbound HTTPS requests (Bible APIs, S3, Resend)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy pre-compiled Go binary (built locally with Go 1.27)
COPY Backend/main .

# Create uploads directory for local media storage and ensure binary is executable
RUN mkdir -p /app/uploads && chmod +x /app/main

EXPOSE 8080 8081

CMD ["./main"]
