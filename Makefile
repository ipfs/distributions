all: deps releases all_dists site

DISTS = $(notdir $(wildcard dists/*))

NDISTS = $(DISTS:%=nightly-%)

.PHONY: all all_dists deps nightly
all_dists: $(DISTS)

$(DISTS):
	@echo "** $@ **"
	$(MAKE) -C dists/$@
	@echo ""

nightly: $(NDISTS)

$(NDISTS):
	@echo "** $@ Nightly **"
	$(MAKE) -C dists/$(@:nightly-%=%) nightly
	@echo ""

deps:
	./deps-check.sh

releases:
	mkdir -p releases


.PHONY: site
site: deps
	@echo "** Building site **"
	npm run build

publish: deps all_dists site
	./scripts/patch.js

clean:
	rm -rf releases
	chmod -f -R u+w dists/*/gopath || true
	rm -rf dists/*/gopath
	npm run clean

.NOTPARALLEL:
