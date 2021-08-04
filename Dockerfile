FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
ARG USER_UID

ARG GO_IPFS_VER
RUN apt-get update -q && apt-get install -y git curl gnupg jq build-essential gawk zip tzdata && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata
RUN curl -s "https://dist.ipfs.io/go-ipfs/${GO_IPFS_VER}/go-ipfs_${GO_IPFS_VER}_linux-amd64.tar.gz" | tar vzx -C /usr/local/bin/ go-ipfs/ipfs --strip-components=1

RUN adduser --shell /bin/bash --home /asdf --disabled-password --gecos asdf asdf --uid $USER_UID
ENV PATH="${PATH}:/asdf/.asdf/shims:/asdf/.asdf/bin"

USER asdf
WORKDIR /asdf

RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git $HOME/.asdf && \
    echo '. $HOME/.asdf/asdf.sh' >> $HOME/.bashrc && \
    echo '. $HOME/.asdf/asdf.sh' >> $HOME/.profile 

RUN asdf plugin-add golang 
RUN asdf plugin-add nodejs
ADD .tool-versions .

RUN asdf install 

ENV IPFS_PATH=/asdf/.ipfs
RUN mkdir -p ${IPFS_PATH} && echo "/ip4/127.0.0.1/tcp/5001" > ${IPFS_PATH}/api

ARG CACHEBUST=undefined
USER root
RUN apt-get update && apt-get -y upgrade

USER asdf
WORKDIR /build
