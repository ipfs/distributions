#!/bin/bash

set -eo pipefail

# settings
GOPATH="$(go env GOPATH)"
export GOPATH

# normalize umask
umask 022

# globals
releases=../../releases

# init colors
txtnon='\e[0m'    # color reset
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow

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
reqbins="jq zip tar go npm"
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
	if ! jq -e ".platforms[\"$goos\"]" dist.json > /dev/null; then
		cp dist.json dist.json.temp
		jq ".platforms[\"$goos\"] = {\"name\":\"$goos Binary\",\"archs\":{}}" dist.json.temp > dist.json
	fi

	local linkname linksha512 linkcid

	linkname="$bundle.$(pkgType "$goos")"
	# Calculate sha512 and write it to .sha512 file
	shasum -a 512 "$dir/$linkname" | awk "{gsub(\"${dir}/\", \"\");print}" > "$dir/$linkname.sha512"
	linksha512=$(awk '{ print $1 }' < "$dir/$linkname.sha512")
	# Calculate CID and write it to .cid file
	ipfs add --only-hash -Q "$dir/$linkname" > "$dir/$linkname.cid"
	linkcid=$(< "$dir/$linkname.cid")
	cp dist.json dist.json.temp
	jq ".platforms[\"$goos\"].archs[\"$goarch\"] = {\"link\":\"/$linkname\",\"cid\":\"$linkcid\",\"sha512\":\"$linksha512\"}" dist.json.temp > dist.json
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

      go build -o "$output" \
	 -trimpath \
	 "${package}"
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
		warn "    failed. logfile at '$logfi'"
		return 1
	fi

	notice "    $goos $goarch build succeeded!"

	# copy dist assets if they exist
	if [ -e "$GOPATH/src/$package/dist" ]; then
		cp -r "$GOPATH/src/$package/dist/"* "$build_dir_name/"
	fi

	# now package it all up
	if bundleDist "$dir/$binname" "$goos" "$build_dir_name"; then
		buildDistInfo "$binname" "$dir"
		rm -rf "$build_dir_name"
	else
		warn "    failed to zip up output"
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
  "date": "$(date '+%B %d, %Y')",
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
	echo "built on $(date)"
}

function buildWithMatrix() {
	local matfile=$1
	local package=$2
	local output=$3
	local commit=$4
	local version=$5

	test -n "$output" || fail "error: output dir not specified"
	test -e "$matfile" || fail "build matrix $matfile does not exist"

	mkdir -p "$output"

	local distname
  distname=$(basename "$(pwd)")

	printInitialDistfile "$distname" "$version" > dist.json
	printBuildInfo "$commit" > "$output/build-info"

	# build each os/arch combo
	while read -r goos goarch
	do
		doBuild "$goos" "$goarch" "$package" "$output" "$version"
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

function checkoutVersion() {
	local repopath=$1
	local ref=$2

	test -n "$repopath" || fail "checkoutVersion: no repo to check out specified"

	echo "==> checking out version $ref in $repopath"
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

function autoGoMod() {
	local repopath=$1
	if test -e "$(git -C "$repopath" rev-parse --show-toplevel)/go.mod"; then
		export GO111MODULE=on
	else
		export GO111MODULE=off
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
	shasum -a 512 "$output/$target" | awk "{gsub(\"${output}/\", \"\");print}" > "$output/$target.sha512"
	linksha512=$(awk '{ print $1 }' < "$output/$target.sha512")
	# Calculate CID and write it to .cid file
	ipfs add --only-hash -Q "$output/$target" > "$output/$target.cid"
	linkcid=$(< "$output/$target.cid")

	cp dist.json dist.json.temp
	jq ".source = {\"link\": \"/$target\",\"cid\":\"$linkcid\",\"sha512\":\"$linksha512\"}" dist.json.temp > dist.json
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
	existing="$5"

	if [ ! -e "$versions" ]; then
		fail "versions file $versions does not exist"
	fi

	if ! mkdir -p "$releases"; then
		fail "failed to create releases directory"
	fi

	if [ -z "$existing" ]; then
		existing="/ipns/dist.ipfs.io"
	fi

	echo "comparing $versions with $existing/$distname/versions"
	newVersions=$(comm -13 <(ipfs cat "$existing/$distname/versions") "$versions")

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
		if [ -e "$outputDir/$version" ]; then
			echo "$version already exists, skipping..."
			continue
		fi

		notice "building version $version binaries"
		checkoutVersion "$repopath" "$version"
		autoGoMod "$repopath"
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

		buildWithMatrix "$matfile" "$repo/$package" "$outputDir/$version" "$(currentSha "$repopath")" "$version"
		echo ""
	done <<< "$newVersions"

	cp "$versions" "$outputDir/versions"

	notice "build complete!"
}

startGoBuilds "$1" "$2" "$3" "$4" "$5"
