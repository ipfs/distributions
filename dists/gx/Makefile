ghrepo = github.com/whyrusleeping/gx
repo = http://${ghrepo}
distname = gx

releases = ../../releases/${distname}

all: dist

dist: versions
	../../build-go.sh ${distname} ${ghrepo} versions
	cp versions $(releases)/versions

versions: filtered_versions
	git ls-remote -t --refs $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | sort > tag_versions
	comm -23 -- tag_versions filtered_versions > versions

update_sources:
	cd gopath/src/${ghrepo}
	git fetch

clean:
	rm -rf $(releases)
