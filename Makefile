all: all_dists index

all_dists: go-ipfs

ipfs-app:
	echo "** making $@ **"
	cd dists/$@ && make

go-ipfs:
	echo "** making $@ **"
	cd dists/$@ && make

index:
	echo "** making index.html **"
	node gen-index.js >releases/index.html
	cp -r static releases/.

publish: all_dists index
	ipfs add -s rabin -q -r releases | tail -n1 >>versions
