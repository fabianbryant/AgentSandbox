#!/usr/bin/env bash
set -euo pipefail

mkdir -p /home/agent/.local/bin

if [[ ! $PATH =~ '.local/bin' ]]; then
    export PATH="/home/agent/.local/bin:$PATH"
fi

exec "$@"
