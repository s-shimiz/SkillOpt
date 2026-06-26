<#
.SYNOPSIS
  SkillOpt-Train runner — full benchmark training loop (scripts/train.py).

  This workflow is NOT self-contained: it needs the full `skillopt` package and
  its runtime deps (openai, numpy, openpyxl, azure-identity, httpx), a benchmark
  dataset, and (for real backends) API keys. This runner locates the repo,
  checks deps, and delegates to scripts/train.py.

.EXAMPLE
  ./run.ps1 -Config configs/searchqa/default.yaml
  ./run.ps1 -Config configs/searchqa/default.yaml -Args @('--num_epochs','2','--batch_size','20')
  ./run.ps1 -ListConfigs
  ./run.ps1 -Setup        # pip install -e . in the resolved repo
#>
param(
    [string]$Config = "",
    [string]$Repo = "",
    [string]$OutRoot = "",
    [switch]$ListConfigs,
    [switch]$Setup,
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
    foreach ($c in $cands) { if ($c -and (Test-Path (Join-Path $c "scripts\train.py"))) { return $c } }
    return $null
}

$py = Find-Python
if (-not $py) { Write-Error "[train] need Python >= 3.10 on PATH."; exit 1 }

$repoRoot = Resolve-Repo -Explicit $Repo
if (-not $repoRoot) {
    Write-Error "[train] needs a SkillOpt repo with scripts/train.py. Pass -Repo <path>, set SKILLOPT_REPO, or write the path to '$SkillsRoot\.skillopt-repo'."
    exit 1
}
Write-Host "[train] repo: $repoRoot"

if ($ListConfigs) {
    Get-ChildItem (Join-Path $repoRoot "configs") -Recurse -Filter "*.yaml" |
        ForEach-Object { $_.FullName.Replace("$repoRoot\", "") } | Sort-Object
    exit 0
}

if ($Setup) {
    Write-Host "[train] installing runtime deps: pip install -e . (this may take a while)"
    & $py.exe @($py.pre + @("-m", "pip", "install", "-e", $repoRoot))
    exit $LASTEXITCODE
}

# Dependency check — these cannot be vendored (numpy is a compiled wheel, etc.)
$depOk = & $py.exe @($py.pre + @("-c", "import importlib.util as u; print(all(u.find_spec(m) for m in ['skillopt','openai','numpy','yaml']))")) 2>$null
if ($depOk -ne "True") {
    Write-Warning "[train] missing runtime deps. Install first:  ./run.ps1 -Setup   (or: cd `"$repoRoot`"; pip install -e .)"
    exit 2
}

if (-not $Config) { Write-Error "[train] -Config is required (use -ListConfigs to see options)."; exit 1 }
$configPath = if ([System.IO.Path]::IsPathRooted($Config)) { $Config } else { Join-Path $repoRoot $Config }
if (-not (Test-Path $configPath)) { Write-Error "[train] config not found: $configPath"; exit 1 }

$passArgs = @("$repoRoot\scripts\train.py", "--config", $configPath)
if ($OutRoot) { $passArgs += @("--out_root", $OutRoot) }
$passArgs += $Args
& $py.exe @($py.pre + $passArgs)
exit $LASTEXITCODE
