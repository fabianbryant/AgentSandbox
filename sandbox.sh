#!/usr/bin/env bash
set -euo pipefail

SUPPORTED_AGENTS=('claude' 'grok')

usage() {
  echo "usage: $0 [options] [--] [command ...]"
  exit 0
}

list_agents() {
  echo "supported agents: ${SUPPORTED_AGENTS[@]}"
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

if [[ $(agent_is_supported $AGENT) != 'true' ]]; then
  echo "Unsupported agent: $AGENT" >&2
  exit 1
fi

if [[ $BUILD == 'true' ]]; then
  NO_CACHE=${NO_CACHE='false'}
  AGENT_USER=${AGENT_USER:='agent'}
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

exec docker run "${run_flags[@]}" $IMAGE_NAME "$@"
