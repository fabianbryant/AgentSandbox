#!/usr/bin/env bash
set -euo pipefail

usage () {
    echo '(* TODO *)'
    exit 0
}

SUPPORTED_AGENTS=('claude' 'grok')

list_agents() {
    echo "${SUPPORTED_AGENTS[@]}"
    exit 0
}

agent_supported() {
    supported='false'
    for agent in "${SUPPORTED_AGENTS[@]}"; do
        if [[ $agent == $1 ]]; then
            supported='true'
            break
        fi
    done
    echo $supported
}

# TODO: Add env var passthrough
# TODO: Use Docker Compose
# TODO: Create Kubernetes/Minikube manifest

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;

        -l|--list-agents)
            list_agents
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
        --debug)
            DEBUG_MODE='true'
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

        -H|--agent-home-mnt)
            AH_MOUNT_DIR="$2"
            shift 2
            ;;
        --agent-home-mnt=*)
            AH_MOUNT_DIR="${1#*=}"
            shift 1
            ;;

        -L|--dot-local-mnt)
            DL_MOUNT_DIR="$2"
            shift 2
            ;;
        --dot-local-mnt=*)
            DL_MOUNT_DIR="${1#*=}"
            shift 1
            ;;

        -R|--ro-mnt)
            RO_MOUNT_DIR="$2"
            shift 2
            ;;
        --ro-mnt=*)
            RO_MOUNT_DIR="${1$*=}"
            shift 1
            ;;

        -W|--rw-mnt)
            RW_MOUNT_DIR="$2"
            shift 2
            ;;
        --rw-mnt=*)
            RW_MOUNT_DIR="$1{#*=}"
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

DEBUG_MODE=${DEBUG_MODE:-'false'}

if [[ $DEBUG_MODE == 'true' ]]; then
    set -x
fi

DO_RUN=${DO_RUN:='false'}
DO_BUILD=${DO_BUILD:='false'}
USE_CACHE=${USE_CACHE:='false'}

AGENT=${AGENT:='grok'}
IMAGE_NAME=${IMAGE_NAME:=$AGENT-sandbox}
SHM_SIZE=${SHM_SIZE:='1g'}
TMPFS_SIZE=${TMPFS_SIZE:='256m'}

supported=$(agent_supported $AGENT)
if [[ $supported == 'false' ]]; then
    echo "Unsupported agent: $AGENT" >&2
    exit 1
fi

if [[ $DO_BUILD == 'true' ]]; then
    if [[ $USE_CACHE == 'true' ]]; then
        docker build --target=$AGENT -t=$IMAGE_NAME .
    else
        docker build --no-cache --target=$AGENT -t=$IMAGE_NAME .
    fi
fi

if [[ $DO_RUN == 'false' ]]; then
    echo 'Skipping execution. Specify --run to launch a sandbox container.' >&2
    exit 0
fi

AGENTS_DIR=${AGENTS_DIR:="$PWD/agents"}
AH_MOUNT_DIR=${AH_MOUNT_DIR:="$HOME/.${AGENT}"}
DL_MOUNT_DIR=${DL_MOUNT_DIR:="${AGENTS_DIR}/${AGENT}/.local"}
RO_MOUNT_DIR=${RO_MOUNT_DIR:="${AGENTS_DIR}/${AGENT}/share/ro"}
RW_MOUNT_DIR=${RW_MOUNT_DIR:="${AGENTS_DIR}/${AGENT}/share/rw"}

mkdir -p "${AH_MOUNT_DIR}" \
    "${DL_MOUNT_DIR}" \
    "${RO_MOUNT_DIR}" \
    "${RW_MOUNT_DIR}"

exec docker run --rm -it \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --shm-size "$SHM_SIZE" \
    --tmpfs "/tmp:rw,noexec,nosuid,size=$TMPFS_SIZE" \
    -v "${AH_MOUNT_DIR}:/home/agent/.${AGENT}" \
    -v "${DL_MOUNT_DIR}:/home/agent/.local" \
    -v "${RW_MOUNT_DIR}:/home/agent/share/rw" \
    -v "${RO_MOUNT_DIR}:/home/agent/share/ro:ro" \
    "$IMAGE_NAME" \
    "$@"
