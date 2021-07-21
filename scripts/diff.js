#!/usr/bin/env node
'use strict'

const spawn = require('child_process').spawn
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

async function ipfsGet (cid, outputPath) {
  const dir = path.dirname(outputPath)
  await fs.mkdir(dir, { recursive: true })
  await exec(`ipfs get -o ${outputPath} ${cid}`)
}

// spawn a subprocess, resolving the ChildProcess but not rejecting if exit code != 0
async function spawnAsync (command, args, options = {}) {
  const proc = spawn(command, args, options)
  const stdoutChunks = []
  const stderrChunks = []
  return new Promise((resolve, reject) => {
    proc.stdout.on('data', d => stdoutChunks.push(d))
    proc.stderr.on('data', d => stderrChunks.push(d))
    proc.on('exit', (code) => resolve({
      code: code,
      stdout: Buffer.concat(stdoutChunks).toString(),
      stderr: Buffer.concat(stderrChunks).toString()
    }))
    proc.on('error', err => reject(err))
  })
}

(async () => {
  const versionsContents = await fs.readFile(path.join(__dirname, '..', 'versions'), 'utf-8')
  const cid = versionsContents.split('\n').filter(x => x).pop()

  // to produce a nice diff we'll setup two dirs and diff them recursively
  const tmpDir = await tempDir()
  const dirA = path.join(tmpDir, 'a')
  await fs.mkdir(dirA, { recursive: true })
  const dirB = path.join(tmpDir, 'b')
  await fs.mkdir(dirB, { recursive: true })

  const ipfsDiffResult = await exec(`ipfs object diff ${DIST_ROOT} /ipfs/${cid} --enc=json`)
  const changes = JSON.parse(ipfsDiffResult.stdout).Changes
  var skipped = []
  for (const f of changes) {
    switch (f.Type) {
      case CHANGE_TYPE_ADD:
        await ipfsGet(`${cid}/${f.Path}`, path.join(dirB, f.Path))
        break
      case CHANGE_TYPE_REMOVE:
        await ipfsGet(`${DIST_ROOT}/${f.Path}`, path.join(dirA, f.Path))
        break
      case CHANGE_TYPE_MOD:
        if (skipDiff.has(f.Path)) {
          skipped.push(f.Path)
        } else {
          await ipfsGet(`${cid}/${f.Path}`, path.join(dirB, f.Path))
          await ipfsGet(`${DIST_ROOT}/${f.Path}`, path.join(dirA, f.Path))
        }
        break
      default:
        throw new Error(`unexpected diff type ${f.Type}`)
    }
  }

  const diffResult = await spawnAsync('diff', [
    '--new-file',
    '-u',
    '--recursive',
    // this changes on every build, so just adds noise, which is why we ignore it
    '--ignore-matching-lines', '^\\s*<lastBuildDate>.*</lastBuildDate>\\s*',
    'a',
    'b'
  ], { cwd: tmpDir })

  if (diffResult.code === 2) {
    throw new Error(`unexpected error from diff: ${diffResult.stderr}`)
  }

  const noDifferences = diffResult.code === 0

  const diffMarkdownLines = []
  if (noDifferences) {
    diffMarkdownLines.push('This change produced no new differences in built artifacts.')
  } else {
    diffMarkdownLines.push('## Diff of Changes', '')

    if (skipped.length > 0) {
      diffMarkdownLines.push('The following files changed but will not show diffs, because the diffs would be unreadable:')
      const unreadable = new Set()
      skipped.forEach(f => unreadable.add(`* ${f}`))
      diffMarkdownLines.push(...unreadable)
      diffMarkdownLines.push('')
    }

    diffMarkdownLines.push(...[
      '```diff',
      diffResult.stdout,
      '```'
    ])
  }

  console.log(diffMarkdownLines.join('\n'))
})()
