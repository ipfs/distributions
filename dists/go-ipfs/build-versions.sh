#!/bin/bash

# globals
outputDir=../../releases/go-ipfs
goipfspath=github.com/ipfs/go-ipfs/cmd/ipfs

txtnon='\e[0m'    # color reset
txtblk='\e[0;30m' # Black
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue

function fail() {
	echo -e $txtred$@$txtnon
	exit 1
}

function warn() {
	echo -e $txtylw$@$txtnon
}

function notice() {
	echo -e $txtgrn$@$txtnon
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
	mkdir -p $dir

	(cd $dir && GOOS=$goos GOARCH=$goarch go build $target 2> build-log)
	local success=$?
	if [ "$success" == 0 ]
	then
		notice "    success!"
	else
		warn "    failed."
	fi

	# output results to results table
	echo $target, $goos, $goarch, $? >> $output/results
}

function buildWithMatrix() {
	local matfile=$1
	local gobin=$2
	local output=$3
	local commit=$4

	if [ -z "$output" ]
	then
		fail "error: output dir not specified"
	fi

	if [ ! -e $matfile ]
	then
		fail "build matrix $matfile does not exist"
	fi

	# print out build information
	mkdir -p $output
	go version > $output/build-info
	echo "git sha of code: $commit" >> $output/build-info
	uname -a >> $output/build-info
	echo built on `date` >> $output/build-info

	# build each os/arch combo
	while read line
	do
		doBuild $line $gobin $output
	done < $matfile
}

function checkoutVersion() {
	local repopath=$1
	local ref=$2

	echo "==> checking out version $ref in $repopath"
	(cd $repopath && git checkout $ref > /dev/null)

	if [ "$?" != 0 ]
	then
		fail "failed to check out $ref in $repopath"
	fi
}

function currentSha() {
	(cd $1 && git show --pretty="%H")
}

# if the output directory already exists, warn user
if [ -e $outputDir ]
then
	warn "dirty output directory"
	warn "will skip building already existing binaries"
fi


export GOPATH=$(pwd)/gopath
if [ ! -e $GOPATH ]
then
	echo "fetching ipfs code..."
	go get $goipfspath 2> /dev/null
fi

repopath=$GOPATH/src/$goipfspath

versarr=""
while read v
do
	versarr="$versarr $v"
done < versions

echo "building versions: $versarr"

echo ""
while read v
do
	notice "Building version $v binaries"
	checkoutVersion $repopath $v

	buildWithMatrix matrices/$v $goipfspath $outputDir/$v $(currentSha $repopath)
	echo ""
done < versions

notice "build complete!"
