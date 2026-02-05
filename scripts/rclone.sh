#!/usr/bin/env bash

set -e

USER=root
SERVER=web.hetzner.yorickpeterse.com
PORT=2222

upload() {
    rclone sync --verbose \
        --multi-thread-streams 8 \
        --transfers 8 \
        --metadata \
        --checksum \
        --no-update-dir-modtime \
        --sftp-host "${SERVER}" \
        --sftp-user "${USER}" \
        --sftp-port "${PORT}" \
        ${@:3} \
        "${1}" ":sftp:${2}"
}

if [[ -v CI ]]
then
    echo -e "${SSH_PRIVATE_KEY}" > deploy_key
    upload "${1}" "${2}" --sftp-key-file deploy_key
    rm deploy_key
else
    upload "${1}" "${2}"
fi
