# ND-120 Vivado Build Script (PowerShell)
# Usage: .\vivado_build.ps1
#
# Prerequisites: Vivado must be installed and in PATH, or set $VivadoPath below.

param(
    [string]$VivadoPath = "F:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat",
    [switch]$SynthOnly,
    [switch]$LintOnly
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TclScript = Join-Path $ScriptDir "vivado_build.tcl"
$LintScript = Join-Path $ScriptDir "vivado_lint.tcl"

# Check Vivado exists
if (-not (Test-Path $VivadoPath)) {
    # Try common locations
    $alternatives = @(
        "F:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat",
        "C:\Xilinx\Vivado\2025.2\bin\vivado.bat",
        "C:\Xilinx\Vivado\2024.1\bin\vivado.bat"
    )
    $found = $false
    foreach ($alt in $alternatives) {
        if (Test-Path $alt) {
            $VivadoPath = $alt
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Error "Vivado not found. Set -VivadoPath parameter."
        exit 1
    }
}

Write-Host "Using Vivado: $VivadoPath" -ForegroundColor Cyan

if ($LintOnly) {
    Write-Host "`n=== Running Linter Only ===" -ForegroundColor Yellow
    & $VivadoPath -mode batch -source $LintScript -log vivado_lint.log -journal vivado_lint.jou
} else {
    Write-Host "`n=== Running Full Build ===" -ForegroundColor Yellow
    & $VivadoPath -mode batch -source $TclScript -log vivado_build.log -journal vivado_build.jou
}

$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "`nBUILD SUCCESSFUL" -ForegroundColor Green
} else {
    Write-Host "`nBUILD FAILED (exit code: $exitCode)" -ForegroundColor Red
    Write-Host "Check vivado_build.log for details."
}

exit $exitCode
