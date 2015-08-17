#!/usr/bin/env node
var fs = require('fs')

if (process.argv.length != 3) {
  console.log("usage: mkdist.js <version>")
  process.exit(1)
}

var oses = [
  {id: 'darwin',  name: "Mac OSX Binaries", browser:'OS X',    icon: 'apple'},
  {id: 'linux',   name: "Linux Binaries",   browser:'Linux',   icon: 'linux'},
  {id: 'openbsd', name: "OpenBSD Binaries", browser:'OpenBSD', icon: 'circle-o'},
  {id: 'freebsd', name: "FreeBSD Binaries", browser:'FreeBSD', icon: 'circle-o'},
  {id: 'windows', name: "Windows Binaries", browser:'Windows', icon: 'windows'},
]

var archs = [
  {id: '386',   name: '32 bit', browser: '32'},
  {id: 'amd64', name: '64 bit', browser: '64'},
  {id: 'arm',   name: 'ARM',    browser: 'ARM'},
]

main() // run the program.

function main() {
  var dist = require('./dist.json')
  var ver = dist.current_version = process.argv[2]
  if (ver.match(/^v/)) ver = ver.substring(1)
  dist.releaseLink = 'releases/go-ipfs/v' + ver
  var releasePath = '../../' + dist.releaseLink
  dist.platforms = []

  var dir = fs.readdirSync(releasePath)

  // add osx installer
  var f = findFile(/\.pkg$/)
  if (f) {
    dist.platforms.push({
      id: 'osxpkg',
      name: 'Mac OSX Installer (.pkg)',
      icon: 'apple',
      archs: [{
        name: 'Universal',
        link: f,
      }]
    })
  }

  // TODO: windows msi installer

  // add standard os binaries
  addOSBinaries(dir, dist.platforms)

  // add source
  dist.platforms.push({
    id: 'src',
    name: 'Source Code (.zip)',
    icon: 'archive',
    archs: [{
      name: 'src',
      link: 'go-ipfs_v'+ver+'_src.zip'
    }]
  })

  writeDist(releasePath + '/dist.json', dist)
}

function writeDist(path, dist) {
  fs.writeFileSync(path, JSON.stringify(dist, null, '    '))
  console.log('wrote', path)
}

function addOSBinaries(dir, platforms) {
  for (var osi in oses) {
    var os = oses[osi]
    var p = {
      id: os.id,
      name: os.name,
      icon: os.icon,
      archs: [],
    }

    for (var a in archs) {
      var arch = archs[a]
      var f = findFile(dir, os.id + '-' + arch.id) // e.g. darwin-amd64
      if (!f) continue // does not exist

      console.log('found', f)
      p.archs.push({
        id: arch.id,
        name: arch.name,
        link: f,
      })
    }

    if (p.archs.length > 0) {
      platforms.push(p) // do have releases for this os.
    }
  }
  return platforms
}

function findFile(dir, pattern) {
  for (var e in dir) {
    if (dir[e].match(pattern)) {
      return dir[e]
    }
  }
  return null
}
