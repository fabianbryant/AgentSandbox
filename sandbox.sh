#!/usr/bin/env bash
set -euo pipefail

usage () {
    echo '(* TODO *)'
    exit 0
}

# TODO: Add env var passthrough
# TODO: Use Docker Compose
# TODO: Create Kubernetes/Minikube manifest

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;

        --build)
            DO_BUILD='true'
            shift 1
            ;;
        --cache)
            USE_CACHE='true'
            shift 1
            ;;
        --run)
            DO_RUN='true'
            shift 1
            ;;

        -a|--agent)
            AGENT="$2"
            shift 2
            ;;
        --agent=*)
            AGENT="${1#*=}"
            shift 1
            ;;

        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --image=*)
            IMAGE_NAME="${1#*=}"
            shift 1
            ;;

        -s|--shm-size)
            SHM_SIZE="$2"
            shift 2
            ;;
        --shm-size=*)
            SHM_SIZE="${1#*=}"
            shift 1
            ;;

        -t|--tmpfs-size)
            TMPFS_SIZE="$2"
            shift 2
            ;;
        --tmpfs-size=*)
            TMPFS_SIZE="${1#*=}"
            shift 1
            ;;

        -d|--agents-dir)
            AGENTS_DIR="$2"
            shift 2
            ;;
        --agents-dir=*)
            AGENTS_DIR="${1#*=}"
            shift 1
            ;;

        -H|--agent-home-dir)
            AGENT_HOME_DIR="$2"
            shift 2
            ;;
        --agent-home-dir=*)
            AGENT_HOME_DIR="${1#*=}"
            shift 1
            ;;

        -l|--agent-local-dir)
            AGENT_LOCAL_DIR="$2"
            shift 2
            ;;
        --agent-local-dir=*)
            AGENT_LOCAL_DIR="${1#*=}"
            shift 1
            ;;

        -r|--ro-dir)
            READ_ONLY_DIR="$2"
            shift 2
            ;;
        --ro-dir=*)
            READ_ONLY_DIR="${1$*=}"
            shift 1
            ;;

        -w|--rw-dir)
            READ_WRITE_DIR="$2"
            shift 2
            ;;
        --rw-dir=*)
            READ_WRITE_DIR="$1{#*=}"
            shift 1
            ;;

        --)
            shift
            break
            ;;
        -*)
            echo "Invalid option: $1" >&2
            echo "Run '$0 --help' for valid options." >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

DO_RUN=${DO_RUN:='false'}
DO_BUILD=${DO_BUILD:='false'}
USE_CACHE=${USE_CACHE:='false'}

AGENT=${AGENT:='grok'}
IMAGE_NAME=${IMAGE_NAME:=$AGENT-sandbox}
SHM_SIZE=${SHM_SIZE:='1g'}
TMPFS_SIZE=${TMPFS_SIZE:='256m'}

if [[ $DO_BUILD == 'true' ]]; then
    if [[ $USE_CACHE == 'true' ]]; then
        docker build --target=$AGENT -t=$IMAGE_NAME .
    else
        docker build --no-cache --target=$AGENT -t=$IMAGE_NAME .
    fi
else
    echo 'Skipping build. Specify --build to compile the image.' >&2
fi

if [[ $DO_RUN == 'false' ]]; then
    echo 'Skipping execution. Specify --run to launch a container.' >&2
    exit 0
fi

AGENTS_DIR=${AGENTS_DIR:=$PWD/agents}
AGENT_HOME_DIR=${AGENT_HOME_DIR:=$HOME/.${AGENT}}
AGENT_LOCAL_DIR=${AGENT_LOCAL_DIR:="${AGENTS_DIR}/${AGENT}/.local"}
READ_ONLY_DIR=${READ_ONLY_DIR:="${AGENTS_DIR}/${AGENT}/share/ro"}
READ_WRITE_DIR=${READ_WRITE_DIR:="${AGENTS_DIR}/${AGENT}/share/rw"}

mkdir -p "${AGENT_HOME_DIR}" \
    "${AGENT_LOCAL_DIR}" \
    "${READ_ONLY_DIR}" \
    "${READ_WRITE_DIR}"

exec docker run --rm -it \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --shm-size "$SHM_SIZE" \
    --tmpfs "/tmp:rw,noexec,nosuid,size=$TMPFS_SIZE" \
    -v "${AGENT_HOME_DIR}:/home/agent/.${AGENT}" \
    -v "${AGENT_LOCAL_DIR}:/home/agent/.local" \
    -v "${READ_WRITE_DIR}:/home/agent/share/rw" \
    -v "${READ_ONLY_DIR}:/home/agent/share/ro:ro" \
    "$IMAGE_NAME" \
    "$@"
