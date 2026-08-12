# Kenopsia -- WEPPY MCP helpers (PowerShell 5.1)
#
# Talks to the WEPPY server's local HTTP endpoint directly instead of going
# through the MCP tool layer. Script bodies therefore never pass through an
# agent's context, which makes a whole-place SHA-256 parity check cheap and
# free of transcription-induced false mismatches.
#
#   . .\tools\weppy.ps1
#   Test-KenopsiaPreflight -PlaceId 129909297895850 -ExpectedGameId 10640788131
#   Get-KenopsiaParity -PlaceId 129909297895850 -SourceRoot dev-src -Map $map
#
# Writes still go through the normal MCP tools. This file is read/verify only.

$script:WeppyPort = 3002

# Known places. Never let a call default to "whatever Studio is focused on".
$script:KenopsiaPlaces = @{
    MainGame = @{ PlaceId = 110672791536316; GameId = 10640788131; Source = "studio-src" }
    Dev      = @{ PlaceId = 129909297895850; GameId = 10640788131; Source = "dev-src"    }
}

function Get-WeppyPort {
    # The server may be restarted on a different port; /status is the cheap probe.
    foreach ($p in @($script:WeppyPort, 3002, 3000, 3001)) {
        try {
            $null = Invoke-RestMethod -Uri "http://127.0.0.1:$p/status" -TimeoutSec 3 -ErrorAction Stop
            $script:WeppyPort = $p
            return $p
        } catch { }
    }
    throw "WEPPY server not reachable on any candidate port."
}

function Invoke-Weppy {
    <#
      Calls POST /execute. `requestId` is MANDATORY -- without it the server
      returns a truncated body with `success` unset, which is indistinguishable
      from a read failure and makes every file look broken.
    #>
    param(
        [Parameter(Mandatory)][string] $Command,
        [hashtable] $Params = @{},
        [Parameter(Mandatory)][int64] $PlaceId,
        [int] $TimeoutSec = 45
    )
    $port = Get-WeppyPort
    $Params = $Params.Clone()
    $Params["placeId"] = $PlaceId
    $body = @{
        command   = $Command
        params    = $Params
        requestId = "kenopsia-" + [guid]::NewGuid().ToString("N").Substring(0, 10)
    } | ConvertTo-Json -Depth 10 -Compress

    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:$port/execute" -Method POST `
             -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec -ErrorAction Stop
    } catch {
        return [pscustomobject]@{ ok = $false; error = "HTTP: $($_.Exception.Message)"; data = $null }
    }

    if (-not $r.success) {
        return [pscustomobject]@{ ok = $false; error = [string]$r.error; data = $null }
    }
    # The only proof the call hit the intended place.
    if ([int64]$r.routing.actualPlaceId -ne $PlaceId) {
        return [pscustomobject]@{
            ok = $false
            error = "ROUTING MISMATCH: asked $PlaceId, hit $($r.routing.actualPlaceId) ($($r.routing.actualPlaceName))"
            data = $null
        }
    }
    return [pscustomobject]@{ ok = $true; error = $null; data = $r.data; routing = $r.routing }
}

