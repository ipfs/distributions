repo=http://github.com/ipfs/fs-repo-migrations
releases=../../releases/fs-repo-migrations

all: dist

dist: versions
	mkdir -p $(releases)
	cp versions $(releases)/versions
	../../build-go.sh fs-repo-migrations github.com/ipfs/fs-repo-migrations

versions: filtered_versions
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' > tag_versions
	cat tag_versions | grep -f filtered_versions -vE > versions

filtered_versions:
	touch filtered_versions

clean:
	rm -rf ./gopath
	rm -rf $(releases)
	rm versions tag_versions

