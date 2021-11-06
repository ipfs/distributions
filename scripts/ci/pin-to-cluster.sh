#!/usr/bin/env bash
set -e

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
    if [[ $(jq '.peer_map[].status' cluster-pin-status | grep '"pinned"' | wc -l) -ge 2 ]]; then
        echo "Got 2 pin confirmations, finishing the workflow"
        break
    else
        echo "(sleeping for 15 seconds)"
        sleep 15
    fi
    done
echo "::endgroup::"
