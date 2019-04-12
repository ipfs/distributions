package = github.com/ipfs/ipfs-pack
repo = ${package}
distname = ipfs-pack

releases = ../../releases/${distname}

all: dist

dist: versions
	../../build-go.sh ${distname} ${repo} ${package} versions
	cp versions $(releases)/versions

versions: filtered_versions
	git ls-remote -t --refs https://$(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | grep -v "{}" | sort > tag_versions
	comm -23 -- tag_versions filtered_versions > versions

update_sources:
	cd gopath/src/${package}
	git fetch

clean:
	rm -rf $(releases)
