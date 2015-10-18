var fs = require('fs')
var marked = require('marked')
var nunjucks = require('nunjucks')
var njmd = require('nunjucks-markdown')

var njx = nunjucks.configure('.')
njmd.register(njx, marked)

var spec = {
  template: "tmpl/index.html",
  data: { dists: {} },
}

var goipfsPath = './releases/go-ipfs/v0.3.7/dist.json'
spec.data.dists['go-ipfs'] = require(goipfsPath)

njx.render(spec.template, spec.data, function(err, res) {
  if (err) throw err
  process.stdout.write(res)
  process.exit(0)
})
