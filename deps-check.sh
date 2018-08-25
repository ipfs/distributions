#!/bin/bash

function fail() {
	printf $txtred%s$txtnon\\n "$*"
	exit 1
}

(ipfs version > /dev/null 2>&1) || (fail "Missing ipfs, please install it :-)")
(awk --version > /dev/null 2>&1) || (fail "Missing awk, please install it")
(date | shasum -a 512 - > /dev/null 2>&1) || (fail "Missing shasum with sha512 support, please install it")

(hugo version > /dev/null 2>&1) || (fail "Missing hugo, please see https://gohugo.io/")

(node --version > /dev/null 2>&1) || (fail "Missing node.js, please see https://nodejs.org/")

(npm --version > /dev/null 2>&1) || (fail "Missing npm, please see https://npmjs.com/")

(yarn --version > /dev/null 2>&1) || (fail "Missing yarn, please install with `npm i -g yarn`")

exec yarn
