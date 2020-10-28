all: deps releases all_dists site

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
	./scripts/patch.js

clean:
	rm -rf releases
	rm -rf dists/*/gopath
	npm run clean

.NOTPARALLEL:
