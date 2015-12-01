const gulp = require('gulp')
const browserSync = require('browser-sync')
const reload = browserSync.reload
const harp = require('harp')
const $ = require('gulp-load-plugins')()

const makeGlob = ext => `public/**/*.${ext}`

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
gulp.task('serve', () => {
  harp.server(__dirname, {
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
    // Watch for stlye changes, tell BrowserSync to refresh main.css
    $.watch(styles, $.batch((events, done) => {
      reload('main.css', {stream: true})
      done()
    }))

    // Watch for all other changes, reload the whole page
    $.watch(others, $.batch((events, done) => {
      reload()
      done()
    }))
  })
})

gulp.task('lint', () => {
  return gulp.src([
    '*.js',
    'public/**/*.js'
  ])
    .pipe($.eslint())
    .pipe($.eslint.format())
    .pipe($.eslint.failAfterError())
})

// Default task, running `gulp` will fire up the Harp site,
// launch BrowserSync & watch files.
gulp.task('default', ['serve'])
