#!/bin/bash
# pre-compact-log.sh — PreCompact hook
#
# コンパクション発生をログに記録する。

set -euo pipefail

mkdir -p "$HOME/.claude/sessions" 2>/dev/null || true
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] コンパクション実行" >> "$HOME/.claude/sessions/compaction-log.txt" || true

exit 0
