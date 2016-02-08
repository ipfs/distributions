#### Welcome to IPFS distributions

This is the downloads website for all the official software distributions of
the [IPFS Project](https://ipfs.io). You can find all the apps, binaries,
and packages here. Every distribution has a section on this
page with,

* the distribution name and a short description
* the current version number and release date
* the software license (usually MIT)
* a download button that detects your platform
* a grid with download links for all supported platforms (os and architectures)
* `Changelog`, a link to a summary of all version changes
* `All Versions`, a link to view and download previous versions

The `All Versions` link on each distribution shows directory listings for all the available versions, and a `versions` file ([example](http://dist.ipfs.io/go-ipfs/versions)). This file can be used by tools, such as [ipfs-update](#ipfs-update), to find all the available versions and download the latest.

The directory listing of each version ([example](http://dist.ipfs.io/go-ipfs/v0.3.11)) has all the platform archives (`.zip` or `.tar.gz`), a `README.md` and a `dist.json` which describe the release for humans and machines. It is meant to be easily consumed and used by tools.

##### Code Signing

All releases are signed using [OpenPGP](http://www.openpgp.org/). You can verify this by running

```bash
$ gpg --verify go-ipfs.tar.gz.asc go-ipfs.tar.gz
```

You will need to download the public key of the release managers, which are currently,

* Friedel Ziegelmayer <dignifiedquire@gmail.com> [`E2C5 3DFE 7CBA 9864 38B9  88D9 0741 3B8A 27F5 0659`](https://pgp.mit.edu/pks/lookup?search=0xE2C53DFE7CBA986438B988D907413B8A27F50659&op=index&fingerprint=on&exact=on).

The command for this is

```bash
$ gpg --keyserver pgpkeys.mit.edu --recv-key <keyid>
```

There is also a `file.sha` file for every package that contains the `sha512` checksum
as an additional integrity check.
