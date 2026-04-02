---
name: pr-attach-image
description: ローカルの画像ファイルをGitHub PRにコメントとして添付する。Playwright MCPでブラウザ経由のアップロードを行い、Markdown画像付きコメントを投稿する。「PRに画像を貼って」「スクショをPRに添付して」「PRにエビデンスを貼って」「PRに画像を追加して」「検証結果をPRに載せて」など、GitHub PRへの画像添付が求められたときに使用する。Playwright等で撮影したスクリーンショットや、ローカルに保存された画像ファイルをPRコメントに含めたい場合は常にこのスキルを使う。
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, mcp__plugin_playwright_playwright__browser_navigate, mcp__plugin_playwright_playwright__browser_snapshot, mcp__plugin_playwright_playwright__browser_file_upload, mcp__plugin_playwright_playwright__browser_click, mcp__plugin_playwright_playwright__browser_evaluate, mcp__plugin_playwright_playwright__browser_run_code, mcp__plugin_playwright_playwright__browser_wait_for, mcp__plugin_playwright_playwright__browser_close
---

# PR画像添付スキル

ローカルの画像ファイルをGitHub PRにコメントとして添付する。
GitHub APIには画像直接アップロードの公式エンドポイントがないため、Playwright MCPでブラウザ経由のアップロードを行い、生成されたURLを`gh pr comment`で投稿する。

## 入力

- 画像ファイルパス: 1つまたは複数の絶対パス
- PR指定: PR番号、PR URL、または省略（現在のブランチのPR）

入力が不足している場合はAskUserQuestionで確認する。

## 処理フロー

### Step 1: PR情報の取得

```bash
# PR番号が指定されている場合
gh pr view <PR番号> --json url,number,title --jq '{url, number, title}'

# 現在のブランチのPRを探す場合
gh pr view --json url,number,title --jq '{url, number, title}'
```

PRのHTMLページURLを取得する（例: `https://github.com/owner/repo/pull/123`）。

### Step 2: 画像ファイルの検証

指定された画像ファイルが存在し、サポートされる形式であることを確認する。

```bash
# ファイルの存在と形式を確認
file <画像パス>
```

対応形式: png, jpg, jpeg, gif, webp, svg（GitHubがサポートする形式）
サイズ上限: 25MB（GitHub制限）

### Step 3: PRページへのアクセスとログイン確認

1. `browser_navigate` でPR URLにアクセスする
2. `browser_snapshot` でページの状態を確認する
3. ログイン画面が表示された場合:
   - ユーザーに「Playwright MCPのブラウザウィンドウでGitHubにログインしてください」と案内する
   - ログイン完了後、再度PRページにアクセスする

ログイン確認のポイント: snapshotでコメント用テキストエリアが存在するかどうかで判定する。

### Step 4: 画像のアップロードとURL取得

PRページのコメント欄に関連付けられた隠しファイル入力（`<input type="file">`）を使って画像をアップロードする。
GitHubは画像を受け取ると `https://github.com/user-attachments/assets/...` のURLを生成し、テキストエリアにMarkdown画像記法として挿入する。

`browser_run_code` で以下のコードを実行する。`IMAGE_PATH` を実際の絶対パスに置き換えること:

```javascript
async (page) => {
  // ページ末尾のコメントエリアにあるfile-attachmentコンポーネントのfile inputを取得
  // GitHub PRページにはレビューコメント用など複数のfile inputがあるため、
  // ページ末尾の新規コメント用を使う（last()）
  const fileInput = page.locator('file-attachment input[type="file"]').last();

  // ファイルを設定するとアップロードが自動的に開始される
  await fileInput.setInputFiles(['IMAGE_PATH']);

  // GitHubがアップロードを処理し、テキストエリアにURLを挿入するのを待つ
  // 「Uploading」プレースホルダーが消えて実際のURLに置き換わるまで待機する
  await page.waitForFunction(
    () => {
      const ta = document.querySelector(
        '.js-new-comment-form textarea, #new_comment_field'
      );
      if (!ta) return false;
      const val = ta.value;
      return val.includes('user-attachments/assets/') && !val.includes('Uploading');
    },
    { timeout: 30000 }
  );

  // テキストエリアから画像タグを取得
  // GitHubはHTML形式（<img width="..." src="..." />）で挿入する
  const textarea = page.locator(
    '.js-new-comment-form textarea, #new_comment_field'
  ).last();
  const value = await textarea.inputValue();

  // テキストエリアをクリア（コメント投稿はgh CLIで行うため）
  await textarea.fill('');

  return value;
}
```

戻り値の例:
```html
<img width="1440" height="730" alt="screenshot" src="https://github.com/user-attachments/assets/abcd1234-..." />
```

GitHubはHTML `<img>` タグ形式で画像を挿入する。このHTMLはそのままPRコメントで使用できる。

複数画像がある場合は、画像ごとにこのスクリプトを繰り返し実行する。
各実行で取得したHTMLを配列に蓄積しておく。

### Step 5: PRコメントの投稿

取得した画像HTMLをまとめて、`gh pr comment`でコメントを投稿する。

```bash
gh pr comment <PR番号> --body "$(cat <<'EOF'
## エビデンス

<画像の説明>
<img width="1440" height="730" alt="screenshot" src="https://github.com/user-attachments/assets/..." />
EOF
)"
```

コメントのフォーマット:
- 画像が複数ある場合は見出し「## エビデンス」を付け、各画像に説明を添える
- 画像が1枚の場合は見出しを省略してシンプルに記述してもよい
- 画像の説明はファイル名やコンテキスト（どの画面のスクショか等）から推測する
- Step 4で取得したHTMLタグはそのまま使用する（GitHub MarkdownはHTMLをレンダリングする）

### Step 6: 後処理

1. 投稿されたコメントのURLをユーザーに報告する
2. ブラウザは閉じない（他のタスクで再利用される可能性があるため）

## セレクタが見つからない場合の対処

GitHubのUI変更でセレクタが機能しなくなった場合:

1. `browser_snapshot` でページ全体の構造を確認する
2. `file-attachment` カスタム要素を探す（GitHubのファイルアップロードは常にこの要素を使う）
3. その中の `input[type="file"]` を特定する
4. テキストエリアは `.js-new-comment-form` 内、または `id` が `new_comment_field` の要素を探す

## 制約事項

- Playwright MCPのブラウザセッションでGitHubにログイン済みである必要がある
- GitHubのUI変更により、セレクタの調整が必要になる可能性がある
- アップロードはGitHubのフロントエンドを経由するため、ネットワーク状態に依存する
- プライベートリポジトリの場合、アップロードされた画像URLは認証なしではアクセスできない
