repo = github.com/ipfs/go-ipfs
package = cmd/ipfs

include ../../common.mk

# we override dist recipe for go-ipfs to provide a stub binary that tells users to use kubo instead
dist:
	${relpath}/dists/go-ipfs/build-placeholder.sh "${relpath}" "${distname}" "${repo}" "${package}" "${versions}"
