#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"

if [[ ! $PATH =~ '.local/bin' ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

exec "$@"
