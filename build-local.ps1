# build-local.ps1
# Локальная сборка BPI-R4 через WSL2 — воспроизводит логику GitHub Actions workflow
# Запуск: .\build-local.ps1 [-Variant standard|wired] [-Branch <ветка>]
#
# Требования: WSL2 с Ubuntu-22.04 (установится автоматически если нет)

param(
    [ValidateSet("standard", "wired")]
    [string]$Variant  = "standard",
    [string]$Branch   = "feature/fm350gl-usb-support",
    [string]$RepoUrl  = "https://github.com/Clientik/bpi-r4-deploy"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== BPI-R4 Local Build ===" -ForegroundColor Cyan
Write-Host "Variant : $Variant"
Write-Host "Branch  : $Branch"
Write-Host ""

# --- Проверка WSL2 ---
$wslDistros = wsl --list --quiet 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL2 не найден. Устанавливаю..." -ForegroundColor Yellow
    wsl --install --no-distribution
    Write-Host "Перезагрузи компьютер и запусти скрипт снова." -ForegroundColor Red
    exit 1
}

$hasUbuntu = $wslDistros | Where-Object { $_ -match "Ubuntu-22.04" }
if (-not $hasUbuntu) {
    Write-Host "Устанавливаю Ubuntu-22.04..." -ForegroundColor Yellow
    wsl --install -d Ubuntu-22.04
    Write-Host "Ubuntu установлена. Запусти скрипт снова." -ForegroundColor Green
    exit 0
}

Write-Host "WSL2 Ubuntu-22.04 найден." -ForegroundColor Green

# --- Путь к build директории внутри WSL2 ---
# Используем /home/<user>/bpi-r4-build чтобы избежать проблем с NTFS
$wslBuildDir = "/home/\$USER/bpi-r4-build"

# --- Inline bash скрипт ---
$bashScript = @"
#!/bin/bash
set -euo pipefail

OPENWRT_COMMIT="13ff2256e5dd9bc070f9a9c6a673bff4a9191837"
MTK_COMMIT="dceb45f8cb945bce16f0e09f8d2cd974c9f0ce58"
VARIANT="$Variant"
BRANCH="$Branch"
REPO_URL="$RepoUrl"
BUILD_DIR="\$HOME/bpi-r4-build"
CACHE_DIR="\$HOME/bpi-r4-cache"

echo ""
echo "=== [1/5] Установка зависимостей ==="
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
  gettext libncurses-dev libssl-dev python3-distutils python3-setuptools \
  rsync swig unzip zlib1g-dev file wget libelf-dev ccache git \
  python3-dev > /dev/null 2>&1
echo "OK"

echo ""
echo "=== [2/5] Подготовка repo-cache ==="
mkdir -p "\$CACHE_DIR"

if [ ! -f "\$CACHE_DIR/openwrt.tar.gz" ]; then
  echo "  Клонирую OpenWrt (один раз)..."
  git clone --branch openwrt-25.12 --depth=1000 https://github.com/openwrt/openwrt.git /tmp/openwrt-clone
  cd /tmp/openwrt-clone && git checkout \$OPENWRT_COMMIT && cd -
  tar -czf "\$CACHE_DIR/openwrt.tar.gz" -C /tmp openwrt-clone
  rm -rf /tmp/openwrt-clone
  echo "  OpenWrt закеширован."
else
  echo "  OpenWrt: кеш найден, пропускаю."
fi

if [ ! -f "\$CACHE_DIR/mtk-openwrt-feeds.tar.gz" ]; then
  echo "  Клонирую MTK feeds (один раз)..."
  git clone --branch master https://git01.mediatek.com/openwrt/feeds/mtk-openwrt-feeds /tmp/mtk-clone
  cd /tmp/mtk-clone && git checkout \$MTK_COMMIT && cd -
  tar -czf "\$CACHE_DIR/mtk-openwrt-feeds.tar.gz" -C /tmp mtk-clone
  rm -rf /tmp/mtk-clone
  echo "  MTK feeds закешированы."
else
  echo "  MTK feeds: кеш найден, пропускаю."
fi

echo ""
echo "=== [3/5] Клонирование репозитория ==="
rm -rf "\$BUILD_DIR"
mkdir -p "\$BUILD_DIR"
git clone "\$REPO_URL" "\$BUILD_DIR"
cd "\$BUILD_DIR"
git checkout "\$BRANCH"

# Подкладываем кеш
mkdir -p repo-cache
ln -s "\$CACHE_DIR/openwrt.tar.gz"           repo-cache/openwrt.tar.gz           2>/dev/null || cp "\$CACHE_DIR/openwrt.tar.gz"           repo-cache/
ln -s "\$CACHE_DIR/mtk-openwrt-feeds.tar.gz" repo-cache/mtk-openwrt-feeds.tar.gz 2>/dev/null || cp "\$CACHE_DIR/mtk-openwrt-feeds.tar.gz" repo-cache/

echo ""
echo "=== [4/5] Сборка (VARIANT=\$VARIANT) ==="
if [ "\$VARIANT" = "wired" ]; then
  BUILDER="./builder-wired-universal.sh"
else
  BUILDER="./builder-wifimgr-universal.sh"
fi

export OPENWRT_COMMIT=\$OPENWRT_COMMIT
chmod +x \$BUILDER
\$BUILDER

echo ""
echo "=== [5/5] Готово ==="
echo ""
echo "Артефакты:"
ls -lh openwrt/bin/targets/mediatek/filogic/*.itb 2>/dev/null || true
ls -lh openwrt/bin/targets/mediatek/filogic/*.img.gz 2>/dev/null || true
echo ""
echo "Путь: \$BUILD_DIR/openwrt/bin/targets/mediatek/filogic/"
echo ""
echo "Для копирования на Windows:"
echo "  explorer.exe \\\`wslpath -w \$BUILD_DIR/openwrt/bin/targets/mediatek/filogic\`"
"@

# Сохраняем bash скрипт во временный файл WSL2
$tmpScript = "/tmp/bpi_build_$([System.DateTime]::Now.Ticks).sh"
Write-Host "Запускаю сборку в WSL2..." -ForegroundColor Cyan
Write-Host ""

# Передаём скрипт в WSL2 и запускаем
$bashScript | wsl -d Ubuntu-22.04 -- bash -c "cat > $tmpScript && chmod +x $tmpScript && bash $tmpScript"

Write-Host ""
Write-Host "=== Сборка завершена ===" -ForegroundColor Green
Write-Host "Открыть папку с артефактами:" -ForegroundColor Cyan
Write-Host '  wsl -d Ubuntu-22.04 -- bash -c "explorer.exe \$(wslpath -w ~/bpi-r4-build/openwrt/bin/targets/mediatek/filogic)"'
