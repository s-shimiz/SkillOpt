---
name: skillopt-now
description: "Run one SkillOpt optimization cycle immediately on the current project — no nightly scheduling. Use when the user says 'optimize my skill now', 'improve my skill right now', 'quick skill tune', 'run skillopt immediately', 'make my skill better from today's tasks', or similar on-demand optimization requests. SELF-CONTAINED: runs the vendored zero-dependency engine via run.ps1 (shared with skillopt-sleep), no external repo or pip install for the default mock backend. Returns proposed skill edits with before/after scores in a single synchronous run."
---

# SkillOpt Now — 即時最適化

スケジュールなし、1 回だけ今すぐ SkillOpt の最適化サイクルを走らせる。
`skillopt-sleep run` の **速度優先・インタラクティブ版**。

> **自己完結。** 同梱エンジン（`skillopt-sleep/vendor/skillopt_sleep`）を共有し、
> `run.ps1` 経由で実行する。**外部リポジトリ不要・pip install 不要**（mock バックエンド）。

## ⚠️ スコープ

**扱う範囲:** 現プロジェクトのセッション履歴から即座に最適化を実行し、提案をステージして adopt まで誘導。
**扱わない範囲:** スケジュール管理 → `skillopt-sleep` / ベンチマーク訓練 → `skillopt-train` / 評価のみ → `skillopt-eval`。

---

## 実行方法

```powershell
$NOW = "$env:USERPROFILE\.copilot\skills\skillopt-now\run.ps1"
```

`run.ps1` は同梱エンジンを `自前 vendor → 兄弟 skillopt-sleep/vendor → SKILLOPT_REPO` の順で解決する。

---

## Step 1: パラメータを決定

| 状況 | 推奨設定 |
|---|---|
| 試し実行・費用ゼロ | `--backend mock --max-tasks 10` |
| 本番品質・Claude 使用 | `--backend claude --max-tasks 15` |
| 直近セッションのみ | `--lookback-hours 12` |
| 全セッション対象 | `--lookback-hours 0` |
| 確認なしで即 adopt | `--auto-adopt`（ユーザー明示時のみ） |

---

## Step 2: 即時最適化を実行

```powershell
# 引数なしで run.ps1 を呼ぶと `run --backend mock` 相当
& $NOW run --project "$PWD" --backend mock --max-tasks 10 --lookback-hours 24 --source auto --progress
```

実バックエンド（実費あり）:
```powershell
& $NOW run --project "$PWD" --backend claude --max-tasks 15 --lookback-hours 48 --source auto --progress
```

---

## Step 3: 結果を読み取る

| 出力行 | 意味 |
|---|---|
| `night N: X sessions -> Y tasks` | 取り込んだセッション数・タスク数 |
| `held-out 0.XXX -> 0.YYY => ACCEPT` | baseline→candidate。**ACCEPT = 改善あり** |
| `held-out 0.XXX -> 0.YYY => REJECT` | 改善なし。スキルは変更されない |
| `+ [skill/add] <text>` | 採用された追加ルール |
| `staged: <path>` | 提案保存先 |

---

## Step 4: 採用するか確認してから adopt

```powershell
Get-Content "<staged_path>\report.md" -ErrorAction SilentlyContinue
# 内容をユーザーに見せて合意を得てから:
& $NOW adopt --project "$PWD"
```

---

## 報告フォーマット

```markdown
# SkillOpt Now — 実行結果
- baseline: X.XXX → candidate: Y.YYY → **ACCEPT / REJECT**
- 採用変更: [add/delete] <ルール>
- ステージ先: `<staged_path>`
- 次: `adopt` で適用 / 内容確認して判断
```

---

## ルール

- **REJECT の場合は adopt を提案しない**。「改善なし」と正直に報告
- REJECT でも rejected_edits を表示し「何が却下されたか」を伝える
- 実バックエンドは API 費用が発生するため事前に案内
- `--auto-adopt` はユーザーが明示的に要求した場合のみ
- セッション履歴が無い場合は `0 sessions -> 0 tasks` になる（Copilot ハーベストは未保証）。
  動作確認は `skillopt-sleep\run.ps1 --proof` を案内する。
