#!/usr/bin/env node
'use strict'

const fs = require('fs/promises')
const path = require('path')
const util = require('util')
const exec = util.promisify(require('child_process').exec)
require('make-promises-safe') // exit on error

const DIST_ROOT = '/ipns/dist.ipfs.io'
const CHANGE_TYPE_ADD = 0
const CHANGE_TYPE_REMOVE = 1
const CHANGE_TYPE_MOD = 2

// Set of files to skip printing diffs.
// These typically contain minified code that produce unreadable diffs.
// Fail open so we don't accidentally miss something.
const skipDiff = new Set(['site.js', 'site.css'])

async function tempDir () {
  const f = await exec('mktemp -d')
  return f.stdout.trim()
}

async function tryExec (command) {
  return exec(command).catch(e => e)
}

async function ipfsGet (cid, outputPath) {
  const dir = path.dirname(outputPath)
  await fs.mkdir(dir, { recursive: true })
  await exec(`ipfs cat ${cid} > ${outputPath}`)
}

(async () => {
  const versionsContents = await fs.readFile(path.join(__dirname, '..', 'versions'), 'utf-8')
  const cid = versionsContents.split('\n').filter(x => x).pop()

  // to produce a nice diff we'll setup two dirs and diff them recursively
  const tmpDirA = await tempDir()
  const tmpDirB = await tempDir()

  const diffResult = await exec(`ipfs object diff ${DIST_ROOT} /ipfs/${cid} --enc=json`)
  const changes = JSON.parse(diffResult.stdout).Changes
  for (const f of changes) {
    switch (f.Type) {
      case CHANGE_TYPE_ADD:
        await ipfsGet(f.After['/'], path.join(tmpDirB, f.Path))
        break
      case CHANGE_TYPE_REMOVE:
        await ipfsGet(f.Before['/'], path.join(tmpDirA, f.Path))
        break
      case CHANGE_TYPE_MOD:
        if (!skipDiff.has(f.Path)) {
          await ipfsGet(f.Before['/'], path.join(tmpDirA, f.Path))
          await ipfsGet(f.After['/'], path.join(tmpDirB, f.Path))
        }
        break
      default:
        throw new Error(`unexpected diff type ${f.Type}`)
    }
  }

  const gitDiffResult = await tryExec(`git diff --no-index ${tmpDirA} ${tmpDirB}`)
  console.log(gitDiffResult.stdout)
})()
