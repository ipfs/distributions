const $ = window.jQuery = require('jquery')
window.Tether = require('tether')
const Stickyfill = require('stickyfill')()
require('bootstrap')

Stickyfill.add($('.sticky')[0])
