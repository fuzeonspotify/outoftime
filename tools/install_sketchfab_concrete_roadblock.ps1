param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$ModelUid = "f0dac55ac873433cbbfa3a42b6e0c622"
$ExpectedModelName = "concrete roadblock scan"
$ModelPageUrl = "https://sketchfab.com/3d-models/concrete-roadblock-scan-f0dac55ac873433cbbfa3a42b6e0c622"
$ModelInfoEndpoint = "https://api.sketchfab.com/v3/models/$ModelUid"
$DownloadEndpoint = "https://api.sketchfab.com/v3/models/$ModelUid/download"
$MaxModelBytes = 100MB
$Destination = Join-Path $ProjectRoot "assets\models\props\concrete_roadblock_scan"
$AttributionFile = Join-Path $ProjectRoot "assets\models\props\CONCRETE_ROADBLOCK_SCAN_ATTRIBUTION.md"

Write-Host "Installing the exact Concrete Roadblock Scan from Sketchfab..." -ForegroundColor Cyan
Write-Host "The Sketchfab token is entered locally, never printed, and never written to disk." -ForegroundColor DarkGray

$ModelInfo = Invoke-RestMethod -Method Get -Uri $ModelInfoEndpoint -Headers @{ Accept = "application/json" }
if ($null -eq $ModelInfo -or $ModelInfo.uid -ne $ModelUid) {
    throw "Sketchfab returned the wrong model record."
}
if (-not [bool]$ModelInfo.isDownloadable) {
    throw "The selected Sketchfab roadblock is not currently downloadable."
}
if ([string]::IsNullOrWhiteSpace([string]$ModelInfo.name)) {
    throw "The Sketchfab model record did not contain a name."
}
if ([string]$ModelInfo.name -ne $ExpectedModelName) {
    throw "Sketchfab returned '$($ModelInfo.name)' instead of the required '$ExpectedModelName'."
}

$SecureToken = Read-Host "Paste your Sketchfab API token" -AsSecureString
$TokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken)
try {
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($TokenPointer)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($TokenPointer)
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "No Sketchfab API token was entered."
}

$DownloadInfo = $null
$AuthenticationErrors = @()
try {
    foreach ($Scheme in @("Token", "Bearer")) {
        $Headers = @{
            Authorization = "$Scheme $Token"
            Accept = "application/json"
        }
        try {
            $DownloadInfo = Invoke-RestMethod -Method Get -Uri $DownloadEndpoint -Headers $Headers
            break
        }
        catch {
            $AuthenticationErrors += $_.Exception.Message
        }
        finally {
            $Headers = $null
        }
    }
}
finally {
    $Token = $null
}

if ($null -eq $DownloadInfo) {
    throw "Sketchfab authentication failed. Confirm the token is valid and that this model is downloadable. $($AuthenticationErrors -join ' | ')"
}
if ($null -eq $DownloadInfo.gltf -or [string]::IsNullOrWhiteSpace([string]$DownloadInfo.gltf.url)) {
    throw "Sketchfab did not return a glTF archive for model $ModelUid."
}
if ($null -ne $DownloadInfo.gltf.size -and [int64]$DownloadInfo.gltf.size -gt $MaxModelBytes) {
    throw "The reported glTF archive is $([math]::Round([int64]$DownloadInfo.gltf.size / 1MB, 2)) MB, exceeding the project's 100 MB per-model limit."
}

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("outoftime_roadblock_" + [Guid]::NewGuid().ToString("N"))
$ArchivePath = Join-Path $TempRoot "concrete_roadblock.zip"
$ExtractRoot = Join-Path $TempRoot "extracted"
New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null

