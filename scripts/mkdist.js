var fs = require('fs')

module.exports = mkdist

function mkdist (opts, cb) {
  if (!opts) throw new Error('no options given')
  if (!opts.dist) throw new Error('no dist given')
  if (!opts.dist.id) throw new Error('no dist.id given')
  if (!opts.dist.owner) throw new Error('no dist.owner given')
  if (!opts.dist.version) throw new Error('no dist.version given')
  if (!opts.path) throw new Error('no path given')
  if (!opts.platforms) throw new Error('no platforms given')
  if (!cb) cb = noopcb

  var dist = opts.dist
  var ver = dist.version
  if (ver.match(/^v/)) ver = ver.substring(1)

  dist.releaseLink = 'releases/' + dist.id + '/v' + ver
  var releasePath = opts.path + '/' + dist.releaseLink
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
        link: f
      }]
    })
  }

  // TODO: windows msi installer

  // add standard os binaries
  addOSBinaries(dir, opts.platforms, dist.platforms)

  // add source
  dist.platforms.push({
    id: 'src',
    name: 'Source Code (.zip)',
    icon: 'archive',
    archs: [{
      name: 'src',
      link: dist.id + '_v' + ver + '_src.zip'
    }]
  })

  writeDist(releasePath + '/dist.json', dist, function (err) {
    if (err) return cb(err)
    cb(null, dist)
  })
}

function writeDist (path, dist) {
  fs.writeFileSync(path, JSON.stringify(dist, null, '    '))
  console.log('wrote', path)
}

function addOSBinaries (dir, src, dst) {
  for (var osi in src.oses) {
    var os = src.oses[osi]
    var p = {
      id: os.id,
      name: os.name,
      icon: os.icon,
      archs: []
    }

    for (var a in src.archs) {
      var arch = src.archs[a]
      var f = findFile(dir, os.id + '-' + arch.id) // e.g. darwin-amd64
      if (!f) continue // does not exist

      console.log('found', f)
      p.archs.push({
        id: arch.id,
        name: arch.name,
        link: f
      })
    }

    if (p.archs.length > 0) {
      dst.push(p) // do have releases for this os.
    }
  }
  return dst
}

function findFile (dir, pattern) {
  for (var e in dir) {
    if (dir[e].match(pattern)) {
      return dir[e]
    }
  }
  return null
}

function noopcb (err) {
  if (err) throw err
}
