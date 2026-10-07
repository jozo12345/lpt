# Serves this folder at http://localhost:8080/ for testing on this computer. Stop with Ctrl+C.
param([int]$Port = 8080)
$root = $PSScriptRoot
$types = @{ ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".mjs" = "text/javascript; charset=utf-8";
  ".json" = "application/json; charset=utf-8"; ".webmanifest" = "application/manifest+json"; ".png" = "image/png"; ".svg" = "image/svg+xml"; ".md" = "text/plain; charset=utf-8" }
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "Serving $root at http://localhost:$Port/"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart("/")
  if (-not $path) { $path = "index.html" }
  $file = Join-Path $root $path
  if ((Test-Path $file -PathType Leaf) -and ([IO.Path]::GetFullPath($file)).StartsWith($root)) {
    $bytes = [IO.File]::ReadAllBytes($file)
    $ext = [IO.Path]::GetExtension($file).ToLower()
    $ctx.Response.ContentType = if ($types[$ext]) { $types[$ext] } else { "application/octet-stream" }
    $ctx.Response.Headers.Add("Cache-Control", "no-cache")
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else { $ctx.Response.StatusCode = 404 }
  $ctx.Response.Close()
}
