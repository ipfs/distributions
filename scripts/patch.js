#!/usr/bin/env node
'use strict'

/*
 * Patch the items in the local releases dir into the current dist.ipfs.tech
 *
 * Two types of content in ./releases/:
 *   1. Dist artifacts (built by build-go.sh): releases/<distname>/<version>/
 *      These are always new, so we skip querying the remote tree for them.
 *   2. Site files (built by Hugo): index.html, fonts/, img/, etc.
 *      These are diffed against the remote, with stale files removed.
 *
 * Builds an array of operations required to patch the local files into distRoot,
 * then applies those changes via MFS (sequential, not thread-safe).
 *
 * Prints the CID of the patched dist site, for pinning to cluster and publishing.
 */

const fs = require('fs')
const path = require('path')
const all = require('it-all')
const chalk = require('chalk')
const IpfsHttpClient = require('ipfs-http-client')
const { globSource } = IpfsHttpClient
require('make-promises-safe') // exit on error

const ipfs = IpfsHttpClient({ timeout: '45m' })
const pathTo = (file) => path.join(__dirname, '..', file)

const event = new Date()
const DIST_DOMAIN = 'dist.ipfs.tech'
const MFS_DIR = `/${DIST_DOMAIN}/${DIST_DOMAIN}` + '_' + event.toISOString()
const PATCH_SRC = pathTo('releases')
const VERSIONS = pathTo('versions')
const DIST_PATH = pathTo('dists')

// Read dist names from the dists/ directory on disk.
// Used to distinguish dist directories from site files in the remote root.
function getDistNames () {
  return new Set(
    fs.readdirSync(DIST_PATH).filter(name =>
      fs.statSync(path.join(DIST_PATH, name)).isDirectory()
    )
  )
}

// Scan ./releases/ to generate ops for dist content without querying IPFS.
// build-go.sh only creates directories for versions it just built, so
// everything under releases/<distname>/ is known-new content.
function classifyDistOps (distNames, remoteRootMap) {
  const ops = []
  let entries
  try {
    entries = fs.readdirSync(PATCH_SRC)
  } catch (err) {
    return ops
  }

  for (const entry of entries) {
    if (!distNames.has(entry)) continue
    const fullPath = path.join(PATCH_SRC, entry)
    if (!fs.statSync(fullPath).isDirectory()) continue

    if (!remoteRootMap.has(entry)) {
      // Entirely new dist: add the whole directory at once
      ops.push({ action: 'add', path: `/${entry}` })
      continue
    }

    // Existing dist with new content: add version dirs, update metadata files
    for (const sub of fs.readdirSync(fullPath)) {
      const subPath = path.join(fullPath, sub)
      if (fs.statSync(subPath).isDirectory()) {
        ops.push({ action: 'add', path: `/${entry}/${sub}` })
      } else {
        ops.push({ action: 'update', path: `/${entry}/${sub}` })
      }
    }
  }

  return ops
}

// Diff site files (non-dist content) between patchRoot and distRoot.
// Unlike the old calculatePatch, this also detects removals of stale files.
// distNames is used at the root level to skip dist directories.
async function diffSiteFiles (patchRoot, distRoot, subpath, distNames, existingRemoteList) {
  const ops = []
  const remoteList = existingRemoteList || await all(ipfs.ls(distRoot + subpath))
  const remoteMap = new Map(remoteList.map(item => [item.name, item]))

  const localList = await all(ipfs.ls(patchRoot + subpath))
  const localMap = new Map(localList.map(item => [item.name, item]))

  // Items present locally: check for adds and updates
  for (const [name, localItem] of localMap) {
    if (subpath === '' && distNames.has(name)) continue
    const itemPath = `${subpath}/${name}`
    const remoteItem = remoteMap.get(name)

    if (!remoteItem) {
      ops.push({ action: 'add', path: itemPath })
      continue
    }
    if (localItem.cid.equals(remoteItem.cid)) continue

    if (localItem.type === 'dir') {
      const subOps = await diffSiteFiles(patchRoot, distRoot, itemPath, distNames)
      ops.push(...subOps)
    } else {
      ops.push({ action: 'update', path: itemPath })
    }
  }

  // Items present in remote but not locally: stale site files to remove.
  // Dist directories are never removed (they have no local counterpart
  // when their builds are skipped, but must be preserved in the DAG).
  for (const [name] of remoteMap) {
    if (subpath === '' && distNames.has(name)) continue
    if (!localMap.has(name)) {
      ops.push({ action: 'remove', path: `${subpath}/${name}` })
    }
  }

  return ops
}

async function applyPatch (ops, patchRoot, distRoot) {
  await ipfs.files.rm(MFS_DIR, { recursive: true, force: true })
  await ipfs.files.mkdir(`/${DIST_DOMAIN}`, { parents: true })
  await ipfs.files.cp(distRoot, MFS_DIR)

  // MFS files API is not thread-safe: operations must be sequential
  for (const op of ops) {
    const src = `${patchRoot}${op.path}`
    const dst = `${MFS_DIR}${op.path}`
    if (op.action === 'add') {
      await ipfs.files.mkdir(path.posix.dirname(dst), { parents: true })
      await ipfs.files.cp(src, dst)
    }
    if (op.action === 'update') {
      await ipfs.files.rm(dst)
      await ipfs.files.cp(src, dst)
    }
    if (op.action === 'remove') {
      await ipfs.files.rm(dst, { recursive: true })
    }
  }

  const root = await ipfs.files.stat(MFS_DIR)
  return root.cid.toString()
}

function logOps (ops) {
  const colors = { add: 'green', update: 'yellow', remove: 'red' }
  for (const op of ops) {
    console.log(chalk.keyword(colors[op.action] || 'white')(`- ${op.action} ${op.path}`))
  }
}

async function addFiles (localPath) {
  const res = await ipfs.add(globSource(localPath, { recursive: true }))
  return `/ipfs/${res.cid.toString()}` // ipfs.files commands expect ipfs paths in `/ipfs` style...
}

(async () => {
  console.log(`Adding ${PATCH_SRC} to IPFS`)
  const patchRoot = await addFiles(PATCH_SRC)
  console.log(`Patch root is ${patchRoot}`)

  const distRoot = await ipfs.resolve(`/ipns/${DIST_DOMAIN}`)
  console.log(`DNSLink for ${DIST_DOMAIN} is ${distRoot}`)

  const distNames = getDistNames()

  // One remote root listing serves both dist classification and site diffing
  const remoteRootList = await all(ipfs.ls(distRoot))
  const remoteRootMap = new Map(remoteRootList.map(item => [item.name, item]))

  // Dist content: ops derived from local filesystem, no remote subdir listings needed
  const distOps = classifyDistOps(distNames, remoteRootMap)

  // Site files: diff against remote with stale removal, reuse the root listing
  const siteOps = await diffSiteFiles(patchRoot, distRoot, '', distNames, remoteRootList)

  const ops = [...distOps, ...siteOps]

  console.log('Patch operations:')
  logOps(ops)
  await fs.promises.writeFile(pathTo('patch-ops.json'), JSON.stringify(ops, null, 2))
  const newRoot = await applyPatch(ops, patchRoot, distRoot)

  console.log(`Appending CID to ${VERSIONS}`)
  await fs.promises.appendFile(VERSIONS, `${newRoot}\n`)

  console.log('New root CID:')
  console.log(chalk.green(newRoot))
})()
