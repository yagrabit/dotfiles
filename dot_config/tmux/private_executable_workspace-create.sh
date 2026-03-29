#!/bin/bash
set -euo pipefail

# ============================
# tmux ワークスペース作成スクリプト
# ghqプロジェクト選択 → レイアウト選択 → ウィンドウ展開
# ============================

# ステップ1: ghqプロジェクト選択
GHQ_ROOT="$(ghq root)"
PROJECT="$(ghq list | fzf \
  --height=100% \
  --layout=reverse \
  --border \
  --prompt='プロジェクト> ' \
  --preview 'bat --color=always --style=header,grid --line-range :80 '"${GHQ_ROOT}"'/{}/README.md 2>/dev/null || eza --icons --tree --level=2 '"${GHQ_ROOT}"'/{}' || true)"

# キャンセル時は終了
if [[ -z "${PROJECT}" ]]; then
  exit 0
fi

PROJECT_PATH="${GHQ_ROOT}/${PROJECT}"

# ステップ2: レイアウト選択（fzfプレビューでASCII artを表示）
LAYOUT="$(printf '3分割\n4分割\n2分割\nシンプル' | SHELL=/bin/bash fzf \
  --height=100% \
  --layout=reverse \
  --border \
  --prompt='レイアウト> ' \
  --preview '
    case {} in
      3分割)
        echo "┌──────────┬────┐"
        echo "│          │    │"
        echo "│    1     │ 2  │"
        echo "│  (70%)   │30% │"
        echo "├──────────┴────┤"
        echo "│      3        │"
        echo "│    (50%)      │"
        echo "└───────────────┘"
        ;;
      4分割)
        echo "┌───────┬───────┐"
        echo "│       │       │"
        echo "│   1   │   2   │"
        echo "│       │       │"
        echo "├───────┼───────┤"
        echo "│       │       │"
        echo "│   3   │   4   │"
        echo "│       │       │"
        echo "└───────┴───────┘"
        ;;
      2分割)
        echo "┌───────┬───────┐"
        echo "│       │       │"
        echo "│       │       │"
        echo "│   1   │   2   │"
        echo "│       │       │"
        echo "│       │       │"
        echo "└───────┴───────┘"
        ;;
      シンプル)
        echo "┌───────────────┐"
        echo "│               │"
        echo "│               │"
        echo "│       1       │"
        echo "│               │"
        echo "│               │"
        echo "└───────────────┘"
        ;;
    esac
  ' || true)"

# キャンセル時は終了
if [[ -z "${LAYOUT}" ]]; then
  exit 0
fi

# ステップ3: 選択に応じてtmuxレイアウトを展開
case "${LAYOUT}" in
  "3分割")
    # 上左70% + 上右30% + 下50%、カーソルは左上
    tmux new-window -c "${PROJECT_PATH}" \; \
      split-window -v -p 50 -c "${PROJECT_PATH}" \; \
      select-pane -t 1 \; \
      split-window -h -p 30 -c "${PROJECT_PATH}" \; \
      select-pane -t 1
    ;;
  "4分割")
    # 2x2均等グリッド、カーソルは左上
    tmux new-window -c "${PROJECT_PATH}" \; \
      split-window -h -c "${PROJECT_PATH}" \; \
      split-window -v -c "${PROJECT_PATH}" \; \
      select-pane -t 1 \; \
      split-window -v -c "${PROJECT_PATH}" \; \
      select-pane -t 1
    ;;
  "2分割")
    # 左右50:50
    tmux new-window -c "${PROJECT_PATH}" \; \
      split-window -h -c "${PROJECT_PATH}"
    ;;
  "シンプル")
    # 単一ペイン
    tmux new-window -c "${PROJECT_PATH}"
    ;;
esac
