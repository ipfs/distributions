#!/usr/bin/env bash
set -e

echo "::group::Store credentials to avoid GUI prompt in CI"
    xcrun notarytool store-credentials "notarytool-profile" \
        --apple-id "${APPLE_AC_USERNAME}" --team-id "${APPLE_AC_TEAM_ID}" --password "${APPLE_AC_PASSWORD}"
echo "::endgroup::"

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
        # TODO: restore dists/kubo/build_matrix (only macos for now, for faster tests)
        DIST_MAC_ARCHS=$(gawk '{ print $2; }' <(grep darwin "./dists/${DIST_NAME}/build_matrix"))
        for arch in $DIST_MAC_ARCHS; do
            # create destination dir matching .tar.gz structure
            mkdir -p "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/${DIST_NAME}"
            # find executable files, and process each one
            find "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned" -perm +111 -type f -print | while read -r file; do
                echo "-> Processing ${file}"
                ls -hl "${file}"

                echo "-> Signing ${file}"

                # TODO: we can use  rcodesign if we ever swithc away from macos runner
                rcodesign sign \
                    --p12-file ~/.apple-certs.p12 --p12-password-file ~/.apple-certs.pass \
                    --code-signature-flags runtime --for-notarization \
                    "${file}"

                echo "-> Notarizing ${file}"
                # TODO:  ugh, rcodesign uses different secrets than old tooling, and we can' generate them easily
                # rcodesign notary-submit --api-key-path ~/.apple-api-key --wait "${file}"

                # Notarize with Apple's notarytool for now (only reason we use macOS runner)
                xcrun notarytool submit --keychain-profile "notarytool-profile" --wait "${file}"

                # Verify produced blob is a-ok
                if ! xcrun spctl --assess --type install --context context:primary-signature --ignore-cache --verbose=2 "${file}"; then
                    echo "error: Signature of ${file} will not be accepted by Apple Gatekeeper!" 1>&2
                    exit 1
                fi

                # move signed binaries to a directory matching .tar.gz structure
                mv "${file}" "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/${DIST_NAME}/"
            done
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
            cd "${WORK_DIR}"
            mkdir -p "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/${DIST_NAME}"
            cd "./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/${DIST_NAME}/"
            echo "-> Signed contents"
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
