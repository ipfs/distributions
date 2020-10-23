'use strict'

/*
 * Copy dist.json for the current version of each distribution to the hugo data dir.
 * Looks for a local releases/<dist>/<ver>/dist.json and fallsback to fetching the
 * current publised one from dist.ipfs.io/<dist>/<ver>/dist.json
 */

const fs = require('fs')
const del = require('del')
const join = require('path').join
const chalk = require('chalk')
const fetch = require('node-fetch')

const RELEASE_PATH = join(__dirname, '..', 'releases')
const SITE_PATH = join(__dirname, '..', 'site', 'data', 'releases')
const DIST_PATH = join(__dirname, '..', 'dists')

async function getCurrentVersion (distName) {
  const pathToCurrent = join(DIST_PATH, distName, 'current')
  const version = await fs.promises.readFile(pathToCurrent, 'utf8')
  return version.trim()
}

// For new versions, dist.json only exists locally in the releases dir per dist version.
// For everything else, defer to the published dist.json from IPFS
async function fetchDistData (distName) {
  const version = await getCurrentVersion(distName)
  const dataPath = join(RELEASE_PATH, distName, version, 'dist.json')
  let data = null
  if (fs.existsSync(dataPath)) {
    console.log(chalk.green(`- Using local dist.json for ${distName} ${version}`))
    data = JSON.parse(fs.readFileSync(dataPath).toString())
  } else {
    console.log(`- Fetching published dist.json for ${distName} ${version}`)
    const res = await fetch(`https://ipfs.io/ipns/dist.ipfs.io/${distName}/${version}/dist.json`)
    data = await res.json()
  }
  if (!data.dateUTC && data.date) {
    data.dateUTC = new Date(data.date).toUTCString()
  }
  return data
}

async function writetoHugoDataDir (distName, data) {
  const dataTargetPath = join(SITE_PATH, distName)
  await fs.promises.mkdir(dataTargetPath, { recursive: true })
  return fs.promises.writeFile(join(dataTargetPath, 'data.json'), JSON.stringify(data, null, 2))
}

async function updateHugoDataFiles () {
  console.time('Done')

  await del([
    './releases/*.html',
    './releases/css',
    './releases/build',
    './releases/releases',
    './releases/img'
  ])

  const items = await fs.promises.readdir(DIST_PATH)
  console.log(`Updating hugo data for dist website`)

  for (const distName of items) {
    const data = await fetchDistData(distName)
    await writetoHugoDataDir(distName, data)
  }

  console.timeEnd('Done')
}

updateHugoDataFiles()
