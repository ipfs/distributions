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

echo "::group::Unpack .zip and sign the binaries"
    # Find and sign executables in
    # ./tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned/
    for NEW_DIR in ./releases/*/*; do
        (! test -d "$NEW_DIR") && continue
        DIST_VERSION=$(basename "$NEW_DIR")
        DIST_NAME=$(basename $(dirname "$NEW_DIR"))
        DIST_MAC_ARCHS=$(gawk '{ print $2; }' <(grep darwin "./dists/${DIST_NAME}/build_matrix"))
        for arch in $DIST_MAC_ARCHS; do
            # create destination dir matching .tar.gz structure
            mkdir -p "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-signed/${DIST_NAME}"
            # find executable files, and process each one
            find "${WORK_DIR}/tmp/${DIST_NAME}_${DIST_VERSION}_${arch}-unsigned" -perm +111 -type f -print | while read -r file; do
                # -perm +111 will return all executables, including .sh scripts
                # so we need to skip them
                if [[ "$file" == *.sh ]]; then
                    echo "-- Skipping shell script ${file}"
                    continue
                fi

                echo "-> Processing ${file}"
                ls -hl "${file}"

                echo "-> Signing ${file}"

                # Sign with Apple's tool
                # All credentials are imported to macOS keychain
                # and will be found via TEAM_ID match
                xcrun codesign --force --verbose --display --timestamp --options=runtime --sign "$APPLE_AC_TEAM_ID" "${file}"

                # TODO: revisit switch to rcodesign once we have to generate new credentials anyway
                # if we use rcodesign if we ever swithc away from macos runner
                #rcodesign sign \
                #    --p12-file ~/.apple-certs.p12 --p12-password-file ~/.apple-certs.pass \
                #    --code-signature-flags runtime --for-notarization \
                #    "${file}"

                echo "-> Notarizing ${file}"
                # The tool (or Apple API) seems to only accept.zip, even if it is a single binary
                TMP_ZIP=$(mktemp -u -t "${DIST_NAME}_${DIST_VERSION}_${arch}-signed-for-notarization.zip")
                zip "${TMP_ZIP}" "${file}"

                # Notarize with Apple's notarytool for now (only reason we use macOS runner)
                xcrun notarytool submit --progress --keychain-profile "notarytool-profile" --wait "${TMP_ZIP}"

                # NOTE: no stappling, because it would break signatures of Mach-O Binaries (which we publish without any .app or .dmg envelope)
                # This means out binaries will rely on online notarization the first time macOS Gatewkeeper sees a new binary.

                # Verify produced blob is a-ok
                if ! xcrun spctl --assess --type install --context context:primary-signature --ignore-cache --verbose=2 "${file}"; then
                    echo "error: Signature of ${file} will not be accepted by Apple Gatekeeper!" 1>&2
                    exit 1
                fi
                #
                # TODO: revisit switching notarization to rcodesign once we have to generate new credentials anyway
                # (rcodesign uses "api key" thing which is 3 things, and codesigns appleid + app-specific password
                # and it was easier to use notarytool on macOS worker than to make rcodesign work)
                # rcodesign notary-submit --api-key-path ~/.apple-api-key --wait "${file}"


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
	    pushd "${PKG_ROOT}"
            # calculate new hashes
            NEW_CID=$(ipfs add -Qn "$PKG_NAME")
            NEW_SHA512_LINE=$(gsha512sum "$PKG_NAME")
            NEW_SHA512=$(echo "$NEW_SHA512_LINE" | gawk '{ print $1; }')
            echo "-> New $PKG_NAME"
            echo "   new CID:    $NEW_CID"
            echo "   new SHA512: $NEW_SHA512"
            # update metadata to use new hashes
            echo "$NEW_CID" > "${PKG_NAME}.cid"
            echo "$NEW_SHA512_LINE" > "${PKG_NAME}.sha512"
            gsed -i "s/${OLD_CID}/${NEW_CID}/g; s/${OLD_SHA512}/${NEW_SHA512}/g" "dist.json"
            echo "-> Completed the update of ${arch}.tar.gz for ${DIST_NAME} ${DIST_VERSION}"
	    popd
        done
    done
echo "::endgroup::"
