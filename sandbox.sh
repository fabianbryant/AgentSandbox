#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: sandbox.sh [options] [--] [command ...]

Build and/or run a sandbox container from the Dockerfile in the current
directory. The default agent is grok. Nothing is built or run unless you
pass --build and/or --run. Arguments after the options replace the image
command (the grok or claude binary, or bash on the base stage).

  -h, --help
      Show this help and exit.

  -l, --list-agents
      Print the supported agent names and exit.

  --build
      Build the image. Default: do not build.
      The build target is the agent name. The tag is --image.

  --cache
      Use the Docker build cache. Default: pass --no-cache.

  --run
      Run the container. Default: do not run. Without --run the script
      exits after an optional build.

  --debug
      Trace this script with set -x. Default: off. This does not change
      the container.

  -a, --agent NAME
      Stage to build and run: base, claude, or grok. Default: grok.
      base does not mount the host directories below.

  -i, --image NAME
      Image tag to build and run. Default: <agent>-sandbox.

  -U, --agent-user NAME
      User name baked into the image at build, and the home directory
      used in the mount targets at run. Default: agent.

  -u, --uid UID
      Numeric uid passed to the build. Default: 1000.
      Used only with --build. A later --run uses the user already in
      the image.

  -g, --gid GID
      Numeric gid passed to the build. Default: 1000.
      Used only with --build.

  -c, --cpus N
      CPU limit, forwarded as docker run --cpus. Default: omit the flag.

  -m, --memory SIZE
      RAM limit. When set, --memory-swap is set to the same size, so the
      container has no swap allowance beyond that RAM. Default: omit both
      flags (unlimited).

  -p, --pids-limit N
      Maximum number of tasks in the container. Threads count.
      Default: omit the flag. Pass -1 for Docker's explicit unlimited.

  -s, --shm-size SIZE
      Cap on /dev/shm. Default: 1g.
      This is a filesystem cap. Bytes written there count against
      --memory as they are used. This script does not compare the two.

  -t, --tmpfs-size SIZE
      Cap on the /tmp tmpfs (rw,noexec,nosuid). Default: 256m.
      Same charging rule as --shm-size.

  -e, --env SPEC
      Forwarded to docker run -e. Repeatable.
      SPEC is either KEY (copy from this shell) or KEY=VALUE (set a
      literal). VALUE may contain '='.

  -d, --agents-dir PATH
      Parent of the per-agent .local and share directories.
      Default: $PWD/agents. Created on --run when the agent is not base.

  -A, --dot-agent-mnt PATH
      Host directory mounted at /home/<user>/.<agent>.
      Default: $HOME/.<agent>. This is the live login and session store
      (for grok, ~/.grok).

  -L, --dot-local-mnt PATH
      Host directory mounted at /home/<user>/.local.
      Default: <agents-dir>/<agent>/.local.
      This is a sandbox toolchain cache, not your real ~/.local.

  -R, --ro-mnt PATH
      Host directory mounted read-only at /home/<user>/ro.
      Default: <agents-dir>/<agent>/share/ro.

  -W, --rw-mnt PATH
      Host directory mounted read-write at /home/<user>/rw.
      Default: <agents-dir>/<agent>/share/rw.

  --
      End of options. Remaining arguments are the container command.
      A command that does not start with '-' does not need the '--'.

The same uppercase names can be set in the environment (AGENT, IMAGE_NAME,
SHM_SIZE, and the rest). A flag wins. If the variable is unset or empty,
the default above applies. CPUS, MEMORY, and PIDS_LIMIT have no default;
leave them unset to omit the docker flag.

Examples:
  sandbox.sh --build --run
  sandbox.sh --run
  sandbox.sh --run printenv
  sandbox.sh --run -e API_KEY
  sandbox.sh --run -e API_KEY=literal
  sandbox.sh --build --cache --agent claude --run
  sandbox.sh --build --run --agent base
  sandbox.sh --run --memory 4g --cpus 2 --pids-limit 512
EOF
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

ENV_ARGS=()

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

        -e|--env)
            ENV_ARGS+=("$2")
            shift 2
            ;;
        --env=*)
            ENV_ARGS+=("${1#--env=}")
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

for env_arg in "${ENV_ARGS[@]+"${ENV_ARGS[@]}"}"; do
    run_flags+=(-e "$env_arg")
done

exec docker run "${run_flags[@]}" "$IMAGE_NAME" "$@"
