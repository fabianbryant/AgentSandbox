#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    exec "${AGENT_CMD}"
else
    exec "$@"
fi
