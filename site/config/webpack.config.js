var webpack = require('webpack')

module.exports = {
  entry: ['babel-polyfill', './public/_js/script.js'],
  output: {
    path: __dirname,
    filename: './public/build/script.js'
  },
  module: {
    loaders: [
      {
        test: /\.js$/,
        loader: 'babel',
        query: {
          cacheDirectory: true,
          presets: ['es2015']
        }
      }
    ]
  },
  plugins: [
    new webpack.NoErrorsPlugin()
  ],
  stats: {
    colors: true
  },
  devtool: 'source-map'
}
