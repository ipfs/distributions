all: releases all_dists site

.PHONY: all all_dists deps
all_dists: $(notdir $(wildcard dists/*))

%:
	@echo "** $@ **"
	$(MAKE) -C dists/$@
	@echo ""

deps:
	./deps-check.sh

releases:
	mkdir -p releases

.PHONY: site
site: deps
	@echo "** Building site **"
	npm run build

publish: all_dists site
	ipfs add -q -r releases | tail -n1 | tee -a versions

clean:
	rm -rf releases
	rm -rf dists/*/gopath

.NOTPARALLEL:
