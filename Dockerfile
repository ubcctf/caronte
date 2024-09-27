# Build backend with go
FROM golang:1.20 AS backend_builder

# Install tools and libraries
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -qq \
	git \
	pkg-config \
	libpcap-dev \
	libhyperscan-dev
WORKDIR /caronte
COPY . ./
RUN go mod download
RUN export VERSION=$(git describe --tags --abbrev=0) && \
    go build -ldflags "-X main.Version=$VERSION" && \
	mkdir -p build && \
	cp -r caronte pcaps/ scripts/ shared/ test_data/ build/

# Build frontend via yarn
FROM node:16 AS frontend_builder
ENV PNPM_VERSION 8.3.1
RUN npm install -g pnpm@${PNPM_VERSION}
WORKDIR /caronte-frontend

# pnpm fetch does require only lockfile
# COPY ./frontend/pnpm-lock.yaml ./
# RUN pnpm fetch --prod

COPY ./frontend ./
RUN pnpm install && pnpm build

# LAST STAGE
FROM ubuntu:22.04
COPY --from=backend_builder /caronte/build /opt/caronte
COPY --from=frontend_builder /caronte-frontend/build /opt/caronte/frontend/build
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -qq \
	libpcap-dev \
	libhyperscan-dev && \
	rm -rf /var/lib/apt/lists/*
ENV GIN_MODE release
ENV MONGO_HOST mongo
ENV MONGO_PORT 27017
WORKDIR /opt/caronte
ENTRYPOINT ./caronte -mongo-host ${MONGO_HOST} -mongo-port ${MONGO_PORT} -assembly_memuse_log
