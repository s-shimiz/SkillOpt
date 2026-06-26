<#
.SYNOPSIS
  SkillOpt-Eval runner — evaluate a skill and report a quality score.

  Two modes:
    Quick     : uses the vendored zero-dep engine (`skillopt_sleep dry-run`) —
                self-contained, no external repo, no API key for `mock`.
    Benchmark : resolves a full SkillOpt repo and runs scripts/eval_only.py —
                requires the installed `skillopt` package, a dataset and (for
                real backends) API keys.

.EXAMPLE
  ./run.ps1 -Mode quick -Project "$PWD" -Args @('--backend','mock','--max-tasks','20','--progress')
  ./run.ps1 -Mode benchmark -Config configs/searchqa/default.yaml -Skill path/to/SKILL.md -OutRoot outputs/eval1
#>
param(
    [ValidateSet("quick", "benchmark")]
    [string]$Mode = "quick",
    [string]$Project = "",
    [string]$Config = "",
    [string]$Skill = "",
    [string]$OutRoot = "",
    [string]$Repo = "",
    [string[]]$Args = @()
)
$ErrorActionPreference = "Stop"
$SkillDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsRoot = Split-Path -Parent $SkillDir

function Find-Python {
    $cands = @(
        @{ exe = "py"; pre = @("-3") },
        @{ exe = "python"; pre = @() },
        @{ exe = "python3"; pre = @() }
    )
    foreach ($c in $cands) {
        $cmd = Get-Command $c.exe -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        try {
            $ver = & $c.exe @($c.pre + @("-c", "import sys;print('%d%d'%sys.version_info[:2])")) 2>$null
            if ($ver -and [int]$ver -ge 310) { return @{ exe = $c.exe; pre = $c.pre } }
        } catch { }
    }
    return $null
}

$py = Find-Python
if (-not $py) { Write-Error "[eval] need Python >= 3.10 on PATH."; exit 1 }

if ($Mode -eq "quick") {
    # ── Self-contained: vendored engine dry-run (baseline -> candidate score) ──
    $cands = @(
        (Join-Path $SkillsRoot "skillopt-sleep\vendor"),
        (Join-Path $SkillDir "vendor")
    )
    if ($env:SKILLOPT_REPO) { $cands += $env:SKILLOPT_REPO }
    $engine = $null
    foreach ($c in $cands) { if ($c -and (Test-Path (Join-Path $c "skillopt_sleep"))) { $engine = $c; break } }
    if (-not $engine) {
        Write-Error "[eval] vendored engine not found. Run skillopt-sleep\sync-vendor.ps1 or set SKILLOPT_REPO."
        exit 1
    }
    $env:PYTHONPATH = $engine
    if (-not $Project) { $Project = (Get-Location).Path }
    $base = @("dry-run", "--project", $Project)
    if (-not ($Args -contains "--backend")) { $base += @("--backend", "mock") }
    & $py.exe @($py.pre + @("-m", "skillopt_sleep") + $base + $Args)
    exit $LASTEXITCODE
}

# ── Benchmark mode: needs the full repo + installed deps ──
function Resolve-Repo {
    param([string]$Explicit)
    $cands = @()
    if ($Explicit) { $cands += $Explicit }
    if ($env:SKILLOPT_REPO) { $cands += $env:SKILLOPT_REPO }
    $cfg = Join-Path $SkillsRoot ".skillopt-repo"
    if (Test-Path $cfg) { $cands += (Get-Content $cfg -Raw).Trim() }
    $reposDir = Join-Path $env:USERPROFILE ".copilot\repos"
    $cands += (Join-Path $reposDir "SkillOpt")
    if (Test-Path (Join-Path $reposDir "copilot-worktrees\SkillOpt")) {
        Get-ChildItem (Join-Path $reposDir "copilot-worktrees\SkillOpt") -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { $cands += $_.FullName }
    }
    foreach ($c in $cands) { if ($c -and (Test-Path (Join-Path $c "scripts\eval_only.py"))) { return $c } }
    return $null
}

$repoRoot = Resolve-Repo -Explicit $Repo
if (-not $repoRoot) {
    Write-Error "[eval] benchmark mode needs a SkillOpt repo with scripts/eval_only.py. Pass -Repo <path> or set SKILLOPT_REPO."
    exit 1
}
# Dependency check (numpy/openai/etc. cannot be vendored)
$depOk = & $py.exe @($py.pre + @("-c", "import importlib.util as u; print(all(u.find_spec(m) for m in ['skillopt','openai','numpy','yaml']))")) 2>$null
if ($depOk -ne "True") {
    Write-Warning "[eval] missing runtime deps. Install first:  cd `"$repoRoot`"; pip install -e ."
    exit 2
}
if (-not $Config) { Write-Error "[eval] -Config is required in benchmark mode."; exit 1 }
if (-not $Skill) { Write-Error "[eval] -Skill is required in benchmark mode."; exit 1 }
if (-not $OutRoot) { $OutRoot = "outputs/eval_$(Get-Date -f yyyyMMdd_HHmmss)" }

$configPath = if ([System.IO.Path]::IsPathRooted($Config)) { $Config } else { Join-Path $repoRoot $Config }
& $py.exe @($py.pre + @("$repoRoot\scripts\eval_only.py", "--config", $configPath, "--skill", $Skill, "--out_root", $OutRoot) + $Args)
exit $LASTEXITCODE
