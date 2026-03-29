### 5-3.5. Generator-Evaluator反復ループ

Anthropic公式原則: "separating the agent doing the work from the agent judging it proves to be a strong lever"

do-implement / do-refactor 完了後、以下の反復ループを実行する:

#### 発動条件

- 変更行数が100行以上の場合（小規模変更では不要）
- UI/デザイン系タスクの場合（行数に関係なく常に発動）

#### ループ手順

1. 評価（Evaluate）:
   - Agentツールで新しいエージェントを起動（別コンテキスト）し、変更差分を渡す
   - エージェントには以下を指示:
     - 変更が検証コントラクト（Phase 4で定義）の各項目を満たしているか判定
     - 品質上の問題点を具体的に指摘（ファイル:行番号、問題の説明、改善案）
     - 総合評価: PASS（問題なし） / REFINE（改善推奨） / REJECT（要修正）
   - 評価エージェントはcode-reviewerサブエージェントタイプを使用する

2. 判定:
   - PASS → ループ終了、次のWaveへ
   - REFINE → 改善が推奨だが必須ではない。ユーザーに「改善しますか？」と確認し、承認時のみ修正
   - REJECT → 修正必須。ステップ3（修正）へ

3. 修正（Refine）:
   - 評価結果の指摘事項をodin-do-implementに渡し、修正を実行
   - 修正後、再度ステップ1（評価）へ

4. ループ上限:
   - 最大3回まで反復する
   - 3回でPASSにならない場合、ユーザーにエスカレーション

#### 反復ログ

各反復のサイクルを記録する:
- Cycle 1: 評価結果（REFINE）→ 指摘3件 → 修正実施
- Cycle 2: 評価結果（PASS）→ ループ終了
