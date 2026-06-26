---
name: skillopt-train
description: "Run the full SkillOpt benchmark training loop using a config YAML file (scripts/train.py) via run.ps1. Use when the user asks to 'train skillopt on alfworld', 'run the searchqa training loop', 'reproduce the paper results', 'train on spreadsheetbench', 'start a skillopt training run', or any request to run the multi-epoch reflective optimization loop against a benchmark dataset. NOT self-contained: run.ps1 resolves a full SkillOpt repo and requires installed deps (openai/numpy/etc.), a dataset, and an API key. Long-running (minutes to hours)."
---

# SkillOpt Train — ベンチマーク訓練ループ

`scripts/train.py` を使って SkillOpt の **フルトレーニングループ**
（rollout → reflect → aggregate → select → update → evaluate）を実行する。

> ⚠️ **このスキルは自己完結ではない。** numpy/openai 等のビルド依存・データセット・API キーが必要で同梱不可。
> `run.ps1` がリポジトリを解決し、依存チェックを行ったうえで `scripts/train.py` へ委譲する。
> ⏱️ **長時間（数分〜数時間）かつ API 費用が発生する。**

```powershell
$TR = "$env:USERPROFILE\.copilot\skills\skillopt-train\run.ps1"
```

## ⚠️ スコープ

**扱う範囲:** 公式ベンチマーク（ALFWorld / SearchQA / SpreadsheetBench / LiveMathematicianBench 等）での訓練。
**扱わない範囲:** 自分のセッションからの改善 → `skillopt-sleep` / `skillopt-now`、評価のみ → `skillopt-eval`。

---

## Step 0: セットアップ（初回のみ）

`run.ps1` は repo を `SKILLOPT_REPO` env → `~/.copilot/skills/.skillopt-repo` →
`~/.copilot/repos/SkillOpt` の順で自動解決する。明示する場合は `-Repo`。

```powershell
# 依存をインストール（pip install -e .）
& $TR -Setup
# または -Repo を明示
& $TR -Setup -Repo "C:\path\to\SkillOpt"
```

API キーは repo の `.env`（`.env.example` 参照）または環境変数で設定する。

---

## Step 1: 利用可能な設定を確認

```powershell
& $TR -ListConfigs
```

| config | 環境 | 特徴 |
|---|---|---|
| `configs/searchqa/default.yaml` | SearchQA | テキスト読解 QA |
| `configs/spreadsheetbench/default.yaml` | SpreadsheetBench | openpyxl コード生成 |
| `configs/alfworld/default.yaml` | ALFWorld | ツール使用ゲーム |
| `configs/livemathematicianbench/default.yaml` | 数学 |

---

## Step 2: 訓練を実行

```powershell
# 基本
& $TR -Config "configs/searchqa/default.yaml"

# オプション指定（train.py のフラグは -Args で渡す）
& $TR -Config "configs/searchqa/default.yaml" `
  -OutRoot "outputs/run_$(Get-Date -f yyyyMMdd_HHmmss)" `
  -Args @('--num_epochs','2','--batch_size','20','--seed','42')

# バックエンド変更
& $TR -Config "configs/searchqa/default.yaml" `
  -Args @('--optimizer_backend','claude_chat','--target_backend','openai_chat')
```

> 長時間実行のため、バックグラウンド実行（別ウィンドウ / `Start-Process`）も提案する。

---

## Step 3: 進捗と結果

進捗ログ: `[epoch N/M]` / `[rollout]` / `[reflect]` / `[gate] baseline X -> candidate Y: ACCEPT` / `best_skill.md saved`。

```powershell
$out = "outputs\<run_dir>"
Get-Content "$out\final_results.json" | ConvertFrom-Json | Format-List
Get-Content "$out\best_skill.md"
```

---

## 報告フォーマット

```markdown
# SkillOpt Train — 実行結果
- Config: `<config>` / Backend: optimizer=<X> target=<Y> / Epochs <N> Batch <N>
- スコア推移（epoch ごとの val_score / gate）
- 最終: val X.XXX（test 設定時は test も）
- 出力: 最良スキル `<out_root>/best_skill.md`
```

---

## ルール

- 実行前に **API 費用・所要時間の概算** をユーザーに伝える
- `-Setup` 未実行で依存不足の場合、run.ps1 は `exit 2` を返す → セットアップを案内する
- repo 未解決時は `-Repo` 指定か `SKILLOPT_REPO` 設定を案内する
- `-OutRoot` を指定して上書きを防ぐ
- 長時間実行はバックグラウンド実行も選択肢として提示する
