#!/usr/bin/env bash
set -eux

: ${TARGET:=grok}
: ${IMAGE_NAME:=$TARGET-sandbox}

docker build --target=$TARGET -t=$IMAGE_NAME .
