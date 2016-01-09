repo = http://github.com/ipfs/go-ipfs
releases = ../../releases/go-ipfs

all: dist

dist: versions
	mkdir -p $(releases)
	cp versions $(releases)/versions
	../../build-go.sh go-ipfs github.com/ipfs/go-ipfs/cmd/ipfs

versions: filtered_versions
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | sort > tag_versions
	comm -23 -- tag_versions filtered_versions > versions

clean:
	rm -rf $(releases)
