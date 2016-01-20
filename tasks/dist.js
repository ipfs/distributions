const gulp = require('gulp')
const $ = require('gulp-load-plugins')()
const fs = require('fs')
const {join} = require('path')
const mkdirp = require('mkdirp')
const {series, each} = require('async')
const del = require('del')

const log = $.util.log

function fail (msg) {
  log($.util.colors.red(msg))
  process.exit(1)
}

const RELEASE_PATH = join(__dirname, '..', 'releases')
const SITE_PATH = join(__dirname, '..', 'site', 'public', 'releases')
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
    fs.writeFile.bind(fs, join(dataTargetPath, '_data.json'), JSON.stringify(data, null, 2)),
    fs.writeFile.bind(fs, join(dataTargetPath, 'index.md'), data.description)
  ], done)
}

function writeSiteFiles (type, done) {
  fs.stat(join(RELEASE_PATH, type), (err, stats) => {
    if (err) return done(err)

    if (stats.isDirectory()) {
      getVersion(type, (err, version) => {
        if (err) return done(err)

        writeData(type, version, done)
      })
    } else {
      done()
    }
  })
}

gulp.task('clean:release:site', () => {
  return del([
    './releases/*.html',
    './releases/css',
    './releases/build',
    './releases/releases'
  ])
})

gulp.task('dist', ['clean:release:site'], done => {
  fs.readdir(RELEASE_PATH, (err, types) => {
    if (err) return fail(err.msg)

    each(types, writeSiteFiles, done)
  })
})
