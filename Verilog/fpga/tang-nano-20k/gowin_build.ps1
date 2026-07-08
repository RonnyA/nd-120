# ND120 Tang Nano 20K - build wrapper (Windows PowerShell)
#
#   cd E:\Dev\Repos\Ronny\nd-120\Verilog\fpga\tang-nano-20k
#   .\gowin_build.ps1
#
# Copies the WCS preload images (SKIP_WCS_LOAD - the $readmemh files must be
# reachable from the synthesis working dir), then runs gw_sh on
# gowin_build.tcl.
# Bitstream: build\nd120_tang20k_build\impl\pnr\nd120_tang20k_build.fs

$ErrorActionPreference = "Stop"

$gwsh = "C:\Utils\Gowin\Gowin_V1.9.10.02_x64\IDE\bin\gw_sh.exe"
if (-not (Test-Path $gwsh)) {
    Write-Error "gw_sh.exe not found at $gwsh - adjust the path in this script."
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$wcs  = Join-Path $here "..\..\..\Code\Microcode\wcs"
if (-not (Test-Path (Join-Path $wcs "wcs_16C.hex"))) {
    Write-Error "WCS preload images not found in $wcs - run Code/Microcode/gen_wcs_image.py first."
}

# $readmemh path resolution differs between tool versions: put the hex files
# in every plausible working directory.
$buildDir = Join-Path $here "build"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
foreach ($dest in @($here, $buildDir)) {
    Copy-Item (Join-Path $wcs "wcs_*.hex") -Destination $dest -Force
}
Write-Host "WCS preload images copied (32 files)."

& $gwsh (Join-Path $here "gowin_build.tcl")
if ($LASTEXITCODE -ne 0) {
    Write-Error "gw_sh failed with exit code $LASTEXITCODE"
}

# A build with an empty WCS is a dead CPU - fail loudly if the preload
# images were not found during synthesis (EX3988).
$synLog = Join-Path $here "build\nd120_tang20k_build\impl\gwsynthesis\nd120_tang20k_build.log"
if (Test-Path $synLog) {
    $miss = Select-String -Path $synLog -Pattern "EX3988" | Measure-Object
    if ($miss.Count -gt 0) {
        Write-Error "WCS preload FAILED: $($miss.Count) 'Cannot open file' (EX3988) warnings in the synthesis log - the control store is EMPTY. Do not flash this bitstream."
    } else {
        Write-Host "WCS preload OK (no EX3988 in synthesis log)."
    }
}

$fs = Join-Path $here "build\nd120_tang20k_build\impl\pnr\nd120_tang20k_build.fs"
if (Test-Path $fs) {
    Write-Host "Bitstream: $fs"
    Write-Host "Program (volatile SRAM):  openFPGALoader -b tangnano20k <fs>   (WSL, usbipd)"
    Write-Host "  or use the Gowin Programmer GUI on Windows."
} else {
    Write-Warning "Bitstream not found - check the synthesis/PnR logs under build\"
}
