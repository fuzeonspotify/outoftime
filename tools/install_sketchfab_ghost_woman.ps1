param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$ModelUid = "f59d17be392f4494a5b85d927df48ffd"
$ModelName = "Terrifying Hooded Horror Woman"
$MaxArchiveBytes = 50MB
$Destination = Join-Path $ProjectRoot "assets\models\characters\terrifying_hooded_horror_woman"
$DownloadEndpoint = "https://api.sketchfab.com/v3/models/$ModelUid/download"

Write-Host "Installing $ModelName from Sketchfab..." -ForegroundColor Cyan
Write-Host "Your Sketchfab API token is entered locally and is never written to disk." -ForegroundColor DarkGray

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

$Headers = @{
    Authorization = "Token $Token"
    Accept = "application/json"
}

try {
    $DownloadInfo = Invoke-RestMethod -Method Get -Uri $DownloadEndpoint -Headers $Headers
}
finally {
    $Token = $null
    $Headers = $null
}

if ($null -eq $DownloadInfo.gltf -or [string]::IsNullOrWhiteSpace($DownloadInfo.gltf.url)) {
    throw "Sketchfab did not return a glTF archive for model $ModelUid."
}

$ReportedSize = 0
if ($null -ne $DownloadInfo.gltf.size) {
    $ReportedSize = [int64]$DownloadInfo.gltf.size
    if ($ReportedSize -gt $MaxArchiveBytes) {
        throw "The Sketchfab glTF archive is $([math]::Round($ReportedSize / 1MB, 2)) MB, which exceeds the project's 50 MB per-model limit."
    }
}

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("outoftime_sketchfab_" + [Guid]::NewGuid().ToString("N"))
$ArchivePath = Join-Path $TempRoot "hooded_woman.zip"
$ExtractRoot = Join-Path $TempRoot "extracted"
New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null

try {
    Write-Host "Downloading the official textured glTF archive..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $DownloadInfo.gltf.url -OutFile $ArchivePath -UseBasicParsing

    $ActualArchiveBytes = (Get-Item $ArchivePath).Length
    if ($ActualArchiveBytes -gt $MaxArchiveBytes) {
        throw "The downloaded archive is $([math]::Round($ActualArchiveBytes / 1MB, 2)) MB, which exceeds the 50 MB limit."
    }

    Expand-Archive -Path $ArchivePath -DestinationPath $ExtractRoot -Force

    $SceneFile = Get-ChildItem -Path $ExtractRoot -Recurse -File -Filter "scene.gltf" |
        Select-Object -First 1
    if ($null -eq $SceneFile) {
        $SceneFile = Get-ChildItem -Path $ExtractRoot -Recurse -File -Filter "*.gltf" |
            Select-Object -First 1
    }
    if ($null -eq $SceneFile) {
        throw "The Sketchfab archive did not contain a glTF scene file."
    }

    $SourceRoot = $SceneFile.Directory.FullName
    $TextureFiles = Get-ChildItem -Path $SourceRoot -Recurse -File |
        Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' }
    if ($TextureFiles.Count -eq 0) {
        throw "The downloaded archive contains no image textures. Installation was stopped."
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

    $InstalledTextures = Get-ChildItem -Path $Destination -Recurse -File |
        Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' }
    if ($InstalledTextures.Count -eq 0) {
        throw "Texture verification failed after copying the model into the project."
    }

    Write-Host "Installed model and $($InstalledTextures.Count) texture file(s)." -ForegroundColor Green

    $GodotCache = Join-Path $ProjectRoot ".godot"
    if (Test-Path $GodotCache) {
        Remove-Item -Recurse -Force $GodotCache
    }

    Set-Location $ProjectRoot
    git add -- "assets/models/characters/terrifying_hooded_horror_woman" "assets/models/characters/TERRIFYING_HOODED_HORROR_WOMAN_ATTRIBUTION.md"
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed."
    }

    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "Add the textured Sketchfab hooded ghost woman"
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed."
        }
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed."
        }
        Write-Host "The exact model was committed and pushed to main." -ForegroundColor Green
    }
    else {
        Write-Host "The exact model is already committed." -ForegroundColor Green
    }
}
finally {
    if (Test-Path $TempRoot) {
        Remove-Item -Recurse -Force $TempRoot -ErrorAction SilentlyContinue
    }
}

Write-Host "Done. Reopen Godot and allow the textured model to import." -ForegroundColor Green
