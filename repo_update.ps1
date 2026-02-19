# Antigravity Repo Update Script for Windows (Pro Version - Sileo/Cydia/Zebra)

$RepoConfig = Get-Content -Raw -Path "repo_config.json" -Encoding utf8 | ConvertFrom-Json
$DebsDir = "debs"
$PackagesFile = "Packages"
$PackagesGzFile = "Packages.gz"
$ReleaseFile = "Release"

if (-not (Test-Path $DebsDir)) {
    New-Item -ItemType Directory -Path $DebsDir
    Write-Host "Created 'debs' directory. Place your .deb files there." -ForegroundColor Yellow
    exit
}

$PackagesData = @()
Write-Host "Processing DEB files..." -ForegroundColor Cyan

$MetadataPath = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "packages_metadata.json"
$Metadata = @()
if (Test-Path $MetadataPath) {
    $rawJson = [System.IO.File]::ReadAllText($MetadataPath, [System.Text.Encoding]::UTF8)
    if ($rawJson.Trim()) {
        $jsonObj = $rawJson | ConvertFrom-Json
        if ($jsonObj -is [array]) { $Metadata = $jsonObj }
        elseif ($null -ne $jsonObj) { $Metadata = @($jsonObj) }
    }
}

$Files = Get-ChildItem -Path $DebsDir -Filter "*.deb"
foreach ($File in $Files) {
    Write-Host "Analysing: $($File.Name)" -ForegroundColor Gray
    
    $MD5 = (Get-FileHash $File.FullName -Algorithm MD5).Hash.ToLower()
    $SHA1 = (Get-FileHash $File.FullName -Algorithm SHA1).Hash.ToLower()
    $SHA256 = (Get-FileHash $File.FullName -Algorithm SHA256).Hash.ToLower()
    $Size = $File.Length
    
    # Try to find metadata from dashboard
    $ItemMeta = $Metadata | Where-Object { $_.name -eq $File.BaseName -or $_.packageId -match $File.BaseName } | Select-Object -First 1
    
    $PkgID = if ($ItemMeta.packageId) { $ItemMeta.packageId } else { "com.joker.$($File.BaseName.ToLower())" }
    $PkgName = if ($ItemMeta.name) { $ItemMeta.name } else { $File.BaseName }
    $PkgVer = if ($ItemMeta.version) { $ItemMeta.version } else { "1.0.0" }
    $PkgDev = if ($ItemMeta.developer) { $ItemMeta.developer } else { "JOKER" }
    $PkgDesc = if ($ItemMeta.description) { $ItemMeta.description } else { "Official Tweak by Antigravity" }

    # Map categories to Cydia Sections (Safely via config)
    $Section = "Tweaks"
    if ($ItemMeta.category -and $RepoConfig.CategoryMapping) {
        $ItemCat = $ItemMeta.category
        foreach ($prop in $RepoConfig.CategoryMapping.PSObject.Properties) {
            if ($prop.Name -eq $ItemCat) {
                $Section = $prop.Value
                break
            }
        }
    }

    $ControlInfo = "Package: $PkgID`n" +
    "Name: $PkgName`n" +
    "Version: $PkgVer`n" +
    "Architecture: iphoneos-arm`n" +
    "Maintainer: $PkgDev`n" +
    "Author: $PkgDev`n" +
    "Section: $Section`n" +
    "Description: $PkgDesc`n" +
    "Depiction: https://joker11989.github.io/myrepo/`n" +
    "Filename: debs/$($File.Name)`n" +
    "Size: $Size`n" +
    "MD5sum: $MD5`n" +
    "SHA1: $SHA1`n" +
    "SHA256: $SHA256"
    
    $PackagesData += $ControlInfo

    # Sync found items back to metadata JSON for Dashboard
    $Found = $false
    foreach ($m in $Metadata) {
        if (($m.packageId -and $m.packageId -eq $PkgID) -or $m.name -eq $PkgName) {
            $Found = $true
            break
        }
    }
    
    if (-not $Found) {
        Write-Host "Syncing new item to metadata: $PkgName" -ForegroundColor Yellow
        # Use a safe way to set default category if missing
        $cat = if ($ItemMeta.category) { $ItemMeta.category } else { "أدوات" }
        $NewMeta = @{
            name = $PkgName
            version = $PkgVer
            developer = $PkgDev
            description = $PkgDesc
            packageId = $PkgID
            category = $cat
            price = "$0.00"
            type = ".deb"
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fff")
        }
        $Metadata += $NewMeta
        $MetadataUpdated = $true
    }
}

