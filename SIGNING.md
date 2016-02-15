# Signing and Security

In order to ensure that downloaded binaries are not compromised we provide
two ways of checking the integrity of the downloaded files.

In the following the reference to "tarball" means either a `zip` or `tar.gz` file
depending on the target operating system.
If not stated otherwise "key" refers to a public/private key pair usable for public
key cryptography.

## 1. `SHA512` Checksum

After the tarball was created, [`gpg`](https://gnupg.org/) is used to generate
the `SHA512` checksum of the tarball and put into a file called `$original_file.sha`.
The command for doing this is

```bash
$ gpg --print-md SHA512 $original_file> > $original_file.sha
```

## 2. OpenPGP Compatible ASCII Armored Detached Signatures

After the tarball is generated it is signed using one of the trusted developer keys.
From that an OpenPGP compatible ASCII armored detached signature is created and
put into a file `$original_file.asc`.
The command for doing this is

```bash
$ gpg --armor --output $original_file.asc --detach-sig $original_file
```

## Trusted Developer Keys

These keys are the ones used to sign tarballs and used to verify their integrity.

### Required properties of the keys

* The private key MUST be stored on seperate hardware than the computer used to sign
  the release. For convenience something like a [YubiKey](https://www.yubico.com/)
  is recommended.
* The key must have a length of at least `2048` bits and of type RSA.
* The public key MUST be uploaded to https://pgp.mit.edu/.
* The full fingerprint MUST be listed on the distributions page.

### Obtaining the public keys for verification

The keys fingerprints are listed on the distributions page and the public keys
can be downloaded from https://pgp.mit.edu/ using

```bash
$ gpg --keyserver pgpkeys.mit.edu --recv-key $figerprint
```

## Further Reading

* [Apache Release Signing Document](https://www.apache.org/dev/release-signing.html)
