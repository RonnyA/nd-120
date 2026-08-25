<#
.SYNOPSIS
    Expect-style driver for the ND-120 console on the Nexys 4 DDR - lets an
    unattended session (human or AI) run boot sequences, detect hangs, and
    leave a machine-checkable verdict.

.DESCRIPTION
    Runs a .bt test script (one command per line) against the board console:

        # comment
        SEND <text>            send text, char-paced (CR is sent for \r)
        SENDCR                 send a single CR
        EXPECT <sec> <regex>   wait up to <sec> seconds for <regex> in the
                               stream; on timeout the test FAILS as HANG
        FAILON <regex>         from now on, if <regex> ever appears the test
                               FAILS immediately (e.g. ERRFATAL)
        QUIET <sec>            require NO output for <sec> seconds (verifies
                               a prompt is idle, catches runaway printing);
                               any output = FAIL
        PAUSE <sec>            just wait
        LABEL <text>           progress marker in the log

    Every byte received is logged with timestamps to -Log. Exit code 0 and
    "BT_RESULT: PASS" on success; nonzero and "BT_RESULT: FAIL <reason>"
    otherwise (reasons: HANG line-<n>, FAILON matched, QUIET violated,
    port busy). A HANG leaves the machine UNTOUCHED so the caller can take
    an ILA capture of the live state before resetting.

.EXAMPLE
    powershell -File board_expect.ps1 -Script boardtests\lfn.bt -Log lfn.log
#>
param(
    [Parameter(Mandatory=$true)][string]$Script,
    [string]$Port = "COM11",
    [int]$Baud = 9600,
    [int]$Pace = 150,
    [string]$Log = "board_expect.log"
)

$ErrorActionPreference = "Stop"

function Stamp { (Get-Date).ToString("HH:mm:ss.fff") }

$lines = Get-Content $Script
$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, "None", 8, "One"
$sp.ReadTimeout = 100
$sp.DtrEnable = $true
$sp.RtsEnable = $true
try { $sp.Open() } catch {
    Write-Output "BT_RESULT: FAIL port-busy ($Port): $_"
    exit 2
}

$buf = ""                 # everything received so far
$mark = 0                 # EXPECT scans from here forward
$failPatterns = @()
$logSb = New-Object System.Text.StringBuilder

function Pump {
    # drain the port into $buf, log new bytes, check FAILON patterns
    $chunk = ""
    try { $chunk = $sp.ReadExisting() } catch {}
    if ($chunk.Length -gt 0) {
        $global:buf += $chunk
        [void]$logSb.Append("[$(Stamp) RX] " + ($chunk -replace "`r","\r" -replace "`n","\n`n"))
        foreach ($fp in $global:failPatterns) {
            if ($global:buf.Substring($global:mark) -match $fp) {
                return $fp
            }
        }
    }
    return $null
}

function Finish([string]$verdict, [int]$code) {
    [void]$logSb.AppendLine("")
    [void]$logSb.AppendLine("[$(Stamp)] $verdict")
    $logSb.ToString() | Set-Content -Path $Log
    $sp.Close()
    Write-Output $verdict
    exit $code
}

$ln = 0
foreach ($raw in $lines) {
    $ln++
    $line = $raw.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    $cmd = ($line -split "\s+", 2)[0].ToUpper()
    $rest = if ($line.Contains(" ")) { ($line -split "\s+", 2)[1] } else { "" }

    switch ($cmd) {
        "SEND" {
            [void]$logSb.AppendLine("[$(Stamp) TX] $rest")
            foreach ($ch in $rest.ToCharArray()) {
                $sp.Write([string]$ch); Start-Sleep -Milliseconds $Pace
                $hit = Pump; if ($hit) { Finish "BT_RESULT: FAIL FAILON '$hit' during SEND line-$ln" 1 }
            }
        }
        "SENDCR" {
            [void]$logSb.AppendLine("[$(Stamp) TX] <CR>")
            $sp.Write([string][char]13); Start-Sleep -Milliseconds $Pace
        }
        "EXPECT" {
            $parts = $rest -split "\s+", 2
            $secs = [double]$parts[0]; $rx = $parts[1]
            [void]$logSb.AppendLine("[$(Stamp) --] EXPECT '$rx' within ${secs}s")
            $deadline = (Get-Date).AddSeconds($secs)
            $matched = $false
            while ((Get-Date) -lt $deadline) {
                $hit = Pump; if ($hit) { Finish "BT_RESULT: FAIL FAILON '$hit' at line-$ln" 1 }
                if ($buf.Substring($mark) -match $rx) { $matched = $true; break }
                Start-Sleep -Milliseconds 100
            }
            if (-not $matched) {
                Finish "BT_RESULT: FAIL HANG line-$ln expecting '$rx' (${secs}s)" 3
            }
            # advance the scan mark past the match so repeated prompts work
            $m = [regex]::Match($buf.Substring($mark), $rx)
            $mark += $m.Index + $m.Length
            [void]$logSb.AppendLine("[$(Stamp) OK] matched '$rx'")
        }
        "FAILON" {
            $failPatterns += $rest
            [void]$logSb.AppendLine("[$(Stamp) --] FAILON '$rest' armed")
        }
        "QUIET" {
            $secs = [double]$rest
            [void]$logSb.AppendLine("[$(Stamp) --] QUIET ${secs}s")
            $lenBefore = $buf.Length
            $deadline = (Get-Date).AddSeconds($secs)
            while ((Get-Date) -lt $deadline) {
                $hit = Pump; if ($hit) { Finish "BT_RESULT: FAIL FAILON '$hit' at line-$ln" 1 }
                Start-Sleep -Milliseconds 100
            }
            if ($buf.Length -ne $lenBefore) {
                $noise = $buf.Substring($lenBefore)
                Finish "BT_RESULT: FAIL QUIET violated line-$ln (got: $($noise.Substring(0, [Math]::Min(60,$noise.Length)) -replace "`r|`n",' '))" 4
            }
        }
        "PAUSE" {
            $deadline = (Get-Date).AddSeconds([double]$rest)
            while ((Get-Date) -lt $deadline) {
                $hit = Pump; if ($hit) { Finish "BT_RESULT: FAIL FAILON '$hit' at line-$ln" 1 }
                Start-Sleep -Milliseconds 100
            }
        }
        "LABEL" {
            [void]$logSb.AppendLine("[$(Stamp) ==] $rest")
            Write-Output "[bt] $rest"
        }
        default {
            Finish "BT_RESULT: FAIL bad-command line-$ln '$cmd'" 5
        }
    }
}

Finish "BT_RESULT: PASS" 0
