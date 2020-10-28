# IPFS distributions

[![](https://img.shields.io/badge/made%20by-Protocol%20Labs-blue.svg?style=flat-square)](http://ipn.io)
[![](https://img.shields.io/badge/project-IPFS-blue.svg?style=flat-square)](http://ipfs.io/)
[![](https://img.shields.io/badge/freenode-%23ipfs-blue.svg?style=flat-square)](http://webchat.freenode.net/?channels=%23ipfs)
[![standard-readme compliant](https://img.shields.io/badge/standard--readme-OK-green.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
[![Dependency Status](https://david-dm.org/ipfs/distributions.svg?style=flat-square)](https://david-dm.org/ipfs/distributions)
[![Travis CI](https://travis-ci.org/ipfs/distributions.svg?branch=master)](https://travis-ci.org/ipfs/distributions)

> Source for building https://dist.ipfs.io

**Table of Contents**

- [Install](#install)
- [Usage](#usage)
    - [Adding a version](#adding-a-version)
    - [Adding a new (go) distribution](#adding-a-new-go-distribution)
    - [Publishing](#publishing)
- [Background](#background)
- [Contribute](#contribute)

## Install

Clone the repo and install the following dependencies via your favorite package manager:

* `go`
* `npm`
* `jq`
* `ipfs`

## Usage

Add a new version or a new distribution with `./dist.sh` then run `make publish` to get the new CID to publish as dist.ipfs.io.

### Adding a version

Run:

```sh
> ./dist.sh add-version <dist> <version>
```

This will add the version to `dists/<dist>/versions`, set it as the current version in `dists/<dist>/current`, and build it.

### Adding a new (go) distribution

Run:

```sh
> ./dist.sh new-go-dist <dist> <git-repo>
```

And follow the prompts.

### Publishing

In the root of the repository, run:

```sh
> make publish
```

This will build any new binaries defined by dist and the website to the `releases` dir, add it to ipfs and patch it into the existing dag for the published dist.ipfs.io. Save the hash it spits out (we'll call it `<NEW_HASH>`), that's the new hash for `dists.ipfs.io`. We also append it to a file called `versions` in the repo root (*not* checked into git).

Next, you should probably:

1. Load the dists website in your browser to make sure everything looks right: `http://127.0.0.1:8080/ipfs/<NEW_HASH>`.
2. Compare `<NEW_HASH>` with the current `dists.ipfs.io` to make sure nothing is amiss: `ipfs object diff /ipns/dist.ipfs.io /ipfs/<NEW_HASH>`

If all looks well, **pin the hash using pinbot** (#ipfs-pinbot on Freenode, ask someone if you don't have permission to do so).

Finally,

1. Commit your changes and make a PR. Specifically, the changes to `dists/<dist>/versions` and `dists/<dist>/current`.
2. File an issue on [ipfs/infrastructure](https://github.com/ipfs/infrastructure) with the hash you got from `make publish` and a link to the PR.

If you have permission, you can just merge the PR, update the DNS, and then immediately, close the issue on ipfs/infrastructure. Ping someone on IRC.

## Background

The goal is to generate a file hierarchy that looks like this:

| **File**                                                       | **Description**                                    |
| -------------------------------------------------------------- | -------------------------------------------------- |
| `releases/index.html`                                          | listing of all bundles available                   |
| `releases/<dist>`                                              | all versions of `<dist>`                           |
| `releases/<dist>/versions`                                     | textual list of all versions of `<dist>`           |
| `releases/<dist>/<version>`                                    | dist version                                       |
| `releases/<dist>/<version>/<dist>_<version>_<platform>.tar.gz` | archive for `<platform>`                           |
| `releases/<dist>/<version>/<dist>_<version>_<platform>.tar.gz.cid` | text file with CID of the archive              |
| `releases/<dist>/<version>/<dist>_<version>_<platform>.tar.gz.sha512` | text file with SHA-512 of the archive       |
| `releases/<dist>/<version>/dist.json`                          | json file describing all archives in this release. |
| `releases/<dist>/<version>/build-info`                         | information about the build and build machine      |
| `releases/<dist>/<version>/build-log-*`                        | logs from the platforms that failed to build.      |
| `releases/<dist>/<version>/results`                            | list of platforms successfully built               |

Definitions:
- `<dist>` is a distribution, meaning a program or library we release.
- `<version>` is the version of the `<dist>`.
- `<platform>` is a supported platform of `<dist>@<version>`

So for example, if we had `<dist>` `go-ipfs` and `fs-repo-migrations`, we might see a hierarchy like:

```
.
├── fs-repo-migrations
│   ├── v1.3.0
│   │   ├── build-info
│   │   ├── dist.json
│   │   ├── fs-repo-migrations_v1.3.0_darwin-386.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_darwin-amd64.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_freebsd-386.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_freebsd-amd64.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_freebsd-arm.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_linux-386.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_linux-amd64.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_linux-arm.tar.gz
│   │   ├── fs-repo-migrations_v1.3.0_windows-386.zip
│   │   ├── fs-repo-migrations_v1.3.0_windows-amd64.zip
│   │   └── results
│   └── versions
├── go-ipfs
│   ├── v0.4.9
│   │   ├── build-info
│   │   ├── build-log-freebsd-386
│   │   ├── build-log-freebsd-arm
│   │   ├── dist.json
│   │   ├── go-ipfs_v0.4.9_darwin-386.tar.gz
│   │   ├── go-ipfs_v0.4.9_darwin-amd64.tar.gz
│   │   ├── go-ipfs_v0.4.9_freebsd-amd64.tar.gz
│   │   ├── go-ipfs_v0.4.9_linux-386.tar.gz
│   │   ├── go-ipfs_v0.4.9_linux-amd64.tar.gz
│   │   ├── go-ipfs_v0.4.9_linux-arm.tar.gz
│   │   ├── go-ipfs_v0.4.9_windows-386.zip
│   │   ├── go-ipfs_v0.4.9_windows-amd64.zip
│   │   └── results
│   └── versions
└── index.html
85 directories, 943 files
```

We call this the **distribution index**, the listing of all distributions, their versions, and platform assets.

## Contribute

Issues and PRs welcome! Please [check out the issues](https://github.com/ipfs/distributions/issues).

### Want to hack on IPFS?

[![](https://cdn.rawgit.com/jbenet/contribute-ipfs-gif/master/img/contribute.gif)](https://github.com/ipfs/community/blob/master/CONTRIBUTING.md)

## License

MIT © IPFS
