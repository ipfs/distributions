const $ = window.jQuery = require('jquery')
window.Tether = require('tether')
require('bootstrap')
require('slicknav/jquery.slicknav.js')

const handlePlatform = require('./_platform')

$(() => {
  handlePlatform()

  $('#d-navbar').slicknav({
    label: '',
    closeOnClick: true,
    prependTo: '#d-header-menu'
  })
})
