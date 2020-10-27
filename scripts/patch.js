#!/usr/bin/env node
'use strict'

/*
 * Patch the items in the local releases dir into the current dist.ipfs.io
 * For each item
 *   - if it does not exist in dist, add it.
 *   - if it exists and has the same cid, skip it.
 *   - if it exists and is a file, update it.
 *   - it it exists and is a dir, recurse.
 * 
 * Builds an array of operations required to patch the local files into distRoot,
 * then applies those changes.
 * 
 * Prints the CID of the patched dist site, for pinning to cluster  and publishing.
 */

const fs = require('fs')
const path = require('path')
const all = require('it-all')
const chalk = require('chalk')
const IpfsHttpClient = require('ipfs-http-client')
const { globSource } = IpfsHttpClient

const ipfs = IpfsHttpClient()
const pathTo = (file) => path.join(__dirname, '..', file)

const DIST_DOMAIN = 'dist.ipfs.io'
const MFS_DIR = `/${DIST_DOMAIN}`
const PATCH_SRC = pathTo('releases')
const VERSIONS = pathTo('versions')

async function calculatePatch (patchRoot, distRoot, path = '', ops = []) {
  const distList = await all(ipfs.ls(distRoot + path))
  for await (const item of ipfs.ls(patchRoot + path)) {
    const itemPath = `${path}/${item.name}`
    const target = distList.find(({ name }) => name === item.name)
    if (!target) {
      ops.push({ action: 'add', path: itemPath})
      continue
    }
    if (item.cid.equals(target.cid)) {
      continue
    }
    if (item.type === 'dir') {
      await calculatePatch(patchRoot, distRoot, itemPath, ops)
    } else {
      ops.push({ action: 'update', path: itemPath})
    }
  }
  return ops
}

async function applyPatch (ops, patchRoot, distRoot) {
  await ipfs.files.rm(MFS_DIR, { recursive: true, force: true })
  await ipfs.files.cp(distRoot, MFS_DIR)
  for (const op of ops) {
    const src = `${patchRoot}${op.path}`
    const dst = `${MFS_DIR}${op.path}`
    if (op.action === 'add') {
      // console.log(`add ${src} ${dst}`)
      await ipfs.files.cp(src, dst)
    }
    if (op.action === 'update') {
      // console.log(`update ${src} ${dst}`)
      await ipfs.files.rm(dst)
      await ipfs.files.cp(src, dst)
    }
  }
  const root = await ipfs.files.stat(MFS_DIR)
  return root.cid.toString()
}

function logOps (ops) {
  for (const op of ops) {
    const color = op.action === 'add' ? 'green' : 'yellow'
    console.log(chalk.keyword(color)(`- ${op.action} ${op.path}`))
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

  // const distRoot = await ipfs.dns(DIST_DOMAIN)
  const distRoot = '/ipfs/QmTsAa6gdxmRhDEM1JCLy9uQ9HRozyqWci4LKjoi9oKxvv'
  console.log(`DNSLink for ${DIST_DOMAIN} is ${distRoot}`)

  console.log('Patch operations:')
  const ops = await calculatePatch(patchRoot, distRoot)
  logOps(ops)
  const newRoot = await applyPatch(ops, patchRoot, distRoot)

  console.log('New root CID:')
  console.log(chalk.green(newRoot))

  console.log(`Appending CID to ${VERSIONS}`)
  await fs.promises.appendFile(VERSIONS, `${newRoot}\n`)
})()
