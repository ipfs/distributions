#!/bin/bash

set -eo pipefail

# go-ipfs was renamed to kubo
# this  script provides stub builds that point package managers
# at new name
#
# Usage in Makefile is drop-in replacement for build-go.sh:
# build-from-kubo.sh "${relpath}" "${distname}" "${repo}" "${package}" "${versions}"

# path to the root of ipfs/distributions repo
rootpath="$(realpath "$1")"

distname="$2"
repo="$3"
package="$4"
versions="$5"

# import utility functions and variables from regular go build	script
source "${rootpath}/build-go.sh"

# override build step.
function goBuild() {
	local package="$1"
	local goos="$2"
	local goarch="$3"
	(
	rm -rf ""
	# Replace 'ipfs' with a minimal Go program that provides a gentle way of informing
	# package managers they should update.
	cat > "main.go" <<EOF
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "the name 'go-ipfs' is no longer used. please update your package manager scripts to 'kubo' and download from https://dist.ipfs.tech/kubo/ instead.")
	os.Exit(1)
}
EOF
		export GOOS="$goos"
		if [[ "$goarch" == amd64-* ]]; then
			IFS="-" read -ra arr <<< "$goarch"
			export GOARCH="${arr[0]}"
			export GOAMD64="${arr[1]}"
		else
			export GOARCH="$goarch"
		fi

		local output
		output="$(pwd)/$(basename "$package")$(go env GOEXE)"
		if ! (GO111MODULE=off go build -o "$output" main.go); then
			warn "    go build of $output failed."
			return 1
		fi
	)
}

# swap sources as well, because package managers may use them to build own binaries
function buildSource() {
	local distname="$1"
	local repopath="$2"
	local output="$3"
	local target="$distname-source.tar.gz"

	tmp=$(mktemp -d)
	echo "the name 'go-ipfs' is no longer used. please update your package manager scripts to 'kubo' and download from https://dist.ipfs.tech/kubo/ instead" > "$tmp/README.txt"
	tar -czf "$output/$target" -C "$tmp" README.txt
	rm -rf "$tmp"

	# Calculate sha512 and write it to .sha512 file
	local linksha512 linkcid
	sha512sum "$output/$target" | awk "{gsub(\"${output}/\", \"\");print}" > "$output/$target.sha512"
	linksha512=$(awk '{ print $1 }' < "$output/$target.sha512")
	# Calculate CID and write it to .cid file
	ipfs add --only-hash -Q "$output/$target" > "$output/$target.cid"
	linkcid=$(< "$output/$target.cid")

	cp dist.json dist.json.temp
	jq ".source = {\"link\": \"/$target\",\"cid\":\"$linkcid\",\"sha512\":\"$linksha512\"}" < dist.json.temp > dist.json
	rm dist.json.temp
}

# run unmodified logic from build-go.sh
startGoBuilds "${distname}" "${repo}" "${package}" "${versions}"
# vim: ts=4:noet
