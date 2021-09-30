#!/usr/bin/env bash
set -e

download_dist_package () {
    local DIST_NAME="$1"
    local DIST_VERSION="$2"
    local DIST_FILE="${DIST_NAME}_${DIST_VERSION}_linux-amd64.tar.gz"
    local DIST_URL="https://dist.ipfs.io/${DIST_NAME}/${DIST_VERSION}/${DIST_FILE}"
    wget -nv -c --retry-connrefused --tries=0 --retry-on-host-error --retry-on-http-error=503,504,429 -O "${DIST_FILE}" "${DIST_URL}"
    wget -nv -c --retry-connrefused --tries=0 --retry-on-host-error --retry-on-http-error=503,504,429 -O "${DIST_FILE}.sha512" "${DIST_URL}.sha512"
    sha512sum -c "${DIST_FILE}.sha512"
}

echo "::group::Install go-ipfs and ipfs-cluster-ctl"
    download_dist_package go-ipfs "${GO_IPFS_VER}"
    sudo tar vzx -f "go-ipfs_${GO_IPFS_VER}_linux-amd64.tar.gz" -C /usr/local/bin/ go-ipfs/ipfs --strip-components=1

    download_dist_package ipfs-cluster-ctl "${CLUSTER_CTL_VER}"
    sudo tar vzx -f "ipfs-cluster-ctl_${CLUSTER_CTL_VER}_linux-amd64.tar.gz" -C /usr/local/bin/ ipfs-cluster-ctl/ipfs-cluster-ctl --strip-components=1

    rm *.tar.gz*
echo "::endgroup::"

# fix resolv - DNS provided by Github is unreliable for DNSLik/dnsaddr
sudo sed -i -e 's/nameserver 127.0.0.*/nameserver 1.1.1.1/g' /etc/resolv.conf

# QUIC perf: https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size
sudo sysctl -w net.core.rmem_max=2500000

# init ipfs
echo "::group::Set up IPFS daemon"
    ipfs init --profile flatfs,server,test,lowpower
    # make flatfs async for faster ci
    new_config=$( jq '.Datastore.Spec.mounts[0].child.sync = false' ~/.ipfs/config) && echo "${new_config}" > ~/.ipfs/config
    # restore deterministic port (changed by test profile)
    ipfs config Addresses.API "/ip4/127.0.0.1/tcp/5001"
    # wait for ipfs daemon
    ipfs daemon --routing=none --enable-gc=false & while (! ipfs id --api "/ip4/127.0.0.1/tcp/5001"); do sleep 1; done
echo "::endgroup::"


echo "::group::Preconnect to cluster peers"
    echo '-> preconnect to cluster peers'
    ipfs-cluster-ctl --enc=json \
        --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
        --basic-auth "${CLUSTER_USER}:${CLUSTER_PASSWORD}" \
        peers ls > cluster-peers-ls
    for maddr in $(jq -r '.[].ipfs.addresses[]?' cluster-peers-ls); do
        ipfs swarm peering add "$maddr" || continue
    done
    echo '-> manual connect to cluster.ipfs.io'
    ipfs swarm connect /dnsaddr/cluster.ipfs.io
    echo '-> list swarm peers'
    ipfs swarm peers
echo "::endgroup::"
