# Pinned intentionally. Do NOT bump the base image without revisiting
# build-go.sh's glibc-check assertion (`minor < 32`). Ubuntu 20.04 ships
# glibc 2.31, which caps CGO-linked linux/amd64 binaries at GLIBC_2.31
# symbols, keeping dist.ipfs.tech tarballs runnable on CentOS 7/RHEL 7,
# RHEL 8/9, Ubuntu 18.04/20.04, and Debian 10/11. Upgrading the base
# image is a user-facing compat break and must be announced in release
# notes. Revisit by 2026-08 (Debian 11 LTS EOL) to pick the next floor.
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ARG USER_UID

ARG KUBO_VER
RUN apt-get update -q \
    && apt-get install -y --no-install-recommends \
        ca-certificates git curl gnupg jq build-essential gawk zip unzip tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL --retry 5 \
    "https://github.com/ipfs/kubo/releases/download/${KUBO_VER}/kubo_${KUBO_VER}_linux-amd64.tar.gz" -o /tmp/kubo.tar.gz && \
    tar vzx -f /tmp/kubo.tar.gz -C /usr/local/bin/ kubo/ipfs --strip-components=1

ARG ASDF_VERSION=v0.18.1
RUN curl -fsSL --retry 5 \
    "https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin asdf

RUN adduser --shell /bin/bash --home /asdf --disabled-password --gecos asdf asdf --uid $USER_UID
ENV ASDF_DATA_DIR=/asdf/.asdf \
    PATH="${PATH}:/asdf/.asdf/shims"

USER asdf
WORKDIR /asdf

RUN asdf plugin add golang \
    && asdf plugin add nodejs
COPY .tool-versions .

RUN asdf install

ENV IPFS_PATH=/asdf/.ipfs
RUN mkdir -p ${IPFS_PATH} && echo "/ip4/127.0.0.1/tcp/5001" > ${IPFS_PATH}/api

RUN go install github.com/guseggert/glibc-check/cmd/glibc-check@v0.0.0-20211130152056-cb76aed949fd && asdf reshim

ARG CACHEBUST=undefined
USER root
RUN apt-get update && apt-get -y upgrade \
    && rm -rf /var/lib/apt/lists/*

USER asdf
WORKDIR /build
