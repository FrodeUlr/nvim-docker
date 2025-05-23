FROM ubuntu:25.04

RUN apt-get update && apt-get install -y \
  python3 \
  python3-pip \
  python3-venv \
  python-is-python3 \
  git \
  gcc \
  fzf \
  fd-find \
  luarocks \
  xclip \
  curl \
  ripgrep \
  nodejs \
  npm \
  sqlite3 \
  locales \
  zsh \
  sudo \
  dotnet-sdk-8.0 \
  lynx \
  fish \
  chafa && \
  locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN usermod -aG sudo ubuntu && \
  echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
  wget --progress=dot:giga https://github.com/jesseduffield/lazygit/releases/download/v0.50.0/lazygit_0.50.0_Linux_x86_64.tar.gz && \
  tar xf lazygit_0.50.0_Linux_x86_64.tar.gz lazygit && \
  install lazygit -D -t /usr/local/bin/ && \
  chsh -s "$(which zsh)" && \
  wget --progress=dot:giga https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
  tar -C /opt -xzf nvim-linux-x86_64.tar.gz && \
  sh -c "$(wget --progress=dot:giga https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
  wget --progress=dot:giga https://go.dev/dl/go1.24.3.linux-amd64.tar.gz && \
  tar -C /usr/local -xzf go1.24.3.linux-amd64.tar.gz && \
  pip install neovim debugpy sqlfluff --break-system-packages --no-cache-dir && \
  npm install -g neovim typescript typescript-language-server eslint_d prettier eslint \
  tree-sitter-cli markdown-toc markdownlint-cli2 prettier ast-grep && \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

RUN echo "export PATH=$PATH:/root/.cargo/bin" >> /root/.bashrc && \
  luarocks install tiktoken_core && \
  cargo install viu

USER ubuntu
WORKDIR /home/ubuntu

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN sh -c "$(wget --progress=dot:giga -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.1/zsh-in-docker.sh)" -- \
  -t https://github.com/denysdovhan/spaceship-prompt \
  -a 'SPACESHIP_PROMPT_ADD_NEWLINE="false"' \
  -a 'SPACESHIP_PROMPT_SEPARATE_LINE="true"' \
  -p git \
  -p https://github.com/zsh-users/zsh-autosuggestions \
  -p https://github.com/zsh-users/zsh-completions

RUN dotnet tool install -g csharpier && \
  echo "export PATH=$PATH:/usr/local/go/bin:/opt/nvim-linux-x86_64/bin:~/.cargo/bin" >> ~/.zshrc && \
  echo "alias ls='eza --across --icons --git --git-repos -lahg'" >> ~/.zshrc && \
  git clone https://github.com/FrodeUlr/NvimLazyVim.git ~/.config/nvim

RUN .cargo/bin/cargo install eza
ENTRYPOINT ["tail", "-f", "/dev/null"]
