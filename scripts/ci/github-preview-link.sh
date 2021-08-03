#!/usr/bin/env bash
set -e

PREVIEW_URL=${PREVIEW_URL:-"https://dweb.link$CONTENT_PATH"}
API_PARAMS=$(jq --monochrome-output --null-input \
    --arg state "success" \
    --arg target_url "$PREVIEW_URL" \
    --arg description "${GITHUB_DESCRIPTION:-"Preview updated website on IPFS"}" \
    --arg context "${GITHUB_TITLE:-"Preview is ready"}" \
    '{ state: $state, target_url: $target_url, description: $description, context: $context }' )
curl --output /dev/null --silent --show-error \
    -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H 'Content-Type: application/json' \
    --data "$API_PARAMS" 'https://api.github.com/repos/ipfs/distributions/statuses/${GIT_REVISION}'
echo "Pinned to IPFS - $PREVIEW_URL"
