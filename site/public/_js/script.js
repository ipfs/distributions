const $ = window.jQuery = require('jquery')
window.Tether = require('tether')
const Stickyfill = require('stickyfill')()
require('bootstrap')
require('bootstrap-offcanvas/dist/js/bootstrap.offcanvas.js')

Stickyfill.add($('.sticky')[0])
