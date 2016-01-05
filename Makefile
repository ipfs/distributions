all: all_dists site

all_dists: go-ipfs

ipfs-app:
	echo "** making $@ **"
	cd dists/$@ && make

go-ipfs:
	echo "** making $@ **"
	cd dists/$@ && make

site:
	echo "** Building site **"
	npm run build

publish: all_dists site
	ipfs add -s rabin -q -r releases | tail -n1 >>versions
