repo = http://github.com/ipfs/electron-app
releases = ../../releases/ipfs-app

all: release

release: versions
	mkdir -p $(releases)
	cp versions $(releases)/versions
	./app-release all

versions:
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' > versions

x:
	chmod +x app-release
