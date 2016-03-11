all: all_dists site

.PHONY: all_dists
all_dists: go-ipfs ipfs-update fs-repo-migrations ipget

%:
	echo "** $@ **"
	cd dists/$@ && make

site:
	echo "** Building site **"
	npm run build

publish: all_dists site
	ipfs add -q -r releases | tail -n1 >>versions

clean:
	rm -rf releases
