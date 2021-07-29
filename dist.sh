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

# Adapted from https://stackoverflow.com/a/44660519/702738
compare_version() {
	if [[ $1 == $2 ]]; then
		return 0
	fi
	local IFS=.
	local i a=(${1%%[^0-9.]*}) b=(${2%%[^0-9.]*})
	local arem=${1#${1%%[^0-9.]*}} brem=${2#${2%%[^0-9.]*}}
	for ((i=0; i<${#a[@]} || i<${#b[@]}; i++)); do
		if ((10#${a[i]:-0} < 10#${b[i]:-0})); then
				return 1
		elif ((10#${a[i]:-0} > 10#${b[i]:-0})); then
				return 0
		fi
	done
	if [ "$arem" '<' "$brem" ]; then
		return 1
	elif [ "$arem" '>' "$brem" ]; then
		return 0
	fi
	return 1
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
		sed "s/github.com\/foo\/bar/$(sedEscapeArg "$repo")/g" templates/Makefile | sed "s/cmd\/bar/$subpkg/g" > "dists/$name/Makefile"
		echo "$description" > "dists/$name/description"
		echo "$version" > "dists/$name/current"
		echo "$version" > "dists/$name/versions"

		# Create vtag file that contains version tag prefix
		if [ "$tag_prefix" != "." ]; then
			echo "$tag_prefix" > "dists/$name/vtag"
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

		# Test if the new version is greater than the current version.
		test_version() {
			current_version=$([ -f "dists/$dist/current" ] && cat "dists/$dist/current" | sed "s/v//")
			new_version=$(echo $nvers | sed "s/v//")

			if compare_version "$current_version" "$new_version"; then
				echo "ERROR: The version provided ($new_version) has to be greater than the current release ($current_version)."
				exit 1
			fi
		}

		case "$nvers" in
			*-*) test_version && echo "WARNING: not marking pre-release $dist $nvers as the current version." ;;
			*) test_version && echo "$nvers" > "dists/$dist/current" ;;
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
