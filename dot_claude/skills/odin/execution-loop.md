# Phase 5: 実行ループ詳細

承認された計画をWave単位で実行する。

## 5-0. コヒーレンスゲートチェック（Phase 5進入前）

最初のWave実行前に、Skillツールで `odin-auto-coherence validate` を実行する。
既存の成果物間の整合性を検証し、陳腐化した成果物に基づく実装を防止する。

| 結果 | アクション |
|------|-----------|
| PASS | 5-1へ進む |
| WARN | Amber状態の成果物をAskUserQuestionで「再生成 or 続行」をユーザーに確認する |
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
  2. 設定がない場合や命名規則が判断できない場合は、AskUserQuestionでブランチ名を確認する
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
    "hearing_summary": "Phase 3で承認された理解要約",
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
   - これからSkillツールを使おうとしているか？ → YES: 続行 / NO: 停止して修正
   - Agent/Explore/直接分析で代替しようとしていないか？ → YES: 鉄則1違反。Skillツールに切り替える
   - 「簡単だから自分でやろう」と考えていないか？ → その考え自体が委譲違反の兆候。複雑さに関係なくSkillツールで委譲する

3. Skillツールで対応するodinスキルを実行する（odinコンテキストJSONを$ARGUMENTSとして渡す）
4. スキルの実行結果を確認する
5. auto系スキルの自動挿入: 5-3節に従い、完了したスキルの種別に応じてauto系スキルを挿入・実行する
6. 振り返り（メタ認知）: 5-X セクションに従い、odin-auto-recordスキル（Skillツール: odin-auto-record）に記録を委譲する
7. タスク完了: TaskUpdateツールでステータスを `completed` に更新する

## 5-2. 並列実行とワークツリー隔離

同一Wave内の独立タスクは superpowers:dispatching-parallel-agents を活用して並列実行する。

並列実行の条件:
- 同一Wave内のタスクであること
- タスク間でファイルの競合がないこと
- それぞれが独立したスキルで完結すること

並列数の上限:
- 同時に起動するサブエージェントは最大4つまでとする
- 4つを超える場合はWaveを分割して逐次実行する
- 理由: エージェント数がN個の場合、N(N-1)/2の潜在的競合が発生し、4エージェント以上で精度が飽和・低下する（ベストプラクティス調査結果より）

### ワークツリー隔離（do系並列実行時は必須）

do系スキル（do-implement, do-refactor, do-test等）を並列実行する場合、各エージェントは `Agent(isolation: "worktree")` で起動しなければならない。ワークツリー隔離なしの並列do系実行は禁止する。

理由: 複数エージェントが同一ワーキングディレクトリで同時にファイルを編集すると、競合・上書き・不整合が発生する。

起動例:
```
Agent({
  prompt: "odinコンテキストJSON + タスク内容",
  isolation: "worktree",
  model: "sonnet"
})
```

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

## 5-3. auto系スキルの自動挿入

PostToolUseフック（`post-skill-auto-review-reminder.sh`）がSkillツール完了後に自動発火し、実行すべきauto系スキルをリマインドする。フックの指示に従って順番に実行すること。

適用条件（正本）:
- auto-review: 全実装完了時のみ実行する。次のWaveでodin-do-prを実行する場合はスキップする（do-prがtalk-reviewでフルレビューを実施するため）
- auto-peer-review: レビューアは独立サブエージェント（Agentツール）で起動し、作成時の文脈を渡さない（肯定バイアス防止）。PASS判定後に次のステップへ進む
- auto-verify: 各タスクの完了宣言前に実行する。証拠が先、主張は後

フォールバック: フックが発火しない場合（jq未インストール、設定未反映等）は、上記の適用条件に従って手動でauto系スキルを実行すること。

## 5-3.5. Generator-Evaluator反復ループ

詳細は [generator-evaluator.md](generator-evaluator.md) を参照。
do-implement / do-refactor 完了後、変更行数100行以上またはUI系タスクで発動。独立エージェントで評価→PASS/REFINE/REJECT判定→最大3回反復。

## 5-3.7. Findingベースのフェーズルーティング

レビュースキル（talk-review / auto-review / auto-peer-review）がFinding付きの結果を返した場合、odinは以下のルーティングロジックで差し戻しを実行する。

### ルーティング手順

1. レビュー結果から未解決のFinding一覧（F-{NNN}）を抽出する
2. 各FindingのrouteToSkillを確認する
3. routeToSkillを上流→下流の順序でソートする:
   ```
   think-requirements > think-design > think-plan > do-implement > do-test > do-refactor
   ```
4. 最も上流のrouteToSkillから修正を開始する（上流の修正が下流の問題も解消する可能性があるため）
5. 修正後、レビューを再実行してFinding IDの解決状況を確認する

### ルーティングテーブル

| routeToSkill | 修正アクション |
|-------------|--------------|
| `think-requirements` | Skillツールでodin-think-requirementsを再実行し、該当要件を修正する |
| `think-design` | Skillツールでodin-think-designを再実行し、設計を修正する |
| `think-plan` | Skillツールでodin-think-planを再実行し、タスク分解を修正する |
| `do-implement` | Skillツールでodin-do-implementを実行し、該当コードを修正する |
| `do-test` | Skillツールでodin-do-testを実行し、テストを追加・修正する |
| `do-refactor` | Skillツールでodin-do-refactorを実行し、コードを整理する |

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

## 5-6. 構造化監査ログ（history.jsonl）

odinの各操作を `.claude/artifacts/history.jsonl` に追記専用で記録する。
セッション横断でスキル実行パターン・失敗傾向・改善効果を分析可能にする。

### 記録タイミングとエントリ形式

Phase遷移時:
```bash
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","event":"phase_enter","phase":'${PHASE}',"task_id":"'${TASK_ID}'","skill":"'${SKILL}'"}' >> .claude/artifacts/history.jsonl
```

スキル実行完了時:
```bash
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","event":"skill_complete","skill":"'${SKILL}'","task_id":"'${TASK_ID}'","result":"'${RESULT}'"}' >> .claude/artifacts/history.jsonl
```

レビュー判定時:
```bash
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","event":"review_verdict","skill":"'${SKILL}'","verdict":"'${VERDICT}'","findings":'${FINDING_COUNT}',"findings_detail":"'${FINDING_IDS}'"}' >> .claude/artifacts/history.jsonl
```

検証完了時:
```bash
echo '{"ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","event":"verify","skill":"auto-verify","result":"'${RESULT}'","evidence":['${EVIDENCE}']}' >> .claude/artifacts/history.jsonl
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
