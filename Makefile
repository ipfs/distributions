all: all_dists

all_dists: go-ipfs ipfs-app

ipfs-app:
	echo "** making $@ **"
	cd dists/$@ && make

go-ipfs:
	echo "** making $@ **"
	cd dists/$@ && make

publish: all_dists
	ipfs add -q -r build | tail -n1 >>versions
