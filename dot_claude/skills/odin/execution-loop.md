# Phase 5: 実行ループ詳細

承認された計画をWave単位で実行する。

## 5-1. タスク実行の基本フロー

各タスクについて以下を実行する:

1. タスク開始: TaskUpdateツールでステータスを `in_progress` に更新する
   - think系スキルの場合、タスク内容に関連するベストプラクティスをWebSearchで追加調査する
   - 調査結果はodinコンテキストの一部としてスキルに渡す
   - 定型作業（commit, merge等）ではスキップする
2. odinコンテキストJSON の構築:

```json
{
  "odin_context": {
    "task": "タスクの説明",
    "target_area": "対象のディレクトリやファイル",
    "focus": ["注目すべきポイント"],
    "artifacts": {
      "research": ".claude/artifacts/research-YYYYMMDD-HHMM.md",
      "design": ".claude/artifacts/design-YYYYMMDD-HHMM.md"
    },
    "hearing_summary": "Phase 3で承認された理解要約"
  }
}
```

3. Skillツールで対応するodinスキルを実行する（odinコンテキストJSONを$ARGUMENTSとして渡す）
4. スキルの実行結果を確認する
5. auto系品質チェックを実行する（do系スキル完了後）
6. 振り返り（メタ認知）: 5-X セクションに従い、odin-auto-recordスキル（Skillツール: odin-auto-record）に記録を委譲する
7. タスク完了: TaskUpdateツールでステータスを `completed` に更新する

## 5-2. 並列実行

同一Wave内の独立タスクは superpowers:dispatching-parallel-agents を活用して並列実行する。

並列実行の条件:
- 同一Wave内のタスクであること
- タスク間でファイルの競合がないこと
- それぞれが独立したスキルで完結すること

並列数の上限:
- 同時に起動するサブエージェントは最大4つまでとする
- 4つを超える場合はWaveを分割して逐次実行する
- 理由: エージェント数がN個の場合、N(N-1)/2の潜在的競合が発生し、4エージェント以上で精度が飽和・低下する（ベストプラクティス調査結果より）

## 5-3. auto系スキルの自動挿入

以下のタイミングでauto系スキルを自動的に挿入・実行する:

think系スキル完了後（design/requirements/plan）:
- Skillツールで `odin-auto-peer-review` を実行する
- ドキュメントのファイルパスと種別をodinコンテキストに含めて渡す
- レビューアは独立したサブエージェント（Agentツール）として起動し、ドキュメント内容のみ渡す（作成時の文脈は渡さない）
- PASS判定後に次のステップへ進む

do系スキル完了後:
- Skillツールで `odin-auto-quality` を実行する（--fix付き）

do-implement / do-refactor 完了後（品質チェック通過後）:
- Skillツールで `simplify` を実行する（AI生成コードの冗長性除去）
- 不要なテスト、過剰防衛的チェック、冗長なコメントを除去する

全実装完了後（最後のdo-implement/do-refactor/do-test完了後）:
- Skillツールで `odin-auto-review` を実行する
- ただし、次のWaveでodin-do-prを実行する場合は、auto-reviewをスキップする（do-pr内部でセルフレビューが実行されるため、2重実行を防ぐ）

各タスク完了宣言前:
- Skillツールで `odin-auto-verify` を実行する

## 5-3.5. Generator-Evaluator反復ループ

詳細は [generator-evaluator.md](generator-evaluator.md) を参照。
do-implement / do-refactor 完了後、変更行数100行以上またはUI系タスクで発動。独立エージェントで評価→PASS/REFINE/REJECT判定→最大3回反復。

## 5-4. エラーハンドリング

スキル実行中に問題が発生した場合:

軽微な問題（lint警告、テスト失敗等）:
- odin-auto-quality --fix で自動修正を試みる
- 修正後に再検証する

中程度の問題（ビルドエラー、型エラー等）:
- superpowers:systematic-debugging で体系的にデバッグする
- 原因を特定し、odin-do-implement で修正する
- 最大3回まで自動リトライする

重大な問題（設計の根本問題、要件の矛盾等）:
- 即座にユーザーにエスカレーションする
- 問題の内容、影響範囲、提案する対応策をAskUserQuestionで提示する

3回リトライしても解決しない場合:
- 試みた内容と結果をまとめてユーザーに報告する
- 続行/中止/方針変更の判断をユーザーに委ねる

## 5-5. Wave間の遷移

1つのWaveの全タスクが完了したら:
1. Wave内の全タスクの完了を確認する
2. 次のWaveのタスクに必要な成果物が揃っているか確認する
3. コンテキスト管理: 2 Wave以上経過した場合、以下のいずれかを選択する

   a. ソフトリセット（compaction）— デフォルト:
      - /compact を実行し、コンテキストを要約圧縮する
      - compact後も成果物ファイルのパスさえ覚えていれば復元可能（artifacts設計の恩恵）
      - 適用条件: 4 Wave以下、またはコンテキスト消費が中程度の場合

   b. ハードリセット（context reset）— 5 Wave以上またはコンテキスト肥大化時:
      - `.claude/artifacts/checkpoint-{yyyyMMdd-HHmm}.md` に進捗を保存し、新セッション継続を推奨する
      - Opus 4.6ではcontext anxiety問題は軽減されており、明らかに限界に近い場合のみ使用する
4. 次のWaveの実行を開始する

## 5-X. 振り返り（常時メタ認知レイヤー）

各タスク完了時に、以下の6軸で1-2行ずつ簡潔に振り返る。
全軸に気づきがある必要はない。気づいたものだけ記録する。

振り返り軸:
1. スキル品質: 実行したスキルの指示に不足・曖昧さ・改善点はあったか
2. 進め方: タスクの順序・並列化・分割は最適だったか。もっと良い進め方はあったか
3. 実装判断: 採用した設計パターン・技術選択は適切だったか。より良い選択肢はあったか
4. コミュニケーション: ユーザーへの質問の仕方・説明・報告は適切だったか
5. ツール選択: 使用したツール（Agent/Grep/Explore等）の選択は最適だったか
6. 学び: WebSearchや実作業から得た、今後に活かせる知見はあるか

記録方法:
- Skillツールで `odin-auto-record` を実行し、振り返り内容の記録を委譲する
- odin-auto-recordに渡す情報: タスク名、振り返り軸ごとの気づき
- odin-auto-recordがinsightsファイルへの追記・フォーマット管理を担当する

永続化:
- プロジェクト横断で活かすべき重要な学びは、セッション終了前にmemoryシステム（feedback型）に保存することを検討する
- 「同じミスを2回以上した」「ユーザーに同じ指摘を受けた」は即座にmemoryに保存する

## 完了チェックポイント（Phase 5）

- 全Wave・全タスクが完了していること
- 各タスクのodin-auto-verify結果が全てPASSであること
- 未解決のエラーが0件であること
