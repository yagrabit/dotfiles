## odinコンテキストJSON仕様

odinから配下スキルを呼び出す際に、$ARGUMENTSとして以下のJSON形式でコンテキストを渡す。

各配下スキルはこのJSONを受け取ることで、odinのコンテキストを引き継いで動作する。
odinコンテキストがある場合、配下スキルは初期ヒアリングをスキップし、提供された情報を元にステップ2以降から実行する。

## フィールド定義

| フィールド | 説明 |
|-----------|------|
| `task` | タスクの具体的な説明 |
| `target_area` | 対象ディレクトリまたはファイルパス |
| `focus` | 注目すべきポイントの配列 |
| `artifacts` | 生成済み成果物のパスマップ |
| `hearing_summary` | Phase 3で提示した理解要約テキスト |
| `constraints` | 制約条件の配列 |
| `wave` | 現在のWave番号 |
| `task_id` | タスクID（例: T-03） |
| `board_task_id` | odin-boardの物理タスクID（YYYYMMDD-HHMM-XXXX形式）。odin-board経由の場合に設定。未設定時は空文字列 |
| `artifacts_dir` | 成果物の出力先ディレクトリ。board_task_idあり: `~/.local/share/odin-board/docs/{board_task_id}`、なし: `.claude/artifacts` |

## JSONテンプレート例（全フィールド）

```json
{
  "odin_context": {
    "task": "タスクの具体的な説明",
    "target_area": "対象ディレクトリまたはファイルパス",
    "focus": ["注目すべきポイント1", "注目すべきポイント2"],
    "artifacts": {
      "research": ".claude/artifacts/research-YYYYMMDD-HHMM.md",
      "requirements": ".claude/artifacts/requirements-YYYYMMDD-HHMM.md",
      "design": ".claude/artifacts/design-YYYYMMDD-HHMM.md",
      "plan": ".claude/artifacts/plan-YYYYMMDD-HHMM.md",
      "clarified": ".claude/artifacts/clarified-YYYYMMDD-HHMM.md"
    },
    "hearing_summary": "Phase 3で提示した理解要約テキスト",
    "constraints": ["制約1", "制約2"],
    "wave": 2,
    "task_id": "T-03",
    "board_task_id": "",
    "artifacts_dir": ".claude/artifacts"
  }
}
```
