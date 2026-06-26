<#
.SYNOPSIS
  SkillOpt-Sleep self-contained runner (Windows / PowerShell).

  Locates a Python >= 3.10, points PYTHONPATH at the vendored engine bundled in
  this skill folder (no external SkillOpt repo, no pip install required for the
  default `mock` backend), and delegates to `python -m skillopt_sleep`.

.EXAMPLE
  ./run.ps1 status --project "$PWD"
  ./run.ps1 dry-run --project "$PWD" --backend mock --progress
  ./run.ps1 run --project "$PWD" --backend mock
  ./run.ps1 adopt --project "$PWD"
  ./run.ps1 --proof          # deterministic proof (no API key): asserts the engine improves a held-out score
#>
$ErrorActionPreference = "Stop"

# ── Resolve the vendored engine (this skill folder is the single source of truth) ──
$SkillDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Vendor = Join-Path $SkillDir "vendor"
if (-not (Test-Path (Join-Path $Vendor "skillopt_sleep"))) {
    Write-Error "[sleep] vendored engine not found at '$Vendor\skillopt_sleep'. Run sync-vendor.ps1 to (re)create it."
    exit 1
}

# ── Find Python >= 3.10 ──
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
if (-not $py) {
    Write-Error "[sleep] need Python >= 3.10 on PATH (tried: py -3, python, python3)."
    exit 1
}

$env:PYTHONPATH = $Vendor

# ── Special flag: deterministic proof (no API key) ──
if ($args.Count -ge 1 -and $args[0] -eq "--proof") {
    $rest = @()
    if ($args.Count -gt 1) { $rest = $args[1..($args.Count - 1)] }
    & $py.exe @($py.pre + @("-m", "skillopt_sleep.experiments.run_experiment", "--persona", "researcher", "--assert-improves") + $rest)
    exit $LASTEXITCODE
}

# ── Default action is status (mirrors run-sleep.sh) ──
if ($args.Count -eq 0) { $args = @("status") }

& $py.exe @($py.pre + @("-m", "skillopt_sleep") + $args)
exit $LASTEXITCODE
