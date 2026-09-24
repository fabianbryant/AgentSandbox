#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo '(* TODO *)'
    exit 0
}

SUPPORTED_AGENTS=('base' 'claude' 'grok')

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

    echo "$supported"
}

# TODO: Add env var passthrough

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;

        -l|--list-agents)
            list_agents
            ;;

        --build)
            BUILD='true'
            shift 1
            ;;
        --cache)
            USE_CACHE='true'
            shift 1
            ;;
        --run)
            RUN='true'
            shift 1
            ;;
        --debug)
            DEBUG='true'
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

        -U|--agent-user)
            AGENT_USER="$2"
            shift 2
            ;;
        --agent-user=*)
            AGENT_USER="${1#*=}"
            shift 1
            ;;

        -u|--uid)
            AGENT_UID="$2"
            shift 2
            ;;
        --uid=*)
            AGENT_UID="${1#*=}"
            shift 1
            ;;

        -g|--gid)
            AGENT_GID="$2"
            shift 2
            ;;
        --gid=*)
            AGENT_GID="${1#*=}"
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

        -c|--cpus)
            CPUS="$2"
            shift 2
            ;;
        --cpus=*)
            CPUS="${1#*=}"
            shift 1
            ;;

        -m|--memory)
            MEMORY="$2"
            shift 2
            ;;
        --memory=*)
            MEMORY="${1#*=}"
            shift 1
            ;;

        -p|--pids-limit)
            PIDS_LIMIT="$2"
            shift 2
            ;;
        --pids-limit=*)
            PIDS_LIMIT="${1#*=}"
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

        -A|--dot-agent-mnt)
            DOT_AGENT_MOUNT_DIR="$2"
            shift 2
            ;;
        --dot-agent-mnt=*)
            DOT_AGENT_MOUNT_DIR="${1#*=}"
            shift 1
            ;;

        -L|--dot-local-mnt)
            DOT_LOCAL_MOUNT_DIR="$2"
            shift 2
            ;;
        --dot-local-mnt=*)
            DOT_LOCAL_MOUNT_DIR="${1#*=}"
            shift 1
            ;;

        -R|--ro-mnt)
            RO_MOUNT_DIR="$2"
            shift 2
            ;;
        --ro-mnt=*)
            RO_MOUNT_DIR="${1#*=}"
            shift 1
            ;;

        -W|--rw-mnt)
            RW_MOUNT_DIR="$2"
            shift 2
            ;;
        --rw-mnt=*)
            RW_MOUNT_DIR="${1#*=}"
            shift 1
            ;;

        --)
            shift 1
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

DEBUG=${DEBUG:='false'}
if [[ $DEBUG == 'true' ]]; then
    set -x
fi

RUN=${RUN:='false'}
BUILD=${BUILD:='false'}
USE_CACHE=${USE_CACHE:='false'}

AGENT=${AGENT:='grok'}
IMAGE_NAME=${IMAGE_NAME:="$AGENT-sandbox"}
AGENT_USER=${AGENT_USER:='agent'}

SHM_SIZE=${SHM_SIZE:='1g'}
TMPFS_SIZE=${TMPFS_SIZE:='256m'}

supported=$(agent_supported "$AGENT")
if [[ $supported == 'false' ]]; then
    echo "Unsupported agent: $AGENT" >&2
    exit 1
fi

if [[ $BUILD == 'true' ]]; then
    AGENT_UID=${AGENT_UID:=1000}
    AGENT_GID=${AGENT_GID:=1000}

    build_flags=(
        --build-arg "AGENT_USER=${AGENT_USER}"
        --build-arg "AGENT_UID=${AGENT_UID}"
        --build-arg "AGENT_GID=${AGENT_GID}"
    )

    if [[ $USE_CACHE != 'true' ]]; then
        build_flags+=(--no-cache)
    fi

    docker build "${build_flags[@]}" --target="$AGENT" -t="$IMAGE_NAME" .
fi

if [[ $RUN == 'false' ]]; then
    echo 'Skipping execution. Specify --run to launch a sandbox container.' >&2
    exit 0
fi

run_flags=(
    --rm -it
    --cap-drop ALL
    --security-opt no-new-privileges:true
)

if [[ -v CPUS ]]; then
    run_flags+=(--cpus "$CPUS")
fi
if [[ -v MEMORY ]]; then
    run_flags+=(
        --memory "$MEMORY"
        --memory-swap "$MEMORY"
    )
fi
if [[ -v PIDS_LIMIT ]]; then
    run_flags+=(--pids-limit "$PIDS_LIMIT")
fi

run_flags+=(
    --shm-size "$SHM_SIZE"
    --tmpfs "/tmp:rw,noexec,nosuid,size=$TMPFS_SIZE"
)

if [[ $AGENT != 'base' ]]; then
    AGENTS_DIR=${AGENTS_DIR:="$PWD/agents"}
    DOT_AGENT_MOUNT_DIR=${DOT_AGENT_MOUNT_DIR:="$HOME/.${AGENT}"}
    DOT_LOCAL_MOUNT_DIR=${DOT_LOCAL_MOUNT_DIR:="${AGENTS_DIR}/${AGENT}/.local"}
    RO_MOUNT_DIR=${RO_MOUNT_DIR:="${AGENTS_DIR}/${AGENT}/share/ro"}
    RW_MOUNT_DIR=${RW_MOUNT_DIR:="${AGENTS_DIR}/${AGENT}/share/rw"}

    mkdir -p "${DOT_AGENT_MOUNT_DIR}" \
        "${DOT_LOCAL_MOUNT_DIR}" \
        "${RO_MOUNT_DIR}" \
        "${RW_MOUNT_DIR}"

    run_flags+=(
        -v "${DOT_AGENT_MOUNT_DIR}:/home/${AGENT_USER}/.${AGENT}"
        -v "${DOT_LOCAL_MOUNT_DIR}:/home/${AGENT_USER}/.local"
        -v "${RW_MOUNT_DIR}:/home/${AGENT_USER}/rw"
        -v "${RO_MOUNT_DIR}:/home/${AGENT_USER}/ro:ro"
    )
fi

exec docker run "${run_flags[@]}" "$IMAGE_NAME" "$@"
