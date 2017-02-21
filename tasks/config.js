const webpack = require('webpack')

const base = {
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
    new webpack.NoEmitOnErrorsPlugin()
  ],
  stats: {
    colors: true
  }
}

module.exports = {
  webpack: {
    dev: Object.assign({}, base, {
      watch: true,
      devtool: 'source-map'
    }),
    prod: Object.assign({}, base, {
      plugins: [
        new webpack.optimize.UglifyJsPlugin({
          compressor: {
            warnings: false
          }
        }),
        new webpack.NoEmitOnErrorsPlugin()
      ]
    })
  }
}
