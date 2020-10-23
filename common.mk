# Common makefile rules for each dist.
# Include this from the dist's makefile.

# Path of _this_ file, relative to the sub-makefile.
relpath = $(dir $(lastword $(MAKEFILE_LIST)))

# Default values
distname ?= $(notdir ${CURDIR})
releases ?= $(relpath)releases/${distname}

all: dist

dist:
	${relpath}build-go.sh "${distname}" "${repo}" "${package}" versions /ipfs/QmQmCxMoGhSpTaCNp2pKWnuQoe1khVLm4wwLLByPSbZgJz
	# cp versions "${releases}/versions"

update_sources:
	cd gopath/src/${repo}
	git fetch

clean:
	rm -rf $(releases)
