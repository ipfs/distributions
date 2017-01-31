all: releases all_dists site

dists_to_build=$(shell ls dists | egrep -v '(ipfs-app|ipget)') 

.PHONY: all all_dists
all_dists: $(dists_to_build)

%:
	echo "** $@ **"
	cd dists/$@ && make

releases:
	mkdir -p releases

.PHONY: site
site:
	echo "** Building site **"
	npm run build

publish: all_dists site
	ipfs add -q -r releases | tail -n1 >>versions

clean:
	rm -rf releases
	rm -rf dists/*/gopath
