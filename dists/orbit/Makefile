releases = ../../releases/orbit

all: release

release: versions
	mkdir -p $(releases)
	cp versions $(releases)/versions
	./app-release all

versions:
	echo 'master' > versions

x:
	chmod +x app-release
