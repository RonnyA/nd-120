# Generic Vivado batch runner - no vivado-on-PATH needed.
# Usage:  .\run_tcl.ps1 exp_slowclk.tcl
#         .\run_tcl.ps1 timing_explore.tcl
param(
    [Parameter(Mandatory=$true)][string]$Tcl,
    [string]$VivadoPath = "F:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat"
)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TclPath = if (Test-Path $Tcl) { (Resolve-Path $Tcl).Path } else { Join-Path $ScriptDir $Tcl }
$LogDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$base = [System.IO.Path]::GetFileNameWithoutExtension($TclPath)

if (-not (Test-Path $VivadoPath)) { Write-Error "Vivado not found at $VivadoPath"; exit 1 }
if (-not (Test-Path $TclPath))    { Write-Error "Tcl not found: $TclPath"; exit 1 }

Write-Host "Running $TclPath ..." -ForegroundColor Cyan
& $VivadoPath -mode batch -source $TclPath -log (Join-Path $LogDir "$base.log") -journal (Join-Path $LogDir "$base.jou")
Write-Host "Done. Log: $(Join-Path $LogDir "$base.log")" -ForegroundColor Green
