repo=http://github.com/ipfs/fs-repo-migrations
releases=../../releases/fs-repo-migrations

all: dist

dist: versions
	../../build-go.sh fs-repo-migrations github.com/ipfs/fs-repo-migrations versions
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

