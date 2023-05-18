#!/bin/bash

tagsForRepo() {
	local repo="$1"
	git ls-remote -t --refs https://"$repo" | grep -E -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | grep -v "-"
}

tagsForSubpkg() {
	local repo="$1"
	local subpkg="$2"
	git ls-remote -t --refs https://"$repo" | grep -E -o "refs/tags/$subpkg/v(.*)" | sed 's/refs\/tags\///' | grep -v "-"
}

sedEscapeArg() {
	echo "$@" | sed 's/\//\\\//g'
}

case $1 in
	new-go-dist)
		name="$2"
		repo="$3"
		subpkg="$4"
		if [ -z "$name" ] || [ -z "$repo" ]; then
			echo "usage: dist.sh new-go-dist <distname> <repo> [<sub-package>]"
			exit 1
		fi

		if [ -d "dists/$name" ]; then
			echo "a distribution named $name already exists"
			exit 1
		fi

		echo "enter a description for this package"
		read -r description
		latest_tag=$(tagsForSubpkg "$repo" "$subpkg" | tail -n1)
		if [ -z "$latest_tag" ]; then
			latest_tag=$(tagsForRepo "$repo" | tail -n1)
		fi
		echo "detected $latest_tag as the current version."
		echo "press enter to confirm, or type the correct version"
		read -r actual_latest
		if [ -n "$actual_latest" ]; then
			latest_tag=$actual_latest
		fi

		echo "choosing $latest_tag as current version of $name"
		mkdir -p "dists/$name"

		# If latest_tag is a sub-package tag (e.g. "fs-repo-1-to-2/v1.0.0") then get parts
		version="$(basename "$latest_tag")"
		tag_prefix="$(dirname "$latest_tag")"

		cp templates/build_matrix "dists/$name/"
		sed "s/github.com\/foo\/bar/$(sedEscapeArg "$repo")/g" templates/Makefile | sed "s/cmd\/bar/$(sedEscapeArg "$subpkg")/g" > "dists/$name/Makefile"
		echo "$description" > "dists/$name/description"
		echo "$version" > "dists/$name/current"
		echo "$version" > "dists/$name/versions"

		# Create vtag file that contains version tag prefix
		if [ "$tag_prefix" != "." ]; then
			echo "$tag_prefix" > "dists/${name}/vtag"
		fi

		echo "distribution $name created successfully! To start build: make $name"
		;;
	add-version)
		dist="$2"
		nvers="$3"

		if [ -z "$dist" ] || [ -z "$nvers" ]; then
			echo "usage: dist.sh add-version <dist> <version>"
			exit 1
		fi

		case "$nvers" in
			*-*) echo "WARNING: not marking pre-release $dist $nvers as the current version." ;;
			nightly) nvers=$nvers-$(date -u '+%Y-%m-%d') ;;
			*) echo "$nvers" > "dists/$dist/current" ;;
		esac

		echo "$nvers" >> "dists/$dist/versions"

		# legacy go-ipfs dist needs to be created for every new kubo release:
		# https://github.com/ipfs/distributions/pull/717
		if [ "$dist" == "kubo" ]; then
			# use the same targets
			cat "dists/kubo/build_matrix" > "dists/go-ipfs/build_matrix"
			# make sure latest go-ipfs release follows kubo
			cat "dists/kubo/current" > "dists/go-ipfs/current"
			# make sure go-ipfs has all new kubo releases (one directional sync)
			newreleases="$(mktemp)"
			diff "dists/kubo/versions" "dists/go-ipfs/versions" | grep '^<' | awk '{print $2}' | uniq > "$newreleases"
			cat "$newreleases" >> "dists/go-ipfs/versions"
		fi

		# error on old kubo name
		if [ "$dist" == "go-ipfs" ]; then
			echo "ERROR: go-ipfs is now named kubo, use the new name:"
			echo
			echo "$ dist.sh add-version kubo <version>"
			echo
			echo "(a backward-compatible go-ipfs release will be added automatically)"
			exit 1
		fi

		# cd "dists/$dist" && make update_sources
		# build-go will update sources as needed
		if [ "$CI" == "true" ]; then
			cd "dists/$dist" && make
		fi
		;;
	*)
		echo "unrecognized command $1"
		echo "Commands:"
		echo "  add-version <dist> <version>"
		echo "  new-go-dist <name> <repo>"
		exit 1
		;;
esac
## vim: sts=4:ts=4:sw=4:noet
