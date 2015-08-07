repo = http://github.com/ipfs/go-ipfs
gpath = github.com/ipfs/go-ipfs/cmd/ipfs

all: dist

dist: versions deps
	./go-ipfs-dist all

versions:
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' >versions

deps: bin bin/gobuilder-cli go-ipfs-dist-x

bin:
	@mkdir -p bin

go-ipfs-dist-x:
	chmod +x go-ipfs-dist

bin/gobuilder-cli: bin
	#TODO: make this not require a go compiler...
	go get github.com/Luzifer/gobuilder/cmd/gobuilder-cli
	cp $(shell which gobuilder-cli) bin/gobuilder-cli

# bin/go-env:
# 	ipfs get -o bin/go-env QmfS4PZj7G7KgAztPN3JxXyY6KHJDZ77EaxzocWqsa3XhQ/go-env
# 	chmox +x bin/go-env
