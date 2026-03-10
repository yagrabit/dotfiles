# ベースイメージ
FROM ubuntu:24.04

# apt: 最小限のシステム依存
RUN apt-get update && apt-get install -y \
    curl \
    sudo \
    locales \
    build-essential \
    git \
    procps \
    && rm -rf /var/lib/apt/lists/*

# ロケール設定（ja_JP.UTF-8）
RUN locale-gen ja_JP.UTF-8
ENV LANG=ja_JP.UTF-8
ENV LC_ALL=ja_JP.UTF-8

# testユーザーの作成（初期シェルはbash）
RUN useradd -m -s /bin/bash test \
    && echo "test ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Homebrew（Linuxbrew）インストール
USER test
ENV HOMEBREW_NO_AUTO_UPDATE=1
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# Brewfileでfish, tmuxインストール
COPY --chown=test:test Brewfile /home/test/Brewfile
RUN brew bundle --file=/home/test/Brewfile && brew cleanup --prune=all
RUN rm /home/test/Brewfile

# fishをデフォルトシェルに変更
USER root
RUN chsh -s /home/linuxbrew/.linuxbrew/bin/fish test
USER test

# mise インストール + ツールインストール
COPY --chown=test:test .mise.toml /home/test/.mise.toml
RUN curl https://mise.run | sh
ENV PATH="/home/test/.local/bin:${PATH}"
RUN mise trust ~/.mise.toml && mise install

# dotfiles COPY + chezmoi apply
WORKDIR /home/test
COPY --chown=test:test . /home/test/dotfiles/
SHELL ["/bin/bash", "-c"]
RUN mkdir -p ~/.local/share && ln -s ~/dotfiles ~/.local/share/chezmoi \
    && mise exec -- chezmoi init --apply

# エントリポイント
ENTRYPOINT ["fish", "-l"]
