const gulp = require('gulp')
const browserSync = require('browser-sync')
const reload = browserSync.reload
const harp = require('harp')
const webpackStream = require('webpack-stream')
const $ = require('gulp-load-plugins')()
const _ = require('lodash')

const config = require('./config')

const tmpFiles = p => {
  const file = _.last(p.split('/'))
  const emacsTmp = !!file.match(/^\.#/)
  const flycheck = !!file.match(/^flycheck/)

  return emacsTmp || flycheck
}

const makeGlob = ext => `site/public/**/*.${ext}`

const styles = [
  'css',
  'sass',
  'scss',
  'less'
].map(makeGlob)

const others = [
  'html',
  'ejs',
  'jade',
  'js',
  'json',
  'md'
].map(makeGlob)

// Serve the Harp Site from the src directory
gulp.task('harp', () => {
  harp.server(`${__dirname}/../site`, {
    port: 9000
  }, () => {
    browserSync({
      proxy: 'localhost:9000',
      open: false,
      // Hide the notification. It gets annoying
      notify: {
        styles: ['opacity: 0', 'position: absolute']
      }
    })
    // Watch for stlye changes, tell BrowserSync to refresh
    $.watch(styles, $.batch((events, done) => {
      reload('style.css', {stream: true})
      done()
    }))

    // Watch for all other changes, reload the whole page
    $.watch(others, {
      ignored: tmpFiles,
      followSymlinks: false
    }, $.batch((events, done) => {
      reload()
      done()
    }))
  })
})

gulp.task('webpack', () => {
  gulp.src('./site/public/_js/script.js')
    .pipe(webpackStream(config.webpack.dev))
    .pipe(gulp.dest('site/'))
})

gulp.task('serve', ['dist', 'harp', 'webpack'])
