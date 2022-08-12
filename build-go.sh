#!/bin/bash

set -eo pipefail

# settings
GOPATH="$(go env GOPATH)"
export GOPATH

# Always use go modules
export GO111MODULE=on

# Content path to use when looking for pre-existing release data
DIST_ROOT=$(ipfs resolve "${DIST_ROOT:-/ipns/dist.ipfs.tech}")

# normalize umask
umask 022

# globals
releases=../../releases

# init colors
txtnon='\e[0m'    # color reset
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow

if which sha512sum >/dev/null 2>&1; then
	:
elif which shasum >/dev/null 2>&1; then
	function sha512sum() {
		shasum -a 512 "$@"
	}
fi

function fail() {
	printf "$txtred%s$txtnon\n" "$@"
	exit 1
}

function warn() {
	printf "$txtylw%s$txtnon\n" "$@"
}

function notice() {
	printf "$txtgrn%s$txtnon\n" "$@"
}

# dep checks
reqbins="jq zip unzip tar go npm"
for b in $reqbins
do
	if ! type "$b" > /dev/null; then
		fail "must have '$b' installed"
	fi
done

function pkgType() {
	os=$1
	case $os in
	windows)
		echo "zip"
		;;
	*)
		echo "tar.gz"
		;;
	esac
}

function buildDistInfo() {
	local bundle="$1"
	local dir="$2"

	# print json output
	if ! jq -e ".platforms[\"$goos\"]" < dist.json > /dev/null; then
		cp dist.json dist.json.temp
		jq ".platforms[\"$goos\"] = {\"name\":\"$goos Binary\",\"archs\":{}}" < dist.json.temp > dist.json
	fi

	local linkname linksha512 linkcid

	linkname="$bundle.$(pkgType "$goos")"
	# Calculate sha512 and write it to .sha512 file
	sha512sum "$dir/$linkname" | awk "{gsub(\"${dir}/\", \"\");print}" > "$dir/$linkname.sha512"
	linksha512=$(awk '{ print $1 }' < "$dir/$linkname.sha512")
	# Calculate CID and write it to .cid file
	ipfs add --only-hash -Q "$dir/$linkname" > "$dir/$linkname.cid"
	linkcid=$(< "$dir/$linkname.cid")
	cp dist.json dist.json.temp
	jq ".platforms[\"$goos\"].archs[\"$goarch\"] = {\"link\":\"/$linkname\",\"cid\":\"$linkcid\",\"sha512\":\"$linksha512\"}" < dist.json.temp > dist.json
	rm dist.json.temp
}

function goBuild() {
	local package="$1"
	local goos="$2"
	local goarch="$3"
	(
		export GOOS="$goos"
		export GOARCH="$goarch"

		local output
		output="$(pwd)/$(basename "$package")$(go env GOEXE)"
		go build -mod=mod -o "$output" \
			-trimpath \
			"${package}"

		if [ -x "$(which glibc-check)" ] && [ "$GOOS" == "linux" ] && [ "$GOARCH" == "amd64" ]; then
			echo "GLIBC versions:"
			glibc-check list-versions "$output"
			glibc-check assert-all 'major == 2 && minor < 32' "$output"
		fi
	)
}

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

	echo "==> building for $goos $goarch"

	if [ -e "$dir/$binname" ]; then
		echo "    $dir/$binname exists, skipping build"
		return
	fi
	echo "    output to $dir/$binname"

	local build_dir_name=$name
	mkdir -p "$build_dir_name"

	mkdir -p "$dir"

	if ! (cd "$build_dir_name" && goBuild "$package" "$goos" "$goarch") > build-log; then
		local logfi="$dir/build-log-$goos-$goarch"
		cp "$build_dir_name/build-log" "$logfi"
		warn "    $binname failed. logfile at '$logfi'"
		return 1
	fi

	# copy dist assets if they exist
	if [ -e "$GOPATH/src/$package/dist" ]; then
		cp -r "$GOPATH/src/$package/dist/"* "$build_dir_name/"
	fi

	# now package it all up
	if bundleDist "$dir/$binname" "$goos" "$build_dir_name"; then
		buildDistInfo "$binname" "$dir"
		rm -rf "$build_dir_name"
		notice "    build $binname succeeded!"
	else
		warn "    failed to build $binname"
		success=1
	fi


	# output results to results table
	echo "$target, $goos, $goarch, $success" >> "$output/results"
}

