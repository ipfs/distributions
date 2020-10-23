#!/bin/bash

tagsForRepo() {
	local repo="$1"
	git ls-remote -t --refs https://"$repo" | grep -E -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | grep -v "-"
}

sedEscapeArg() {
	echo "$@" | sed 's/\//\\\//g'
}

case $1 in
	new-go-dist)
		name="$2"
		repo="$3"
		if [ -z "$name" ] || [ -z "$repo" ]; then
			echo "usage: dist.sh new-go-dist <distname> <repo>"
			exit 1
		fi

		if [ -d "dists/$name" ]; then
			echo "a distribution named $name already exists"
			exit 1
		fi

		echo "enter a description for this package"
		read -r description
		latest_tag=$(tagsForRepo "$repo" | tail -n1)
		echo "detected $latest_tag as the current version."
		echo "press enter to confirm, or type the correct version"
		read -r actual_latest
		if [ -n "$actual_latest" ]; then
			latest_tag=$actual_latest
		fi

		echo "choosing $latest_tag as current version of $name"
		mkdir -p "dists/$name"

		cp templates/build_matrix "dists/$name/"
		sed "s/ABCGHREPOXYZ/$(sedEscapeArg "$repo")/g" templates/Makefile | sed "s/ABCDISTNAMEXYZ/$name/g" > "dists/$name/Makefile"
		echo "$description" > "dists/$name/description"
		echo "$latest_tag" > "dists/$name/current"
		echo "$latest_tag" > "dists/$name/versions"
		echo "" > "dists/$name/filtered_versions"

		echo "distribution $name created successfully! starting build..."

		make "$name"
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
			*) echo "$nvers" > "dists/$dist/current" ;;
		esac

		echo "$nvers" >> "dists/$dist/versions"

		# cd "dists/$dist" && make update_sources
		# build-go will update sources as needed
		cd "dists/$dist" && make
		;;
	*)
		echo "unrecognized command $1"
		echo "Commands:"
		echo "  add-version <dist> <version>"
		echo "  new-go-dist <name> <repo>"
		exit 1
		;;
esac
