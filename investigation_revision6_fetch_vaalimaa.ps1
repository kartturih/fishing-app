# TD-027 Revision 6 — third independent border sample (Vaalimaa).
# Investigation only — does not touch any project source file.
#
# Usage:
#   $env:MML_API_KEY = "your-real-key"
#   .\investigation_revision6_fetch_vaalimaa.ps1
#
# Delete this script (and the downloaded PNGs, once handed back for
# analysis) when done — not part of the app, not meant to be committed.

if (-not $env:MML_API_KEY) {
    Write-Error "MML_API_KEY is not set. Run: `$env:MML_API_KEY = 'your-real-key'` first."
    exit 1
}

$root = Join-Path $PSScriptRoot "investigation\revision6\vaalimaa"
$wmtsBase = "https://avoin-karttakuva.maanmittauslaitos.fi/avoin/wmts/1.0.0/maastokartta/default/WGS84_Pseudo-Mercator"
New-Item -ItemType Directory -Force -Path $root | Out-Null

# Vaalimaa border crossing (60.6000N, 27.8050E), z=13, 3x3 grid, center x=4728 y=2351
$tiles = @(
    @{ Name = "vaalimaa_z13_x4727_y2350"; Z = 13; X = 4727; Y = 2350 },
    @{ Name = "vaalimaa_z13_x4728_y2350"; Z = 13; X = 4728; Y = 2350 },
    @{ Name = "vaalimaa_z13_x4729_y2350"; Z = 13; X = 4729; Y = 2350 },
    @{ Name = "vaalimaa_z13_x4727_y2351"; Z = 13; X = 4727; Y = 2351 },
    @{ Name = "vaalimaa_z13_x4728_y2351"; Z = 13; X = 4728; Y = 2351 },  # center: Vaalimaa checkpoint
    @{ Name = "vaalimaa_z13_x4729_y2351"; Z = 13; X = 4729; Y = 2351 },
    @{ Name = "vaalimaa_z13_x4727_y2352"; Z = 13; X = 4727; Y = 2352 },
    @{ Name = "vaalimaa_z13_x4728_y2352"; Z = 13; X = 4728; Y = 2352 },
    @{ Name = "vaalimaa_z13_x4729_y2352"; Z = 13; X = 4729; Y = 2352 }
)

foreach ($t in $tiles) {
    $outFile = Join-Path $root "$($t.Name).png"
    $url = "$wmtsBase/$($t.Z)/$($t.Y)/$($t.X).png?api-key=$($env:MML_API_KEY)"
    Write-Host "Fetching $($t.Name) ..."
    try {
        Invoke-WebRequest -Uri $url -OutFile $outFile -ErrorAction Stop
    } catch {
        Write-Warning "Failed: $($t.Name) - $($_.Exception.Message)"
    }
    Start-Sleep -Milliseconds 400
}

Write-Host ""
Write-Host "Done. $($tiles.Count) tiles requested into $root"
Write-Host "Hand the folder back for analysis. Do not commit it."
