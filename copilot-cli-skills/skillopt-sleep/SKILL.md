---
name: skillopt-sleep
description: "Run a SkillOpt-Sleep cycle to evolve Copilot's SKILL.md / memory from past sessions. Use when the user asks to 'run the sleep cycle', 'learn from past sessions', 'improve agent skills overnight', 'evolve my skill file', 'consolidate memory', 'adopt skill proposals', or similar self-improvement requests. Also triggers on 'skillopt status', 'schedule nightly skill evolution', or 'harvest past tasks'. This skill is SELF-CONTAINED: it bundles the zero-dependency engine in vendor/ and runs via run.ps1 with no external repo and no pip install (default mock backend). Returns a concise summary of what changed and what was staged."
---

# SkillOpt-Sleep

過去セッションを解析し、エージェントの `SKILL.md` / メモリを **検証ゲート付き**で自動進化させるスキル。

> **自己完結（self-contained）。** エンジン本体（`skillopt_sleep/`、ゼロ依存）を
> `vendor/` に同梱済み。すべての実行は同梱の `run.ps1` 経由で行う。
> **外部リポジトリ不要・pip install 不要**（デフォルトの `mock` バックエンド）。

## ⚠️ スコープ

**このスキルが扱う範囲:**
- 過去セッションのハーベスト（反復タスクの抽出）
- スキル・メモリへの有界テキスト編集の提案（stage）
- held-out ゲートを通過した編集のみ採用（adopt）
- ナイトリースケジュール設定 / 解除

**このスキルが扱わない範囲:**
- ベンチマーク訓練 → `skillopt-train`（要 repo + 依存）
- 即時最適化のインタラクティブ実行 → `skillopt-now`
- スキルファイルの手動編集 → 直接ファイル編集で対応

---

## 実行方法（すべて run.ps1 経由）

スキルフォルダ: `~/.copilot/skills/skillopt-sleep`
`run.ps1` が Python>=3.10 を検出し、同梱 `vendor/` を `PYTHONPATH` に通して
`python -m skillopt_sleep` へ委譲する。**カレントディレクトリに依存しない。**

```powershell
$SK = "$env:USERPROFILE\.copilot\skills\skillopt-sleep\run.ps1"
```

---

## Step 0: 自己完結の動作確認（API キー不要・決定的）

まず同梱エンジンが正しく動くことを証明する:

```powershell
& "$env:USERPROFILE\.copilot\skills\skillopt-sleep\run.ps1" --proof
```

`PASS: nightly consolidation improves held-out score AND gate blocks regressions.`
が出れば同梱エンジンは正常。これは held-out スコアが 0.33 → 1.0 に上がり、
有害な編集がゲートで却下されることを実証する（外部リポジトリ・API キー不要）。

---

## Step 1: ユーザーの意図を確認してアクションを選択

| ユーザーの発言 | アクション |
|---|---|
| 状態確認・最新提案を見たい | `status` |
| 試しに動かしたい / お試し実行 | `dry-run` |
| フル実行して提案を生成したい | `run` |
| 最新の提案を採用したい | `adopt` |
| ハーベストだけ確認したい | `harvest` |
| 毎晩自動実行したい | `schedule` |
| 自動実行を止めたい | `unschedule` |

---

## Step 2: 各アクションの実行

### `status` — 状態と最新提案の確認（読み取り専用）

```powershell
& $SK status --project "$PWD"
```

### `dry-run` — 安全なプレビュー（何もステージしない）

```powershell
& $SK dry-run --project "$PWD" --backend mock --source auto --progress
```

確認: ハーベストされたセッション数 / 抽出タスク数 / baseline→candidate スコア。

### `run` — フルサイクル実行（提案をステージ）

```powershell
& $SK run --project "$PWD" --backend mock --source auto --progress
```

- `night N: X sessions -> Y tasks` … 取り込み量
- `held-out X.XXX -> Y.YYY => ACCEPT/REJECT` … ゲート結果
- `staged: <path>` が出たら Step 3 へ
- **`adopt` するまで SKILL.md / メモリは変わらない**

### `adopt` — 最新の提案を採用（バックアップ付き）

```powershell
& $SK adopt --project "$PWD"
```

### `harvest` / `schedule` / `unschedule`

```powershell
& $SK harvest --project "$PWD" --source auto
& $SK schedule --project "$PWD" --hour 3 --minute 17
& $SK unschedule --project "$PWD"
```

実バックエンドを使う場合（API 費用あり）は `--backend claude|codex|copilot` を付ける。

---

## Step 3: staged 提案の確認 → 報告

```powershell
# staged の内容を確認してからユーザーに見せる
Get-Content "<staging_dir>\report.md" -ErrorAction SilentlyContinue
```

報告フォーマット:

```markdown
# SkillOpt-Sleep — <action> 結果
- Night: <N> / セッション <N> → タスク <N>
- ゲート: baseline <X.XXX> → candidate <Y.YYY> → **ACCEPT / REJECT**
- 採用編集: [<target>/<op>] <content>
- ステージ先: `<staging_dir>`
- 次: `adopt` で採用 / `dry-run` で再確認
```

---

## 保守: 同梱エンジンの再同期

`vendor/` はスナップショット。上流リポジトリ更新後に最新化するには:

```powershell
& "$env:USERPROFILE\.copilot\skills\skillopt-sleep\sync-vendor.ps1"   # repo 自動解決
& "$env:USERPROFILE\.copilot\skills\skillopt-sleep\sync-vendor.ps1" -Repo C:\path\to\SkillOpt
```

`vendor\VERSION.txt` に元コミット SHA が記録される。

---

## ルール

- **ユーザーの確認なしに `adopt` を実行しない**（`--auto-adopt` 指定がある場合を除く）
- `run` / `adopt` 前に staged の `report.md` をユーザーに見せる
- ゲートが REJECT の場合は「改善なし」と正直に報告し、rejected_edits も提示
- adopt のバックアップ生成を必ず確認・報告する
- 実バックエンドは API 費用が発生するため事前に案内する
- **Copilot CLI セッションの実ハーベストは未保証**（harvest は claude/codex 由来）。
  Copilot 環境では `--backend mock` / `--tasks-file` / `--proof` を中心に使う。
