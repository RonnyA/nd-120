<#
    Serial console for the Nexys 4 DDR, run from the Windows host.

    The board's FT2232 provides BOTH the USB-JTAG and the USB-UART on one
    device. Do NOT usbipd-attach it into WSL: that takes the JTAG channel away
    from Windows and Vivado can no longer program the board. Read the console
    from Windows instead, which is what this script does. WSL2 does not map
    COM ports to /dev/ttyS* at all, so there is no WSL-side alternative.

    From WSL:
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File console.ps1
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File console.ps1 -Send "1"

    Parameters:
        -Port     COM port (default COM11 - Ronny's board; check Device Manager)
        -Baud     default 9600 (board-test/ and the ND-120 build both use 9600)
        -Parity   None (default) or Even. The ND-120 OPCOM console is 7E1 in
                  some configurations; the board check is plain 8N1.
        -Send     text to send before listening
        -Pace     milliseconds between sent characters (default 100). Sending a
                  whole string at once drops characters on these consoles.
        -Seconds  how long to listen (default 30; 0 = until Ctrl-C)
#>
param(
    [string]$Port = "COM11",
    [int]$Baud = 9600,
    [ValidateSet("None", "Even")][string]$Parity = "None",
    [string]$Send = "",
    [int]$Pace = 100,
    [int]$Seconds = 30
)

$dataBits = if ($Parity -eq "Even") { 7 } else { 8 }

$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, $Parity, $dataBits, "One"
$sp.ReadTimeout = 200
$sp.DtrEnable = $true
$sp.RtsEnable = $true

try {
    $sp.Open()
} catch {
    Write-Host "Could not open ${Port}: $_" -ForegroundColor Red
    Write-Host "Ports present: $([System.IO.Ports.SerialPort]::GetPortNames() -join ', ')"
    exit 1
}

Write-Host "=== $Port @ $Baud $dataBits$($Parity.Substring(0,1))1 - Ctrl-C to stop ===" -ForegroundColor Cyan

if ($Send -ne "") {
    foreach ($ch in $Send.ToCharArray()) {
        $sp.Write([string]$ch)
        Start-Sleep -Milliseconds $Pace
    }
    Write-Host "--- sent $($Send.Length) char(s) ---" -ForegroundColor DarkGray
}

$deadline = if ($Seconds -gt 0) { (Get-Date).AddSeconds($Seconds) } else { [DateTime]::MaxValue }
try {
    while ((Get-Date) -lt $deadline) {
        try {
            $chunk = $sp.ReadExisting()
            if ($chunk.Length -gt 0) { Write-Host -NoNewline $chunk }
        } catch [TimeoutException] { }
        Start-Sleep -Milliseconds 50
    }
} finally {
    $sp.Close()
    Write-Host "`n=== closed ===" -ForegroundColor Cyan
}
