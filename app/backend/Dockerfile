FROM golang:1.27-alpine AS builder

WORKDIR /build

RUN apk add --no-cache git ca-certificates


COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /workup-backend ./cmd/server

FROM alpine:3.20

RUN apk add --no-cache ca-certificates

RUN addgroup -g 1000 workup && adduser -u 1000 -G workup -D workup

WORKDIR /app

COPY --from=builder /workup-backend /app/workup-backend

RUN chown -R workup:workup /app

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1

ENTRYPOINT ["/app/workup-backend"]
