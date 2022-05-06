export NODE_OPTIONS="--unhandled-rejections=strict"

all: deps releases all_dists site

DISTS = $(notdir $(wildcard dists/*))

NIGHTLY_IGNORED := $(shell cat ignored-during-nightly)
DISTS_FILTERED = $(filter-out $(NIGHTLY_IGNORED),$(DISTS))
NDISTS = $(DISTS_FILTERED:%=nightly-%)

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

diff:
	./scripts/diff.js > diff

clean:
	rm -rf releases
	chmod -f -R u+w dists/*/gopath || true
	rm -rf dists/*/gopath
	npm run clean

.NOTPARALLEL:
