param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$ModelUid = "f72642a034744cf5966f29a85eba4d05"
$ModelName = "Bat Animation Fly"
$MaxModelBytes = 50MB
$Destination = Join-Path $ProjectRoot "assets\models\animals\realistic_bat"
$AttributionPath = "assets/models/animals/REALISTIC_BAT_ATTRIBUTION.md"
$DownloadEndpoint = "https://api.sketchfab.com/v3/models/$ModelUid/download"

Write-Host "Installing $ModelName from Sketchfab..." -ForegroundColor Cyan
Write-Host "The API token is entered locally, is never printed, and is never written to disk." -ForegroundColor DarkGray

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
    # Personal API tokens use Token. OAuth access tokens use Bearer. Supporting
    # both keeps the installer local and avoids asking which token type was used.
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
    throw "Sketchfab authentication failed. Confirm that the token is valid and that this model is downloadable. $($AuthenticationErrors -join ' | ')"
}
if ($null -eq $DownloadInfo.gltf -or [string]::IsNullOrWhiteSpace($DownloadInfo.gltf.url)) {
    throw "Sketchfab did not return a glTF archive for model $ModelUid."
}

if ($null -ne $DownloadInfo.gltf.size) {
    $ReportedSize = [int64]$DownloadInfo.gltf.size
    if ($ReportedSize -gt $MaxModelBytes) {
        throw "The reported glTF archive is $([math]::Round($ReportedSize / 1MB, 2)) MB, exceeding the project's 50 MB per-model limit."
    }
}

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("outoftime_bat_" + [Guid]::NewGuid().ToString("N"))
$ArchivePath = Join-Path $TempRoot "animated_bat.zip"
$ExtractRoot = Join-Path $TempRoot "extracted"
New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null

try {
    Write-Host "Downloading the official textured and animated glTF archive..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $DownloadInfo.gltf.url -OutFile $ArchivePath -UseBasicParsing

    $ActualArchiveBytes = (Get-Item $ArchivePath).Length
    if ($ActualArchiveBytes -le 0) {
        throw "The downloaded archive is empty."
    }
    if ($ActualArchiveBytes -gt $MaxModelBytes) {
        throw "The downloaded archive is $([math]::Round($ActualArchiveBytes / 1MB, 2)) MB, exceeding the 50 MB limit."
    }

    Expand-Archive -Path $ArchivePath -DestinationPath $ExtractRoot -Force

    $SceneFile = Get-ChildItem -Path $ExtractRoot -Recurse -File -Filter "scene.gltf" |
        Select-Object -First 1
    if ($null -eq $SceneFile) {
        $SceneFile = Get-ChildItem -Path $ExtractRoot -Recurse -File -Filter "*.gltf" |
            Select-Object -First 1
    }
    if ($null -eq $SceneFile) {
        throw "The Sketchfab archive contains no glTF scene file."
    }

    $SourceRoot = $SceneFile.Directory.FullName
    $BundleFiles = Get-ChildItem -Path $SourceRoot -Recurse -File
    $BundleBytes = [int64](($BundleFiles | Measure-Object -Property Length -Sum).Sum)
    if ($BundleBytes -le 0) {
        throw "The extracted bat bundle is empty."
    }
    if ($BundleBytes -gt $MaxModelBytes) {
        throw "The complete extracted bat bundle is $([math]::Round($BundleBytes / 1MB, 2)) MB, exceeding the project's 50 MB per-model limit."
    }

    $SceneJson = Get-Content -Raw -Path $SceneFile.FullName | ConvertFrom-Json
    if ($null -eq $SceneJson.meshes -or $SceneJson.meshes.Count -eq 0) {
        throw "The downloaded scene contains no mesh."
    }
    if ($null -eq $SceneJson.animations -or $SceneJson.animations.Count -eq 0) {
        throw "The downloaded bat contains no authored animation. Installation was stopped."
    }

    $BinaryFiles = Get-ChildItem -Path $SourceRoot -Recurse -File -Filter "*.bin"
    if ($BinaryFiles.Count -eq 0) {
        throw "The downloaded scene contains no binary geometry/animation buffer."
    }

    $TextureFiles = Get-ChildItem -Path $SourceRoot -Recurse -File |
        Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp|ktx2)$' }
    if ($TextureFiles.Count -eq 0) {
        throw "The downloaded bat contains no image textures. Installation was stopped."
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
        throw "Installed bundle size verification failed."
    }
    if ($null -eq $InstalledJson.animations -or $InstalledJson.animations.Count -eq 0) {
        throw "Animation verification failed after installation."
    }
    if ($InstalledTextures.Count -eq 0) {
        throw "Texture verification failed after installation."
    }

    Write-Host "Installed the exact $([math]::Round($InstalledBytes / 1MB, 2)) MB bat bundle with $($InstalledJson.animations.Count) animation(s) and $($InstalledTextures.Count) texture file(s)." -ForegroundColor Green

    $GodotCache = Join-Path $ProjectRoot ".godot"
    if (Test-Path $GodotCache) {
        Remove-Item -Recurse -Force $GodotCache
    }

    Set-Location $ProjectRoot
    git add -- "assets/models/animals/realistic_bat" $AttributionPath
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed."
    }

    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "Add the exact animated cemetery bat"
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed."
        }
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed."
        }
        Write-Host "The exact bat model was committed and pushed to main." -ForegroundColor Green
    }
    else {
        Write-Host "The exact bat model is already committed." -ForegroundColor Green
    }
}
finally {
    if (Test-Path $TempRoot) {
        Remove-Item -Recurse -Force $TempRoot -ErrorAction SilentlyContinue
    }
}

Write-Host "Done. Reopen Godot and allow the bat scene, textures and animation to import." -ForegroundColor Green
