const $ = require('jquery')
const platform = require('platform')

function getArch (os, arch) {
  if (arch === '32' && os !== 'darwin') return '386'
  if (os === 'darwin') {
    return 'arm64' // assume Apple ARM https://github.com/ipfs/distributions/issues/840
  }
  return 'amd64'
}

function getOsName (family) {
  family = family.toLowerCase()

  if (family.match(/windows/)) return 'windows'
  if (family.match(/(os x|ios)/)) return 'darwin'
  return 'linux'
}

function getExt (os) {
  if (os === 'windows') return 'zip'
  return 'tar.gz'
}

function buildDownloadLink (id, version, os) {
  const osName = getOsName(os.family)
  const arch = getArch(osName, os.architecture)
  const ext = getExt(osName)

  return `${id}/${version}/${id}_${version}_${osName}-${arch}.${ext}`
}

module.exports = function handlePlatform () {
  $('.d-component-download-btn').each(function () {
    const elem = $(this)
    const version = elem.data('version')
    const id = elem.data('id')

    const link = buildDownloadLink(id, version, platform.os)
    let osName = getOsName(platform.os.family)
    let arch = getArch(osName, platform.os.architecture)

    if (arch === 'amd64' || arch === 'arm64') {
      arch = '64bit'
    } else {
      arch = '32bit'
    }

    if (osName === 'darwin') osName = 'macOS'

    elem.attr('href', link)
    elem.parent().find('.d-component-arch').text(`Version ${version} for ${osName} ${arch}`)
  })
}
