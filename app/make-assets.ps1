# Creates the app's four reminder sounds: original, non-musical (no bells, chimes, instruments or tunes).
# Chosen 2026-10-08 from the selection in salah-times-design\sounds.html.
# Run: powershell -ExecutionPolicy Bypass -File app\make-assets.ps1   (icons: see make-brand.ps1)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
New-Item -ItemType Directory -Force "$root\sounds" | Out-Null
$rate = 22050

function Write-Wav($path, [double[]]$samples) {
  # Bring every sound to the same peak volume (90%) so none is too quiet as a notification.
  $peak = 0.0; foreach ($s in $samples) { $a = [Math]::Abs($s); if ($a -gt $peak) { $peak = $a } }
  $gain = if ($peak -gt 0) { 0.9 / $peak } else { 1.0 }
  $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms; $data = $samples.Length * 2
  $w.Write([Text.Encoding]::ASCII.GetBytes("RIFF")); $w.Write([int](36 + $data)); $w.Write([Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
  $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1); $w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
  $w.Write([Text.Encoding]::ASCII.GetBytes("data")); $w.Write([int]$data)
  # 1.0 not 1: with whole-number limits PowerShell picks the integer version of Min/Max and rounds every sample to 0.
  foreach ($s in $samples) { $v = [Math]::Max(-1.0, [Math]::Min(1.0, $s * $gain)); $w.Write([int16]($v * 32000)) }
  [IO.File]::WriteAllBytes($path, $ms.ToArray())
}
# Place sounds at start times: list of @(time, samples). For a single sound write @(, @(0, ...)) so the list isn't flattened.
function Mix($parts, [double]$total) {
  $o = New-Object double[] ([int]($rate * $total))
  foreach ($p in $parts) { $st = [int]($rate * $p[0]); $s = $p[1]; for ($i = 0; $i -lt $s.Length -and $st + $i -lt $o.Length; $i++) { $o[$st + $i] += $s[$i] } }
  return ,$o
}
# Water drop: a short tone whose pitch rises quickly, with a fast fade.
function Drop([double]$f0, [double]$f1, [double]$dur = 0.16) {
  $n = [int]($rate * $dur); $o = New-Object double[] $n; $ph = 0.0
  for ($i = 0; $i -lt $n; $i++) { $t = $i / $rate; $f = $f0 + ($f1 - $f0) * [Math]::Min(1.0, $t / 0.05); $ph += 2 * [Math]::PI * $f / $rate
    $o[$i] = [Math]::Min(1.0, $t / 0.002) * [Math]::Exp(-28 * $t) * [Math]::Sin($ph) }
  return ,$o
}
# A plain tone that fades in and out (no melody).
function Swell([double]$f, [double]$dur) {
  $n = [int]($rate * $dur); $o = New-Object double[] $n
  for ($i = 0; $i -lt $n; $i++) { $t = $i / $rate; $e = [Math]::Sin([Math]::PI * $t / $dur); $o[$i] = $e * $e * ([Math]::Sin(2 * [Math]::PI * $f * $t) + 0.15 * [Math]::Sin(4 * [Math]::PI * $f * $t)) }
  return ,$o
}
# Single-pitch beep with a slightly firm edge.
function Beep([double]$f, [double]$dur) {
  $n = [int]($rate * $dur); $o = New-Object double[] $n
  for ($i = 0; $i -lt $n; $i++) { $t = $i / $rate; $e = [Math]::Min(1.0, [Math]::Min($t, $dur - $t) / 0.004); $s = [Math]::Sin(2 * [Math]::PI * $f * $t)
    $o[$i] = $e * [Math]::Sign($s) * [Math]::Pow([Math]::Abs($s), 0.5) }
  return ,$o
}

# Prayer has started: three water drops in quick succession.
Write-Wav "$root\sounds\start.wav" (Mix @(@(0, (Drop 560 1420)), @(0.17, (Drop 530 1340)), @(0.34, (Drop 500 1260))) 0.62)
# Before jamā'ah: soft pulse, twice.
Write-Wav "$root\sounds\jamaah.wav" (Mix @(@(0, (Swell 520 0.45)), @(0.55, (Swell 520 0.45))) 1.05)
# Last call: double beeps, three times, all on one pitch.
$b = @(); $t = 0.0; foreach ($k in 1..3) { $b += , @($t, (Beep 1000 0.1)); $t += 0.15; $b += , @($t, (Beep 1000 0.1)); $t += 0.35 }
Write-Wav "$root\sounds\lastcall.wav" (Mix $b $t)
# Daily reminders: soft swell, 1.05 s.
Write-Wav "$root\sounds\daily.wav" (Mix @(, @(0, (Swell 440 1.05))) 1.05)

Get-ChildItem "$root\sounds\*.wav" | ForEach-Object {
  $bytes = [IO.File]::ReadAllBytes($_.FullName); $n = [int](($bytes.Length - 44) / 2); $loud = 0
  for ($i = 0; $i -lt $n; $i += 2) { if ([Math]::Abs([BitConverter]::ToInt16($bytes, 44 + 2 * $i)) -gt 1500) { $loud++ } }
  "{0,-13} {1:N2}s, audible ~{2:N2}s" -f $_.Name, ($n / $rate), (2 * $loud / $rate)
}
