FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ARG USER_UID

ARG KUBO_VER
RUN apt-get update -q && apt-get install -y git curl gnupg jq build-essential gawk zip tzdata && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

RUN curl -sS --retry 5 \
    "https://dist.ipfs.tech/kubo/${KUBO_VER}/kubo_${KUBO_VER}_linux-amd64.tar.gz" -o /tmp/kubo.tar.gz && \
    tar vzx -f /tmp/kubo.tar.gz -C /usr/local/bin/ kubo/ipfs --strip-components=1

ARG ASDF_VERSION=v0.18.1
RUN curl -sS --retry 5 \
    "https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin asdf

RUN adduser --shell /bin/bash --home /asdf --disabled-password --gecos asdf asdf --uid $USER_UID
ENV ASDF_DATA_DIR=/asdf/.asdf
ENV PATH="${PATH}:/asdf/.asdf/shims"

USER asdf
WORKDIR /asdf

RUN asdf plugin add golang
RUN asdf plugin add nodejs
ADD .tool-versions .

RUN asdf install

ENV IPFS_PATH=/asdf/.ipfs
RUN mkdir -p ${IPFS_PATH} && echo "/ip4/127.0.0.1/tcp/5001" > ${IPFS_PATH}/api

RUN go install github.com/guseggert/glibc-check/cmd/glibc-check@v0.0.0-20211130152056-cb76aed949fd && asdf reshim

ARG CACHEBUST=undefined
USER root
RUN apt-get update && apt-get -y upgrade

USER asdf
WORKDIR /build
