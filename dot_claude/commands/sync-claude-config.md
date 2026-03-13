Claude Code関連の設定ファイルをchezmoiのテンプレートとしてdotfilesに同期してください。

手順:
1. chezmoiのソースディレクトリに移動: `cd $(chezmoi source-path)`
2. 以下のファイルの差分を確認:
   - `chezmoi diff ~/.claude/settings.json`
   - `chezmoi diff ~/.claude/plugins/installed_plugins.json`
   - `chezmoi diff ~/.claude/plugins/known_marketplaces.json`
3. 差分があるファイルのみ `git add-tmpl` で追加:
   - `git add-tmpl ~/.claude/settings.json`
   - `git add-tmpl ~/.claude/plugins/installed_plugins.json`
   - `git add-tmpl ~/.claude/plugins/known_marketplaces.json`
4. `git status --short` でステージング状態を表示
5. 変更内容を要約して報告
