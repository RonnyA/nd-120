# Flash the existing bitstream to FPGA and/or SPI flash
# Usage: .\flash.ps1              (JTAG + SPI flash, persistent)
#        .\flash.ps1 -Quick       (JTAG only, volatile, fast)

param(
    [string]$VivadoPath = "F:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat",
    [switch]$Quick
)

if (-not (Test-Path $VivadoPath)) {
    Write-Error "Vivado not found at $VivadoPath"
    exit 1
}

$BitFile = "F:/Xilinx/ND120/ND3202D/output/ND120_TOP.bit"
if (-not (Test-Path $BitFile)) {
    Write-Error "No bitstream found at $BitFile - run a build first"
    exit 1
}

Write-Host "Bitstream: $BitFile" -ForegroundColor Cyan
Write-Host "Timestamp: $((Get-Item $BitFile).LastWriteTime)" -ForegroundColor Cyan

if ($Quick) {
    $mode = "jtag_only"
    Write-Host "`n=== Programming FPGA via JTAG (volatile) ===" -ForegroundColor Yellow
} else {
    $mode = "jtag_and_flash"
    Write-Host "`n=== Programming FPGA via JTAG + SPI Flash ===" -ForegroundColor Yellow
}

$TclScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "flash.tcl"

& $VivadoPath -mode batch -source $TclScript -log vivado_flash.log -journal vivado_flash.jou -tclargs $mode

$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Host "`nPROGRAMMING SUCCESSFUL" -ForegroundColor Green
} else {
    Write-Host "`nPROGRAMMING FAILED (exit code: $exitCode)" -ForegroundColor Red
    Write-Host "Check vivado_flash.log for details."
}
exit $exitCode
