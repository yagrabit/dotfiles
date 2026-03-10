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

# Homebrew（Linuxbrew）インストール（キャッシュ効率のためDockerfileで実行）
USER test
ENV HOMEBREW_NO_AUTO_UPDATE=1
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# chezmoiインストール（curl経由）
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /home/test/.local/bin
ENV PATH="/home/test/.local/bin:${PATH}"

# dotfiles COPY → chezmoi init --apply で残り全部自動
WORKDIR /home/test
COPY --chown=test:test . /home/test/dotfiles/
SHELL ["/bin/bash", "-c"]
RUN chezmoi init --apply --source /home/test/dotfiles

# エントリポイント
ENTRYPOINT ["fish", "-l"]
