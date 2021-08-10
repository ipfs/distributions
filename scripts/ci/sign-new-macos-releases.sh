#!/usr/bin/env bash
set -e

echo "::group::Unpack any new darwin arm64 and amd64 binaries to ./tmp"
    # ./releases/{DIST_NAME}/{DIST_VERSION}/*_darwin-${arch}.tar.gz
    # -> ./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned/
    for NEW_DIR in ./releases/*/*; do
        (! test -d "$NEW_DIR") && continue
        DIST_VERSION=$(basename "$NEW_DIR")
        DIST_NAME=$(basename $(dirname "$NEW_DIR"))
        DIST_MAC_ARCHS=$(gawk '{ print $2; }' <(grep darwin "./dists/${DIST_NAME}/build_matrix"))
        for arch in $DIST_MAC_ARCHS; do
            echo "-> Unpacking unsigned darwin_${arch}.tar.gz for name='${DIST_NAME}' and version='${DIST_VERSION}' to ./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned/"
            mkdir -p "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned"
            tar -zxvf "./releases/${DIST_NAME}/${DIST_VERSION}/${DIST_NAME}_${DIST_VERSION}_darwin-${arch}.tar.gz" -C "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned/"
        done
    done
    ls -Rhl ./tmp || echo "Nothing new in ./tmp"
echo "::endgroup::"

echo "::group::Sign and notarize the mac binaries"
    # Find and sign executables in
    # ./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned/
    for NEW_DIR in ./releases/*/*; do
        (! test -d "$NEW_DIR") && continue
        DIST_VERSION=$(basename "$NEW_DIR")
        DIST_NAME=$(basename $(dirname "$NEW_DIR"))
        DIST_MAC_ARCHS=$(gawk '{ print $2; }' <(grep darwin "./dists/${DIST_NAME}/build_matrix"))
        for arch in $DIST_MAC_ARCHS; do
            EXECUTABLES=$(jq -nc '$ARGS.positional' --args $(find "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned/" -perm +111 -type f -print))
            echo "-> Signing ${EXECUTABLES}"
            echo "{
                \"source\" : $EXECUTABLES,
                \"bundle_id\" : \"io.ipfs.dist.${DIST_NAME}\",
                \"apple_id\": {
                \"password\":  \"@env:AC_PASSWORD\"
                },
                \"sign\" :{
                \"application_identity\" : \"Developer ID Application: Protocol Labs, Inc. (7Y229E2YRL)\"
                },
                \"zip\" :{
                    \"output_path\" : \"./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed.zip\"
                }
            }" | tee | jq > "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-gon.json"
            gon -log-level=info -log-json "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-gon.json"
        done
    done
echo "::endgroup::"


echo "::group::Update changed binaries in ./releases"
    # ./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed.zip
    # -> ./releases/{DIST_NAME}/{DIST_VERSION}/*_darwin-${arch}.tar.gz
    for NEW_DIR in ./releases/*/*; do
        cd "${WORK_DIR}" # reset if changed by any 'cd' below
        (! test -d "$NEW_DIR") && continue
        DIST_VERSION=$(basename "$NEW_DIR")
        DIST_NAME=$(basename $(dirname "$NEW_DIR"))
        DIST_MAC_ARCHS=$(gawk '{ print $2; }' <(grep darwin "./dists/${DIST_NAME}/build_matrix"))
        for arch in $DIST_MAC_ARCHS; do
            echo "-> Starting the update of darwin_${arch}.tar.gz for name='${DIST_NAME}' and version='${DIST_VERSION}'"
            # unzip signed binaries to a directory matching .tar.gz structure
            cd "${WORK_DIR}"
            mkdir -p "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/${DIST_NAME}"
            cd "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/${DIST_NAME}/"
            echo "-> Unpacking gon .zip for ${arch}"
            unzip "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed.zip"
            echo "-> Unpacked contents"
            ls -Rhl "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/"
            # replace .tar.gz with one that has the same structure, but signed binaries
            PKG_NAME="${DIST_NAME}_${DIST_VERSION}_darwin-${arch}.tar.gz"
            PKG_ROOT="${WORK_DIR}/releases/${DIST_NAME}/${DIST_VERSION}"
            PKG_PATH="${PKG_ROOT}/${PKG_NAME}"
            DIST_JSON="${PKG_ROOT}/dist.json"
            # read old hashes
            OLD_CID=$(cat "${PKG_PATH}.cid")
            OLD_SHA512=$(gawk '{ print $1; }' < "${PKG_PATH}.sha512")
            echo "-> Found old $PKG_NAME"
            echo "   old CID:    $OLD_CID"
            echo "   old SHA512: $OLD_SHA512"
            echo "-> Updating $PKG_NAME"
            rm "$PKG_PATH"
            tar -czvf "${WORK_DIR}/releases/${DIST_NAME}/${DIST_VERSION}/$PKG_NAME" -C "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/" "${DIST_NAME}"
            # calculate new hashes
            NEW_CID=$(ipfs add -Qn "$PKG_PATH")
            NEW_SHA512_LINE=$(gsha512sum "$PKG_PATH")
            NEW_SHA512=$(echo "$NEW_SHA512_LINE" | gawk '{ print $1; }')
            echo "-> New $PKG_NAME"
            echo "   new CID:    $NEW_CID"
            echo "   new SHA512: $NEW_SHA512"
            # update metadata to use new hashes
            echo "$NEW_CID" > "${PKG_PATH}.cid"
            echo "$NEW_SHA512_LINE" > "${PKG_PATH}.sha512"
            gsed -i "s/${OLD_CID}/${NEW_CID}/g; s/${OLD_SHA512}/${NEW_SHA512}/g" "${PKG_ROOT}/dist.json"
            echo "-> Completed the update of ${arch}.tar.gz for ${DIST_NAME} ${DIST_VERSION}"
        done
    done
echo "::endgroup::"
