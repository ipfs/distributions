const $ = require('jquery')
const platform = require('platform')

function getArch (os, arch) {
  if (arch === '32' && os !== 'darwin') return '386'
  return 'amd64'
}

function getOsName (family) {
  family = family.toLowerCase()

  if (family.match(/windows/)) return 'windows'
  if (family.match(/(os x|ios)/)) return 'darwin'
  return 'linux'
}

function buildDownloadLink (id, version, os) {
  const osName = getOsName(os.family)
  const arch = getArch(osName, os.architecture)

  return `${id}/${version}/${id}_${version}_${osName}-${arch}.zip`
}

module.exports = function run () {
  $('.d-component-download-btn').each(function () {
    const elem = $(this)
    const version = elem.data('version')
    const id = elem.data('id')

    const link = buildDownloadLink(id, version, platform.os)
    let osName = getOsName(platform.os.family)
    let arch = getArch(osName, platform.os.architecture)

    if (arch === 'amd64') {
      arch = '64bit'
    } else {
      arch = '32bit'
    }

    if (osName === 'darwin') osName = 'OS X'

    elem.attr('href', link)
    elem.parent().find('.d-component-arch').text(`Version ${version} for ${osName} ${arch}`)
  })
}
