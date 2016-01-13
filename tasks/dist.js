const gulp = require('gulp')
const $ = require('gulp-load-plugins')()
const fs = require('fs')
const {join} = require('path')
const _ = require('lodash')
const mkdirp = require('mkdirp')
const async = require('async')

const log = $.util.log

function fail (msg) {
  log($.util.colors.red(msg))
  process.exit(1)
}

const RELEASE_PATH = join(__dirname, '..', 'releases')
const SITE_PATH = join(__dirname, '..', 'site', 'public', 'releases')

function getVersion (type, done) {
  const p = join(RELEASE_PATH, type, 'versions')

  fs.readFile(p, (err, versions) => {
    if (err) return done(err)
    done(null, _(versions.toString().split('\n')).compact().last())
  })
}

function writeData (type, version, done) {
  const dataPath = join(RELEASE_PATH, type, version, 'dist.json')
  const data = JSON.parse(fs.readFileSync(dataPath).toString())

  const dataTargetPath = join(SITE_PATH, type)
  async.series([
    mkdirp.bind(mkdirp, dataTargetPath),
    fs.writeFile.bind(fs, join(dataTargetPath, '_data.json'), JSON.stringify(data, null, 2)),
    fs.writeFile.bind(fs, join(dataTargetPath, 'index.md'), data.description)
  ], done)
}

function writeSiteFiles (type, done) {
  getVersion(type, (err, version) => {
    if (err) return done(err)

    writeData(type, version, done)
  })
}

gulp.task('dist', done => {
  fs.readdir(RELEASE_PATH, (err, types) => {
    if (err) return fail(err.msg)

    async.each(types, writeSiteFiles, done)
  })
})
