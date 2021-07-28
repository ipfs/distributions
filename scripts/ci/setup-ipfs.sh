#!/usr/bin/env bash
set -e

echo "::group::Install go-ipfs and ipfs-cluster-ctl"
    curl -s https://dist.ipfs.io/go-ipfs/${GO_IPFS_VER}/go-ipfs_${GO_IPFS_VER}_linux-amd64.tar.gz | sudo tar vzx -C /usr/local/bin/ go-ipfs/ipfs --strip-components=1
    curl -s https://dist.ipfs.io/ipfs-cluster-ctl/${CLUSTER_CTL_VER}/ipfs-cluster-ctl_${CLUSTER_CTL_VER}_linux-amd64.tar.gz | sudo tar vzx -C /usr/local/bin/ ipfs-cluster-ctl/ipfs-cluster-ctl --strip-components=1
echo "::endgroup::"

# fix resolv - DNS provided by Github is unreliable for DNSLik/dnsaddr
sudo sed -i -e 's/nameserver 127.0.0.*/nameserver 1.1.1.1/g' /etc/resolv.conf

# init ipfs
echo "::group::Set up IPFS daemon"
    ipfs init --profile flatfs,server,test,lowpower
    # make flatfs async for faster ci
    new_config=$( jq '.Datastore.Spec.mounts[0].child.sync = false' ~/.ipfs/config) && echo "${new_config}" > ~/.ipfs/config
    # restore deterministic port (changed by test profile)
    ipfs config Addresses.API "/ip4/127.0.0.1/tcp/5001"
    # wait for ipfs daemon
    ipfs daemon --enable-gc=false & while (! ipfs id --api "/ip4/127.0.0.1/tcp/5001"); do sleep 1; done
echo "::endgroup::"


echo "::group::Preconnect to cluster peers"
    echo '-> preconnect to cluster peers'
    ipfs-cluster-ctl --enc=json \
        --host "/dnsaddr/ipfs-websites.collab.ipfscluster.io" \
        --basic-auth '${CLUSTER_USER}:${CLUSTER_PASSWORD}' \
        peers ls > cluster-peers-ls
    for maddr in $(jq -r '.[].ipfs.addresses[]?' cluster-peers-ls); do
        ipfs swarm connect "$maddr" || continue
    done
    echo '-> manual connect to cluster.ipfs.io'
    ipfs swarm connect /dnsaddr/cluster.ipfs.io
    echo '-> list swarm peers'
    ipfs swarm peers
echo "::endgroup::"