# Save updated metadata if changes were made
if ($MetadataUpdated) {
    [System.IO.File]::WriteAllText($MetadataPath, (ConvertTo-Json -InputObject @($Metadata) -Depth 10), [System.Text.Encoding]::UTF8)
    Write-Host "Dashboard metadata synced with folder." -ForegroundColor Cyan
}

# 1. Save Packages file
$PackagesContent = ($PackagesData -join "`n`n") + "`n"
[System.IO.File]::WriteAllText("$(Get-Location)\$PackagesFile", $PackagesContent, [System.Text.Encoding]::UTF8)
Write-Host "Generated $PackagesFile" -ForegroundColor Green

# 2. Generate Packages.gz
$InputFile = [System.IO.File]::OpenRead("$(Get-Location)\$PackagesFile")
$OutputFile = [System.IO.File]::Create("$(Get-Location)\$PackagesGzFile")
$GZipStream = New-Object System.IO.Compression.GzipStream($OutputFile, [System.IO.Compression.CompressionMode]::Compress)
$InputFile.CopyTo($GZipStream)
$GZipStream.Close()
$OutputFile.Close()
$InputFile.Close()
Write-Host "Generated $PackagesGzFile" -ForegroundColor Green

# 3. Calculate Hashes for Release
function Get-FileMetadata($Path) {
    $Name = [System.IO.Path]::GetFileName($Path)
    $MD5 = (Get-FileHash $Path -Algorithm MD5).Hash.ToLower()
    $SHA1 = (Get-FileHash $Path -Algorithm SHA1).Hash.ToLower()
    $SHA256 = (Get-FileHash $Path -Algorithm SHA256).Hash.ToLower()
    $Size = (Get-Item $Path).Length
    return @{ Name = $Name; MD5 = $MD5; SHA1 = $SHA1; SHA256 = $SHA256; Size = $Size }
}

$P_Meta = Get-FileMetadata "$(Get-Location)\$PackagesFile"
$PGz_Meta = Get-FileMetadata "$(Get-Location)\$PackagesGzFile"

# 4. Generate Release file
$ReleaseContent = "Origin: $($RepoConfig.Origin)`n" +
"Label: $($RepoConfig.Label)`n" +
"Suite: stable`n" +
"Version: $($RepoConfig.Version)`n" +
"Codename: ios`n" +
"Architectures: iphoneos-arm iphoneos-arm64`n" +
"Components: main`n" +
"Description: $($RepoConfig.Description)`n" +
"MD5Sum:`n" +
" $($P_Meta.MD5) $($P_Meta.Size) $($P_Meta.Name)`n" +
" $($PGz_Meta.MD5) $($PGz_Meta.Size) $($PGz_Meta.Name)`n" +
"SHA1:`n" +
" $($P_Meta.SHA1) $($P_Meta.Size) $($P_Meta.Name)`n" +
" $($PGz_Meta.SHA1) $($PGz_Meta.Size) $($PGz_Meta.Name)`n" +
"SHA256:`n" +
" $($P_Meta.SHA256) $($P_Meta.Size) $($P_Meta.Name)`n" +
" $($PGz_Meta.SHA256) $($PGz_Meta.Size) $($PGz_Meta.Name)`n"

[System.IO.File]::WriteAllText("$(Get-Location)\$ReleaseFile", $ReleaseContent, [System.Text.Encoding]::UTF8)
Write-Host "Generated $ReleaseFile" -ForegroundColor Green

Write-Host "`nReady! Upload Packages, Packages.gz, and Release to GitHub." -ForegroundColor Green
