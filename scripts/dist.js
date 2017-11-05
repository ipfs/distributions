'use strict'

const fs = require('fs')
const join = require('path').join
const mkdirp = require('mkdirp')
const series = require('async').series
const each = require('async').each
const del = require('del')
const _ = require('lodash')

const log = console.log.bind(console)

function fail (msg) {
  console.error(msg)
  process.exit(1)
}

const RELEASE_PATH = join(__dirname, '..', 'releases')
const SITE_PATH = join(__dirname, '..', 'site', 'data', 'releases')
const DIST_PATH = join(__dirname, '..', 'dists')

function getVersion (type, done) {
  const p = join(DIST_PATH, type, 'current')

  fs.readFile(p, (err, version) => {
    if (err) return done(err)
    done(null, version.toString().trim())
  })
}

function writeData (type, version, done) {
  const dataPath = join(RELEASE_PATH, type, version, 'dist.json')
  const data = JSON.parse(fs.readFileSync(dataPath).toString())

  const dataTargetPath = join(SITE_PATH, type)
  series([
    mkdirp.bind(mkdirp, dataTargetPath),
    fs.writeFile.bind(fs, join(dataTargetPath, 'data.json'), JSON.stringify(data, null, 2))
  ], done)
}

function writeSiteFiles (type, done) {
  fs.stat(join(RELEASE_PATH, type), (err, stats) => {
    if (err) return done(err)

    if (stats.isDirectory() && !_.includes(['fonts'], type)) {
      getVersion(type, (err, version) => {
        if (err) return done(err)

        writeData(type, version, done)
      })
    } else {
      done()
    }
  })
}

del([
  './releases/*.html',
  './releases/css',
  './releases/build',
  './releases/releases',
  './releases/tags',
  './releases/categories'
]).then(() => {
  fs.readdir(RELEASE_PATH, (err, types) => {
    if (err) {
      return fail(err)
    }

    each(types, writeSiteFiles, (err) => {
      if (err) {
        return fail(err)
      }
      log('done')
    })
  })
})
