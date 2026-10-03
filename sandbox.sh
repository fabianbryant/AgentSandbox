#!/usr/bin/env bash
set -euo pipefail

VERSION='0.1.0'
SUPPORTED_AGENTS=('base' 'claude' 'grok')
ENV_VARS=()
VOLUMES=()

usage() {
  cat <<EOF
Usage: $0 [options] [--] [command ...]

  --build
         Build the sandbox image before running. Build target is set with --agent.
         The default image tag can be overwritten with --image.

  --build-only
         Only build the sandbox image. Do not run a container.

  --debug
         Trace this script with set -x. Has no effect on the sandbox.

  --no-cache
         Disable build cache. Used only with --build or --build-only.

  -a, --agent NAME
         Stage to build when building. When running, sets image default: <agent>-sandbox
         Use --list-agents to see a list of supported agent names.

  -c, --cpus N
         Sandbox container CPU limit.

  -e, --env VAR[=VALUE]
         Set sandbox container environment variables. Repeatable.

  -g, --gid GROUP_ID
         Sandbox user group ID. Default: 1000
         Used only with --build or --build-only.

  -h, --help
         Show this help and exit.

  -H, --hostname
         Sandbox container hostname. Default: sandbox

  -i, --image
         Image tag to build or run. Default: <agent>-sandbox

  -l, --list-agents
         Print the supported agent names and exit.

  -m, --memory SIZE
         Sandbox container RAM limit.

  -N, --no-auto-mounts
         Disable automatic container volume setup.

  -p, --pids-limit N
         Maximum number of tasks for the sandbox container.

  -s, --shm-size SIZE
         Cap on /dev/shm. Default: 1g

  -t, --tmpfs-size SIZE
         Cap on the /tmp tmpfs (rw,noexec,nosuid,nodev). Default: 256m

  -u, --uid USER_ID
         Sandbox user ID, baked into the image. Default: 1000
         Used only with --build or --build-only.

  -U, --user NAME
         Sandbox user name, baked into the image. Default: agent
         Used only with --build or --build-only.

  -v, --version
         Show version info and exit.

  -V, --volume VOLUME
         Specify a sandbox container volume. Repeatable. 

  --
         End of options. Remaining arguments are the container command.
         No remaining arguments runs the image's default command.

Examples:
  ./sandbox.sh --build

  ./sandbox.sh --build-only

  ./sandbox.sh --agent claude \
    --build \
    --no-cache \
    --user claude \
    --uid 501 \
    --gid 20

  ./sandbox.sh --agent claude --env ANTHROPIC_API_KEY

  ./sandbox.sh -a grok -e XAI_API_KEY

  ./sandbox.sh -a grok -- grok login --device-auth

  ./sandbox.sh --agent base -e FOO=bar -e BAR=baz printenv

  AGENT=claude ./sandbox.sh --cpus 4 --memory 4g --pids-limit 64
EOF
  exit 0
}

version() {
  echo "AgentSandbox $VERSION"
  exit 0
}

list_agents() {
  echo "Supported agents: ${SUPPORTED_AGENTS[@]}"
  exit 0
}

agent_is_supported() {
  agent=$1
  supported='false'

  for supported_agent in "${SUPPORTED_AGENTS[@]}"; do
    if [[ $agent == $supported_agent ]]; then
      supported='true'
      break
    fi
  done

  echo $supported
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -v|--version)
      version
      ;;
    -l|--list-agents)
      list_agents
      ;;
    --debug)
      DEBUG='true'
      shift
      ;;
    --build)
      BUILD='true'
      shift
      ;;
    --build-only)
      BUILD='true'
      RUN='false'
      shift
      ;;
    --no-cache)
      NO_CACHE='true'
      shift
      ;;
    -a|--agent)
      AGENT=$2
      shift 2
      ;;
    -U|--user)
      AGENT_USER=$2
      shift 2
      ;;
    -u|--uid)
      AGENT_UID=$2
      shift 2
      ;;
    -g|--gid)
      AGENT_GID=$2
      shift 2
      ;;
    -i|--image)
      IMAGE_NAME=$2
      shift 2
      ;;
    -n|--name)
      CONTAINER_NAME=$2
      shift 2
      ;;
    -H|--hostname)
      CONTAINER_HOSTNAME=$2
      shift 2
      ;;
    -c|--cpus)
      CPUS=$2
      shift 2
      ;;
    -m|--memory)
      MEMORY=$2
      shift 2
      ;;
    -s|--shm-size)
      SHM_SIZE=$2
      shift 2
      ;;
    -t|--tmpfs-size)
      TMPFS_SIZE=$2
      shift 2
      ;;
    -p|--pids-limit)
      PIDS_LIMIT=$2
      shift 2
      ;;
    -e|--env)
      ENV_VARS+=("$2")
      shift 2
      ;;
    -V|--volume)
      VOLUMES+=("$2")
      shift 2
      ;;
    -N|--no-auto-mounts)
      AUTO_MOUNTS='false'
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Invalid option: $1" >&2
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

