# build-local.ps1
# Local BPI-R4 build via WSL2 - reproduces the GitHub Actions workflow logic
# Usage: .\build-local.ps1 [-Variant standard|wired] [-Branch <branch>]
#
# Requirements: WSL2 with Ubuntu-22.04 (installed automatically if missing)

param(
    [ValidateSet("standard", "wired")]
    [string]$Variant  = "standard",
    [string]$Branch   = "main",
    [string]$RepoUrl  = "https://github.com/Clientik/bpi-r4-deploy"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== BPI-R4 Local Build ===" -ForegroundColor Cyan
Write-Host "Variant : $Variant"
Write-Host "Branch  : $Branch"
Write-Host ""

# --- Check WSL2 ---
$wslDistros = wsl --list --quiet 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL2 not found. Installing..." -ForegroundColor Yellow
    wsl --install --no-distribution
    Write-Host "Reboot the computer and run the script again." -ForegroundColor Red
    exit 1
}

$hasUbuntu = $wslDistros | Where-Object { $_ -match "Ubuntu-22.04" }
if (-not $hasUbuntu) {
    Write-Host "Installing Ubuntu-22.04..." -ForegroundColor Yellow
    wsl --install -d Ubuntu-22.04
    Write-Host "Ubuntu installed. Run the script again." -ForegroundColor Green
    exit 0
}

Write-Host "WSL2 Ubuntu-22.04 found." -ForegroundColor Green

# --- Build directory path inside WSL2 ---
# Use /home/<user>/bpi-r4-build to avoid NTFS issues
$wslBuildDir = "/home/\$USER/bpi-r4-build"

# --- Inline bash script ---
$bashScript = @"
#!/bin/bash
set -euo pipefail

VARIANT="$Variant"
BRANCH="$Branch"
REPO_URL="$RepoUrl"
BUILD_DIR="\$HOME/bpi-r4-build"

echo ""
echo "=== [1/5] Installing dependencies ==="
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
  gettext libncurses-dev libssl-dev python3-distutils python3-setuptools \
  rsync swig unzip zlib1g-dev file wget libelf-dev ccache git \
  python3-dev > /dev/null 2>&1
echo "OK"

echo ""
echo ""
echo "=== [3/5] Cloning repository ==="
rm -rf "\$BUILD_DIR"
mkdir -p "\$BUILD_DIR"
git clone "\$REPO_URL" "\$BUILD_DIR"
cd "\$BUILD_DIR"
git checkout "\$BRANCH"


echo ""
echo "=== [4/5] Build (VARIANT=\$VARIANT) ==="
if [ "\$VARIANT" = "wired" ]; then
  BUILDER="./builder-wired-universal.sh"
else
  BUILDER="./builder-wifimgr-universal.sh"
fi

chmod +x \$BUILDER
\$BUILDER

echo ""
echo "=== [5/5] Done ==="
echo ""
echo "Artifacts:"
ls -lh openwrt/bin/targets/mediatek/filogic/*.itb 2>/dev/null || true
ls -lh openwrt/bin/targets/mediatek/filogic/*.img.gz 2>/dev/null || true
echo ""
echo "Path: \$BUILD_DIR/openwrt/bin/targets/mediatek/filogic/"
echo ""
echo "To copy to Windows:"
echo "  explorer.exe \\\`wslpath -w \$BUILD_DIR/openwrt/bin/targets/mediatek/filogic\`"
"@

# Save the bash script to a temp file in WSL2
$tmpScript = "/tmp/bpi_build_$([System.DateTime]::Now.Ticks).sh"
Write-Host "Starting the build in WSL2..." -ForegroundColor Cyan
Write-Host ""

# Pass the script into WSL2 and run it
$bashScript | wsl -d Ubuntu-22.04 -- bash -c "cat > $tmpScript && chmod +x $tmpScript && bash $tmpScript"

Write-Host ""
Write-Host "=== Build finished ===" -ForegroundColor Green
Write-Host "Open the artifacts folder:" -ForegroundColor Cyan
Write-Host '  wsl -d Ubuntu-22.04 -- bash -c "explorer.exe \$(wslpath -w ~/bpi-r4-build/openwrt/bin/targets/mediatek/filogic)"'
