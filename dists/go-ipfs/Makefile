repo = github.com/ipfs/go-ipfs
package = cmd/ipfs

include ../../common.mk

# we override dist recipe for go-ipfs to avoid bulding kubo binaries for the second time.
# instead, we repackage existing kubo artifacts under the legacy go-ipfs name
dist:
	${relpath}/dists/go-ipfs/build-from-kubo.sh "${relpath}" "${distname}" "${repo}" "${package}" "${versions}"
