#!/bin/bash

# constants
gpath="github.com/ipfs/go-ipfs/cmd/ipfs"
build="../../build/go-ipfs"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <version>"
  echo "construct the go-ipfs dist directory for given version"
  echo ""
  exit 1
fi

die() {
  echo >&2 "error: $@"
  exit 1
}

# get version from input
version=$1

# check version is ok
cat versions | grep "$version" || die "please run: make versions"

# check we have things installed
bin/gobuilder-cli -h  >/dev/null || die "please run: make deps"
ipfs -h  >/dev/null || die "please install ipfs"

# check the ipfs daemon is running
ipfs swarm peers >/dev/null || die "please run: ipfs daemon"

# variables
dest_path="$build/$version"

# get archives from gobuilder
echo "---> preparing go-ipfs $version dist"
echo "---> getting archives from gobuilder..."
bin/gobuilder-cli get-all "$gpath" "$dest_path" "$version"

# get OSX installer (TODO)
# echo "---> building OSX installer..."

# generate hashes file
cwd=`pwd`
cd "$dest_path"
ipfs add --only-hash * >hashes
cd "$cwd"
