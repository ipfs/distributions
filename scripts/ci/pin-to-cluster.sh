#!/usr/bin/env bash
set -euo pipefail

CLUSTER_HOST="/dnsaddr/ipfs-websites.collab.ipfscluster.io"
CLUSTER_AUTH="${CLUSTER_USER}:${CLUSTER_PASSWORD}"

cluster_ctl() {
    ipfs-cluster-ctl --enc=json \
        --host "$CLUSTER_HOST" \
        --basic-auth "$CLUSTER_AUTH" \
        "$@"
}

echo "::group::preconnect to cluster"
cluster_ctl peers ls | tee cluster-peers-ls
for maddr in $(jq -r '.ipfs.addresses[]?' cluster-peers-ls); do
    ipfs swarm peering add "$maddr"
    ipfs swarm connect "$maddr" || true &
done
echo "::endgroup::"

# Upload additions .car to pre-seed new blocks before the full root pin
ADDITIONS_CID=""
if [[ -n "${ADDITIONS_CAR:-}" ]]; then
    car_file=$(ls $ADDITIONS_CAR 2>/dev/null | head -1) || true
    if [[ -n "$car_file" ]]; then
        echo "::group::upload additions .car"
        echo "Uploading $car_file as pin '${ADDITIONS_PIN_NAME}'"
        add_output=$(cluster_ctl add --format=car --local \
            --wait --wait-timeout 10m \
            --name "$ADDITIONS_PIN_NAME" \
            "$car_file")
        echo "$add_output"
        ADDITIONS_CID=$(echo "$add_output" | jq -rs '.[-1].cid' 2>/dev/null) || true
        echo "Additions CID: ${ADDITIONS_CID:-unknown}"
        echo "::endgroup::"
    else
        echo "No file matching ADDITIONS_CAR='${ADDITIONS_CAR}', skipping upload"
    fi
fi

echo "::group::pin root CID and wait"
echo "Pinning $PIN_CID as '${PIN_NAME}'"
cluster_ctl pin add \
    --wait --wait-timeout 20m \
    --name "$PIN_NAME" $PIN_ADD_EXTRA_ARGS \
    "$PIN_CID"
echo "::endgroup::"

# unpin the temporary additions pin (full root CID subsumes it)
if [[ -n "$ADDITIONS_CID" ]]; then
    echo "::group::unpin additions"
    echo "Removing temporary additions pin '$ADDITIONS_CID'"
    cluster_ctl pin rm "$ADDITIONS_CID" 2>/dev/null || true
    echo "::endgroup::"
fi
