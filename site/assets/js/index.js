const $ = window.jQuery = require('jquery')
window.Tether = require('tether')
require('bootstrap/dist/js/bootstrap.js')
require('slicknav/dist/jquery.slicknav.js')

const handlePlatform = require('./platform')

$(() => {
  handlePlatform()

  $('#d-navbar').slicknav({
    label: '',
    closeOnClick: true,
    prependTo: '#d-header-menu'
  })
})
