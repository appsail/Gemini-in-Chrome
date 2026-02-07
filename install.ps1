# Enable Gemini in Chrome (PowerShell)
# Patches Chrome config to unlock Gemini features for non-US users
# Supports: Windows

Write-Host ""
Write-Host "🚀 Gemini in Chrome Enabler" -ForegroundColor Cyan
Write-Host ""

# Set Chrome config paths
$chromeUserData = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$chromeStatePath = "$chromeUserData\Local State"
$variationsPath = "$chromeUserData\Variations"
$variationsSafePath = "$chromeUserData\Variations Safe"

# Check if Chrome is running
$chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue

if ($chromeProcesses) {
    Write-Host "⚠️  Chrome is running. Please quit completely before proceeding." -ForegroundColor Yellow
    Read-Host "Press Enter after closing Chrome"
    $chromeProcesses = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
    if ($chromeProcesses) {
        Write-Host "❌ Chrome is still running. Please quit and try again." -ForegroundColor Red
        exit 1
    }
}

# Check if config file exists
if (-not (Test-Path $chromeStatePath)) {
    Write-Host "❌ Chrome config not found: $chromeStatePath" -ForegroundColor Red
    exit 1
}

# Backup Local State
$backupPath = "$chromeStatePath.bak"
Copy-Item -Path $chromeStatePath -Destination $backupPath -Force
Write-Host "✓ Backed up: Local State.bak" -ForegroundColor Green

# 1. Delete Cached Variations Files (CRITICAL STEP)
# This forces Chrome to fetch a fresh configuration instead of using the cached non-US seed.
if (Test-Path $variationsPath) {
    Remove-Item -Path $variationsPath -Force
    Write-Host "✓ Deleted cached Variations file (forces clean fetch)" -ForegroundColor Green
}
if (Test-Path $variationsSafePath) {
    Remove-Item -Path $variationsSafePath -Force -ErrorAction SilentlyContinue
}

# Read content
$content = Get-Content -Path $chromeStatePath -Raw -Encoding UTF8

# 2. Apply Patches to Local State
# Force country to US
$content = $content -replace '"variations_country":"[^"]*"', '"variations_country":"us"'
$content = $content -replace '("variations_permanent_consistency_country":\[[^]]*)"[^"]*"\]', '$1"us"]'

# Enable Gemini (is_glic_eligible)
# Regex handles: "is_glic_eligible":false -> "is_glic_eligible":true
if ($content -match '"is_glic_eligible"\s*:\s*false') {
    $content = $content -replace '"is_glic_eligible"\s*:\s*false', '"is_glic_eligible":true'
    Write-Host "✓ Enabled is_glic_eligible" -ForegroundColor Green
} elseif ($content -notmatch '"is_glic_eligible"') {
    # If key doesn't exist, we might need to inject it, but for now assuming it exists if Chrome > 132
    Write-Host "⚠️  'is_glic_eligible' key not found (ensure Chrome is updated)" -ForegroundColor Yellow
}

# 3. Clear Seed Signatures from Local State
# Remove variations_compressed_seed and variations_seed_signature keys to invalidate old seeds
$content = $content -replace '"variations_compressed_seed":"[^"]*",?', ''
$content = $content -replace '"variations_seed_signature":"[^"]*",?', ''
Write-Host "✓ Cleared old variations seeds from Local State" -ForegroundColor Green

# Write with UTF-8 no BOM (Chrome expects this)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($chromeStatePath, $content, $utf8NoBom)

# Final Instructions
Write-Host ""
Write-Host "✅ Configuration applied!" -ForegroundColor Green
Write-Host ""
Write-Host "📢 IMPORTANT: First Launch Instructions" -ForegroundColor Cyan
Write-Host "1. Connect your VPN to the US."
Write-Host "2. Copy and run this command in PowerShell to force the initial fetch:"
Write-Host ""
Write-Host "   & 'C:\Program Files\Google\Chrome\Application\chrome.exe' --enable-features=Glic --force-variations-country=US" -ForegroundColor Yellow
Write-Host ""
Write-Host "After the first successful launch (Gemini icon appears), you can close Chrome and launch normally."
