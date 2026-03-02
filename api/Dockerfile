# 多阶段构建：编译 Go 再运行
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN go mod tidy && CGO_ENABLED=0 go build -o mop-api .

FROM alpine:3.18
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/mop-api .
# 默认数据目录（可挂卷）
ENV DB_PATH=/data/mop.db
EXPOSE 80
CMD ["./mop-api"]
