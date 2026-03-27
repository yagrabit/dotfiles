---
name: odin-auto-evolve
description: 自己進化。odinのタスク分解で対応スキルが見つからない時に、skill-creatorスキルを使って新スキルをプロジェクトローカルに生成する。「スキルを作って」「新しいスキルが必要」で起動。
user-invocable: true
allowed-tools: Bash, Read, Write, Grep, Glob, Agent, AskUserQuestion
---

# odin-auto-evolve

odinシリーズに不足しているスキルを自己生成する進化スキル。
odin司令塔のPhase 4（タスク分解）で対応スキルがマッピングできなかった時に発動する。

## 発動条件

1. odin司令塔がタスクリストを生成した際、既存のodinスキルでカバーできないタスクがある
2. ユーザーが明示的に新スキルの作成を要求した

## 1. スキル要件の定義

1. カバーできなかったタスクの内容を分析する
2. 必要なスキルの要件を整理する:
   - スキル名（odin-{形態}-{機能名}形式）
   - 説明（何をするスキルか）
   - 形態の判定（think/do/talk/auto）
   - 入力と出力
   - 必要なツール
   - superpowers連携の有無

## 2. スキル生成

1. Skillツールで `skill-creator:skill-creator` を実行する
   - 要件を引数で渡す
2. skill-creatorがスキルファイルを生成する

## 3. プロジェクトローカルに配置

1. 生成されたスキルをプロジェクトの `.claude/skills/{スキル名}/SKILL.md` に配置する
   - dotfiles（dot_claude/skills/）ではなく、プロジェクトローカルに配置する
2. スキルが正しく認識されることを確認する

## 4. 報告

以下を報告する:
- 生成したスキル名と説明
- 配置先パス
- 昇格方法（良ければdotfilesのdot_claude/skills/に手動で移動する手順）

## 昇格フロー

生成したスキルが有用と判断された場合:
1. プロジェクトの `.claude/skills/{name}/SKILL.md` から
2. dotfilesの `dot_claude/skills/{name}/SKILL.md` にコピーする
3. chezmoi applyで全マシンに反映する

この昇格判断はユーザーが行う。自動では昇格しない。
