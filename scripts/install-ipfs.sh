#!/bin/bash

set -ex

IPFS_VERSION=$(curl -s https://dist.ipfs.io/go-ipfs/versions | tail -n 1)
IPFS_TAR=go-ipfs_${IPFS_VERSION}_linux-amd64.tar.gz
curl -sO "https://dist.ipfs.io/go-ipfs/$IPFS_VERSION/$IPFS_TAR"
curl -sO "https://dist.ipfs.io/go-ipfs/$IPFS_VERSION/$IPFS_TAR.sha512"
sha512sum -c "$IPFS_TAR.sha512"
tar xzf "$IPFS_TAR"
go-ipfs/install.sh
