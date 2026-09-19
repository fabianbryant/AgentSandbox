FROM ubuntu:24.04 AS base

ARG AGENT_UID=1000
ARG AGENT_GID=1000
ARG AGENT_USER=agent

# Install some useful tools and set up the agent user
RUN set -eux; \
      \
      apt-get update; \
      apt-get install -y --no-install-recommends \
        ca-certificates curl git openssh-client \
        python3 python3-pip python3-venv build-essential \
        jq ripgrep fd-find zip unzip tar \
      ;\
      ln -s /usr/bin/fdfind /usr/local/bin/fd; \
      rm -rf /var/lib/apt/lists/*; \
      \
      userdel -r ubuntu; \
      groupadd --gid ${AGENT_GID} ${AGENT_USER}; \
      useradd --uid ${AGENT_UID} \
        --gid ${AGENT_GID} \
        --create-home \
        --shell /bin/bash \
        ${AGENT_USER} \
      ;

ENV HOME=/home/agent
WORKDIR $HOME

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
