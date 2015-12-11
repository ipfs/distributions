const gulp = require('gulp')
const $ = require('gulp-load-plugins')()
const {join} = require('path')

const mkdist = require('../scripts/mkdist')

const log = $.util.log

function fail (msg) {
  log($.util.colors.red(msg))
}

gulp.task('dist', done => {
  const {version, path: dir} = $.util.env

  if (!version) return fail('No --version provided')
  if (!dir) return fail('No --path provided')

  log('Building %s with dir %s', version, dir)

  const config = require(join(dir, 'dist.json'))
  config.version = version
  mkdist(config, done)
})
