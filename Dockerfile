ARG AGENT_USER=agent
ARG AGENT_UID=1000
ARG AGENT_GID=1000


# Base image
FROM ubuntu:24.04 AS base

ARG AGENT_USER
ARG AGENT_UID
ARG AGENT_GID

# Install some useful tools
RUN set -eux; \
      \
      apt-get update; \
      apt-get install -y --no-install-recommends \
        ca-certificates curl git openssh-client \
        python3 python3-pip python3-venv build-essential \
        jq ripgrep fd-find zip unzip tar \
      ;\
      ln -s /usr/bin/fdfind /usr/local/bin/fd; \
      rm -rf /var/lib/apt/lists/*;

# Set up the agent user
RUN set -eux; \
      \
      userdel -r ubuntu; \
      groupadd --gid ${AGENT_GID} ${AGENT_USER}; \
      useradd --uid ${AGENT_UID} \
        --gid ${AGENT_GID} \
        --create-home \
        --shell /bin/bash \
        ${AGENT_USER} \
      ;

ENV HOME=/home/${AGENT_USER}
WORKDIR $HOME

# Set entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

USER ${AGENT_USER}
CMD ["/bin/bash"]


# Claude image
FROM base AS claude

ARG AGENT_USER

USER root
RUN set -eux; \
      \
      curl -fsSL https://claude.ai/install.sh | bash; \
      install -m 0755 $HOME/.local/bin/claude /usr/local/bin/claude; \
      /usr/local/bin/claude --version;

USER ${AGENT_USER}
CMD ["/usr/local/bin/claude"]


# Grok image
FROM base AS grok

ARG AGENT_USER

USER root
RUN set -eux; \
      \
      curl -fsSL https://x.ai/cli/install.sh | bash; \
      install -m 0755 $HOME/.grok/bin/grok /usr/local/bin/grok; \
      /usr/local/bin/grok --version;

USER ${AGENT_USER}
CMD ["/usr/local/bin/grok"]
