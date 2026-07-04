# ND-120 Vivado Build Script (PowerShell)
# Usage: .\vivado_build.ps1
#
# Prerequisites: Vivado must be installed and in PATH, or set $VivadoPath below.

param(
    [string]$VivadoPath = "F:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat",
    [switch]$SynthOnly,
    [switch]$LintOnly,
    [switch]$SkipProgram,
    # Omit full_synth in Tcl — reuse last synth checkpoint (no ~1h resynthesis). Default PS1 behavior is still full_synth.
    [switch]$ReuseSynth
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

# Copy microcode hex files to Vivado project directory
# (Verilog uses $readmemh with relative paths; Vivado runs from the project dir)
$VivadoProjectDir = "F:\Xilinx\ND120\ND3202D"
$MicrocodeDir = "E:\Dev\Repos\Ronny\nd-120\Code\Microcode"
$HexFiles = @("AM27256_45132L.hex", "AM27256_45133L.hex")

foreach ($hex in $HexFiles) {
    $src = Join-Path $MicrocodeDir $hex
    $dst = Join-Path $VivadoProjectDir $hex
    if (-not (Test-Path $src)) {
        Write-Error "Microcode file not found: $src"
        exit 1
    }
    Copy-Item $src $dst -Force
    Write-Host "Copied microcode: $hex" -ForegroundColor Gray
}

Write-Host "Using Vivado: $VivadoPath" -ForegroundColor Cyan

if ($LintOnly) {
    Write-Host "`n=== Running Linter Only ===" -ForegroundColor Yellow
    & $VivadoPath -mode batch -source $LintScript -log vivado_lint.log -journal vivado_lint.jou
} elseif ($SkipProgram) {
    Write-Host "`n=== Running Build (no programming) ===" -ForegroundColor Yellow
    if ($ReuseSynth) {
        Write-Host "ReuseSynth: Tcl will NOT run full_synth (uses existing synth_1 checkpoint)." -ForegroundColor Cyan
        & $VivadoPath -mode batch -source $TclScript -log vivado_build.log -journal vivado_build.jou -tclargs skip_program
    } else {
        & $VivadoPath -mode batch -source $TclScript -log vivado_build.log -journal vivado_build.jou -tclargs full_synth skip_program
    }
} else {
    Write-Host "`n=== Running Full Build + Program FPGA + Flash ===" -ForegroundColor Yellow
    if ($ReuseSynth) {
        Write-Host "ReuseSynth: Tcl will NOT run full_synth (uses existing synth_1 checkpoint)." -ForegroundColor Cyan
        & $VivadoPath -mode batch -source $TclScript -log vivado_build.log -journal vivado_build.jou
    } else {
        & $VivadoPath -mode batch -source $TclScript -log vivado_build.log -journal vivado_build.jou -tclargs full_synth
    }
}

$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "`nBUILD SUCCESSFUL" -ForegroundColor Green
    if (-not $SkipProgram -and -not $LintOnly) {
        Write-Host "Bitstream programmed to FPGA and SPI flash (persistent)." -ForegroundColor Green
    }

    # Show ROM init check result
    $RomCheck = "F:\Xilinx\ND120\ND3202D\output\rom_init_check.txt"
    if (Test-Path $RomCheck) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host " MICROCODE ROM CHECK" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        $content = Get-Content $RomCheck
        $hasData = $content | Select-String "OK: INIT_00 has non-zero data"
        $isEmpty = $content | Select-String "WARNING.*empty"
        if ($hasData) {
            Write-Host "  ROM: POPULATED (microcode loaded OK)" -ForegroundColor Green
        } elseif ($isEmpty) {
            Write-Host "  ROM: EMPTY - MICROCODE NOT LOADED!" -ForegroundColor Red
            Write-Host "  Check hex files in $VivadoProjectDir" -ForegroundColor Red
        } else {
            Write-Host "  ROM: No rom_lo/rom_hi BRAMs found (check synthesis)" -ForegroundColor Yellow
        }
        Write-Host "  Full report: $RomCheck" -ForegroundColor Gray
        Write-Host "  RAM report:  F:\Xilinx\ND120\ND3202D\output\ram_utilization.rpt" -ForegroundColor Gray
        Write-Host "========================================" -ForegroundColor Cyan
    }

    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  ILA: open ND120_TOP.ltx with the same ND120_TOP.bit — $VivadoProjectDir\output\ or ND3202D.runs\impl_1\" -ForegroundColor Gray
    Write-Host "  .\flash.ps1          # Program JTAG + SPI flash (persistent)" -ForegroundColor Gray
    Write-Host "  .\flash.ps1 -Quick   # Program JTAG only (volatile, fast)" -ForegroundColor Gray
    Write-Host "  Serial: COM16 @ 115200 8N1" -ForegroundColor Gray
    Write-Host "  SW0 UP = run, SW0 DOWN = reset" -ForegroundColor Gray
} else {
    Write-Host "`nBUILD FAILED (exit code: $exitCode)" -ForegroundColor Red
    Write-Host "Check vivado_build.log for details."
}

exit $exitCode
