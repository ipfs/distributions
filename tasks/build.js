const gulp = require('gulp')
const runSequence = require('run-sequence')
const harp = require('harp')
const webpackStream = require('webpack-stream')
const del = require('del')

const config = require('./config')

gulp.task('clean', () => {
  return del(['./www'])
})

gulp.task('webpack:prod', () => {
  return gulp.src('./site/public/_js/script.js')
    .pipe(webpackStream(config.webpack.prod))
    .pipe(gulp.dest('site/'))
})

gulp.task('harp:compile', (done) => {
  harp.compile('./site', '../www', done)
})

gulp.task('copy:site', (done) => {
  return gulp.src(['./www/**/*'])
    .pipe(gulp.dest('./releases'))
})

gulp.task('build', (done) => {
  runSequence(
    ['clean', 'dist'],
    'webpack:prod',
    'harp:compile',
    'copy:site',
    'clean',
    done
  )
})
