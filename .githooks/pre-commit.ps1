$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
$stagedPaths = @(& git diff --cached --name-only --diff-filter=ACMR)
if ($stagedPaths.Count -eq 0) {
    exit 0
}

$signingValues = @()
$propertiesPath = Join-Path $repoRoot 'app\android\key.properties'
if (Test-Path -LiteralPath $propertiesPath) {
    foreach ($line in Get-Content -LiteralPath $propertiesPath) {
        if ($line -match '^\s*(storePassword|keyPassword)\s*=(.*)$') {
            $value = $Matches[2].Trim()
            if ($value) { $signingValues += $value }
        }
    }
}

$blocked = @()
foreach ($path in $stagedPaths) {
    $leaf = [System.IO.Path]::GetFileName($path).ToLowerInvariant()
    $extension = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($leaf -eq 'key.properties' -or $extension -in @('.jks', '.keystore', '.p12', '.pfx')) {
        $blocked += "$path (signing file)"
        continue
    }

    $blobLines = @(& git show ":$path")
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Could not inspect staged file: $path"
        exit 1
    }
    $content = $blobLines -join "`n"
    if ($content -match '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----') {
        $blocked += "$path (private key material)"
        continue
    }
    foreach ($value in $signingValues) {
        if ($content.Contains($value)) {
            $blocked += "$path (local signing password)"
            break
        }
    }
}

if ($blocked.Count -gt 0) {
    Write-Error "Commit blocked: signing secrets must not be staged:`n  $($blocked -join "`n  ")`nRemove the secret from the index; keep it in ignored local files."
    exit 1
}
