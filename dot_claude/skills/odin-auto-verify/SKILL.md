---
name: odin-auto-verify
description: 完了前検証。タスク完了宣言時にsuperpowersのverification-before-completionを実行し、証拠付きで成果を検証する。odin司令塔からタスク完了時に自動呼び出し。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# odin-auto-verify

タスク完了宣言の前に、成果を証拠付きで検証する自動補助スキル。
superpowersの verification-before-completion スキルを呼び出して検証を実行する。

## 鉄則

検証なしに「完了」「修正済み」「テスト通過」と言ってはならない。
証拠が先、主張は後。

## 1. 検証対象の特定

完了を主張する内容に応じて検証コマンドを決定する:

| 主張 | 必須の検証 | 不十分な検証 |
|------|-----------|-------------|
| テスト通過 | テスト実行して出力確認 | 前回の実行結果 |
| ビルド成功 | ビルド実行してexit 0確認 | lintの通過 |
| バグ修正 | 再現テストが通過 | コード変更のみ |
| lint通過 | lint実行して出力確認 | 部分チェック |
| 機能実装 | テスト通過 + 動作確認 | コード存在 |

## 2. 検証実行

1. Skillツールで `superpowers:verification-before-completion` を実行する
2. 検証ゲート:
   - IDENTIFY: この主張は何で証明するか特定する
   - RUN: 完全なコマンドを新規実行する（キャッシュ不可）
   - READ: 出力全体と終了コードを確認する
   - VERIFY: 出力は主張を裏付けるか判定する
3. 判定:
   - YES → 証拠付きで完了を報告する
   - NO → 実際のステータスを証拠付きで報告する

## 3. 結果報告

検証結果を以下の形式で報告する:

```
## 検証結果

状態: PASS / FAIL

### 検証項目
- [PASS] テスト: vitest run → 50/50 passed (exit 0)
- [PASS] ビルド: tsc --noEmit → no errors (exit 0)
- [FAIL] lint: biome check → 2 errors found (exit 1)

### 証拠
（コマンド出力を添付）
```

FAILの場合は修正が必要な箇所を具体的に報告する。
