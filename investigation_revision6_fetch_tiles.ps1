# TD-027 Revision 6 evidence-collection script.
# Investigation only — does not touch any project source file.
# Run this yourself, locally, after setting $env:MML_API_KEY in this
# PowerShell session. The key is read from the environment only; it is
# never written to disk, never echoed to the console, and never appears
# in any committed file.
#
# Usage:
#   $env:MML_API_KEY = "your-real-key"
#   .\investigation_revision6_fetch_tiles.ps1
#
# Delete this script (and the downloaded PNGs, once handed back for
# analysis) when you're done — it is not part of the app and is not
# meant to be committed.

if (-not $env:MML_API_KEY) {
    Write-Error "MML_API_KEY is not set. Run: `$env:MML_API_KEY = 'your-real-key'` first."
    exit 1
}

$root = Join-Path $PSScriptRoot "investigation\revision6"
$wmtsBase = "https://avoin-karttakuva.maanmittauslaitos.fi/avoin/wmts/1.0.0/maastokartta/default/WGS84_Pseudo-Mercator"

# name, subfolder, z, x, y
$tiles = @(
    # --- Part A: Imatra checkpoint, z=13, 3x3 grid ---
    @{ Name = "imatra_z13_x4750_y2325"; Sub = "imatra"; Z = 13; X = 4750; Y = 2325 },
    @{ Name = "imatra_z13_x4751_y2325"; Sub = "imatra"; Z = 13; X = 4751; Y = 2325 },
    @{ Name = "imatra_z13_x4752_y2325"; Sub = "imatra"; Z = 13; X = 4752; Y = 2325 },
    @{ Name = "imatra_z13_x4750_y2326"; Sub = "imatra"; Z = 13; X = 4750; Y = 2326 },
    @{ Name = "imatra_z13_x4751_y2326"; Sub = "imatra"; Z = 13; X = 4751; Y = 2326 },  # center: Imatra checkpoint
    @{ Name = "imatra_z13_x4752_y2326"; Sub = "imatra"; Z = 13; X = 4752; Y = 2326 },
    @{ Name = "imatra_z13_x4750_y2327"; Sub = "imatra"; Z = 13; X = 4750; Y = 2327 },
    @{ Name = "imatra_z13_x4751_y2327"; Sub = "imatra"; Z = 13; X = 4751; Y = 2327 },
    @{ Name = "imatra_z13_x4752_y2327"; Sub = "imatra"; Z = 13; X = 4752; Y = 2327 },

    # --- Part A: Nuijamaa checkpoint, z=13, 3x3 grid ---
    @{ Name = "nuijamaa_z13_x4743_y2333"; Sub = "nuijamaa"; Z = 13; X = 4743; Y = 2333 },
    @{ Name = "nuijamaa_z13_x4744_y2333"; Sub = "nuijamaa"; Z = 13; X = 4744; Y = 2333 },
    @{ Name = "nuijamaa_z13_x4745_y2333"; Sub = "nuijamaa"; Z = 13; X = 4745; Y = 2333 },
    @{ Name = "nuijamaa_z13_x4743_y2334"; Sub = "nuijamaa"; Z = 13; X = 4743; Y = 2334 },
    @{ Name = "nuijamaa_z13_x4744_y2334"; Sub = "nuijamaa"; Z = 13; X = 4744; Y = 2334 },  # center: Nuijamaa checkpoint
    @{ Name = "nuijamaa_z13_x4745_y2334"; Sub = "nuijamaa"; Z = 13; X = 4745; Y = 2334 },
    @{ Name = "nuijamaa_z13_x4743_y2335"; Sub = "nuijamaa"; Z = 13; X = 4743; Y = 2335 },
    @{ Name = "nuijamaa_z13_x4744_y2335"; Sub = "nuijamaa"; Z = 13; X = 4744; Y = 2335 },
    @{ Name = "nuijamaa_z13_x4745_y2335"; Sub = "nuijamaa"; Z = 13; X = 4745; Y = 2335 },

    # --- Part B: Aland / archipelago / open-sea transect, z=12 ---
    @{ Name = "aland_origin_mariehamn_z12_x2274_y1187"; Sub = "aland_transect"; Z = 12; X = 2274; Y = 1187 },
    @{ Name = "aland_foglo_z12_x2279_y1188";            Sub = "aland_transect"; Z = 12; X = 2279; Y = 1188 },

    @{ Name = "aland_west_20km_z12_x2270_y1187"; Sub = "aland_transect"; Z = 12; X = 2270; Y = 1187 },
    @{ Name = "aland_west_40km_z12_x2266_y1187"; Sub = "aland_transect"; Z = 12; X = 2266; Y = 1187 },
    @{ Name = "aland_west_70km_z12_x2260_y1187"; Sub = "aland_transect"; Z = 12; X = 2260; Y = 1187 },

    @{ Name = "aland_sw_20km_z12_x2271_y1190"; Sub = "aland_transect"; Z = 12; X = 2271; Y = 1190 },
    @{ Name = "aland_sw_40km_z12_x2269_y1193"; Sub = "aland_transect"; Z = 12; X = 2269; Y = 1193 },
    @{ Name = "aland_sw_70km_z12_x2264_y1197"; Sub = "aland_transect"; Z = 12; X = 2264; Y = 1197 },

    @{ Name = "aland_south_20km_z12_x2274_y1191"; Sub = "aland_transect"; Z = 12; X = 2274; Y = 1191 },
    @{ Name = "aland_south_40km_z12_x2274_y1195"; Sub = "aland_transect"; Z = 12; X = 2274; Y = 1195 },
    @{ Name = "aland_south_70km_z12_x2274_y1201"; Sub = "aland_transect"; Z = 12; X = 2274; Y = 1201 },

    @{ Name = "aland_se_20km_z12_x2277_y1190"; Sub = "aland_transect"; Z = 12; X = 2277; Y = 1190 },
    @{ Name = "aland_se_40km_z12_x2280_y1193"; Sub = "aland_transect"; Z = 12; X = 2280; Y = 1193 },
    @{ Name = "aland_se_70km_z12_x2284_y1197"; Sub = "aland_transect"; Z = 12; X = 2284; Y = 1197 },

    @{ Name = "aland_east_20km_z12_x2278_y1187"; Sub = "aland_transect"; Z = 12; X = 2278; Y = 1187 },
    @{ Name = "aland_east_40km_z12_x2282_y1188"; Sub = "aland_transect"; Z = 12; X = 2282; Y = 1188 },
    @{ Name = "aland_east_70km_z12_x2289_y1188"; Sub = "aland_transect"; Z = 12; X = 2289; Y = 1188 }
)

foreach ($t in $tiles) {
    $dir = Join-Path $root $t.Sub
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $outFile = Join-Path $dir "$($t.Name).png"

    # WMTS ResourceURL convention is reversed: {TileMatrix}/{TileRow}/{TileCol} = z/y/x
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
Write-Host "Hand the 'investigation\revision6' folder back for analysis. Do not commit it."
