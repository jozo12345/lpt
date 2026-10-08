# Builds every app and website icon from the logo files in app\brand:
#   logo.png         1024x1024, full logo including its green background
#   logo-symbol.png  white symbol on transparent (for the notification icon)
# Run after changing the logo: powershell -ExecutionPolicy Bypass -File app\make-brand.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$app = $PSScriptRoot; $web = Split-Path $app -Parent
$logoPath = Join-Path $app "brand\logo.png"; $symbolPath = Join-Path $app "brand\logo-symbol.png"

function Load-Pixels($path) {
  $bmp = New-Object Drawing.Bitmap $path
  $rect = New-Object Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height
  $data = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
  [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
  $bmp.UnlockBits($data)
  $o = @{ W = $bmp.Width; H = $bmp.Height; S = $data.Stride; B = $bytes }; $bmp.Dispose(); return $o
}
function Save-Pixels($w, $h, [byte[]]$bytes, $path) {
  $bmp = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $data = $bmp.LockBits((New-Object Drawing.Rectangle 0, 0, $w, $h), [Drawing.Imaging.ImageLockMode]::WriteOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length); $bmp.UnlockBits($data)
  $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
function Resize($srcPath, $size, $outPath, [double]$scale = 1.0, $backgroundPath = $null) {
  $src = New-Object Drawing.Bitmap $srcPath
  $out = New-Object Drawing.Bitmap $size, $size; $g = [Drawing.Graphics]::FromImage($out)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear([Drawing.Color]::Transparent)
  if ($backgroundPath) { $bg = New-Object Drawing.Bitmap $backgroundPath; $g.DrawImage($bg, 0, 0, $size, $size); $bg.Dispose() }
  $s = [int][Math]::Round($size * $scale); $off = [int](($size - $s) / 2)
  $g.DrawImage($src, $off, $off, $s, $s)
  $out.Save($outPath, [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $out.Dispose(); $src.Dispose()
}

$L = Load-Pixels $logoPath; $W = $L.W; $H = $L.H; $S = $L.S; $B = $L.B
# Background colour of each row, read from the logo's left edge (pure background there).
$bgRow = New-Object 'int[,]' $H, 3
for ($y = 0; $y -lt $H; $y++) { $i = $y * $S + 6 * 4; $bgRow[$y, 0] = $B[$i + 2]; $bgRow[$y, 1] = $B[$i + 1]; $bgRow[$y, 2] = $B[$i] }
# Gold at the top and bottom of the pattern (it has its own gradient), sampled from the centre of the corner squares.
function Px($x, $y) { $i = $y * $S + $x * 4; return @($B[$i + 2], $B[$i + 1], $B[$i]) }
$goldTop = Px ([int]($W * 0.195)) ([int]($H * 0.19)); $goldBot = Px ([int]($W * 0.195)) ([int]($H * 0.80))

# 1) Background layer: the logo's green gradient, full size.
$bgBytes = New-Object byte[] ($W * $H * 4)
for ($y = 0; $y -lt $H; $y++) { for ($x = 0; $x -lt $W; $x++) { $o = ($y * $W + $x) * 4; $bgBytes[$o] = $bgRow[$y, 2]; $bgBytes[$o + 1] = $bgRow[$y, 1]; $bgBytes[$o + 2] = $bgRow[$y, 0]; $bgBytes[$o + 3] = 255 } }
$bgPath = Join-Path $app "assets\icon-background.png"; Save-Pixels $W $H $bgBytes $bgPath

# 2) Pattern layer: gold only, on transparent. Alpha comes from how far each pixel is from the background towards gold.
$fgBytes = New-Object byte[] ($W * $H * 4)
for ($y = 0; $y -lt $H; $y++) {
  $t = $y / ($H - 1); $gR = $goldTop[0] + ($goldBot[0] - $goldTop[0]) * $t; $gG = $goldTop[1] + ($goldBot[1] - $goldTop[1]) * $t; $gB = $goldTop[2] + ($goldBot[2] - $goldTop[2]) * $t
  $bR = $bgRow[$y, 0]; $bG = $bgRow[$y, 1]; $bB = $bgRow[$y, 2]
  for ($x = 0; $x -lt $W; $x++) {
    $i = $y * $S + $x * 4; $pR = $B[$i + 2]; $pG = $B[$i + 1]; $pB = $B[$i]
    $a = ($pR - $bR) / [Math]::Max(1, $gR - $bR); if ($a -le 0.02) { continue }; if ($a -gt 1) { $a = 1 }
    $o = ($y * $W + $x) * 4
    $fgBytes[$o + 2] = [byte][Math]::Max(0, [Math]::Min(255, ($pR - (1 - $a) * $bR) / $a))
    $fgBytes[$o + 1] = [byte][Math]::Max(0, [Math]::Min(255, ($pG - (1 - $a) * $bG) / $a))
    $fgBytes[$o] = [byte][Math]::Max(0, [Math]::Min(255, ($pB - (1 - $a) * $bB) / $a))
    $fgBytes[$o + 3] = [byte]([Math]::Round($a * 255))
  }
}
$patternPath = Join-Path $env:TEMP "salah-pattern.png"; Save-Pixels $W $H $fgBytes $patternPath

# Android adaptive icons show only the middle ~2/3 and may crop to a circle, so the pattern is shrunk to fit that safe area.
# 0.72 = slightly larger than the strict circle-safe 0.64 (user preferred it less zoomed out); circle masks may just touch the outer corners.
$SAFE = 0.72
Resize $patternPath 1024 (Join-Path $app "assets\icon-foreground.png") $SAFE
Resize $patternPath 1024 (Join-Path $app "assets\icon-only.png") $SAFE $bgPath

# Website icons: the full logo where the phone keeps the whole square, the safe version where it may crop.
Resize $logoPath 192 (Join-Path $web "icons\icon-192.png")
Resize $logoPath 512 (Join-Path $web "icons\icon-512.png")
Resize $logoPath 180 (Join-Path $web "icons\apple-touch-icon.png")
Resize $patternPath 512 (Join-Path $web "icons\icon-maskable-512.png") $SAFE $bgPath

# Favicon (browser tab): only the central eight-point star, on the same green gradient.
# The star sits in the middle of the logo, roughly 26%-74% across and down.
function Favicon($size, $outPath) {
  $pat = New-Object Drawing.Bitmap $patternPath; $bg = New-Object Drawing.Bitmap $bgPath
  $out = New-Object Drawing.Bitmap $size, $size; $g = [Drawing.Graphics]::FromImage($out)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
  $g.DrawImage($bg, 0, 0, $size, $size)
  $c = [int]($W * 0.255); $cw = $W - 2 * $c                       # crop box around the star
  $d = [int][Math]::Round($size * 0.86); $off = [int](($size - $d) / 2)   # star fills ~86% of the favicon
  $g.DrawImage($pat, (New-Object Drawing.Rectangle $off, $off, $d, $d), (New-Object Drawing.Rectangle $c, $c, $cw, $cw), [Drawing.GraphicsUnit]::Pixel)
  $out.Save($outPath, [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $out.Dispose(); $pat.Dispose(); $bg.Dispose()
}
Favicon 32 (Join-Path $web "icons\favicon-32.png")
Favicon 64 (Join-Path $web "icons\favicon-64.png")
Favicon 512 (Join-Path $env:TEMP "salah-favicon-preview.png")

# Notification icon: the white symbol, at Android's largest status-bar size.
Resize $symbolPath 96 (Join-Path $app "res\drawable\ic_stat_salah.png")
Remove-Item $patternPath
"Done: app\assets (3 files), app\res\drawable\ic_stat_salah.png, icons (4 files)"
