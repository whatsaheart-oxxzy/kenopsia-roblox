# Kenopsia -- start the WEPPY HTTP bridge that tools/weppy.ps1 talks to.
#
#   .\tools\start-weppy.ps1
#
# Run this once per working session, BEFORE Test-KenopsiaPreflight or
# Get-KenopsiaParity. Idempotent: if the bridge is already up it reports and
# exits without starting a second one.
#
# WHY THIS IS NEEDED ----------------------------------------------------------
#
# weppy-roblox-mcp is registered in .claude.json under the project "C:/Users/Asus"
# only. An agent session started from any other directory never launches it, so
# port 3002 stays closed and every weppy.ps1 call fails with
# "WEPPY server not reachable on any candidate port." Nothing is broken in that
# case -- the server was simply never started.
#
# WHY A VISIBLE cmd WINDOW ----------------------------------------------------
#
# The server speaks MCP over **stdio**. When it is launched with stdin already
# closed -- which is what backgrounding or redirecting normally does -- it starts,
# logs "MCP Server started successfully", and then shuts the HTTP bridge down
# again about half a second later. Verified: it binds 3002 and immediately
# releases it.
#
# `cmd /k` keeps a real console attached, so stdin never reaches EOF and the
# bridge stays up. The window is deliberately left visible-but-minimised: it is
# the off switch. Close it and the bridge stops.

param(
    [int] $TimeoutSec = 60,
    [int] $Port = 3002
)

$ErrorActionPreference = "Stop"

function Get-WeppyStatus {
    param([int] $P)
    try {
        return Invoke-RestMethod -Uri "http://127.0.0.1:$P/status" -TimeoutSec 3 -ErrorAction Stop
    } catch {
        return $null
    }
}

# The port answering does NOT mean the bridge is usable: the Studio plugin
# registers a few seconds later, and a call made in that window fails with
# "Target place not found", which reads like the wrong place rather than a race.
# Waiting here means callers cannot hit it.
function Wait-WeppyPlugin {
    param([int] $P, [int] $Seconds = 45)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        $s = Get-WeppyStatus -P $P
        if ($null -ne $s -and @($s.pluginClients).Count -gt 0) { return $s }
        Start-Sleep -Seconds 2
    }
    return (Get-WeppyStatus -P $P)
}

function Write-WeppySummary {
    param($Status)
    Write-Host "  version   $($Status.version)   pid $($Status.pid)" -ForegroundColor Gray
    $clients = @($Status.pluginClients)
    if ($clients.Count -eq 0) {
        Write-Host "  WARNING: no Studio plugin connected." -ForegroundColor Yellow
        Write-Host "           Open the place in Roblox Studio. If it is already open," -ForegroundColor Yellow
        Write-Host "           check that WeppyRobloxMCP.rbxm is enabled in Plugins." -ForegroundColor Yellow
        return
    }
    foreach ($c in $clients) {
        Write-Host "  studio    $($c.placeName) ($($c.placeId))  state=$($c.studioState)  alias=$($c.targetAlias)" -ForegroundColor Green
    }
    if ($clients.Count -gt 1) {
        Write-Host "  WARNING: $($clients.Count) Studio clients -- routing is ambiguous and the" -ForegroundColor Yellow
        Write-Host "           preflight will refuse to transfer. Close all but one." -ForegroundColor Yellow
    }
}

$existing = Get-WeppyStatus -P $Port
if ($null -ne $existing) {
    Write-Host "WEPPY already running on port $Port." -ForegroundColor Green
    Write-WeppySummary -Status (Wait-WeppyPlugin -P $Port)
    exit 0
}

Write-Host "Starting WEPPY on port $Port ..." -ForegroundColor Cyan
Start-Process -FilePath "cmd.exe" `
              -ArgumentList '/k', 'npx -y @weppy/roblox-mcp@latest' `
              -WindowStyle Minimized | Out-Null

# First run may download the package, so the timeout is generous.
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    $status = Get-WeppyStatus -P $Port
    if ($null -ne $status) {
        Write-Host "WEPPY online after $([int]((Get-Date) - $deadline.AddSeconds(-$TimeoutSec)).TotalSeconds)s." -ForegroundColor Green
        Write-WeppySummary -Status (Wait-WeppyPlugin -P $Port)
        Write-Host ""
        Write-Host "Stop it by closing the minimised 'npx' console window." -ForegroundColor Gray
        exit 0
    }
}

Write-Host "WEPPY did not come up within ${TimeoutSec}s." -ForegroundColor Red
Write-Host "Check the minimised console window for the actual error -- the usual" -ForegroundColor Red
Write-Host "causes are no network on first install, or port $Port already taken." -ForegroundColor Red
exit 1
