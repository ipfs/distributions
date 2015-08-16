var njx = require('njx')
var fs = require('fs')

var spec = {
  template: "tmpl/index.html",
  data: { dists: {} },
}

var goipfsPath = './releases/go-ipfs/v0.3.7/dist.json'
spec.data.dists['go-ipfs'] = require(goipfsPath)

njx.render(spec, function(err, res) {
  if (err) throw err
  process.stdout.write(res)
  process.exit(0)
})