function Test-KenopsiaPreflight {
    <#
      Gate M1 section 1.4: correct place, correct universe, Edit mode, clean git,
      exactly one Studio writer. Returns $true only if every check passes.
    #>
    param(
        [Parameter(Mandatory)][int64] $PlaceId,
        [int64] $ExpectedGameId = 0,
        [string] $RepoRoot = $null
    )
    $port = Get-WeppyPort
    $fail = @()
    Write-Host "PREFLIGHT  place $PlaceId  (port $port)" -ForegroundColor Cyan

    $status = Invoke-RestMethod -Uri "http://127.0.0.1:$port/status" -TimeoutSec 10
    $clients = @($status.pluginClients)
    $target  = $clients | Where-Object { [int64]$_.placeId -eq $PlaceId }

    if (-not $target) {
        $open = ($clients | ForEach-Object { "$($_.placeId) ($($_.placeName))" }) -join ", "
        $fail += "Place $PlaceId is not open in Studio. Currently connected: $(if($open){$open}else{'none'})"
    } else {
        if (@($target).Count -gt 1) { $fail += "Place $PlaceId has $(@($target).Count) plugin clients -- ambiguous routing" }
        $t = @($target)[0]
        if ($t.studioState -ne "edit") { $fail += "Studio is '$($t.studioState)', expected 'edit'. Stop Play before transferring." }
        else { Write-Host "  OK  Edit mode              $($t.placeName)  Studio $($t.studioVersion)" -ForegroundColor Green }
    }

    if (@($clients).Count -gt 1) {
        $fail += "$(@($clients).Count) Studio clients connected -- only one writer is permitted"
    } else { Write-Host "  OK  single Studio client" -ForegroundColor Green }

    $mcp = @($status.mcpInstances)
    if (@($mcp).Count -gt 1) {
        $names = ($mcp | ForEach-Object { $_.aiClientName }) -join ", "
        $fail += "$(@($mcp).Count) MCP instances attached ($names) -- close the others"
    } else { Write-Host "  OK  single MCP instance" -ForegroundColor Green }

    if ($ExpectedGameId -gt 0 -and $target) {
        $g = Invoke-Weppy -Command "manage_properties_get" -Params @{ path = "game"; property = "GameId" } -PlaceId $PlaceId
        if ($g.ok) {
            if ([int64]$g.data.value -ne $ExpectedGameId) {
                $fail += "GameId is $($g.data.value), expected $ExpectedGameId -- WRONG UNIVERSE"
            } else { Write-Host "  OK  universe $ExpectedGameId" -ForegroundColor Green }
        } else {
            Write-Host "  --  GameId unreadable at this tier ($($g.error)); verify manually" -ForegroundColor Yellow
        }
    }

    if ($RepoRoot) {
        Push-Location $RepoRoot
        $dirty = git status --porcelain
        $head  = (git rev-parse --short HEAD)
        Pop-Location
        if (-not [string]::IsNullOrWhiteSpace(($dirty | Out-String))) {
            $fail += "Working tree is dirty -- commit or stash before transferring"
        } else { Write-Host "  OK  clean tree at $head" -ForegroundColor Green }
    }

    if ($fail.Count -gt 0) {
        Write-Host "PREFLIGHT FAILED" -ForegroundColor Red
        $fail | ForEach-Object { Write-Host "  X  $_" -ForegroundColor Red }
        return $false
    }
    Write-Host "PREFLIGHT PASS" -ForegroundColor Green
    return $true
}

function Get-KenopsiaParity {
    <#
      Byte-exact SHA-256 comparison between a local source tree and the live
      place. $Map is an ordered hashtable: relative file path -> Studio path.
      Returns the row objects; $Ok on the summary tells you if everything matched.
    #>
    param(
        [Parameter(Mandatory)][int64] $PlaceId,
        [Parameter(Mandatory)][string] $SourceRoot,
        [Parameter(Mandatory)] $Map
    )
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $rows = @(); $ok = 0; $bad = 0

    foreach ($rel in $Map.Keys) {
        $local = Join-Path $SourceRoot ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $local)) {
            $rows += [pscustomobject]@{ File = $rel; Result = "LOCAL-MISSING"; Studio = "-" }; $bad++; continue
        }
        $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $local).Hash
        $r = Invoke-Weppy -Command "manage_scripts_get_source" -Params @{ path = $Map[$rel] } -PlaceId $PlaceId
        if (-not $r.ok) {
            $rows += [pscustomobject]@{ File = $rel; Result = "READ-FAIL: $($r.error)"; Studio = "-" }; $bad++; continue
        }
        $studioHash = (($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes([string]$r.data.source)) |
                        ForEach-Object { $_.ToString("X2") }) -join "")
        if ($studioHash -eq $localHash) { $ok++; $res = "MATCH" } else { $bad++; $res = "*** MISMATCH ***" }
        $rows += [pscustomobject]@{ File = $rel; Result = $res; Studio = $studioHash.Substring(0, 16) }
    }

    $rows | Format-Table -AutoSize | Out-String | Write-Host
    if ($bad -eq 0) { Write-Host "PARITY: $ok/$($Map.Count) MATCH" -ForegroundColor Green }
    else            { Write-Host "PARITY: $ok match / $bad FAIL of $($Map.Count) -- STOP" -ForegroundColor Red }
    return $rows
}

function Get-KenopsiaChildren {
    <#
      WARNING: query_instances_descendants is PRO. At Basic it silently falls
      back to query_instances_children (see data.proFallback) and returns a
      FLATTENED SUBTREE, not direct children. Reading it as a child list
      invents duplicate instances. This wrapper surfaces the fallback so the
      caller cannot be fooled by it.
    #>
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][int64] $PlaceId
    )
    $r = Invoke-Weppy -Command "query_instances_descendants" -Params @{ path = $Path } -PlaceId $PlaceId
    if (-not $r.ok) { Write-Host "  query failed: $($r.error)" -ForegroundColor Red; return $null }
    if ($r.data.proFallback) {
        Write-Host "  NOTE: PRO fallback active -- result is a FLATTENED SUBTREE, not direct children." -ForegroundColor Yellow
    }
    return $r.data.children
}