try {
    Write-Host "Downloading the official textured glTF archive..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $DownloadInfo.gltf.url -OutFile $ArchivePath -UseBasicParsing

    $ActualArchiveBytes = (Get-Item $ArchivePath).Length
    if ($ActualArchiveBytes -le 0) {
        throw "The downloaded archive is empty."
    }
    if ($ActualArchiveBytes -gt $MaxModelBytes) {
        throw "The downloaded archive is $([math]::Round($ActualArchiveBytes / 1MB, 2)) MB, exceeding the 100 MB limit."
    }

    Expand-Archive -Path $ArchivePath -DestinationPath $ExtractRoot -Force

    $SceneFile = Get-ChildItem -Path $ExtractRoot -Recurse -File -Filter "scene.gltf" | Select-Object -First 1
    if ($null -eq $SceneFile) {
        $SceneFile = Get-ChildItem -Path $ExtractRoot -Recurse -File -Filter "*.gltf" | Select-Object -First 1
    }
    if ($null -eq $SceneFile) {
        throw "The Sketchfab archive contains no glTF scene file."
    }

    $SourceRoot = $SceneFile.Directory.FullName
    $BundleFiles = Get-ChildItem -Path $SourceRoot -Recurse -File
    $BundleBytes = [int64](($BundleFiles | Measure-Object -Property Length -Sum).Sum)
    if ($BundleBytes -le 0) {
        throw "The extracted roadblock bundle is empty."
    }
    if ($BundleBytes -gt $MaxModelBytes) {
        throw "The complete extracted roadblock bundle is $([math]::Round($BundleBytes / 1MB, 2)) MB, exceeding the project's 100 MB per-model limit."
    }

    $SceneJson = Get-Content -Raw -Path $SceneFile.FullName | ConvertFrom-Json
    if ($null -eq $SceneJson.meshes -or $SceneJson.meshes.Count -eq 0) {
        throw "The downloaded roadblock scene contains no mesh."
    }

    $BinaryFiles = Get-ChildItem -Path $SourceRoot -Recurse -File -Filter "*.bin"
    if ($BinaryFiles.Count -eq 0) {
        throw "The downloaded scene contains no binary geometry buffer."
    }

    $TextureFiles = Get-ChildItem -Path $SourceRoot -Recurse -File |
        Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp|ktx2)$' }
    if ($TextureFiles.Count -eq 0) {
        throw "The downloaded roadblock contains no image textures. Installation was stopped."
    }

    if (Test-Path $Destination) {
        Remove-Item -Recurse -Force $Destination
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -Path (Join-Path $SourceRoot "*") -Destination $Destination -Recurse -Force

    $InstalledScene = Join-Path $Destination "scene.gltf"
    if (-not (Test-Path $InstalledScene)) {
        Copy-Item -Path $SceneFile.FullName -Destination $InstalledScene -Force
    }

    $InstalledJson = Get-Content -Raw -Path $InstalledScene | ConvertFrom-Json
    $InstalledTextures = Get-ChildItem -Path $Destination -Recurse -File |
        Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp|ktx2)$' }
    $InstalledBytes = [int64](((Get-ChildItem -Path $Destination -Recurse -File | Measure-Object -Property Length -Sum).Sum))
    if ($InstalledBytes -gt $MaxModelBytes) {
        throw "Installed bundle size verification failed: $([math]::Round($InstalledBytes / 1MB, 2)) MB exceeds the 100 MB limit."
    }
    if ($null -eq $InstalledJson.meshes -or $InstalledJson.meshes.Count -eq 0) {
        throw "Mesh verification failed after installation."
    }
    if ($InstalledTextures.Count -eq 0) {
        throw "Texture verification failed after installation."
    }

    $CreatorDisplayName = [string]$ModelInfo.user.displayName
    $CreatorUserName = [string]$ModelInfo.user.username
    if ([string]::IsNullOrWhiteSpace($CreatorDisplayName)) {
        $CreatorDisplayName = $CreatorUserName
    }
    if ([string]::IsNullOrWhiteSpace($CreatorUserName)) {
        $CreatorUserName = "unknown"
    }

    $LicenseLabel = [string]$ModelInfo.license.label
    $LicenseUrl = [string]$ModelInfo.license.url
    if ([string]::IsNullOrWhiteSpace($LicenseLabel)) {
        throw "Sketchfab did not return license information for this model. Installation was stopped."
    }

    $AttributionContent = @"
# Concrete Roadblock Scan

- **Model:** $($ModelInfo.name)
- **Creator:** $CreatorDisplayName (@$CreatorUserName)
- **Source:** $ModelPageUrl
- **Sketchfab model UID:** $ModelUid
- **License:** $LicenseLabel
- **License URL:** $LicenseUrl

This exact model is used as the required first-impact roadblock in *Out of Time*.
The original creator, license, and Sketchfab source must remain credited with distributed builds and project copies.
"@
    Set-Content -Path $AttributionFile -Value $AttributionContent -Encoding UTF8

    Write-Host "Installed the exact $([math]::Round($InstalledBytes / 1MB, 2)) MB roadblock bundle with $($InstalledJson.meshes.Count) mesh definition(s) and $($InstalledTextures.Count) texture file(s)." -ForegroundColor Green

    $GodotCache = Join-Path $ProjectRoot ".godot"
    if (Test-Path $GodotCache) {
        Remove-Item -Recurse -Force $GodotCache
    }

    Set-Location $ProjectRoot
    git add -- "assets/models/props/concrete_roadblock_scan" "assets/models/props/CONCRETE_ROADBLOCK_SCAN_ATTRIBUTION.md"
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed."
    }

    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "Add the exact Sketchfab concrete roadblock"
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed."
        }
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed."
        }
        Write-Host "The exact roadblock model and official attribution were committed and pushed to main." -ForegroundColor Green
    }
    else {
        Write-Host "The exact roadblock model is already committed." -ForegroundColor Green
    }
}
finally {
    if (Test-Path $TempRoot) {
        Remove-Item -Recurse -Force $TempRoot -ErrorAction SilentlyContinue
    }
}

Write-Host "Done. Reopen Godot and allow the roadblock scene and textures to import." -ForegroundColor Green
