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
    rules: [{
      test: /\.js$/,
      exclude: /node_modules/,
      loader: 'babel-loader',
      options: {
        cacheDirectory: true,
        presets: ['@babel/preset-env']
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
