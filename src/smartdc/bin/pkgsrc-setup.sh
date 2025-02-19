#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright 2022 Joyent, Inc.
# Copyright 2023 MNX Cloud, Inc.
#

function fatal () {
    printf '%s' "$*"
    exit 1
}

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi

# If there's an existing install...
if [[ -e /opt/tools/bin/pkgin ]]; then
    # Re-bootstrap pkgsrc if requested.
    if [[ $1 == '--clean' ]]; then
        pkg_stash=$(mktemp)
        pkgin export > "$pkg_stash"
        rm -rf /opt/tools
        shift
    else
        # Don't stomp an existing install.
        printf 'pkgsrc has already been set up.\n'
        exit
    fi
fi

root="/${1}"

# Occasionally, the filename and hash will need to be updated. Refer to
# pkgsrc.smartos.org for changes. Old boostrap tars are kept around indefinitely,
# so there's no particular urgency for getting it done when a new bootstrap
# is available, but we'll want to stay relatively up to date.
BOOTSTRAP_TAR="bootstrap-trunk-tools-20230910.tar.gz"
BOOTSTRAP_SHA="23169c6b462526799a009c76c13f2be783c86851"

cd /tmp || fatal 'cd to /tmp failed'

printf 'Downloading pkgsrc bootstrap...\n'
curl -# -kO https://pkgsrc.smartos.org/packages/SmartOS/bootstrap/${BOOTSTRAP_TAR}
DOWNLOADED_SHA="$(/bin/digest -a sha1 ${BOOTSTRAP_TAR})"

if ! [[ "${BOOTSTRAP_SHA}" = "${DOWNLOADED_SHA}" ]]; then
    fatal "ERROR: pkgsrc bootstrap checksum failure"
fi

if [[ -d "$root" ]]; then
    tar -zxpf ${BOOTSTRAP_TAR} -C "${root}"
fi

if [[ -n $pkg_stash ]]; then
    pkgin -y update
    pkgin -y upgrade
    pkgin -y import "$pkg_stash"
    rm "${pkg_stash:?}"
fi

if [[ ${#root} == 1 ]]; then
    printf '\nThe pkgsrc-tools collection is now ready for use. It will be in\n'
    printf 'your PATH the next time you log in.\n'
fi
