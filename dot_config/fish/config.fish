# Fish設定ファイル

# 環境変数
set -x EDITOR nvim
set -x LANG ja_JP.UTF-8
set -x GHQ_ROOT ~/ghq

# パス設定
fish_add_path /opt/homebrew/bin

# モダンなツールのエイリアス
alias ls='eza --icons --git'
alias ll='eza --icons --git -lh'
alias la='eza --icons --git -lha'
alias tree='eza --icons --git --tree'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias vim='nvim'
alias v='nvim'

# zoxide初期化
if type -q zoxide
    zoxide init fish | source
end

# fzfの設定
set -x FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -x FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border'

# Starship プロンプト
if type -q starship
    starship init fish | source
end

# tmux自動起動設定（クイックターミナル以外）
if status is-interactive
    # クイックターミナルでない場合のみtmuxを起動
    if not set -q GHOSTTY_QUICK_TERMINAL
        if command -v tmux > /dev/null
            if not set -q TMUX
                tmux attach-session -t default 2>/dev/null || tmux new-session -s default
            end
        else
            echo "⚠️  tmuxがインストールされていません"
            echo "インストールするには: brew install tmux"
        end
    end
end

# Ctrl+gでghqリポジトリに移動
function ghq_cd
    set selected_repo (ghq list -p | fzf)
    if test -n "$selected_repo"
        cd $selected_repo
        commandline -f repaint
    end
end

bind \cg ghq_cd

