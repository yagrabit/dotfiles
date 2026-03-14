Claude Code関連の設定ファイルをchezmoiのテンプレートとしてdotfilesに同期してください。

注意: テンプレートファイル内の `{{ .chezmoi.homeDir }}` を絶対パスに置き換えないこと。テンプレートファイルを直接編集する。

手順:
1. 以下のファイルの差分を確認:
   - `chezmoi diff ~/.claude/settings.json`
   - `chezmoi diff ~/.claude/plugins/installed_plugins.json`
   - `chezmoi diff ~/.claude/plugins/known_marketplaces.json`
2. 差分があるファイルのみ、dotfilesリポジトリ内の対応するテンプレートファイルを直接編集:
   - `dot_claude/settings.json.tmpl`
   - `dot_claude/private_plugins/installed_plugins.json.tmpl`
   - `dot_claude/private_plugins/private_known_marketplaces.json.tmpl`
   パス内の絶対ホームパスは `{{ .chezmoi.homeDir }}` に置き換えて記述する。
3. 編集後、差分が解消されたことを確認:
   - 手順1と同じ `chezmoi diff` コマンドを再実行し、出力がないことを確認
4. `git status --short` でステージング状態を表示
5. 変更内容を要約して報告
