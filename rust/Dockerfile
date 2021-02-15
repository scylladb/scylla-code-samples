FROM rust:alpine

COPY ps-logger/ /app/ps-logger
RUN apk add musl-dev
RUN cd /app/ps-logger && cargo build

CMD ["/app/ps-logger/target/debug/test-cdrs"]
