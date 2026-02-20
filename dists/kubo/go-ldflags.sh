#!/bin/bash
# Compute ldflags for kubo builds.
# Sets CurrentCommit (git hash) and taggedRelease (version tag for clean
# tagged builds, used to omit redundant commit from the user agent).

set -e

repopath="$1"

commit=$(git -C "$repopath" rev-parse --short HEAD 2>/dev/null)

# Detect if HEAD points at a version tag (clean tagged release)
tag=$(git -C "$repopath" tag --points-at HEAD 2>/dev/null | grep '^v' | head -1)

ldflags="-X github.com/ipfs/kubo.CurrentCommit=$commit"
if [ -n "$tag" ]; then
	ldflags="$ldflags -X github.com/ipfs/kubo.taggedRelease=$tag"
fi

echo "$ldflags"
