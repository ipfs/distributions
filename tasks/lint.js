const gulp = require('gulp')
const $ = require('gulp-load-plugins')()

gulp.task('lint', () => {
  return gulp.src([
    '*.js',
    'site/**/*.js',
    'tasks/*.js',
    'scripts/*.js'
  ])
    .pipe($.eslint())
    .pipe($.eslint.format())
    .pipe($.eslint.failAfterError())
})
