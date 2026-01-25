# Build frontend
FROM node:20 AS frontend-builder

WORKDIR /app/web
COPY web/package*.json ./
RUN npm install
COPY web/ .
RUN npm run build

# Build backend
FROM golang:1.21 AS backend-builder

WORKDIR /app
COPY Backend/go.mod Backend/go.sum ./
RUN go mod download
COPY Backend/ .
COPY web/ ./web
RUN go build -o main .

# Final stage
FROM debian:bullseye-slim

WORKDIR /app
COPY --from=frontend-builder /app/web/dist ./web/build
COPY --from=backend-builder /app/main .
COPY Backend/config.yaml .

EXPOSE 8080
CMD ["./main"] 