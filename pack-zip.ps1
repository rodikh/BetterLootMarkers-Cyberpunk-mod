param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$ZipPath
)

# Builds a zip that extracts cleanly on Windows and Linux: forward-slash entry
# names, no "./" prefix, no directory entries, and unix mode 0644 on files.
# (Compress-Archive on Windows PowerShell 5.1 writes backslash paths; tar.exe
# writes "./" prefixes and world-writable directory entries.)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$source = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')
if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }

$zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $files = Get-ChildItem -LiteralPath $source -Recurse -File | Sort-Object FullName
    foreach ($file in $files) {
        $entryName = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
        $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $file.LastWriteTime
        try { $entry.ExternalAttributes = (0x81A4 -shl 16) } catch { }

        $in = [System.IO.File]::OpenRead($file.FullName)
        $out = $entry.Open()
        try { $in.CopyTo($out) } finally { $out.Dispose(); $in.Dispose() }
    }
}
finally {
    $zip.Dispose()
}
