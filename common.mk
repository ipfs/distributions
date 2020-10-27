# Common makefile rules for each dist.
# Include this from the dist's makefile.

# Path of _this_ file, relative to the sub-makefile.
relpath = $(dir $(lastword $(MAKEFILE_LIST)))

# Default values
distname ?= $(notdir ${CURDIR})
releases ?= $(relpath)releases/${distname}

all: dist

dist:
	${relpath}build-go.sh "${distname}" "${repo}" "${package}" versions /ipfs/QmTsAa6gdxmRhDEM1JCLy9uQ9HRozyqWci4LKjoi9oKxvv

update_sources:
	cd gopath/src/${repo}
	git fetch

clean:
	rm -rf $(releases)
