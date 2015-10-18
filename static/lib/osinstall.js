(function(window) {

   function downloadForPlatform(userOS, platforms) {
    var userArch = userOS.architecture.toString()

    var srcp
    for (var i in platforms) {
      var p = platforms[i]
      if (p.id == 'src') {
        srcp = p
      }

      var exp = new RegExp(p.browser, 'gi')
      if (!userOS.toString().match(exp)) {
        continue
      }

      for (var i in p.archs) {
        var a = p.archs[i]
        var exp = new RegExp(a.browser, 'gi')
        if (userArch.match(exp)) {
          return a.link
        }
      }
    }

    // default to source download.
    return srcp.archs[0].link
  }

  function installHandler(dist) {
    return function(ev) {
      var userOS = window.platform.os
      var link = downloadForPlatform(userOS, dist.platforms)
      window.location.href = '/'+ dist.releaseLink +'/'+ link
      return false
    }
  }

  function setupInstallHandler(distid) {
    $.get('/releases/'+distid+'/latest/dist.json', function(dist) {
      var elem = $('#' + distid + '-install-btn')
      elem.on('click', installHandler(dist))
      console.log('setup handler for', dist.id, dist.name)
    })
  }

  var ib = window.installButtons = {}
  ib.setupInstallHandler = setupInstallHandler
  ib.downloadForPlatform = downloadForPlatform
  ib.installHandler = installHandler

})(window)
