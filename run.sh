#!/usr/bin/env bash
set -eux

: ${TARGET:=grok}
: ${IMAGE_NAME:=$TARGET-sandbox}
: ${SHM_SIZE:=1g}
: ${TMPFS_SIZE:=256m}

mkdir -p "$HOME/.${TARGET}" \
    "$PWD/agents/${TARGET}/.local" \
    "$PWD/agents/${TARGET}/share/ro" \
    "$PWD/agents/${TARGET}/share/rw"

docker run --rm -it \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --shm-size $SHM_SIZE \
    --tmpfs "/tmp:rw,noexec,nosuid,size=$TMPFS_SIZE" \
    -v "$HOME/.${TARGET}:/home/agent/.${TARGET}" \
    -v "$PWD/agents/${TARGET}/.local:/home/agent/.local" \
    -v "$PWD/agents/${TARGET}/share/rw:/home/agent/share/rw" \
    -v "$PWD/agents/${TARGET}/share/ro:/home/agent/share/ro:ro" \
    "$IMAGE_NAME" \
    "$@"
