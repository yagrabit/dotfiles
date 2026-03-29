## odinコンテキストJSON仕様

odinから配下スキルを呼び出す際に、$ARGUMENTSとして以下のJSON形式でコンテキストを渡す。

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
    "hearing_summary": "Phase 3で承認された理解要約テキスト",
    "constraints": ["制約1", "制約2"],
    "wave": 2,
    "task_id": "T-03"
  }
}
```

各配下スキルはこのJSONを受け取ることで、odinのコンテキストを引き継いで動作する。
odinコンテキストがある場合、配下スキルは初期ヒアリングをスキップし、提供された情報を元にステップ2以降から実行する。
