var mkdist = require('../../scripts/mkdist')

if (process.argv.length != 3) {
  console.log('usage: mkdist.js <version>')
  process.exit(1)
}

var dist = require('./dist.json')
dist.version = process.argv[2]

mkdist({
  dist: dist,
  path: '../..',
  platforms: {
    oses: [
      {id: 'darwin',  name: 'Mac OSX Binary (.zip)', browser: 'OS X'},
      {id: 'linux',   name: 'Linux Binary (.zip)',   browser: 'Linux'},
      {id: 'openbsd', name: 'OpenBSD Binary (.zip)', browser: 'OpenBSD'},
      {id: 'freebsd', name: 'FreeBSD Binary (.zip)', browser: 'FreeBSD'},
      {id: 'windows', name: 'Windows Binary (.zip)', browser: 'Windows'}
    ],
    archs: [
      {id: '386',   name: '32 bit', browser: '32'},
      {id: 'amd64', name: '64 bit', browser: '64'},
      {id: 'arm',   name: 'ARM',    browser: 'ARM'}
    ]
  }
})
