FROM ubuntu:25.04

# Avoid interactive prompts during build
ARG DEBIAN_FRONTEND=noninteractive

# Pinned tool versions (override at build time with --build-arg)
ARG LAZYGIT_VERSION=0.50.0
ARG GO_VERSION=1.24.3
ARG NODE_MAJOR=22
ARG TECTONIC_VERSION=0.16.9

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Fail pipelines on the first error (e.g. `curl ... | bash`) instead of only the last command.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install system packages in one layer, then clean apt cache to keep the image small.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
  python3 \
  python3-pip \
  python3-venv \
  python-is-python3 \
  git \
  gcc \
  ghostscript \
  fzf \
  fd-find \
  imagemagick \
  luarocks \
  xclip \
  curl \
  ca-certificates \
  gnupg \
  ripgrep \
  sqlite3 \
  locales \
  zsh \
  sudo \
  trash-cli \
  dotnet-sdk-8.0 \
  lynx \
  fish \
  chafa && \
  locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8 && \
  rm -rf /var/lib/apt/lists/*

# Install third-party binaries (lazygit, neovim, go) and clean up tarballs in the same layer.
RUN usermod -aG sudo ubuntu && \
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
  chsh -s "$(which zsh)" ubuntu && \
  curl -fSL -O "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
  tar xf "lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" lazygit && \
  install lazygit -D -t /usr/local/bin/ && \
  curl -fSL -O https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
  tar -C /opt -xzf nvim-linux-x86_64.tar.gz && \
  curl -fSL -O "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" && \
  tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz" && \
  curl -fSL -O "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic%40${TECTONIC_VERSION}/tectonic-${TECTONIC_VERSION}-x86_64-unknown-linux-gnu.tar.gz" && \
  tar -xzf "tectonic-${TECTONIC_VERSION}-x86_64-unknown-linux-gnu.tar.gz" tectonic && \
  install tectonic -D -t /usr/local/bin/ && \
  rm -f lazygit lazygit_*.tar.gz nvim-linux-x86_64.tar.gz "go${GO_VERSION}.linux-amd64.tar.gz" tectonic tectonic-*.tar.gz

# Install Node.js from NodeSource (Ubuntu's apt package lags behind; we want Node 22+).
# hadolint ignore=DL3008
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - && \
  apt-get install -y --no-install-recommends nodejs && \
  rm -rf /var/lib/apt/lists/*

# Install Google Chrome to back Puppeteer (used by mermaid-cli/mmdc to render diagrams).
# Its apt dependencies pull in all the shared libs headless Chromium needs.
# hadolint ignore=DL3008
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
  apt-get update && apt-get install -y --no-install-recommends google-chrome-stable && \
  rm -rf /var/lib/apt/lists/*

# Tell Puppeteer to use the system Chrome instead of downloading its own copy.
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# Python and Node global tooling.
# hadolint ignore=DL3013,DL3016
RUN pip install neovim debugpy sqlfluff --break-system-packages --no-cache-dir && \
  npm install -g \
  neovim \
  typescript \
  typescript-language-server \
  eslint_d \
  prettier \
  eslint \
  tree-sitter-cli \
  markdown-toc \
  markdownlint-cli2 \
  ast-grep \
  @mermaid-js/mermaid-cli && \
  npm cache clean --force && \
  printf '{"args":["--no-sandbox","--disable-setuid-sandbox"]}\n' > /etc/puppeteer-config.json && \
  printf '#!/bin/sh\nexec /usr/bin/mmdc -p /etc/puppeteer-config.json "$@"\n' > /usr/local/bin/mmdc && \
  chmod +x /usr/local/bin/mmdc

# Rust toolchain for root (needed by luarocks tiktoken_core and viu).
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:/usr/local/go/bin:${PATH}"

# Build root-level rust tooling; install viu globally so all users can access it.
# jsregexp is required by LuaSnip for variable/placeholder transformations.
RUN luarocks install tiktoken_core && \
  luarocks install jsregexp && \
  cargo install --root /usr/local viu

# Default to the `ubuntu` user when this image is exported and imported into WSL
# (WSL otherwise logs in as root). `wsl --import` reads this on first launch.
RUN printf '[user]\ndefault=ubuntu\n' > /etc/wsl.conf

USER ubuntu
WORKDIR /home/ubuntu

# Rust toolchain for the ubuntu user (used to build eza).
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Dedicated Python venv for Neovim's python3 provider (config sets
# g:python3_host_prog to ~/.nvim_python/bin/python).
RUN python3 -m venv ~/.nvim_python && \
  ~/.nvim_python/bin/pip install --no-cache-dir --upgrade pip pynvim

# Oh My Zsh + spaceship prompt + plugins.
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v1.2.1/zsh-in-docker.sh)" -- \
  -t https://github.com/denysdovhan/spaceship-prompt \
  -a 'SPACESHIP_PROMPT_ADD_NEWLINE="false"' \
  -a 'SPACESHIP_PROMPT_SEPARATE_LINE="true"' \
  -p git \
  -p https://github.com/zsh-users/zsh-autosuggestions \
  -p https://github.com/zsh-users/zsh-completions

# Dotnet formatter, shell config, personal neovim config, and the eza build.
# OSC52 clipboard block is appended to the cloned config: copy goes through OSC52
# (works headless: docker/ssh/WSL); paste reads Neovim's own register instead of
# querying the terminal, which would otherwise hang on terminals that ignore
# OSC52 read-back.
RUN dotnet tool install -g csharpier && \
  echo "export PATH=$PATH:/usr/local/go/bin:/opt/nvim-linux-x86_64/bin:$HOME/.cargo/bin:$HOME/.dotnet/tools" >> ~/.zshrc && \
  echo "alias ls='eza --across --icons --git --git-repos -lahg'" >> ~/.zshrc && \
  git clone --depth 1 https://github.com/FrodeUlr/NvimLazyVim.git ~/.config/nvim && \
  mkdir -p ~/.config/nvim/lua/config && \
  printf '%s\n' \
  '' \
  'local osc52 = require("vim.ui.clipboard.osc52")' \
  'vim.g.clipboard = {' \
  '  name = "OSC 52",' \
  '  copy = {' \
  '    ["+"] = osc52.copy("+"),' \
  '    ["*"] = osc52.copy("*"),' \
  '  },' \
  '  paste = {' \
  '    ["+"] = function() return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") } end,' \
  '    ["*"] = function() return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") } end,' \
  '  },' \
  '}' \
  >> ~/.config/nvim/lua/config/options.lua && \
  ~/.cargo/bin/cargo install eza

ENTRYPOINT ["tail", "-f", "/dev/null"]