function bundleDist() {
	local name=$1
	local os=$2
	local build_dir=$3

	test -n "$build_dir" || fail "must specify dir to bundle!"

	case $(pkgType "$os") in
	zip)
		zip -r "$name.zip" "$build_dir"/* > /dev/null
		return $?
		;;
	tar.gz)
		tar czf "$name.tar.gz" "$build_dir"/*
		return $?
		;;
	esac

	fail "unrecognized package type"
}

function printInitialDistfile() {
	local distname=$1
	local version=$2
	test -e description || fail "no description file found"

	local reponame="$distname"
	if [ -e repo-name ]; then
		reponame=$(cat repo-name)
	fi

  jq . <<EOF
{
  "id": "$reponame",
  "version": "$version",
  "releaseLink": "$distname/$version",
  "name": "$distname",
  "owner": "$(< repo-owner)",
  "description": "$(< description)",
  "date": "$(date -u '+%B %d, %Y')",
  "platforms": {}
}
EOF
}

function printBuildInfo() {
	# print out build information
	local commit=$1
	go version
	echo "git sha of code: $commit"
	uname -a
	echo "built on $(date -u)"
}

function buildWithMatrix() {
	local matfile=$1
	local package=$2
	local output=$3
	local commit=$4
	local buildVersion=$5

	test -n "$output" || fail "error: output dir not specified"
	test -e "$matfile" || fail "build matrix $matfile does not exist"

	mkdir -p "$output"

	local distname
	distname=$(basename "$(pwd)")

	printInitialDistfile "$distname" "$buildVersion" > dist.json
	printBuildInfo "$commit" > "$output/build-info"

	# build each os/arch combo
	while read -r goos goarch
	do
		doBuild "$goos" "$goarch" "$package" "$output" "$buildVersion"
	done < "$matfile"

	# build the source
	buildSource "$distname" "$GOPATH/src/$package" "$output"

	mv dist.json "$output/dist.json"
}

function cleanRepo() {
	local repopath=$1

	git -C "$repopath" clean -df
	git -C "$repopath" reset --hard
}

function nightlyRevision() {
	local repopath=$1
	local version=$2

	# Use default branch, may be master, main or some other name
	default_branch="$(git -C "$repopath" symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
	# Find the last commit before nightly cut-off
	cutoff_date="${version#nightly-}"
	git -C "$repopath" rev-list -1 --first-parent --before="$cutoff_date" "$default_branch"
}

function checkoutVersion() {
	local repopath=$1
	local version=$2

	test -n "$repopath" || fail "checkoutVersion: no repo to check out specified"

	case $version in
	nightly*)
		ref="$(nightlyRevision "$repopath" "$version")"
		;;
	*)
		ref=$version

		# If there is a vtag, then checkout using <vtag>/<version>
		# ('vtag' file is used for indicating 'submodule'
		# such as 'fs-repo-migrations/fs-repo-0-to-1',
		# those have release tags like 'fs-repo-0-to-1/v1.0.0')
		if [ -e vtag ]; then
			ref="$(cat vtag)/${version}"
		fi
		;;
	esac

	echo "==> checking out version $version (git: $ref) in $repopath"
	cleanRepo "$repopath"

	git -C "$repopath" checkout "$ref" > /dev/null || fail "failed to check out $ref in $reporoot"
}

function installDeps() {
	local repopath=$1

	reporoot=$(git -C "$repopath" rev-parse --show-toplevel)

	if make -C "$reporoot" -n deps > /dev/null 2>&1; then
		make -C "$reporoot" deps
	fi
}

function buildSource() {
	local distname="$1"
	local repopath="$2"
	local output="$3"
	local target="$distname-source.tar.gz"

	reporoot=$(git -C "$repopath" rev-parse --show-toplevel)

	if ! make -C "$reporoot" -n "$target" > /dev/null 2>&1; then
		# Nothing to do, fail silently.
		return 0
	fi

	make -C "$reporoot" "$target"

	cp "$reporoot/$target" "$output"

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

function currentSha() {
	git -C "$1" rev-parse HEAD
}

function printVersions() {
	local versions="$1"
	versarr=$(tr "\n" ' ' <<< "$versions")
	notice "building versions: $versarr"
}

function startGoBuilds() {
	distname="$1"
	repo="$2"
	package="$3"
	versions="$4"
	existing="$6"

	if [ ! -e "$versions" ]; then
		fail "versions file $versions does not exist"
	fi

	if ! mkdir -p "$releases"; then
		fail "failed to create releases directory"
	fi

	if [ -z "$existing" ]; then
		existing="$DIST_ROOT"
	fi

	echo "comparing $versions with $existing/$distname/versions"

	existingVersions=$(mktemp)
	ipfs cat "$existing/$distname/versions" > "$existingVersions" || touch "$existingVersions"

	newVersions=$(comm --nocheck-order -13 "$existingVersions" "$versions")

	if [ -z "$newVersions" ]; then
		notice "skipping $distname - all versions published at $existing"
		return
	fi
	printVersions "$newVersions"

	outputDir="$releases/$distname"

	# if the output directory already exists, warn user
	if [ -e "$outputDir" ]; then
		warn "dirty output directory"
		warn "will skip building already existing binaries"
		warn "to perform a fresh build, please delete $outputDir"
	fi

	export GOPATH
	GOPATH="$(pwd)/gopath"
	repopath="$GOPATH/src/$repo"

	if [ ! -e "$repopath/$package" ]; then
		echo "fetching $distname code..."
		git clone "https://$repo" "$repopath"
	fi

	cleanRepo "$repopath"
	git -C "$repopath" fetch

	while read -r version
	do
		outputVersion=$outputDir/$version

		if [ -e "$outputVersion" ]; then
			echo "$version already exists, skipping..."
			continue
		fi

		case $version in
		nightly*)
			buildVersion="$version-$(nightlyRevision "$repopath" "$version" | head -c 7)"
			;;
		*)
			buildVersion=$version
			;;
		esac

		notice "building version $version binaries"
		checkoutVersion "$repopath" "$version"
		installDeps "$repopath" > "deps-$version.log" 2>&1

		matfile="matrices/$version"
		if [ ! -e "$matfile" ]; then
			if [ -e build_matrix ]; then
				matfile=build_matrix
			else
				fail "no matrix file for version $version found, and no 'build_matrix' detected"
			fi
		fi

		rm -f "go.mod"
		if [ "$GO111MODULE" == "on" ]; then
		    # Setup version information so we can build with go mod
		    go mod init "ipfs-distributions"
		    go mod edit -require "$repo@$(git -C "$repopath" rev-parse HEAD)"
		fi

		buildWithMatrix "$matfile" "$repo/$package" "$outputVersion" "$(currentSha "$repopath")" "$buildVersion"
		echo ""
	done <<< "$newVersions"

	# Keep all tagged versions from repo
	grep -v ^nightly "$versions" > "$outputDir/versions"

	# Additional cleanup/normalization for nightly builds
	if grep -h ^nightly "$versions" "$existingVersions" > /dev/null; then
		# Keep at most 7 nightly versions
		grep -h ^nightly "$versions" "$existingVersions" | sort -ur | head -n7 >> "$outputDir/versions"
	fi

	notice "build complete!"
}

# Execute only when called directly (allows for sourcing)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
startGoBuilds "$1" "$2" "$3" "$4" "$5"
fi

# vim: ts=4:noet
