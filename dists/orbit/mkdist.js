#!/usr/bin/env node

var mkdist = require('../../scripts/mkdist')

if (process.argv.length != 3) {
  console.log('usage: mkdist.js <version>')
  process.exit(1)
}

var dist = require('./dist.json')
dist.version = process.argv[2]

mkdist({
  dist: dist,
  path: "../..",
  platforms: {
    oses: [
      {id: 'darwin',  name: 'darwin Binary', browser: 'OS X'},
      {id: 'linux',   name: 'linux Binary',   browser: 'Linux'},
    ],
    archs: [
      {id: 'amd64', name: '64 bit', browser: '64'},
    ]
  }
})
