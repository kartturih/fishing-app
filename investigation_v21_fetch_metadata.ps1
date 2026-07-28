# MML v21 vector-tile PoC — metadata-collection script.
# Investigation only — does not touch any project source file.
# Run this yourself, locally, after setting $env:MML_API_KEY in this
# PowerShell session. The key is read from the environment only; it is
# never written to disk, never echoed to the console, and never appears
# in any committed file. The two saved JSON files themselves may contain
# tile-URL templates with the key embedded (MML's own TileJSON/style
# format does this) — do not commit the investigation\v21 folder, and
# delete it once handed back for analysis.
#
# Usage:
#   $env:MML_API_KEY = "your-real-key"
#   .\investigation_v21_fetch_metadata.ps1

if (-not $env:MML_API_KEY) {
    Write-Error "MML_API_KEY is not set. Run: `$env:MML_API_KEY = 'your-real-key'` first."
    exit 1
}

$root = Join-Path $PSScriptRoot "investigation\v21"
New-Item -ItemType Directory -Force -Path $root | Out-Null

$tilejsonUrl = "https://avoin-karttakuva.maanmittauslaitos.fi/vectortiles/tilejson/taustakartta/1.0.0/taustakartta/default/v21/WGS84_Pseudo-Mercator/tilejson.json?api-key=$($env:MML_API_KEY)"
$styleUrl = "https://avoin-karttakuva.maanmittauslaitos.fi/vectortiles/stylejson/v21/backgroundmap.json?TileMatrixSet=WGS84_Pseudo-Mercator&api-key=$($env:MML_API_KEY)"

Write-Host "Fetching v21 TileJSON..."
try {
    Invoke-WebRequest -Uri $tilejsonUrl -OutFile (Join-Path $root "tilejson.json") -ErrorAction Stop
    Write-Host "  Saved tilejson.json"
} catch {
    Write-Warning "  Failed: $($_.Exception.Message)"
}

Write-Host "Fetching v21 backgroundmap style..."
try {
    Invoke-WebRequest -Uri $styleUrl -OutFile (Join-Path $root "backgroundmap_style.json") -ErrorAction Stop
    Write-Host "  Saved backgroundmap_style.json"
} catch {
    Write-Warning "  Failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Done. Hand the 'investigation\v21' folder back for analysis. Do not commit it."
