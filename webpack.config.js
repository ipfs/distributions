'use strict'

const webpack = require('webpack')
const path = require('path')

module.exports = {
  entry: [
    'babel-polyfill',
    './site/assets/js/index.js'
  ],
  output: {
    path: path.resolve(__dirname, 'site', 'static'),
    filename: 'site.js'
  },
  module: {
    loaders: [{
      test: /\.js$/,
      exclude: /node_modules/,
      loader: 'babel-loader',
      query: {
        cacheDirectory: true,
        presets: ['es2015']
      }
    }]
  },
  plugins: [
    new webpack.NoEmitOnErrorsPlugin()
  ],
  stats: {
    colors: true
  }
}
