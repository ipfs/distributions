# IPFS distributions

[![](https://img.shields.io/badge/made%20by-Protocol%20Labs-blue.svg?style=flat-square)](https://protocol.ai)
[![](https://img.shields.io/badge/project-IPFS-blue.svg?style=flat-square)](https://ipfs.io/)
[![](https://img.shields.io/badge/matrix%20chat-%23lobby:ipfs.io-blue.svg?style=flat-square)](https://matrix.to/#/#lobby:ipfs.io )

> Source for building https://dist.ipfs.io

**Table of Contents**

- [IPFS distributions](#ipfs-distributions)
  - [Install](#install)
  - [Managing `golang` and `nodejs` versions](#managing-golang-and-nodejs-versions)
  - [Running in Docker](#running-in-docker)
  - [Usage](#usage)
    - [Adding a version](#adding-a-version)
    - [Adding a new (go) distribution](#adding-a-new-go-distribution)
    - [Publishing](#publishing)
  - [Background](#background)
    - [Notes on reproducible builds](#notes-on-reproducible-builds)
  - [Contribute](#contribute)
    - [Want to hack on IPFS?](#want-to-hack-on-ipfs)
  - [License](#license)

## Install

Clone the repo and use Docker via `./dockerized <cmd>` wrapper.

If you don't want to run `./dockerized` build, install
the following dependencies via your favorite package manager:

* `go`
* `npm` (v7.13.0+ with nodejs v16.2.0+)
* `jq`  (v1.6+)
* `ipfs`
* `awk`

## Managing `golang` and `nodejs` versions

There is a `.tool-versions` file for the [asdf](https://asdf-vm.com/#/) version
manager, which the Docker build environment will also use.

## Running in Docker

There is a `./dockerize` script, you can run it without arguements and be in a
shell with the correct software installed in an Ubuntu 20.04 in a directory
thats mapped to the present working directory

Note that we use host networking so you must run an IPFS daemon locally as the
build process assumes a fairly long-lived ipfs node has the CIDs (we give them
to the collab cluster to pin)

You can also do `./dockerized <COMAND>`, for instance:

```
./dockerized make clean
./dockerized ./dist.sh add-version go-ipfs v0.9.0
./dockerized make publish
```

Note that you can't use bash in the command, so 

```
./dockerized make clean && ./dist.sh go-ipfs add-version v0.9.0
# Does not work
```
and

```
./dockerized "make clean && ./dist.sh go-ipfs add-version v0.9.0"
# Does not work
```


## Usage

Add a new version or a new distribution with `./dist.sh` then let CI run `make publish` to update DNSLink at dist.ipfs.io.

### Adding a version

Run:

```sh
> ./dist.sh add-version <dist> <version>
```

This will add the version to `dists/<dist>/versions`, set it as the current version in `dists/<dist>/current`, and build it locally.

Example:
```sh
> ./dist.sh add-version fs-repo-99-to-100 v1.0.1
```

To produce a signed, **official build** for use in DNSLink at `dist.ipfs.io`:

1. Run `./dist.sh add-version` locally.
2. Commit created changes to `dists/<dist>` and open a PR against `ipfs/distributions`.
3. Wait for Github Action to finish PR build. It runs `./dockerized` build, then signs macOS binaries and spits out updated root CID at the end.
4. If everything looks good, merge PR and wait for CI running on `master` to update the DNSlink at `dist.ipfs.io`.

### Adding a new (go) distribution

Run:

```sh
> ./dist.sh new-go-dist <dist> <git-repo> [sub_package]
```

And follow the prompts.

The optional `sub_package` argument is used to specify a module within a repo.  The script looks to see if the subpackage is tagged separately from the repo by looking for `sub_package/version` tags. Example:
```sh
> ./dist.sh new-go-dist fs-repo-99-to-100 github.com/ipfs/fs-repo-migrations fs-repo-99-to-100
```

- If the distribution should not show up on the website (e.g. go-ipfs migrations) add a `no-site` file into the `dists/<repo>` folder.
- Manually create a repo-owner file
- Reminder that for submodules the version numbers will look like fs-repo-x-to-y/v1.0.0

### Publishing

To produce a CID (`<NEW_HASH>`) that includes binaries for all versions defined in `./dists/`, in the root of the repository, run:

```sh
> make publish
```

- This will build any new binaries defined by dist and the website to the `releases` dir, add it to ipfs and patch it into the existing dag for the published `/ipns/dist.ipfs.io`.
- Versions that are already present on the website will be reused, speeding up the build.
- Updated CID (`<NEW_HASH>`) will be printed at the end. That's the new hash for `dists.ipfs.io`. We also append it to a file called `versions` in the repo root (*not* checked into git).

After the local build is done, make a quick inspection:

2. Load the dists website in your browser to make sure everything looks right: `http://localhost:8080/ipfs/<NEW_HASH>`.
3. Compare `<NEW_HASH>` with the current `dists.ipfs.io` to make sure nothing is amiss: `ipfs object diff /ipns/dist.ipfs.io /ipfs/<NEW_HASH>`

Finally,

1. Commit your changes and make a PR. Specifically, the changes to `dists/<dist>/versions` and `dists/<dist>/current`.
2. Wait for [Github Action](https://github.com/ipfs/distributions/actions/) on your PR to build **signed** binaries. `<NEW_SIGNED_HASH>` will be different than one from local build.
3. Make a PR with an edit on [protocol/infra](https://github.com/protocol/infra/blob/master/dns/config/dist.ipfs.io.yaml) with `<NEW_SIGNED_HASH>` you got from the Github Action output and a link to the PR above.
   - TODO: this step may be automated in the future - see the [discussion](https://github.com/ipfs/distributions/issues/372).

If you have permission, you can just merge the PR, update the DNS, and then immediately, close the issue on ipfs/infrastructure. Ping someone on IRC.

## Background

The goal is to generate a file hierarchy that looks like this:

| **File**                                                              | **Description**                                    |
| --------------------------------------------------------------------- | -------------------------------------------------- |
| `releases/index.html`                                                 | listing of all bundles available                   |
| `releases/<dist>`                                                     | all versions of `<dist>`                           |
| `releases/<dist>/versions`                                            | textual list of all versions of `<dist>`           |
| `releases/<dist>/<version>`                                           | dist version                                       |
| `releases/<dist>/<version>/<dist>_<version>_<platform>.tar.gz`        | archive for `<platform>`                           |
| `releases/<dist>/<version>/<dist>_<version>_<platform>.tar.gz.cid`    | text file with CID of the archive                  |
| `releases/<dist>/<version>/<dist>_<version>_<platform>.tar.gz.sha512` | text file with SHA-512 of the archive              |
| `releases/<dist>/<version>/dist.json`                                 | json file describing all archives in this release. |
| `releases/<dist>/<version>/build-info`                                | information about the build and build machine      |
| `releases/<dist>/<version>/build-log-*`                               | logs from the platforms that failed to build.      |
| `releases/<dist>/<version>/results`                                   | list of platforms successfully built               |

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

### Notes on reproducible builds

Running `./dockerized make publish` will produce binaries using the same
runtime as CI. The main difference between local build and official CI one is
signing step on platforms such as `darwin` (macOS).

Signatures are attached at the end of macOS binaries, which means
`*_darwin-*.tar.gz` produced by CI will have additional bytes when compared
with local build.

## Contribute

Issues and PRs welcome! Please [check out the issues](https://github.com/ipfs/distributions/issues).

### Want to hack on IPFS?

[![](https://cdn.rawgit.com/jbenet/contribute-ipfs-gif/master/img/contribute.gif)](https://github.com/ipfs/community/blob/master/CONTRIBUTING.md)

## License

MIT © IPFS
