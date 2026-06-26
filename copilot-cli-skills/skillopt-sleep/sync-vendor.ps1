<#
.SYNOPSIS
  Re-vendor the SkillOpt-Sleep engine (skillopt_sleep/) from a SkillOpt repo into
  this skill folder's vendor/ directory, and record the source commit SHA.

.DESCRIPTION
  The bundled engine is a snapshot. Run this to refresh it after the upstream
  repo changes. Repo resolution order:
    1. -Repo <path> argument
    2. $env:SKILLOPT_REPO
    3. ~/.copilot/skills/.skillopt-repo  (a file containing the repo path)
    4. known locations under ~/.copilot/repos

.EXAMPLE
  ./sync-vendor.ps1 -Repo C:\path\to\SkillOpt
  ./sync-vendor.ps1            # auto-resolve
#>
param(
    [string]$Repo = ""
)
$ErrorActionPreference = "Stop"
$SkillDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-Repo {
    param([string]$Explicit)
    $cands = @()
    if ($Explicit) { $cands += $Explicit }
    if ($env:SKILLOPT_REPO) { $cands += $env:SKILLOPT_REPO }
    $cfg = Join-Path (Split-Path -Parent $SkillDir) ".skillopt-repo"
    if (Test-Path $cfg) { $cands += (Get-Content $cfg -Raw).Trim() }
    $reposDir = Join-Path $env:USERPROFILE ".copilot\repos"
    $cands += (Join-Path $reposDir "SkillOpt")
    if (Test-Path (Join-Path $reposDir "copilot-worktrees\SkillOpt")) {
        Get-ChildItem (Join-Path $reposDir "copilot-worktrees\SkillOpt") -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { $cands += $_.FullName }
    }
    foreach ($c in $cands) {
        if ($c -and (Test-Path (Join-Path $c "skillopt_sleep"))) { return $c }
    }
    return $null
}

$repoRoot = Resolve-Repo -Explicit $Repo
if (-not $repoRoot) {
    Write-Error "[sync] could not locate a SkillOpt repo (needs a skillopt_sleep/ dir). Pass -Repo <path> or set SKILLOPT_REPO."
    exit 1
}

$src = Join-Path $repoRoot "skillopt_sleep"
$vendor = Join-Path $SkillDir "vendor"
$dst = Join-Path $vendor "skillopt_sleep"
New-Item -ItemType Directory -Path $vendor -Force | Out-Null
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }

robocopy $src $dst /E /XD __pycache__ /NFL /NDL /NJH /NJS /NP | Out-Null

$sha = ""
try { $sha = (git -C $repoRoot rev-parse HEAD 2>$null) } catch { }
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
@"
SkillOpt-Sleep engine vendored from a SkillOpt repo
source: skillopt_sleep/
repo: $repoRoot
commit: $sha
vendored_at: $date
license: MIT (see SkillOpt repository)
"@ | Set-Content (Join-Path $vendor "VERSION.txt") -Encoding utf8

$n = (Get-ChildItem $dst -Recurse -File -Filter *.py | Measure-Object).Count
Write-Host "[sync] vendored $n .py files from $repoRoot (commit $sha)"
