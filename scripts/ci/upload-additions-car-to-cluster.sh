#!/usr/bin/env bash
# Upload additions .car to the cluster, pre-seeding new blocks before
# the full root pin. Uses retry logic similar to ipfs-deploy-action.
set -euo pipefail

CAR_FILE=$(ls additions_*.car 2>/dev/null | head -1)

if [[ -z "$CAR_FILE" ]]; then
    echo "No additions .car file found, skipping upload"
    exit 0
fi

echo "Uploading $CAR_FILE to cluster as pin '${PIN_NAME}'"

MAX_ATTEMPTS=3
TIMEOUT=5m

for attempt in $(seq 1 $MAX_ATTEMPTS); do
    echo "Attempt $attempt/$MAX_ATTEMPTS"
    if timeout "$TIMEOUT" ipfs-cluster-ctl --enc=json \
        --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
        --basic-auth "${CLUSTER_USER}:${CLUSTER_PASSWORD}" \
        add --format=car \
        --local \
        --name "${PIN_NAME}" \
        "$CAR_FILE"; then
        echo "Upload succeeded on attempt $attempt"
        exit 0
    fi
    if [[ $attempt -lt $MAX_ATTEMPTS ]]; then
        echo "Upload failed, retrying in 30s.."
        sleep 30
    fi
done

echo "ERROR: upload failed after $MAX_ATTEMPTS attempts"
exit 1
