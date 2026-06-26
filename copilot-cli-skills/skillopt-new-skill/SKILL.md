---
name: skillopt-new-skill
description: "Create a brand-new SKILL.md from scratch for any domain or task type, then optionally run an immediate SkillOpt optimization cycle on it. Use when the user asks 'create a new skill for X', 'generate a skill for Y tasks', 'I need a skill file for my project', 'start a new SKILL.md', 'make a skill that helps with Z', or when no SKILL.md exists in the current project. After creating the seed file, offers to optimize it immediately via the skillopt-now skill (self-contained, no setup)."
---

# SkillOpt New Skill — ゼロからスキル作成

新しいドメイン / タスク用の `SKILL.md` を対話的に生成し、必要であれば即座に最適化する。

> このスキル自体は外部ツール不要。最適化を行う場合のみ、自己完結の `skillopt-now` スキルへ橋渡しする。

## ⚠️ スコープ

**扱う範囲:** `SKILL.md` のゼロからの生成（seed skill）、ドメイン特化ルールの雛形作成、生成後の即時最適化連携。
**扱わない範囲:** 既存スキルの改善 → `skillopt-now` / `skillopt-sleep`、評価 → `skillopt-eval`。

---

## Step 1: ドメイン情報を収集（1 問ずつ確認）

1. **ドメイン名** — 例: "Python コードレビュー", "SQL クエリ生成"
2. **主なタスク** — このスキルが何をするか（1〜3 文）
3. **重要なルール** — 「いつも守ってほしい」制約・スタイル（3〜5 件）
4. **避けるべき行動** — NG パターン（任意）
5. **出力フォーマット** — 回答形式の制約（任意）

---

## Step 2: 既存シードを参考にする（任意）

```powershell
# repo がある場合、初期スキルの書き味を参照
$repo = $env:SKILLOPT_REPO
if (-not $repo) { $repo = "$env:USERPROFILE\.copilot\repos\SkillOpt" }
if (Test-Path $repo) {
  Get-ChildItem "$repo\skillopt\envs" -Recurse -Filter "initial.md" | Select-Object FullName
}
```

---

## Step 3: SKILL.md を生成

収集情報をテンプレートに埋めて `$PWD\SKILL.md` に保存する:

```powershell
$skillContent = @"
# <ドメイン名> Skill

## Core Rules
- <ルール 1>
- <ルール 2>

## Output Format
- <フォーマット>

## Avoid
- <避けるべき行動>
"@
Set-Content "$PWD\SKILL.md" $skillContent -Encoding utf8
Write-Host "SKILL.md を作成: $PWD\SKILL.md"
```

> 既に `SKILL.md` がある場合は上書き前に必ず確認する。

---

## Step 4: 内容を表示してユーザーに確認

生成した `SKILL.md` をチャットに表示し、修正の機会を与える。

---

## Step 5: 即時最適化を提案（任意）

```
SKILL.md を作成しました。今すぐ過去セッションを使って最適化しますか？
（skillopt-now スキルで実行します）
```

同意があれば `skillopt-now` スキルを呼び出す:

```powershell
& "$env:USERPROFILE\.copilot\skills\skillopt-now\run.ps1" run --project "$PWD" --backend mock --progress
```

---

## 報告フォーマット

```markdown
# SkillOpt New Skill — 作成完了
- 作成ファイル: `<path>/SKILL.md`
- 内容プレビュー: <SKILL.md 抜粋>
- 次: 内容確認・修正 / `skillopt-now` で最適化 / `skillopt-eval` でスコア確認
```

---

## ルール

- ユーザーの言葉をそのまま使う。独自ルールを勝手に追加しない
- 生成後は必ずユーザーにレビューしてもらう（SKILL.md は「ユーザーのもの」）
- 最適化は任意。押し付けない
- `SKILL.md` 既存時は上書き前に確認する
