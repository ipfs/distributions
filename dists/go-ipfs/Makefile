repo = http://github.com/ipfs/go-ipfs
gpath = github.com/ipfs/go-ipfs/cmd/ipfs
releases = ../../releases/go-ipfs
gbcli = $(shell which gobuilder-cli)

all: dist

dist: versions deps
	mkdir -p $(releases)
	cp versions $(releases)/versions
	./go-ipfs-dist all

versions: filtered_versions
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' > tag_versions
	cat tag_versions | grep -f filtered_versions -vE > versions

deps: bin bin/gobuilder-cli go-ipfs-dist-x

bin:
	@mkdir -p bin

go-ipfs-dist-x:
	chmod +x go-ipfs-dist

bin/gobuilder-cli: bin
	#TODO: make this not require a go compiler...
	go get github.com/Luzifer/gobuilder/cmd/gobuilder-cli
	cp $(gbcli) bin/gobuilder-cli

# bin/go-env:
# 	ipfs get -o bin/go-env QmfS4PZj7G7KgAztPN3JxXyY6KHJDZ77EaxzocWqsa3XhQ/go-env
# 	chmox +x bin/go-env
