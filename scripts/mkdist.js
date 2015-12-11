const fs = require('fs')
const {join} = require('path')
const mkdirp = require('mkdirp')

const sitePath = join(__dirname, '..', 'site', 'public', 'releases')

module.exports = mkdist

function mkdist (opts, cb) {
  if (!opts) throw new Error('no options given')
  if (!opts.id) throw new Error('no id given')
  if (!opts.version) throw new Error('no version given')
  if (!opts.platforms) throw new Error('no platforms given')

  let ver = opts.version
  if (ver.match(/^v/)) ver = ver.substring(1)

  opts.releaseLink = `releases/${opts.id}/v${ver}`
  const releasePath = join(__dirname, '..', opts.releaseLink)
  opts.releases = []

  const dir = fs.readdirSync(releasePath)

  // add osx installer
  const f = findFile(/\.pkg$/)
  if (f) {
    opts.releases.push({
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
  opts.releases = opts.releases.concat(addOSBinaries(dir, opts.platforms))

  // add source
  opts.releases.push({
    id: 'src',
    name: 'Source Code (.zip)',
    icon: 'archive',
    archs: [{
      name: 'src',
      link: opts.id + '_v' + ver + '_src.zip'
    }]
  })

  writeDist(opts)
  cb()
}

function writeDist (dist) {
  const targetPath = join(sitePath, dist.id, dist.version)
  const targetJson = join(targetPath, '_data.json')
  const targetMd = join(targetPath, 'index.md')

  mkdirp.sync(targetPath)
  fs.writeFileSync(targetJson, JSON.stringify(dist, null, '  '))
  fs.writeFileSync(targetMd, dist.description)
}

function addOSBinaries (dir, src) {
  const dst = []
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
