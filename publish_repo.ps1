# Antigravity Repo Auto-Publisher (Sileo/Cydia/Zebra)

Write-Host "--- Starting Auto-Publishing Process ---" -ForegroundColor Cyan

# 1. Update the repository metadata
Write-Host "Step 1: Updating repository indexes..." -ForegroundColor Gray
powershell -ExecutionPolicy Bypass -File repo_update.ps1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Repository update failed." -ForegroundColor Red
    exit 1
}

# 2. Add changes to Git
Write-Host "Step 2: Adding files to Git..." -ForegroundColor Gray
git add Packages Packages.gz Release debs/

# 3. Commit changes
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Step 3: Committing changes..." -ForegroundColor Gray
git commit -m "Auto-update repository indexes [$Timestamp]"

# 4. Push to GitHub
Write-Host "Step 4: Pushing to GitHub..." -ForegroundColor Gray
git push origin main

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to push to GitHub. Check your internet connection or git permissions." -ForegroundColor Red
    exit 1
}

Write-Host "`n--- Successfully published to GitHub! ---" -ForegroundColor Green
exit 0
