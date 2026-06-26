---
name: skillopt-eval
description: "Evaluate a SKILL.md file and report its quality score. Use when the user asks 'evaluate this skill', 'how good is my skill', 'score my SKILL.md', 'run eval only', 'check skill quality', or 'benchmark this skill against a dataset'. Two modes via run.ps1: (1) Quick — SELF-CONTAINED, uses the vendored zero-dep engine (no repo/keys); (2) Benchmark — resolves a full SkillOpt repo and runs scripts/eval_only.py (needs installed deps + dataset + API key). Returns a numeric score and recommended edits."
---

# SkillOpt Eval — スキル評価

`SKILL.md` の品質をスコアで測定する。トレーニングは行わず **評価のみ**。

```powershell
$EV = "$env:USERPROFILE\.copilot\skills\skillopt-eval\run.ps1"
```

## モード選択

| モード | 前提 | 自己完結 | 精度 |
|---|---|---|---|
| **Quick**（推奨） | 同梱 vendor のみ | ✅ | 概算（セッション履歴ベース） |
| **Benchmark** | repo + 依存 + データ + API キー | ❌ | 公式スコア |

---

## Quick モード（自己完結・データセット不要）

同梱エンジンの `dry-run` でベースラインと候補スコアを比較する。

```powershell
& $EV -Mode quick -Project "$PWD" -Args @('--backend','mock','--max-tasks','20','--progress')
```

確認する値:
- `held-out X.XXX` — 現スキルのスコア（baseline）
- `held-out X.XXX -> Y.YYY` — 改善後の推定（candidate）
- `=> ACCEPT / REJECT` — 改善余地の有無

> Quick の "スコア" は推定値。セッション履歴が無い場合は 0 タスクになる。

---

## Benchmark モード（公式スコア）

### Step 1: 利用可能なベンチマークを確認

```powershell
# skillopt-train スキルの -ListConfigs を流用
& "$env:USERPROFILE\.copilot\skills\skillopt-train\run.ps1" -ListConfigs
```

| config | 説明 |
|---|---|
| `configs/searchqa/default.yaml` | 検索型 QA |
| `configs/spreadsheetbench/default.yaml` | スプレッドシート操作 |
| `configs/alfworld/default.yaml` | テキストゲーム（ツール使用） |
| `configs/livemathematicianbench/default.yaml` | 数学 |

### Step 2: 評価実行

```powershell
& $EV -Mode benchmark `
  -Config "configs/searchqa/default.yaml" `
  -Skill "C:\path\to\your\SKILL.md" `
  -OutRoot "outputs/eval_$(Get-Date -f yyyyMMdd_HHmmss)"
```

- repo は `SKILLOPT_REPO` env → `~/.copilot/skills/.skillopt-repo` → 既知パスで自動解決
- 依存不足時は run.ps1 が `exit 2` で `pip install -e .` を促す（`skillopt-train\run.ps1 -Setup` でも可）

### Step 3: 結果確認

```powershell
Get-Content "<OutRoot>\eval_results.json" | ConvertFrom-Json | Format-List
```

---

## 報告フォーマット

```markdown
# SkillOpt Eval — 評価結果
- モード: Quick / Benchmark(<config>)
- baseline: X.XXX → candidate: Y.YYY（改善 +Z.ZZZ）/ ACCEPT・REJECT
- 評価対象: `<SKILL.md path>`
- 所見: >0.8=良好 / <0.6=改善余地（`skillopt-now` 推奨）/ REJECT=現状最適に近い
- 次: 改善は `skillopt-now`、別ベンチは config 変更
```

---

## ルール

- Quick の "スコア" は推定値であることを明示する
- Benchmark は時間・API コストがかかることを事前に案内する
- スコアの高低だけでなく改善余地と実用性を合わせて伝える
- 依存不足・repo 未解決時は run.ps1 の終了コード（2=依存不足）と指示に従って案内する
