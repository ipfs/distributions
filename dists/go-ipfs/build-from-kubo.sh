#!/bin/bash

set -eo pipefail

# This script replaces go build with repackaging of existing 'kubo' binaries
# - go-ipfs is the old name of kubo, and we provide it for legacy reasons
# - this script assumes kubo artifacts were built recently and are still
#   in local "releases/kubo/${version}" - this is ok because nobody will build
#   go-ipfs on their own, only kubo, and go-ipfs build happens automatically
#   when someone adds new kubo release with './dist add-release kubo <version>'

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
# goBuild is skipped and we replaced it with repackaging of existing kubo artifacts
# this way we build everything only once
function doBuild() {
	local goos=$1
	local goarch=$2
	local package=$3
	local output=$4
	local version=$5

	local dir name binname

	dir="$output"
	name="$(basename "$(pwd)")"
	binname="${name}_${version}_${goos}-${goarch}"

	# local dir with just recently built kubo release
	# that will be repackaged under go-ipfs name
	kuboreleasedir="${rootpath}/releases/kubo/${version}"
	kubobinname="kubo_${version}_${goos}-${goarch}"

	echo "==> repackaging kubo to go-ipfs for $goos $goarch"

	if [ -e "$dir/$binname" ]; then
		echo "	  $dir/$binname exists, skipping build"
		return
	fi
	echo "	  output to $dir/$binname"

	local build_dir_name=$name
	mkdir -p "$dir"

	# unpack kubo package (it produces 'kubo/ipfs[.exe]')
	case $(pkgType "$goos") in
	zip)
		unzip -oq "${kuboreleasedir}/${kubobinname}.zip"
		;;
	tar.gz)
		tar xf "${kuboreleasedir}/${kubobinname}.tar.gz"
		;;
	esac

	# remove any stale unpacked data
	rm -rf "$build_dir_name"

	# rename extracted directory to match name expected by build scripts (go-ipfs)
	mv "kubo" "$build_dir_name"

	# now (re)package it all up
	if bundleDist "$dir/$binname" "$goos" "$build_dir_name"; then
		buildDistInfo "$binname" "$dir"
		rm -rf "$build_dir_name"
		notice "	repackaging of $binname succeeded!"
	else
		fail "	  failed to repackage $binname"
		success=1
	fi

	notice "	$goos $goarch repackaging succeeded!"

	# output results to results table
	echo "$target, $goos, $goarch, $success" >> "$output/results"
}

# run unmodified logic from build-go.sh
startGoBuilds "${distname}" "${repo}" "${package}" "${versions}"
# vim: ts=4:noet
