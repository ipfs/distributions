# IPFS distributions

[![](https://img.shields.io/badge/made%20by-Protocol%20Labs-blue.svg?style=flat-square)](http://ipn.io)
[![](https://img.shields.io/badge/project-IPFS-blue.svg?style=flat-square)](http://ipfs.io/)
[![](https://img.shields.io/badge/freenode-%23ipfs-blue.svg?style=flat-square)](http://webchat.freenode.net/?channels=%23ipfs)
[![standard-readme compliant](https://img.shields.io/badge/standard--readme-OK-green.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
[![Dependency Status](https://david-dm.org/ipfs/distributions.svg?style=flat-square)](https://david-dm.org/ipfs/distributions)
[![Travis CI](https://travis-ci.org/ipfs/distributions.svg?branch=master)](https://travis-ci.org/ipfs/distributions)
[![Circle CI](https://circleci.com/gh/ipfs/distributions.svg?style=svg)](https://circleci.com/gh/ipfs/distributions)

> Source for building https://dist.ipfs.io

## Table of Contents

- [Background](#background)
  - [distribution index versions / updates](#distribution-index-versions--updates)
- [Install](#install)
- [Usage](#usage)
- [Contribute](#contribute)
  - [Want to hack on IPFS?](#want-to-hack-on-ipfs)
- [License](#license)

## Background

The goal is to generate a file hierarchy that looks like this:

```
dist/index.html -- listing of all bundles available
dist/<dist> -- all versions of <dist>
dist/<dist>/README.md -- simple readme for <dist>
dist/<dist>/latest -- points to latest <version>
dist/<dist>/<version> -- dist version
dist/<dist>/<version>/README.md -- readme for <version> listing
dist/<dist>/<version>/<platform>.tar.gz -- archive for <platform>
```

Definitions:
- `<dist>` is a distribution, meaning a program or library we release.
- `<version>` is the version of the `<dist>`
- `<platform>` is a supported platform of `<dist>@<version>`

So for example, if we had `<dist>` `go-ipfs` and `native-app`, we might see a hierarchy like:

```
.
├── go-ipfs
│   ├── latest -> v0.3.7
│   ├── v0.3.6
│   │   ├── README.md
│   │   ├── go-ipfs_v0.3.6_darwin-386.tar.gz
│   │   ├── go-ipfs_v0.3.6_darwin-amd64.tar.gz
│   │   ├── go-ipfs_v0.3.6_linux-386.tar.gz
│   │   ├── go-ipfs_v0.3.6_linux-amd64.tar.gz
│   │   └── hashes
│   └── v0.3.7
├── index.html
└── native-app
    ├── latest -> v0.2.1
    └── v0.2.1
        ├── README.md
        ├── hashes
        ├── ipfs-native-app_v0.2.1_linux.tar.gz
        └── ipfs-native-app_v0.2.1_osx.zip

7 directories, 11 files
```

We call this the **distribution index**, the listing of all distributions, their versions, and platform assets.

Note how they each describe `<platform>` differently. This is likely to be inevitable as different platform identifiers will be used by different communities.

### distribution index versions / updates

The **distribution index** changes over time, kind of like a git repository. [Since we don't yet have commits](https://github.com/ipfs/notes/issues/23), we will just do a poor-man's versioning for the index itself. We will write all version hashes to a file `versions` in this repository.

A site like `dist.ipfs.io` or `ipfs.io/dist` would just serve the _latest_ version of the index.

## Install

```sh
https://github.com/ipfs/distributions
```

This project uses a makefile + scripts to build all the things.

```sh
make
```

should do everything.


## Usage

Each `<dist>` has a directory in the root of this repo. inside it there is a `Makefile` and other necessary scripts. Running

```
make
```

Should:
- figure out what the latest released version is (from github tags)
- figure out what versions are missing from the index
- construct the missing `<dist>/<version>` directories

## Contribute

Issues and PRs welcome! Please [check out the issues](https://github.com/ipfs/distributions/issues).

### Want to hack on IPFS?

[![](https://cdn.rawgit.com/jbenet/contribute-ipfs-gif/master/img/contribute.gif)](https://github.com/ipfs/community/blob/master/contributing.md)

## License

MIT © IPFS