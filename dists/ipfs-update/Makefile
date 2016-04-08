repo=http://github.com/ipfs/ipfs-update
releases=../../releases/ipfs-update

all: dist

dist: versions
	../../build-go.sh ipfs-update github.com/ipfs/ipfs-update versions
	cp versions $(releases)/versions

versions: filtered_versions
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | sort > tag_versions
	comm -23 -- tag_versions filtered_versions > versions

filtered_versions:
	touch filtered_versions

clean:
	rm -rf ./gopath
	rm -rf $(releases)
	rm versions tag_versions

