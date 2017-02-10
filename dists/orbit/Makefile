releases = ../../releases/orbit

all: release

release: versions
	mkdir -p $(releases)
	cp versions $(releases)/versions
	./app-release all

versions:
	echo 'v0.1.0' > versions

x:
	chmod +x app-release
