<#
    OPCOM deposit loader for the Nexys 4 DDR ND-120.

    Reads a deposit file ("aaaaaa vvvvvv" octal pairs per line, e.g.
    tests/floppy-dma-test/deposits.txt), deposits every word through the
    OPCOM console, verifies each by re-examining, retries failures once,
    and reports PASS/FAIL counts. Optionally starts a program afterwards.

    The CPU must be STOPPED at the OPCOM prompt (fresh configuration).

    Usage (from WSL):
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File deposit_loader.ps1 `
          -Deposits ..\..\tests\floppy-dma-test\deposits.txt -Start 2000 -Listen 30
#>
param(
    [Parameter(Mandatory)][string]$Deposits,
    [string]$Port = "COM11",
    [int]$Baud = 9600,
    [int]$PaceMs = 250,
    [string]$Start = "",     # octal address to start with '!' when done
    [int]$Listen = 0         # seconds to listen after starting
)

$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, "None", 8, "One"
$sp.ReadTimeout = 100
$sp.DtrEnable = $true
$sp.RtsEnable = $true
$sp.Open()

function Send-Paced([string]$s) {
    foreach ($ch in $s.ToCharArray()) {
        $sp.Write([string]$ch)
        Start-Sleep -Milliseconds $script:PaceMs
    }
}
function Drain([int]$ms = 500) {
    $buf = ""
    $end = (Get-Date).AddMilliseconds($ms)
    while ((Get-Date) -lt $end) {
        try { $buf += [char]$sp.ReadChar() } catch { Start-Sleep -Milliseconds 30 }
    }
    return $buf
}

# wake OPCOM
Send-Paced "`r"
Drain 800 | Out-Null

$lines = Get-Content $Deposits | Where-Object { $_.Trim() -ne "" }
$total = $lines.Count
Write-Host "Depositing $total words..."

function Deposit([string]$addr, [string]$val) {
    Send-Paced "$addr/"
    Drain 400 | Out-Null
    Send-Paced "$val`r"
    Drain 400 | Out-Null
}
function Examine([string]$addr) {
    Send-Paced "$addr/"
    $r = Drain 700
    Send-Paced "`r"
    Drain 300 | Out-Null
    # response: echo of addr, then the cell value - take the LAST octal token
    $toks = [regex]::Matches($r, "[0-7]{4,6}") | ForEach-Object { $_.Value }
    if ($toks.Count -ge 2) { return $toks[$toks.Count - 1] }
    return ""
}

$n = 0
foreach ($ln in $lines) {
    $a, $v = $ln.Trim() -split "\s+"
    Deposit $a $v
    $n++
    if ($n % 20 -eq 0) { Write-Host "  $n / $total deposited" }
}

Write-Host "Verifying..."
$bad = @()
foreach ($ln in $lines) {
    $a, $v = $ln.Trim() -split "\s+"
    $got = Examine $a
    if ([convert]::ToInt32($got, 8) -ne [convert]::ToInt32($v, 8)) {
        Write-Host "  MISMATCH $a : got '$got' want $v"
        $bad += , @($a, $v)
    }
}
foreach ($p in $bad) {
    Write-Host "  retry $($p[0])"
    Deposit $p[0] $p[1]
    $got = Examine $p[0]
    if ([convert]::ToInt32($got, 8) -ne [convert]::ToInt32($p[1], 8)) {
        Write-Host "LOAD FAILED at $($p[0]): got '$got' want $($p[1])"
        $sp.Close(); exit 1
    }
}
Write-Host "LOAD OK ($total words)"

if ($Start -ne "") {
    Write-Host "Starting at $Start..."
    Send-Paced "$Start!"
    if ($Listen -gt 0) {
        $end = (Get-Date).AddSeconds($Listen)
        while ((Get-Date) -lt $end) {
            try { Write-Host -NoNewline ([char]$sp.ReadChar()) } catch { Start-Sleep -Milliseconds 50 }
        }
        Write-Host ""
    }
}
$sp.Close()
Write-Host "=== done ==="
