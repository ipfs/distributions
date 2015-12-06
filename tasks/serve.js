const gulp = require('gulp')
const browserSync = require('browser-sync')
const reload = browserSync.reload
const harp = require('harp')
const webpack = require('webpack')
const webpackStream = require('webpack-stream')
const $ = require('gulp-load-plugins')()

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

gulp.task('webpack', () => {
  gulp.src('./site/public/_js/script.js')
    .pipe(webpackStream({
      watch: true,
      entry: [
        'babel-polyfill',
        './site/public/_js/script.js'
      ],
      output: {
        path: __dirname,
        filename: './public/build/script.js'
      },
      module: {
        loaders: [{
          test: /\.js$/,
          exclude: /node_modules/,
          loader: 'babel',
          query: {
            cacheDirectory: true,
            presets: ['es2015']
          }
        }]
      },
      plugins: [
        new webpack.NoErrorsPlugin()
      ],
      stats: {
        colors: true
      },
      devtool: 'source-map'
    }))
    .pipe(gulp.dest('site/'))
})

gulp.task('serve', ['harp', 'webpack'])
