#!/usr/bin/env bash

set -e
echo -e "${SSH_PRIVATE_KEY}" > deploy_key
chmod 600 deploy_key
just deploy --flags='-i deploy_key'
rm deploy_key
