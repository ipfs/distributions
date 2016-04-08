repo = http://github.com/noffle/ipget
releases = ../../releases/ipget

all: dist

dist: versions
	../../build-go.sh ipget github.com/noffle/ipget versions
	cp versions $(releases)/versions

versions: filtered_versions
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' | sort > tag_versions
	comm -23 -- tag_versions filtered_versions > versions

filtered_versions:
	touch filtered_versions

clean:
	rm -rf $(releases)
