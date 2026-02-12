#!/usr/bin/env bash
set -e

echo "::group::preconnect to cluster"
ipfs-cluster-ctl --enc=json \
    --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
    --basic-auth "${CLUSTER_USER}:${CLUSTER_PASSWORD}" \
    peers ls | tee cluster-peers-ls
for maddr in $(jq -r '.ipfs.addresses[]?' cluster-peers-ls); do
    ipfs swarm peering add $maddr
    ipfs swarm connect $maddr || true &
done

echo "::group::pin add"
ipfs-cluster-ctl --enc=json \
    --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
    --basic-auth "${CLUSTER_USER}:${CLUSTER_PASSWORD}" \
    pin add \
    --name "${PIN_NAME}" \
    --no-status $PIN_ADD_EXTRA_ARGS \
    "$PIN_CID"
echo "::endgroup::"

# TODO: below can now be replaced with ipfs-cluster-ctl --wait now (https://github.com/ipfs/ipfs-cluster/blob/v0.14.1/CHANGELOG.md#v0141---2021-08-18)
echo "::group::waiting until pinned"
    while true; do
    ipfs-cluster-ctl --enc=json \
        --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
        --basic-auth "${CLUSTER_USER}:${CLUSTER_PASSWORD}" \
        status "$PIN_CID" | tee cluster-pin-status
    if [[ $(jq '.peer_map[].status' cluster-pin-status | grep '"pinned"' | wc -l) -ge 1 ]]; then
        echo "Got first pin confirmation, finishing the workflow"
        # unpin the temporary additions pin (full root CID subsumes it)
        if [[ -n "${ADDITIONS_PIN_NAME:-}" ]]; then
            echo "Removing temporary additions pin '${ADDITIONS_PIN_NAME}' (if any).."
            ADDITIONS_CID=$(ipfs-cluster-ctl --enc=json \
                --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
                --basic-auth "${CLUSTER_USER}:${CLUSTER_PASSWORD}" \
                pin ls | jq -r "select(.name == \"${ADDITIONS_PIN_NAME}\") | .cid" | head -1) || true
            if [[ -n "$ADDITIONS_CID" ]]; then
                ipfs-cluster-ctl --enc=json \
                    --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
                    --basic-auth "${CLUSTER_USER}:${CLUSTER_PASSWORD}" \
                    pin rm "$ADDITIONS_CID" 2>/dev/null || true
            fi
        fi
        break
    else
        echo "Still waiting for at least one pin confirmation, sleeping for 1 minute.."
        sleep 60
    fi
    done
echo "::endgroup::"
