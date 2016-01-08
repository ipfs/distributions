#!/bin/bash

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
reqbins="jq zip go"
for b in $reqbins
do
	if ! type $b > /dev/null
	then
		fail "must have '$b' installed"
	fi
done

function printDistInfo() {
	# print json output
	jq -e ".platforms[\"$goos\"]" dist.json > /dev/null
	if [ ! $? -eq 0 ]
	then
		cp dist.json dist.json.temp
		jq ".platforms[\"$goos\"] = {\"name\":\"$goos Binary\",\"archs\":{}}" dist.json.temp > dist.json
	fi

	local binname="$1"
	if [ "$goos" = "windows" ]
	then
		binname="$binname.exe"
	fi

	cp dist.json dist.json.temp
	jq ".platforms[\"$goos\"].archs[\"$goarch\"] = {\"link\":\"$goos-$goarch/$binname\"}" dist.json.temp > dist.json

}

function doBuild() {
	local goos=$1
	local goarch=$2
	local target=$3
	local output=$4

	echo "==> building for $goos $goarch"

	dir=$output/$1-$2
	if [ -e $dir ]
	then
		echo "    $dir exists, skipping build"
		return
	fi
	echo "    output to $dir"

	mkdir -p tmp-build

	(cd tmp-build && GOOS=$goos GOARCH=$goarch go build $target 2> build-log)
	local success=$?
	local binname=$(basename $target)
	if [ "$success" != 0 ]
	then
		warn "    failed."
		return 1
	fi

	notice "    build succeeded!"

	# copy dist assets if they exist
	if [ -e $GOPATH/src/$target/dist ]; then
		cp -r $GOPATH/src/$target/dist/* tmp-build/
	fi

	# now zip it all up
	mkdir -p $dir
	if  zip -r $dir/$binname.zip tmp-build > /dev/null
	then
		printDistInfo $binname
		rm -rf tmp-build
	else
		warn "    failed to zip up output"
		success=1
	fi


	# output results to results table
	echo $target, $goos, $goarch, $success >> $output/results
}

function printInitialDistfile() {
	local distname=$1
	local version=$2
	printf "{\"id\":\"$distname\",\"version\":\"$version\",\"releaseLink\":\"releases/$distname/$version\"}" |
	jq ".name = \"$disname\"" |
	jq ".platforms = {}" |
	jq ".description = \"`cat description`\""
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

	if [ -z "$output" ]; then
		fail "error: output dir not specified"
	fi

	if [ ! -e $matfile ]; then
		fail "build matrix $matfile does not exist"
	fi

	mkdir -p $output

	local distname=$(basename $gobin)

	printInitialDistfile $distname $version > dist.json
	printBuildInfo $commit > $output/build-info

	# build each os/arch combo
	while read line
	do
		doBuild $line $gobin $output
	done < $matfile

	mv dist.json $output/dist.json
}

function checkoutVersion() {
	local repopath=$1
	local ref=$2

	if [ -z "$repopath" ]
	then
		fail "checkoutVersion: no repo to check out specified"
	fi

	echo "==> checking out version $ref in $repopath"
	(cd $repopath && git reset --hard)
	(cd $repopath && git clean -df)
	(cd $repopath && git checkout $ref > /dev/null)

	if [ "$?" != 0 ]
	then
		fail "failed to check out $ref in $repopath"
	fi
}

function currentSha() {
	(cd $1 && git show --pretty="%H")
}

function printVersions() {
	versarr=""
	while read v
	do
		versarr="$versarr $v"
	done < versions
	echo "building versions: $versarr"
}

function startGoBuilds() {
	distname=$1
	gpath=$2

	outputDir=$releases/$distname

	# if the output directory already exists, warn user
	if [ -e $outputDir ]
	then
		warn "dirty output directory"
		warn "will skip building already existing binaries"
	fi

	export GOPATH=$(pwd)/gopath
	if [ ! -e $GOPATH ]
	then
		echo "fetching $distname code..."
		go get $gpath 2> /dev/null
	fi

	repopath=$GOPATH/src/$gpath

	(cd $repopath && git reset --hard && git clean -df)

	printVersions

	echo ""
	while read version
	do
		notice "Building version $version binaries"
		checkoutVersion $repopath $version

		buildWithMatrix matrices/$version $gpath $outputDir/$version $(currentSha $repopath)
		echo ""
	done < versions

	notice "build complete!"
}

# globals
gpath=github.com/ipfs/go-ipfs/cmd/ipfs

startGoBuilds go-ipfs $gpath