<#
.SYNOPSIS
  SkillOpt-Now runner — run one optimization cycle immediately.

  Reuses the vendored engine from the sibling `skillopt-sleep` skill (single
  source of truth), with fallbacks. Delegates to `python -m skillopt_sleep`.

.EXAMPLE
  ./run.ps1 run --project "$PWD" --backend mock --max-tasks 10 --progress
  ./run.ps1 dry-run --project "$PWD" --backend mock
  ./run.ps1 adopt --project "$PWD"
#>
$ErrorActionPreference = "Stop"
$SkillDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsRoot = Split-Path -Parent $SkillDir

# ── Resolve the vendored engine: own vendor -> sibling skillopt-sleep -> env repo ──
function Resolve-EnginePath {
    $cands = @(
        (Join-Path $SkillDir "vendor"),
        (Join-Path $SkillsRoot "skillopt-sleep\vendor")
    )
    if ($env:SKILLOPT_REPO) { $cands += $env:SKILLOPT_REPO }
    foreach ($c in $cands) {
        if ($c -and (Test-Path (Join-Path $c "skillopt_sleep"))) { return $c }
    }
    return $null
}

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

$engine = Resolve-EnginePath
if (-not $engine) {
    Write-Error "[now] vendored engine not found. Expected '$SkillsRoot\skillopt-sleep\vendor\skillopt_sleep' (run skillopt-sleep\sync-vendor.ps1) or set SKILLOPT_REPO."
    exit 1
}
$py = Find-Python
if (-not $py) {
    Write-Error "[now] need Python >= 3.10 on PATH (tried: py -3, python, python3)."
    exit 1
}

$env:PYTHONPATH = $engine
if ($args.Count -eq 0) { $args = @("run", "--backend", "mock") }
& $py.exe @($py.pre + @("-m", "skillopt_sleep") + $args)
exit $LASTEXITCODE
