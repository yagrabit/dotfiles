# Phase 5: 実行ループ詳細

Phase 1-4で確定した計画をWave単位で実行する。

## 5-0. コヒーレンスゲートチェック（Phase 5進入前）

最初のWave実行前に、Skillツールで `odin-auto-coherence validate` を実行する。
既存の成果物間の整合性を検証し、陳腐化した成果物に基づく実装を防止する。

| 結果 | アクション |
|------|-----------|
| PASS | 5-1へ進む |
| WARN | Amber状態の成果物を警告としてログに記録し、自動的に続行する。ただし、依存元の変更が以下の破壊的条件に該当する場合は該当成果物を自動再生成する: (1) 依存元のkindフィールドが変更されている (2) 依存元の主要な結論・方針が変更されている（diffで構造的変更が50%超） (3) 依存元が削除されている |
| FAIL（Missing） | 欠損している上流成果物の生成Phaseを再実行する |
| FAIL（循環依存） | 成果物のfrontmatter依存宣言を修正する |

スキップ条件:
- think系スキルのみの計画（分析・調査のみでdo系タスクを含まない場合）
- 成果物が0件の場合（新規プロジェクト）

## 5-1. タスク実行の基本フロー

事前準備（最初のdo系タスク実行前に1度だけ）:
- 保護ブランチ（main, develop, epic/*）にいる場合、フィーチャーブランチを作成して切り替える（ガードレール準拠）
- ブランチ名の決定:
  1. CLAUDE.local.mdの「プロジェクト管理」設定を確認し、命名規則（local/jira/github-issues）を適用する
  2. 設定がない場合はlocalモード（`{type}/{description}`）で自動命名する
- 作成したフィーチャーブランチ名を記録し、ワークツリーPRの `--base` に使用する

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
    "hearing_summary": "Phase 3で提示した理解要約",
    "board_task_id": "",
    "artifacts_dir": ".claude/artifacts"
  }
}
```

#### artifacts_dirの伝搬

odinコンテキストJSONの `artifacts_dir` フィールドを各スキルに伝搬する。
スキルのARGUMENTSに `--artifacts-dir {artifacts_dir}` を含める。

各スキル（think系・do系）は成果物を `artifacts_dir` に出力する。
odinが `artifacts` フィールドに記録するパスも `artifacts_dir` 配下を使用する。

2.5. 委譲前セルフチェック（スキップ不可）:
   - これからSkillツールを使おうとしているか？ → YES: 続行 / NO: 停止して修正（例外: § 5-2の並列worktree実行はAgentツール直接使用が必須）
   - Agent/Explore/直接分析で代替しようとしていないか？ → YES: 鉄則1違反。Skillツールに切り替える（例外: § 5-2の並列worktree実行）
   - 「簡単だから自分でやろう」と考えていないか？ → その考え自体が委譲違反の兆候。複雑さに関係なくSkillツールで委譲する

3. Skillツールで対応するodinスキルを実行する（odinコンテキストJSONを$ARGUMENTSとして渡す）
4. スキルの実行結果を確認する
5. auto系スキルの自動挿入: 5-3節に従い、完了したスキルの種別に応じてauto系スキルを挿入・実行する
6. 振り返り（メタ認知）: 5-X セクションに従い、odin-auto-recordスキル（Skillツール: odin-auto-record）に記録を委譲する
7. タスク完了: TaskUpdateツールでステータスを `completed` に更新する

## 5-2. 並列実行とワークツリー隔離

同一Wave内の独立タスクは並列実行する。think系・talk系はSkillツール経由またはAgentツールで並列実行する。do系は `Agent(isolation: "worktree")` で直接起動する（§ ワークツリー隔離 参照）。

並列実行の条件:
- 同一Wave内のタスクであること
- タスク間でファイルの競合がないこと
- それぞれが独立したスキルで完結すること

並列数の上限:
- 同時に起動するサブエージェントは最大4つまでとする
- 4つを超える場合はWaveを分割して逐次実行する
- 理由: エージェント数がN個の場合、N(N-1)/2の潜在的競合が発生し、4エージェント以上で精度が飽和・低下する（ベストプラクティス調査結果より）

### ワークツリー隔離（do系並列実行時は必須）

do系スキル（do-implement, do-refactor, do-test等）を並列実行する場合、各エージェントは `Agent(isolation: "worktree")` で直接起動しなければならない。Skillツールにはisolationパラメータがないため、Skillツール経由の並列do系実行は禁止する。ワークツリー隔離なしの並列do系実行も禁止する。

理由: 複数エージェントが同一ワーキングディレクトリで同時にファイルを編集すると、競合・上書き・不整合が発生する。Skillツールはメインセッションのワーキングディレクトリで実行されるため、並列実行時の分離ができない。

#### なぜSkillツールではなくAgentツール直接なのか

| 方式 | worktree隔離 | スキル自動ロード | 結果 |
|------|------------|---------------|------|
| Skillツール | 不可（isolationパラメータなし） | あり | ブランチ混線・競合が発生 |
| Agent(isolation: "worktree") | 可能 | なし（プロンプトに含める） | 各エージェントが独立worktreeで安全に作業 |

#### プロンプトテンプレート

`Agent(isolation: "worktree")` で起動する各サブエージェントには、以下の情報を全てプロンプトに含める。サブエージェントはスキル定義を自動ロードしないため、必要な指示は全てプロンプト内に記述すること。

```
Agent({
  prompt: `
## タスク
{タスクの説明（plan-*.mdから抽出）}

## 対象ファイル
{変更すべきファイルパスの一覧}
注意: 上記以外のファイルを変更しないこと。

## 設計仕様
{design-*.mdの該当セクションをここに展開する。「ファイルを読め」ではなく内容を直接渡す}

## TDDサイクル
1. Red: 失敗するテストを書く → テスト実行で失敗を確認
2. Green: テストを通す最小実装を書く → 全テスト通過を確認
3. Refactor: コードを整理 → テストが引き続き通ることを確認

テストコマンド: {自動検出したテストコマンド}

## コーディング規約
- コメント・ドキュメント: 日本語
- コミットメッセージ: Conventional Commits形式（日本語）例: feat: 〇〇を追加
- 型安全性: any型の使用禁止

## 完了基準
{タスクの完了基準をplan-*.mdから抽出}

## 制約（必ず守ること）
- 対象ファイル以外を変更しない
- 作業が完了したらgit commitする
- git push / git merge / gh pr create は絶対に実行しない
- 完了時にコミットハッシュと変更ファイル一覧を報告する
`,
  isolation: "worktree",
  model: "sonnet"
})
```

プロンプト構築時の注意:
- 設計仕様はファイルパスではなく内容をインライン展開する（サブエージェントの追加ファイル読み込みを最小化する）
- 仕様が150行を超える場合はタスクをさらに分割する
- 対象ファイルのスコープを明確に制限し、エージェント間の競合を防止する

並列ワークツリー完了後:
1. 既存PRのタイトルパターンを取得し、命名スタイルを分析する:
   ```bash
   gh pr list --state all --limit 10 --json title --jq '.[].title'
   ```
2. 各ワークツリーの変更ブランチからフィーチャーブランチへのDraft PRを作成する:
   ```bash
   gh pr create --draft --base フィーチャーブランチ名 --title "既存パターンに合わせたタイトル" --body "..."
   ```
   - `--base` には必ずフィーチャーブランチを指定する（mainではない）
   - タイトルは手順1で分析したパターンに合わせる
3. PR本文にタスク内容・変更概要・検証結果を記載する
4. 作成したDraft PR一覧をユーザーに報告する
5. 自動マージは行わない。マージはユーザーの判断に委ねる

後続Waveへの影響:
- 後続Waveが並列ワークツリーの成果に依存する場合、Draft PRのマージをユーザーに依頼して待機する
- マージ確認後、odinは後続Waveの実行を継続する

think系・talk系の並列実行はファイル変更を伴わないため、ワークツリー隔離は不要。通常のAgentで実行してよい。

## 5-3. 必須レビューチェーン

ユーザー承認ゲートを廃止した代わりに、レビューチェーンが品質ゲートとして機能する。チェーンの省略は禁止する。

PostToolUseフック（`post-skill-auto-review-reminder.sh`）がSkillツール完了後に自動発火し、次に実行すべきステップをリマインドする。フックの指示は必須であり、スキップしてはならない。

### think系スキル完了後の必須チェーン

think系スキル（research, requirements, design, plan, investigate, analyze）の成果物完了後:
1. odin-auto-peer-review — 必須。独立サブエージェント（Agentツール）で起動し、作成時の文脈を渡さない（肯定バイアス防止）
2. codex:rescue — 必須。Codex（異なるモデル）による独立レビュー。auto-peer-reviewとは別の視点で問題を検出する
3. PASS判定後に次のステップへ進む。REJECT時はFindingベースのフェーズルーティング（§ 5-3.7）で自動差し戻し

### do系スキル完了後の必須チェーン

do系スキル（implement, refactor, test）の各タスク完了後:
1. odin-auto-quality（--fix付き） — 必須
2. simplify — 必須
3. odin-auto-verify — 必須

全do系タスク完了後（Phase 5の最終レビュー）:
4. odin-talk-review — 必須。code-reviewer + security-reviewerによる品質・セキュリティレビュー
5. codex:rescue — 必須。Codex（異なるモデル）による独立レビュー。talk-reviewとは別の視点で問題を検出する
6. odin-auto-verify（最終検証） — 必須

### Codexレビューについて

Codexレビューは独立した必須ステップとして、talk-review / auto-peer-review とは分離して実行する。理由:
- 単一モデルでは検出できない問題を異なるモデルが発見する
- talk-review（Claude）の出力を前提とせず、独立した視点でレビューする
- Codexプラグイン未導入環境ではスキル呼び出しが失敗する。失敗をログに記録して続行するが、サイレントスキップはしない（失敗が可視化される）

### レビューチェーンの意義

推測せず調査→計画→レビュー→実行のサイクルを回すことで、ユーザー承認なしでも高い品質を維持する。

フォールバック: フックが発火しない場合（jq未インストール、設定未反映等）は、上記のチェーンに従って手動でauto系スキルを実行すること。

## 5-3.5. Generator-Evaluator反復ループ

詳細は [generator-evaluator.md](generator-evaluator.md) を参照。
do-implement / do-refactor 完了後、変更行数100行以上またはUI系タスクまたはフロントエンドプロジェクトの変更で発動。品質担保テスト設計→テストコード検証→ブラウザ検証の3段階で評価し、PASS/REFINE/REJECT判定→最大3回反復。

## 5-3.7. Findingベースのフェーズルーティング

レビュースキル（talk-review / auto-review / auto-peer-review）がFinding付きの結果を返した場合、odinは以下のルーティングロジックで差し戻しを実行する。

### ルーティング手順

1. レビュー結果から未解決のFinding一覧（F-{NNN}）を抽出する
2. 各FindingのrouteToSkillを確認する
3. routeToSkillを上流→下流の順序でソートする:
   ```
   think-research > think-requirements > think-design > think-plan > do-implement > do-test > do-refactor
   ```
4. 最も上流のrouteToSkillから修正を開始する（上流の修正が下流の問題も解消する可能性があるため）
5. 修正後、レビューを再実行してFinding IDの解決状況を確認する

### ルーティングテーブル

| routeToSkill | 修正アクション | 対象となる指摘の例 |
|-------------|--------------|------------------|
| `think-research` | Skillツールでodin-think-researchを再実行し、調査範囲を拡大する | 調査の不足・情報源の欠如 |
| `think-requirements` | Skillツールでodin-think-requirementsを再実行し、該当要件を修正する | 仕様の欠陥・要件漏れ |
| `think-design` | Skillツールでodin-think-designを再実行し、設計を修正する | アーキテクチャ不備・設計上の問題 |
| `think-plan` | Skillツールでodin-think-planを再実行し、タスク分解を修正する | タスク分解の問題 |
| `do-implement` | Skillツールでodin-do-implementを実行し、該当コードを修正する | 実装バグ・セキュリティ脆弱性・AIスロップ |
| `do-test` | Skillツールでodin-do-testを実行し、テストを追加・修正する | テストカバレッジ不足・テスト品質問題 |
| `do-refactor` | Skillツールでodin-do-refactorを実行し、コードを整理する | コード構造の問題・重複排除・可読性改善 |

routeToSkill判定基準（正本: 各レビュースキルはこの基準を参照すること）:
- 調査の不足・情報源の欠如 → `think-research`
- 仕様の欠陥・要件漏れ → `think-requirements`
- 設計上の問題・アーキテクチャ不備 → `think-design`
- タスク分解の問題 → `think-plan`
- 実装のバグ・セキュリティ脆弱性・AIスロップ → `do-implement`
- テストカバレッジ不足・テスト品質問題（テストスロップ含む） → `do-test`
- コード構造の問題・重複排除・可読性改善 → `do-refactor`
- [quality]タグの判定: 品質問題の性質で分岐する。実装のバグならdo-implement、テスト不足ならdo-test、構造改善ならdo-refactor

### Finding解決追跡

反復ループ（Generator-Evaluator、auto-peer-review等）では、各CycleでFinding IDの解決状況を追跡する:

```
Finding解決状況:
- F-001 [security]: Cycle 1で指摘 → Cycle 2で解決済み
- F-002 [quality]: Cycle 1で指摘 → Cycle 2で未解決 → Cycle 3で解決済み
- F-003 [slop]: Cycle 2で新規指摘 → Cycle 3で解決済み
```

全Findingが解決（または情報レベルに格下げ）されたらループ終了。

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
- 鉄則4の「外部判断が必要な場合」に該当する。即座にユーザーにエスカレーションする
- 問題の内容、影響範囲、提案する対応策をAskUserQuestionで提示する

3回リトライしても解決しない場合:
- 鉄則4の「外部判断が必要な場合」に該当する。試みた内容と結果をまとめてユーザーに報告する
- 続行/中止/方針変更の判断をユーザーに委ねる

## 5-5. Wave間の遷移と自動コンテキスト管理

1つのWaveの全タスクが完了したら:
1. Wave内の全タスクの完了を確認する
2. 次のWaveのタスクに必要な成果物が揃っているか確認する
3. 自動コンテキスト管理（毎Wave完了時に必ず実行）:

   以下の判定を機械的に実行する。判断を迷わない・タイミングを見失わないことが目的。

   a. Wave 3完了時: /compact を自動実行する（予防的圧縮）
      - compact後も成果物ファイルのパスさえ覚えていれば復元可能（artifacts設計の恩恵）
      - Wave 2以下の小規模計画では不要（think → do の最短構成等）

   b. Wave 4完了時: /compact を自動実行する（定期圧縮）
      - 品質劣化の兆候（同じ提案の繰り返し、指示の忘却、出力の短縮化）がある場合は即座にc.へ格上げ

   c. Wave 5以上、またはcompact後も品質が回復しない場合: ハードリセット
      - `.claude/artifacts/checkpoint-{yyyyMMdd-HHmm}.md` を自動作成し、以下を記録する:
        1. 完了タスク・未完了タスクの一覧
        2. 次にやるべきこと（次のWaveのタスク）
        3. 重要な判断履歴（このセッションで下した設計判断とその理由）
        4. 参照すべき成果物のパス一覧
        5. 注意事項（既知のバグ、制約等）
      - チェックポイントのパスをpbcopyし、ユーザーに報告する:
        「コンテキスト残量が少ないため、新セッションでの継続を推奨します。チェックポイント: {path}」

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

## 5-X.5. 知識の蓄積（think系スキル完了後）

think系スキル（research, design, investigate, analyze）が完了した場合、成果物にプロジェクト横断で有用な知見が含まれるか簡易判定する。

判定基準: 成果物にフレームワークの使い方、設計パターン、エラー対処パターン、ベストプラクティス等の汎用技術知見が含まれているか。

有用な知見がある場合（随時保存: タスク完了時の即時ingest）:
- Skillツールで `odin-knowledge` (ingestモード) をバックグラウンドで実行する
- 引数: 成果物ファイルパスを指定
- ユーザーへの確認は不要。自動でknowledgeに統合する（作業をブロックしない）
- 完了したら「知見をknowledgeに保存しました」と通知のみ行う
- Phase 6の§6-1.5（セッション完了時のまとめ保存）とは役割が異なる。`_log.md` の重複チェックで二重ingestを防止する

スキップ条件:
- do系スキルのみの計画（実装・テスト・コミットのみで調査・設計がない）
- 成果物にプロジェクト固有の情報しか含まれない場合
- `~/.claude/knowledge/_log.md` で同一成果物のingestが記録済みの場合

## 5-6. 構造化監査ログ（history.jsonl）

odinの各操作を `.claude/artifacts/history.jsonl` に追記専用で記録する。
セッション横断でスキル実行パターン・失敗傾向・改善効果を分析可能にする。

### 記録タイミングとエントリ形式

全エントリは `jq -c` で正しいJSON行を生成する。シェル変数の直接展開はJSON構文破壊のリスクがあるため禁止する。

Phase遷移時:
```bash
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg phase "${PHASE}" --arg task_id "${TASK_ID}" --arg skill "${SKILL}" \
  '{ts: $ts, event: "phase_enter", phase: $phase, task_id: $task_id, skill: $skill}' >> .claude/artifacts/history.jsonl
```

スキル実行完了時:
```bash
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg skill "${SKILL}" --arg task_id "${TASK_ID}" --arg result "${RESULT}" \
  '{ts: $ts, event: "skill_complete", skill: $skill, task_id: $task_id, result: $result}' >> .claude/artifacts/history.jsonl
```

レビュー判定時:
```bash
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg skill "${SKILL}" --arg verdict "${VERDICT}" --argjson findings "${FINDING_COUNT}" --arg detail "${FINDING_IDS}" \
  '{ts: $ts, event: "review_verdict", skill: $skill, verdict: $verdict, findings: $findings, findings_detail: $detail}' >> .claude/artifacts/history.jsonl
```

検証完了時:
```bash
jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg result "${RESULT}" --arg evidence "${EVIDENCE}" \
  '{ts: $ts, event: "verify", skill: "auto-verify", result: $result, evidence: $evidence}' >> .claude/artifacts/history.jsonl
```

### 記録の原則

- 追記専用: 既存エントリを編集・削除しない
- 最小限: 各イベントは1行のJSONで記録する。詳細は成果物ファイルを参照
- 自動化: odinの各Phaseで上記コマンドをBashツールで実行する
- 参照: odin-auto-improveがhistory.jsonlを入力として、スキル実行パターンと失敗傾向を分析する

### history.jsonlの管理

- ファイルが存在しない場合は自動作成する
- .gitignoreに含まれるため（.claude/artifacts/配下）、コミット対象外
- セッション横断で蓄積される（artifacts/配下は永続）
- 大きくなりすぎた場合（1000行超）は古いエントリを別ファイルにアーカイブする

## 完了チェックポイント（Phase 5）

- 全Wave・全タスクが完了していること
- 各タスクのodin-auto-verify結果が全てPASSであること
- 未解決のエラーが0件であること
