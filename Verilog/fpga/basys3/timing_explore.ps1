# Runs timing_explore.tcl (opens the routed checkpoint, no resynth, ~1-2 min).
# Wrapper so you don't need vivado on PATH.
param(
    [string]$VivadoPath = "F:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat"
)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Tcl = Join-Path $ScriptDir "timing_explore.tcl"
$LogDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

if (-not (Test-Path $VivadoPath)) {
    Write-Error "Vivado not found at $VivadoPath - pass -VivadoPath."
    exit 1
}
Write-Host "Running timing explore (no resynth)..." -ForegroundColor Cyan
& $VivadoPath -mode batch -source $Tcl -log (Join-Path $LogDir "explore.log") -journal (Join-Path $LogDir "explore.jou")
Write-Host "`nReports in: $LogDir" -ForegroundColor Green
Get-ChildItem (Join-Path $LogDir "explore_*.rpt") | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor Gray }
