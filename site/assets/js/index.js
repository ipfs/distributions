const $ = window.jQuery = require('jquery')
window.Tether = require('tether')
require('bootstrap/dist/js/bootstrap.js')
require('slicknav/dist/jquery.slicknav.js')

const handlePlatform = require('./platform')
const maybeRedirectToNewDomain = () => {
  // https://github.com/protocol/bifrost-infra/issues/2018#issue-1319432302
  const { href } = window.location
  if (href.includes('dist.ipfs.io')) {
    window.location.replace(href.replace('dist.ipfs.io', 'dist.ipfs.tech'))
  }
  if (href.includes('dist-ipfs-io')) {
    window.location.replace(href.replace('dist-ipfs-io', 'dist-ipfs-tech'))
  }
}

$(() => {
  maybeRedirectToNewDomain()
  handlePlatform()

  $('#d-navbar').slicknav({
    label: '',
    closeOnClick: true,
    appendTo: '#d-header-menu'
  })
})
