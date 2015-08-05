all: all_dists

all_dists: go-ipfs

go-ipfs:
	echo "** making $@ **"
	cd dists/$@ && make
