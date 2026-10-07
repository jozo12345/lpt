# Creates the app's reminder sounds (original tones, no third-party audio) and Android icons.
# Run once: powershell -ExecutionPolicy Bypass -File app\make-assets.ps1
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
New-Item -ItemType Directory -Force "$root\sounds", "$root\res\drawable", "$root\assets" | Out-Null

# ---------- Sounds: 22.05 kHz, 16-bit mono WAV ----------
$rate = 22050
function Write-Wav($path, [double[]]$samples) {
  $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
  $data = $samples.Length * 2
  $w.Write([Text.Encoding]::ASCII.GetBytes("RIFF")); $w.Write([int](36 + $data)); $w.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
  $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1); $w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
  $w.Write([Text.Encoding]::ASCII.GetBytes("data")); $w.Write([int]$data)
  foreach ($s in $samples) { $v = [Math]::Max(-1, [Math]::Min(1, $s)); $w.Write([int16]($v * 30000)) }
  [IO.File]::WriteAllBytes($path, $ms.ToArray())
}
# A soft bell: fundamental plus quieter overtones, quick attack, exponential decay.
function Bell([double]$freq, [double]$dur, [double]$decay = 4.0, [double]$vol = 0.6) {
  $n = [int]($rate * $dur); $out = New-Object double[] $n
  for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $rate
    $env = [Math]::Min(1, $t / 0.008) * [Math]::Exp(-$decay * $t)
    $out[$i] = $vol * $env * ([Math]::Sin(2 * [Math]::PI * $freq * $t) + 0.35 * [Math]::Sin(4 * [Math]::PI * $freq * $t) + 0.12 * [Math]::Sin(6 * [Math]::PI * $freq * $t)) / 1.47
  }
  return ,$out
}
# A harsher warning beep: square-ish tone with a flat envelope.
function Beep([double]$freq, [double]$dur, [double]$vol = 0.5) {
  $n = [int]($rate * $dur); $out = New-Object double[] $n
  for ($i = 0; $i -lt $n; $i++) {
    $t = $i / $rate; $edge = [Math]::Min(1, [Math]::Min($t, $dur - $t) / 0.006)
    $s = [Math]::Sin(2 * [Math]::PI * $freq * $t); $out[$i] = $vol * $edge * [Math]::Sign($s) * [Math]::Pow([Math]::Abs($s), 0.35)
  }
  return ,$out
}
function Silence([double]$dur) { return ,(New-Object double[] ([int]($rate * $dur))) }
# Overlap-add notes that start at given times.
function Mix($parts, [double]$total) {
  $out = New-Object double[] ([int]($rate * $total))
  foreach ($p in $parts) { $start = [int]($rate * $p[0]); $s = $p[1]; for ($i = 0; $i -lt $s.Length -and $start + $i -lt $out.Length; $i++) { $out[$start + $i] += $s[$i] } }
  return ,$out
}

# Prayer start: two calm descending bells (E5 then A4).
Write-Wav "$root\sounds\start.wav" (Mix @(@(0, (Bell 659.3 1.4 3.2)), @(0.45, (Bell 440 1.6 2.8))) 2.1)
# Before start: one soft high bell.
Write-Wav "$root\sounds\before.wav" (Mix @(@(0, (Bell 1046.5 1.2 4.5 0.5))) 1.2)
# Before jamaah: three rising bells (C5 E5 G5), "gather".
Write-Wav "$root\sounds\jamaah.wav" (Mix @(@(0, (Bell 523.3 1.0 4)), @(0.28, (Bell 659.3 1.0 4)), @(0.56, (Bell 784 1.5 3))) 2.1)
# Last call: urgent alternating beeps, twice.
$beeps = @(); $t = 0
foreach ($k in 1..2) { foreach ($f in 988, 740, 988, 740) { $beeps += ,@($t, (Beep $f 0.14)); $t += 0.19 }; $t += 0.25 }
Write-Wav "$root\sounds\lastcall.wav" (Mix $beeps ($t + 0.1))

# ---------- Icons ----------
Add-Type -AssemblyName System.Drawing
$green = [Drawing.Color]::FromArgb(255, 30, 74, 56); $gold = [Drawing.Color]::FromArgb(255, 227, 200, 142)
function Star($g, $size, $scale, $color, $width) {
  $c = $size / 2; $h = $size * $scale
  $pen = New-Object Drawing.Pen $color, ([float]($size * $width)); $pen.LineJoin = 'Miter'
  foreach ($ang in 0, 45) {
    $pts = @(); foreach ($k in 0..3) { $a = ($ang + 45 + 90 * $k) * [Math]::PI / 180; $pts += New-Object Drawing.PointF ([float]($c + $h * 1.414 * [Math]::Cos($a))), ([float]($c + $h * 1.414 * [Math]::Sin($a))) }
    $g.DrawPolygon($pen, [Drawing.PointF[]]$pts)
  }
  $cr = $size * 0.075; $g.DrawEllipse($pen, [float]($c - $cr), [float]($c - $cr), [float]($cr * 2), [float]($cr * 2))
}
function NewImg($size, [scriptblock]$draw, $path) {
  $bmp = New-Object Drawing.Bitmap $size, $size; $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'; $g.Clear([Drawing.Color]::Transparent)
  & $draw $g $size; $bmp.Save($path, [Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
}
# Adaptive launcher icon pieces (capacitor-assets): full icon, foreground star, plain background.
NewImg 1024 { param($g, $s) $g.Clear($green); Star $g $s 0.24 $gold 0.04 } "$root\assets\icon-only.png"
NewImg 1024 { param($g, $s) Star $g $s 0.20 $gold 0.035 } "$root\assets\icon-foreground.png"
NewImg 1024 { param($g, $s) $g.Clear($green) } "$root\assets\icon-background.png"
# Notification status-bar icon: white on transparent, as Android requires.
NewImg 96 { param($g, $s) Star $g $s 0.30 ([Drawing.Color]::White) 0.08 } "$root\res\drawable\ic_stat_salah.png"
Get-ChildItem -Recurse "$root\sounds", "$root\assets", "$root\res" -File | Select-Object @{n = "File"; e = { $_.FullName.Substring($root.Length + 1) } }, Length
