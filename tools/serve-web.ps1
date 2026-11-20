param([int]$Port = 8060)
$ErrorActionPreference = 'Stop'
$webRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../builds/web'))
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Output "Serving $webRoot at http://127.0.0.1:$Port/ (Ctrl+C to stop)"
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $relative = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).TrimStart('/')
            if (!$relative) { $relative = 'index.html' }
            $target = [IO.Path]::GetFullPath((Join-Path $webRoot $relative))
            if (!$target.StartsWith($webRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                $context.Response.StatusCode = 403
            } elseif (![IO.File]::Exists($target)) {
                $context.Response.StatusCode = 404
            } else {
                $mimeTypes = @{ '.html'='text/html; charset=utf-8'; '.js'='application/javascript'; '.wasm'='application/wasm'; '.png'='image/png'; '.pck'='application/octet-stream' }
                $extension = [IO.Path]::GetExtension($target)
                $context.Response.ContentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { 'application/octet-stream' }
                $context.Response.Headers['Cache-Control'] = 'no-store'
                $bytes = [IO.File]::ReadAllBytes($target)
                $context.Response.ContentLength64 = $bytes.Length
                $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        } catch {
            Write-Warning $_.Exception.Message
        } finally {
            $context.Response.Close()
        }
    }
} finally {
    $listener.Close()
}
