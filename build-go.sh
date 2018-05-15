#!/bin/bash

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
	printf $txtred%s$txtnon\\n "$@"
	exit 1
}

function warn() {
	printf $txtylw%s$txtnon\\n "$@"
}

function notice() {
	printf $txtgrn%s$txtnon\\n "$@"
}

# dep checks
reqbins="jq zip tar go npm"
for b in $reqbins
do
	if ! type $b > /dev/null; then
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

function printDistInfo() {
	local bundle="$1"
	local version="$2"

	# print json output
	jq -e ".platforms[\"$goos\"]" dist.json > /dev/null
	if [ ! $? -eq 0 ]; then
		cp dist.json dist.json.temp
		jq ".platforms[\"$goos\"] = {\"name\":\"$goos Binary\",\"archs\":{}}" dist.json.temp > dist.json
	fi

	local linkname="$version/$bundle.`pkgType $goos`"
	cp dist.json dist.json.temp
	jq ".platforms[\"$goos\"].archs[\"$goarch\"] = {\"link\":\"$linkname\"}" dist.json.temp > dist.json
	rm dist.json.temp
}

function doBuild() {
	local goos=$1
	local goarch=$2
	local target=$3
	local output=$4
	local version=$5

	dir=$output
	name=$(basename `pwd`)
	binname=${name}_${version}_${goos}-${goarch}

	echo "==> building for $goos $goarch"

	if [ -e $dir/$binname ]; then
		echo "    $dir/$binname exists, skipping build"
		return
	fi
	echo "    output to $dir/$binname"

	local build_dir_name=$name
	mkdir -p $build_dir_name

	mkdir -p $dir
	(cd $build_dir_name && GOOS=$goos GOARCH=$goarch go build -asmflags -trimpath="$GOPATH/src" -gcflags -trimpath="$GOPATH/src" $target 2> build-log)
	if [ $? -ne 0 ]; then
		local logfi="$dir/build-log-$goos-$goarch"
		cp $build_dir_name/build-log "$logfi"
		warn "    failed. logfile at '$logfi'"
		return 1
	fi

	notice "    build succeeded!"

	# copy dist assets if they exist
	if [ -e $GOPATH/src/$target/dist ]; then
		cp -r $GOPATH/src/$target/dist/* $build_dir_name/
	fi

	# now package it all up
	if bundleDist $dir/$binname $goos $build_dir_name; then
		printDistInfo $binname
		rm -rf $build_dir_name
	else
		warn "    failed to zip up output"
		success=1
	fi


	# output results to results table
	echo $target, $goos, $goarch, $success >> $output/results
}

function bundleDist() {
	local name=$1
	local os=$2
	local build_dir=$3

	test -n "$build_dir" || fail "must specify dir to bundle!"

	case `pkgType $os` in
	zip)
		zip -r $name.zip $build_dir/* > /dev/null
		return $?
		;;
	tar.gz)
		tar czf $name.tar.gz $build_dir/*
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

	printf "{\"id\":\"$reponame\",\"version\":\"$version\",\"releaseLink\":\"/$distname/$version\"}" |
	jq ".name = \"$distname\"" |
	jq ".owner  = \"`cat repo-owner`\"" |
	jq ".description = \"`cat description`\"" |
	jq ".date = \"`date '+%B %d, %Y'`\"" |
	jq ".platforms = {}"
}

function printBuildInfo() {
	# print out build information
	local commit=$1
	go version
	echo "git sha of code: $commit"
	uname -a
	echo built on `date`
}

function buildWithMatrix() {
	local matfile=$1
	local gobin=$2
	local output=$3
	local commit=$4
	local version=$5

	test -n "$output" || fail "error: output dir not specified"
	test -e "$matfile" || fail "build matrix $matfile does not exist"

	mkdir -p "$output"

	local distname=$(basename `pwd`)

	printInitialDistfile $distname $version > dist.json
	printBuildInfo $commit > $output/build-info

	# build each os/arch combo
	while read line
	do
		doBuild $line $gobin $output $version
	done < $matfile

	# build the source
	buildSource "$distname" "$GOPATH/src/$gobin" "$output"

	mv dist.json $output/dist.json
}

function cleanRepo() {
	local repopath=$1

	reporoot=$(cd "$repopath" && git rev-parse --show-toplevel)
	(cd "$reporoot" && git clean -df)
	(cd "$reporoot" && git reset --hard)
}

function checkoutVersion() {
	local repopath=$1
	local ref=$2

	test -n "$repopath" || fail "checkoutVersion: no repo to check out specified"

	echo "==> checking out version $ref in $repopath"
	cleanRepo "$repopath"
	(cd "$repopath" && git checkout $ref > /dev/null)

	test $? -eq 0 || fail "failed to check out $ref in $reporoot"
}

function installDeps() {
	local repopath=$1

	reporoot=$(cd "$repopath" && git rev-parse --show-toplevel)

	(cd "$reporoot" && make -n deps > /dev/null 2>&1 && make deps)
}

function buildSource() {
	local distname="$1"
	local repopath="$2"
	local output="$3"
	local target="$distname-source.tar.gz"

	reporoot=$(cd "$repopath" && git rev-parse --show-toplevel)

	(cd "$reporoot" && make -n "$target" > /dev/null 2>&1 && make "$target") || return

	cp "$reporoot/$target" "$output"

	cp dist.json dist.json.temp
	jq ".source = {\"link\": \"/$target\"}" dist.json.temp > dist.json
	rm dist.json.temp
}

function currentSha() {
	(cd $1 && git show --no-patch --pretty="%H")
}

function printVersions() {
	local versfile="$1"
	versarr=$(tr \n ' ' < $versfile)
	echo "building versions: $versarr"
}

function startGoBuilds() {
	distname="$1"
	gpath="$2"
	versions="$3"
	existing="$4"

	if [ -z "$existing" ]; then
		existing="/ipns/dist.ipfs.io"
	fi
	echo "using $existing as a template."


	if ! mkdir -p "$releases"; then
		fail "failed to create releases directory"
	fi

	outputDir="$releases/$distname"

	# if the output directory already exists, warn user
	if [ -e $outputDir ]; then
		warn "dirty output directory"
		warn "will skip building already existing binaries"
		warn "to perform a fresh build, please delete $outputDir"
	else
		local tmpdir=$(mktemp -d)
		echo "fetching $existing to $tmpdir"
		if ! ipfs get "$existing/$distname" -o "$tmpdir" 2> get_output; then
			if grep "can't resolve ipns entry" get_output > /dev/null; then
				fail "Your IPFS daemon is probably not running"
			fi
			if ! grep "no link named" get_output > /dev/null; then
				fail "failed to fetch existing distributions"
			fi
		fi
		mv "$tmpdir" "$outputDir"
	fi

	if [ ! -e "$versions" ]; then
		fail "versions file $versions does not exist"
	fi

	export GOPATH=$(pwd)/gopath
	if [ ! -e $GOPATH/src/$gpath ]; then
		echo "fetching $distname code..."
		go get -d $gpath 2> /dev/null
	fi

	repopath="$GOPATH/src/$gpath"

	(cd "$repopath" && git reset --hard && git clean -df && git fetch)

	printVersions $versions

	echo ""
	while read version
	do
		if [ -e "$outputDir/$version" ]; then
			echo "$version already exists, skipping..."
			continue
		fi

		notice "Building version $version binaries"
		checkoutVersion $repopath $version
		installDeps "$repopath" 2>&1 > deps-$version.log

		matfile="matrices/$version"
		if [ ! -e "$matfile" ]; then
			if [ -e build_matrix ]; then
				matfile=build_matrix
			else
				fail "no matrix file for version $version found, and no 'build_matrix' detected"
			fi
		fi

		buildWithMatrix "$matfile" "$gpath" "$outputDir/$version" "$(currentSha $repopath)" "$version"
		echo ""
	done < $versions

	notice "build complete!"
}

startGoBuilds $1 $2 $3 $4
