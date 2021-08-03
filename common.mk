# Common makefile rules for each dist.
# Include this from the dist's makefile.

# Path of _this_ file, relative to the sub-makefile.
relpath = $(dir $(lastword $(MAKEFILE_LIST)))

# Default values
distname ?= $(notdir ${CURDIR})
releases ?= $(relpath)releases/${distname}
versions ?= versions

nightlyVer = nightly-$(shell date -u '+%Y-%m-%d')


all: dist

dist:
	${relpath}build-go.sh "${distname}" "${repo}" "${package}" "${versions}"

update_sources:
	cd gopath/src/${repo}
	git fetch

clean:
	rm -rf $(releases)

nightly:
	grep -qxF ${nightlyVer} versions || echo ${nightlyVer} >> versions

