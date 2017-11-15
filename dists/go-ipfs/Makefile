repo = http://github.com/ipfs/go-ipfs
releases = ../../releases/go-ipfs

all: dist

dist: versions
	../../build-go.sh go-ipfs github.com/ipfs/go-ipfs/cmd/ipfs versions 
	cp versions $(releases)/versions

versions: FORCE
	git ls-remote -t --refs $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | grep -v -- '-buildfails$$' | sort > tag_versions
	comm -23 -- tag_versions filtered_versions > versions
FORCE:

update_sources:
	cd gopath/src/${ghrepo}
	git fetch

clean:
	rm -rf $(releases) tag_versions versions