RUN=${RUN:='true'}
BUILD=${BUILD:='false'}

AGENT=${AGENT:='grok'}
IMAGE_NAME=${IMAGE_NAME:=$AGENT-sandbox}
AGENT_USER=${AGENT_USER:='agent'}

if [[ $(agent_is_supported $AGENT) != 'true' ]]; then
  echo "Unsupported agent: $AGENT" >&2
  exit 1
fi

if [[ $BUILD == 'true' ]]; then
  NO_CACHE=${NO_CACHE='false'}
  AGENT_UID=${AGENT_UID:=1000}
  AGENT_GID=${AGENT_GID:=1000}

  build_flags=(
    --build-arg AGENT_USER=${AGENT_USER}
    --build-arg AGENT_UID=${AGENT_UID}
    --build-arg AGENT_GID=${AGENT_GID}
  )

  if [[ $NO_CACHE == 'true' ]]; then
    build_flags+=(--no-cache)
  fi

  docker build "${build_flags[@]}" --target $AGENT -t $IMAGE_NAME .
fi

if [[ $RUN != 'true' ]]; then
  exit 0
fi

CONTAINER_NAME=${CONTAINER_NAME:=$IMAGE_NAME}
CONTAINER_HOSTNAME=${CONTAINER_HOSTNAME:='sandbox'}

run_flags=(
  --rm -it
  --name $CONTAINER_NAME
  --hostname $CONTAINER_HOSTNAME
  --cap-drop ALL
  --security-opt no-new-privileges:true
)

AUTO_MOUNTS=${AUTO_MOUNTS:='true'}

if [[ $AUTO_MOUNTS == 'true' && $AGENT != 'base' ]]; then
  AGENTS_DIR=${AGENTS_DIR:="$PWD/agents"}
  AGENT_SHARE_DIR=${AGENT_SHARE_DIR:="${AGENTS_DIR}/${AGENT}/share"}

  AGENT_CONFIG_SOURCE=${AGENT_CONFIG_SOURCE:="$HOME/.${AGENT}"}
  AGENT_CACHE_SOURCE=${AGENT_CACHE_SOURCE:="${AGENTS_DIR}/${AGENT}/.local"}
  AGENT_RO_SOURCE=${AGENT_RO_SOURCE:="${AGENT_SHARE_DIR}/ro"}
  AGENT_RW_SOURCE=${AGENT_RW_SOURCE:="${AGENT_SHARE_DIR}/rw"}

  mkdir -p "$AGENT_CONFIG_SOURCE" \
    "$AGENT_CACHE_SOURCE" \
    "$AGENT_RO_SOURCE" \
    "$AGENT_RW_SOURCE"

  run_flags+=(
    -v "${AGENT_CONFIG_SOURCE}:/home/${AGENT_USER}/.${AGENT}"
    -v "${AGENT_CACHE_SOURCE}:/home/${AGENT_USER}/.local"
    -v "${AGENT_RO_SOURCE}:/home/${AGENT_USER}/share/ro:ro"
    -v "${AGENT_RW_SOURCE}:/home/${AGENT_USER}/share/rw"
  )
fi

SHM_SIZE=${SHM_SIZE:='1g'}
TMPFS_SIZE=${TMPFS_SIZE:='256m'}

run_flags+=(
  --shm-size $SHM_SIZE
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=$TMPFS_SIZE
)

if [[ -v CPUS ]]; then
  run_flags+=(--cpus $CPUS)
fi

if [[ -v MEMORY ]]; then
  run_flags+=(
    --memory $MEMORY
    --memory-swap $MEMORY
  )
fi

if [[ -v PIDS_LIMIT ]]; then
  run_flags+=(--pids-limit $PIDS_LIMIT)
fi

for env_var in "${ENV_VARS[@]+"${ENV_VARS[@]}"}"; do
  run_flags+=(-e "$env_var")
done

for volume in "${VOLUMES[@]+"${VOLUMES[@]}"}"; do
  run_flags+=(-v "$volume")
done

exec docker run "${run_flags[@]}" $IMAGE_NAME "$@"
