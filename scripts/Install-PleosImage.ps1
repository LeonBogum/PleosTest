param(
    [Parameter(Mandatory)][string]$Archive,
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk",
    [switch]$AcceptPleosLicense
)
$ErrorActionPreference = 'Stop'
if (-not $AcceptPleosLicense) {
    throw 'Read https://nexus-playground.pleos.ai/repository/raw-releases/connect-avd/2.x/crp-sys-img.xml and pass -AcceptPleosLicense only if you agree.'
}
if ((Get-FileHash -LiteralPath $Archive -Algorithm SHA1).Hash -ne 'b4f858d5bcc6c71506d7edfc872bcb9e5a11acaa') {
    throw 'Archive checksum differs from the official Pleos 2.1.0 repository.'
}
# The publisher ZIP declares TagId=android-automotive. Modern avdmanager
# derives its package ID from that tag, so install at the matching SDK path.
$destination = Join-Path $SdkRoot 'system-images\android-34\android-automotive\x86_64'
if (Test-Path $destination) { throw "Destination already exists; inspect it instead of overwriting: $destination" }
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Archive))
try {
    foreach ($entry in $zip.Entries) {
        $prefix = 'crp_avd_out_x86_64/'
        if (-not $entry.FullName.StartsWith($prefix)) { throw "Unexpected archive entry: $($entry.FullName)" }
        $relative = $entry.FullName.Substring($prefix.Length)
        if (-not $relative) { continue }
        $target = [System.IO.Path]::GetFullPath((Join-Path $destination $relative))
        if (-not $target.StartsWith($destination + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Archive entry escapes destination.'
        }
        if ($entry.FullName.EndsWith('/')) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        } else {
            New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
            $inputStream = $entry.Open()
            $outputStream = [System.IO.File]::Open($target, [System.IO.FileMode]::CreateNew)
            try { $inputStream.CopyTo($outputStream, 1048576) }
            finally { $inputStream.Dispose(); $outputStream.Dispose() }
        }
    }
} finally { $zip.Dispose() }
# Android SDK tools generate package.xml from the unmodified source.properties.
Write-Output "Installed official Pleos image: $destination"
