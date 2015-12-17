var mkdist = require('../../scripts/mkdist')

if (process.argv.length != 3) {
  console.log("usage: mkdist.js <version>")
  process.exit(1)
}

var dist = require('./dist.json')
dist.version = process.argv[2]

mkdist({
  dist: dist,
  path: "../..",
  platforms: {
    oses: [
      {id: 'darwin',  name: "Mac OSX App", browser:'OS X',    icon: 'apple'},
      {id: 'linux',   name: "Linux App",   browser:'Linux',   icon: 'linux'},
      {id: 'openbsd', name: "OpenBSD App", browser:'OpenBSD', icon: 'circle-o'},
      {id: 'freebsd', name: "FreeBSD App", browser:'FreeBSD', icon: 'circle-o'},
      {id: 'windows', name: "Windows App", browser:'Windows', icon: 'windows'},
    ],
    archs: [
      {id: '386',   name: '32 bit', browser: '32'},
      {id: 'amd64', name: '64 bit', browser: '64'},
      {id: 'arm',   name: 'ARM',    browser: 'ARM'},
    ]
  }
})
