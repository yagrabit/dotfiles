# ベースイメージ
FROM ubuntu:24.04

# 必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    fish \
    git \
    curl \
    sudo \
    locales \
    fzf \
    eza \
    bat \
    fd-find \
    ripgrep \
    tmux \
    unzip \
    neovim \
    && rm -rf /var/lib/apt/lists/*

# ロケール設定（ja_JP.UTF-8）
RUN locale-gen ja_JP.UTF-8
ENV LANG=ja_JP.UTF-8
ENV LC_ALL=ja_JP.UTF-8

# chezmoi のインストール
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

# starship のインストール
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y

# testユーザーの作成（sudo可、パスワードなし）
RUN useradd -m -s /usr/bin/fish test \
    && echo "test ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ソースコピー
COPY . /home/test/dotfiles/
RUN chown -R test:test /home/test/dotfiles

# testユーザーに切り替え
USER test
WORKDIR /home/test

# chezmoi のソースディレクトリとして dotfiles をリンクし適用
RUN mkdir -p ~/.local/share && ln -s ~/dotfiles ~/.local/share/chezmoi \
    && chezmoi init --apply

# エントリポイント
ENTRYPOINT ["fish"]
