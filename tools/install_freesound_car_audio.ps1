param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$MaxCombinedBytes = 40MB
$Destination = Join-Path $ProjectRoot "assets\audio\car"
$AttributionPath = "assets/audio/REALISTIC_CAR_AUDIO_ATTRIBUTION.md"
$SoundDefinitions = @(
    @{
        Id = 748027
        ExpectedName = "Sedan engine loop"
        OutputName = "engine_loop.ogg"
    },
    @{
        Id = 439311
        ExpectedName = "Inside Car Noise While Driving"
        OutputName = "road_noise.ogg"
    }
)

Write-Host "Installing the realistic CC0 car-audio layers from Freesound..." -ForegroundColor Cyan
Write-Host "Use a Freesound API key from https://freesound.org/apiv2/apply" -ForegroundColor DarkGray
Write-Host "The key is entered locally, never printed, and never written to disk." -ForegroundColor DarkGray

$SecureToken = Read-Host "Paste your Freesound API key" -AsSecureString
$TokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken)
try {
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($TokenPointer)
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($TokenPointer)
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "No Freesound API key was entered."
}

$Headers = @{
    Authorization = "Token $Token"
    Accept = "application/json"
}

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("outoftime_car_audio_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
    if (Test-Path $Destination) {
        Remove-Item -Recurse -Force $Destination
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    foreach ($Definition in $SoundDefinitions) {
        $SoundId = [int]$Definition.Id
        $Endpoint = "https://freesound.org/apiv2/sounds/$SoundId/"
        Write-Host "Verifying Freesound sound $SoundId..." -ForegroundColor Cyan
        $Info = Invoke-RestMethod -Method Get -Uri $Endpoint -Headers $Headers

        if ($null -eq $Info -or [int]$Info.id -ne $SoundId) {
            throw "Freesound returned the wrong record for sound $SoundId."
        }
        if ([string]$Info.name -ne [string]$Definition.ExpectedName) {
            throw "Freesound returned '$($Info.name)' instead of '$($Definition.ExpectedName)'."
        }

        $LicenseUrl = [string]$Info.license
        if (-not $LicenseUrl.ToLowerInvariant().Contains("creativecommons.org/publicdomain/zero")) {
            throw "Sound $SoundId is no longer listed as CC0. Installation was stopped."
        }

        $PreviewUrl = [string]$Info.previews.'preview-hq-ogg'
        if ([string]::IsNullOrWhiteSpace($PreviewUrl)) {
            throw "Freesound returned no high-quality Ogg preview for sound $SoundId."
        }

        $TempFile = Join-Path $TempRoot ([string]$Definition.OutputName)
        $OutputFile = Join-Path $Destination ([string]$Definition.OutputName)
        Write-Host "Downloading $($Definition.ExpectedName)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $PreviewUrl -OutFile $TempFile -UseBasicParsing

        $DownloadedBytes = (Get-Item $TempFile).Length
        if ($DownloadedBytes -le 0) {
            throw "The downloaded audio for sound $SoundId is empty."
        }
        Copy-Item -Path $TempFile -Destination $OutputFile -Force
    }

    $InstalledFiles = Get-ChildItem -Path $Destination -File -Filter "*.ogg"
    if ($InstalledFiles.Count -ne $SoundDefinitions.Count) {
        throw "Car-audio verification failed: expected $($SoundDefinitions.Count) Ogg files and found $($InstalledFiles.Count)."
    }

    $InstalledBytes = [int64](($InstalledFiles | Measure-Object -Property Length -Sum).Sum)
    if ($InstalledBytes -le 0 -or $InstalledBytes -gt $MaxCombinedBytes) {
        throw "Installed car-audio size verification failed: $([math]::Round($InstalledBytes / 1MB, 2)) MB."
    }

    Write-Host "Installed $($InstalledFiles.Count) CC0 car-audio layers totaling $([math]::Round($InstalledBytes / 1MB, 2)) MB." -ForegroundColor Green

    $GodotCache = Join-Path $ProjectRoot ".godot"
    if (Test-Path $GodotCache) {
        Remove-Item -Recurse -Force $GodotCache
    }

    Set-Location $ProjectRoot
    git add -- "assets/audio/car" $AttributionPath
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed."
    }

    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "Add the realistic CC0 Porsche audio layers"
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed."
        }
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed."
        }
        Write-Host "The car-audio files were committed and pushed to main." -ForegroundColor Green
    }
    else {
        Write-Host "The exact car-audio files are already committed." -ForegroundColor Green
    }
}
finally {
    $Token = $null
    $Headers = $null
    if (Test-Path $TempRoot) {
        Remove-Item -Recurse -Force $TempRoot -ErrorAction SilentlyContinue
    }
}

Write-Host "Done. Reopen Godot and allow the Ogg files to import." -ForegroundColor Green
