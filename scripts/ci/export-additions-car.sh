#!/usr/bin/env bash
# Export newly added content as a single .car file.
# This is used to pre-seed the cluster with new blocks before pinning
# the full root CID, avoiding slow fetches from the ephemeral CI node.
set -euo pipefail

PATCH_OPS="./patch-ops.json"

if [[ ! -f "$PATCH_OPS" ]]; then
    echo "No $PATCH_OPS found, skipping .car export"
    exit 0
fi

# extract paths of "add" operations only (we don't care about updates/removals)
ADD_PATHS=$(jq -r '.[] | select(.action == "add") | .path' "$PATCH_OPS")

if [[ -z "$ADD_PATHS" ]]; then
    echo "No add operations in $PATCH_OPS, skipping .car export"
    exit 0
fi

echo "Add operations found:"
echo "$ADD_PATHS"

# read the new root CID (last line of ./versions, written by patch.js)
NEW_CID=$(tail -1 ./versions)
if [[ -z "$NEW_CID" ]]; then
    echo "ERROR: could not read new root CID from ./versions"
    exit 1
fi
echo "New root CID: $NEW_CID"

# build an additions-only MFS tree
ipfs files rm -r /additions 2>/dev/null || true
ipfs files mkdir -p /additions

while IFS= read -r add_path; do
    # add_path looks like /kubo/v0.40.0-rc1
    # create parent directories in /additions
    parent_dir=$(dirname "$add_path")
    if [[ "$parent_dir" != "/" && "$parent_dir" != "." ]]; then
        ipfs files mkdir -p "/additions${parent_dir}"
    fi
    echo "Copying /ipfs/${NEW_CID}${add_path} -> /additions${add_path}"
    ipfs files cp "/ipfs/${NEW_CID}${add_path}" "/additions${add_path}"
done <<< "$ADD_PATHS"

# get CID of the additions tree
ADDITIONS_CID=$(ipfs files stat --hash /additions)
echo "Additions tree CID: $ADDITIONS_CID"

# export as .car
CAR_FILE="additions_${ADDITIONS_CID}.car"
echo "Exporting to $CAR_FILE"
ipfs dag export "$ADDITIONS_CID" > "$CAR_FILE"

CAR_SIZE=$(du -h "$CAR_FILE" | cut -f1)
echo "Exported $CAR_FILE ($CAR_SIZE)"

# write summary to GitHub Actions step summary if available
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat >> "$GITHUB_STEP_SUMMARY" <<EOF
### Additions .car export
- CID: \`$ADDITIONS_CID\`
- File: \`$CAR_FILE\`
- Size: $CAR_SIZE
- Paths:
\`\`\`
$ADD_PATHS
\`\`\`
EOF
fi
