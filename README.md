# AgentSandbox

Run AI agents from within a sandboxed Docker container.

An agent is a Dockerfile stage built `FROM base`, plus its stage name in `SUPPORTED_AGENTS` in `sandbox.sh`. The stage `CMD` is the command the container runs by default. `base` is the shared image: a user, a shell, and common tools. This repository includes a couple example stages. `./sandbox.sh --list-agents` prints the names already wired up. Add any other agent the same way.

## Requirements

- Bash
- Docker
- The CLI for the agent you want to run

## Add an agent

1. Add a stage to the Dockerfile. The stage name is the agent name.

```dockerfile
FROM base as <agent>

ARG AGENT_USER

USER root
RUN set -eux; \
    # install the agent CLI onto PATH
    <agent> --version

USER ${AGENT_USER}
CMD ["<agent>"]
```

2. Append that stage to `SUPPORTED_AGENTS` in `sandbox.sh`.

3. Build and run it from the directory containing the Dockerfile. The build context is the current directory.

```bash
./sandbox.sh --agent=<agent> --build
```

Config, cache, and share directories are created from the agent name, so each agent keeps its own state on the host.

## Usage

### Build and run:

```bash
./sandbox.sh --agent=<agent> --build
```

### Build only:

```bash
./sandbox.sh --agent=<agent> --build-only
```

### Run only:

```bash
./sandbox.sh --agent=<agent>
```

### Run commands

By default, running a container via `sandbox.sh` runs that image's `CMD`. `base` runs `bash`. An agent stage runs the command you set,
usually its CLI. To override this, specify a command to run:

```bash
./sandbox.sh --agent <agent> printenv

./sandbox.sh --agent <agent> -- <agent> --version

./sandbox.sh --agent <agent> -- bash
```

`--` ends options parsing.

### Environment and volumes

Typically, you will want to set an environment variable for AI agent authentication. A name alone forwards that variable from the host:

```bash
./sandbox.sh --agent <agent> --env API_KEY
```

Multiple environment variables can be set with repeated use of `-e`/`--env`:

```bash
./sandbox.sh --agent <agent> \
    -e API_KEY \
    -e FOO=bar \
    -e BAR=baz
```

Arbitrary volume mounts can be specified similarly using `-V`/`--volume`:

```bash
./sandbox.sh --agent claude --env ANTHROPIC_API_KEY \
    -V /path/to/repo/to/share/with/agent:/path/inside/container \
    -V /path/to/other/repo/but/read-only:/path/inside/sandbox:ro
```

## Auto Mounts

Automatic mounts are enabled by default for every agent stage. `base` skips them. Turn them off with `-N`/`--no-auto-mounts` or
`NO_AUTO_MOUNTS='true'`.

`sandbox.sh` creates each host directory when it is missing, then mounts it:

| Volume variable       | Default host path             | Container path          | Mode |
| --------------------- | ----------------------------- | ----------------------- | ---- |
| `AGENT_CONFIG_SOURCE` | `$HOME/.<agent>`              | `/home/<user>/.<agent>` | rw   |
| `AGENT_CACHE_SOURCE`  | `<agents-dir>/<agent>/.local` | `/home/<user>/.local`   | rw   |
| `AGENT_RO_SOURCE`     | `<agent-share-dir>/ro`        | `/home/<user>/share/ro` | ro   |
| `AGENT_RW_SOURCE`     | `<agent-share-dir>/rw`        | `/home/<user>/share/rw` | rw   |

`<agents-dir>` is `AGENTS_DIR` (default `$PWD/agents`). `<agent-share-dir>` is `$AGENT_SHARE_DIR` (default `<agents-dir>/<agent>/share`).
`<user>` is `AGENT_USER` (default `agent`). The account inside the image is set at build time with `--user`. At run time, that same name is the home path for these mounts.

The config mount is the `.<agent>` directory, so login state stays on the host. The cache mount is `.local`. The share mounts are a
read-only `ro` direcotry and a read-write `rw` directory. Mounts pass with `-V` are added in addition to these.

## Container defaults

Every run uses `--rm` and `it`, drops all capabilities, and sets `no-new-privileges`. `/dev/shm` is capped with `--shm-size` (default `1g`). `/tmp` is a tmpfs mounted `rw,noexec,nosuid,nodev`, capped with `--tmpfs-size` (default `256m`). When `--memory` is set, swap is capped to that same size.

## Flags and Configuration

Note: Flags override environment variables.

| Variable            | Flag                  | Default                      | Build | Run | Description                   |
| ------------------- | --------------------- | ---------------------------- |:-----:|:---:| ----------------------------- |
| -                   | -h, --help            | -                            |       |     | show help                     |
| -                   | -v, --version         | -                            |       |     | show version                  |
| -                   | -l, --list-agents     | -                            |       |     | list supported agents         |
| DEBUG               | --debug               | 'false'                      |       |     | trace the sandbox.sh script   |
| RUN                 |                       | 'true'                       |       | x   | run a container               |
| BUILD               | --build, --build-only | 'false'                      | x     | x   | build an image                |
| NO_CACHE            | --no-cache            | 'false'                      | x     |     | disable build cache           |
| AGENT               | -a, --agent           | grok                         | x     | x   | target agent                  |
| IMAGE_NAME          | -i, --image           | \<agent>-sandbox             | x     | x   | image to build or run         |
| AGENT_USER          | -U, --user            | agent                        | x     | x   | container user                |
| AGENT_UID           | -u, --uid             | 1000                         | x     |     | container user UID            |
| AGENT_GID           | -g, --gid             | 1000                         | x     |     | container user GID            |
| CONTAINER_NAME      | -n, --name            | \<agent>-sandbox             |       | x   | name of container             |
| CONTAINER_HOSTNAME  | -H, --hostname        | sandbox                      |       | x   | container hostname            |
| CPUS                | -c, --cpus            | -                            |       | x   | container CPU limit           |
| MEMORY              | -m, --memory          | -                            |       | x   | container RAM limit           |
| PIDS_LIMIT          | -p, --pids-limit      | -                            |       | x   | container PID limit           |
| SHM_SIZE            | -s, --shm-size        | 1g                           |       | x   | cap on /dev/shm               |
| TMPFS_SIZE          | -t, --tmpfs-size      | 256m                         |       | x   | cap on /tmp tmpfs             |
| -                   | -e, --env             | -                            |       | x   | environment variable          |
| -                   | -V, --volume          | -                            |       | x   | volume mount                  |
| NO_AUTO_MOUNTS      | -N, --no-auto-mounts  | 'false'                      |       | x   | disable automounted volumes   |
| AGENTS_DIR          | -                     | $PWD/agents                  |       | x   | agents data parent dir        |
| AGENT_SHARE_DIR     | -                     | \<agents-dir>/\<agent>/share |       | x   | agent share parent dir        |
| AGENT_CONFIG_SOURCE | -                     | $HOME/.\<agent>              |       | x   | src dir for config volume     |
| AGENT_CACHE_SOURCE  | -                     | \<agents-dir>/.local         |       | x   | src dir for cache volume      |
| AGENT_RO_SOURCE     | -                     | \<agent-share-dir>/ro        |       | x   | src dir for read-only volume  |
| AGENT_RW_SOURCE     | -                     | \<agent-share-dir>/rw        |       | x   | src dir for read-write volume |
