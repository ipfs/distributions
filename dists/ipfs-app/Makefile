repo = http://github.com/ipfs/electron-app

all: release

release: versions
	./app-release all

versions:
	git ls-remote -t $(repo) | egrep -o "refs/tags/v(.*)" | sed 's/refs\/tags\///' > versions

x:
	chmod +x app-release
