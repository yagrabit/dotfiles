---
name: odin-auto-evolve
description: odinのタスク分解で対応スキルが見つからない時に、skill-creatorスキルを使って新スキルをプロジェクトローカルに生成する自己進化スキル。生成後は昇格フローでdotfilesへの移動も案内する。「スキルを作って」「新しいスキルが必要」で起動。
user-invocable: false
allowed-tools: Bash, Read, Write, Grep, Glob, Agent, AskUserQuestion
---

# odin-auto-evolve

odinシリーズに不足しているスキルを自己生成する進化スキル。
odin司令塔のPhase 4（タスク分解）で対応スキルがマッピングできなかった時に発動する。

## コンテキスト検出

### odinコンテキストがある場合（$ARGUMENTSにodin_contextが含まれる場合）
- odinから自動呼び出しされている
- カバーできなかったタスクの情報をodinコンテキストから取得する
- 生成完了後、スキル名をodinに返却する

### odinコンテキストがない場合（ユーザー直接呼び出し）
- ユーザーにどのようなスキルが必要か確認する

## Instructions

### 完了チェックポイントの原則

各ステップの最後には「完了チェックポイント」を設けている。
チェックポイントに記載された全ての条件を満たさない限り、次のステップに進んではならない。

## 発動条件

1. odin司令塔がタスクリストを生成した際、既存のodinスキルでカバーできないタスクがある
2. ユーザーが明示的に新スキルの作成を要求した

### ステップ1: スキル要件の定義

1. カバーできなかったタスクの内容を分析する
2. 必要なスキルの要件を整理する:
   - スキル名（odin-{形態}-{機能名}形式）
   - 説明（何をするスキルか）
   - 形態の判定（think/do/talk/auto）
   - 入力と出力
   - 必要なツール
   - superpowers連携の有無

#### 完了チェックポイント（ステップ1）

- スキル名がodin-{形態}-{機能名}形式であること
- 入出力・必要ツールが定義されていること

### ステップ2: スキル生成

1. skill-creatorプラグインの存在を確認する
   - Skillツールで `skill-creator:skill-creator` の実行を試みる
2. skill-creatorが利用可能な場合:
   - 要件を引数で渡してスキルファイルを生成する
3. skill-creatorプラグインが未インストールの場合（フォールバック）:
   - 「skill-creator:skill-creatorプラグインが未インストールのため、手動でスキルファイルを作成します」とログに記録する
   - ステップ1で定義した要件をもとに、odinスキルの標準構造（frontmatter + Instructions + Examples）に従ってSKILL.mdの内容を組み立てる
   - Writeツールで `.claude/skills/{スキル名}/SKILL.md` に直接書き出す

#### 完了チェックポイント（ステップ2）

- skill-creatorまたはフォールバック手順でスキルファイルが生成されていること

### ステップ3: プロジェクトローカルに配置

1. 生成されたスキルをプロジェクトの `.claude/skills/{スキル名}/SKILL.md` に配置する
   - dotfiles（dot_claude/skills/）ではなく、プロジェクトローカルに配置する
2. スキルが正しく認識されることを確認する

#### 完了チェックポイント（ステップ3）

- SKILL.mdが`.claude/skills/{スキル名}/SKILL.md`に配置されていること
- Claude Codeにスキルとして認識されることが確認されていること

### ステップ4: 報告

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

#### 完了チェックポイント（ステップ4）

- 生成スキルの情報（名前、説明、配置先）が報告されていること
- 昇格方法が案内されていること
- odinのタスクリストに新スキルが割り当てられていること

## Examples

### 不足スキルの自動生成

odin: 「Storybook連携タスクに対応するスキルがありません」

```
ステップ1: スキル要件の定義
  スキル名: odin-do-storybook
  形態: do（実行系）
  目的: コンポーネントからStorybookストーリーを自動生成する
  入力: コンポーネントファイル
  出力: *.stories.tsx
  必要ツール: Bash, Read, Write, Grep, Glob

ステップ2: スキル生成
  skill-creator:skill-creator を実行
  → SKILL.md 生成完了

ステップ3: プロジェクトローカルに配置
  → .claude/skills/odin-do-storybook/SKILL.md 配置
  → Claude Codeで認識確認 OK

ステップ4: 報告
  生成スキル: odin-do-storybook
  配置先: .claude/skills/odin-do-storybook/SKILL.md
  昇格方法: dot_claude/skills/ にコピーして chezmoi apply
```
