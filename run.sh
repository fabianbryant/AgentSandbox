#!/usr/bin/env bash
set -eux

: ${TARGET:=grok}
: ${IMAGE_NAME:=$TARGET-sandbox}
: ${SHM_SIZE:=1g}
: ${TMPFS_SIZE:=256m}

: ${HOST_AGENTS_DIR:=$PWD/agents}
: ${HOST_AGENT_HOME_DIR:=$HOME/.${TARGET}}

HOST_AGENT_DOT_LOCAL_DIR="${HOST_AGENTS_DIR}/${TARGET}/.local"
HOST_AGENT_SHARE_RO_DIR="${HOST_AGENTS_DIR}/${TARGET}/share/ro"
HOST_AGENT_SHARE_RW_DIR="${HOST_AGENTS_DIR}/${TARGET}/share/rw"

mkdir -p "${HOST_AGENT_HOME_DIR}" \
    "${HOST_AGENT_DOT_LOCAL_DIR}" \
    "${HOST_AGENT_SHARE_RO_DIR}" \
    "${HOST_AGENT_SHARE_RW_DIR}"

docker run --rm -it \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --shm-size $SHM_SIZE \
    --tmpfs "/tmp:rw,noexec,nosuid,size=$TMPFS_SIZE" \
    -v "${HOST_AGENT_HOME_DIR}:/home/agent/.${TARGET}" \
    -v "${HOST_AGENT_DOT_LOCAL_DIR}:/home/agent/.local" \
    -v "${HOST_AGENT_SHARE_RW_DIR}:/home/agent/share/rw" \
    -v "${HOST_AGENT_SHARE_RO_DIR}:/home/agent/share/ro:ro" \
    "$IMAGE_NAME" \
    "$@"
