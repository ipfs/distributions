all: all_dists site

all_dists: go-ipfs ipfs-update fs-repo-migrations

%:
	echo "** $@ **"
	cd dists/$@ && make

site:
	echo "** Building site **"
	npm run build

publish: all_dists site
	ipfs add -s rabin -q -r releases | tail -n1 >>versions

clean:
	rm -rf releases
