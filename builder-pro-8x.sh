#!/bin/bash
set -euo pipefail


rm -rf openwrt
# rm -rf mtk-openwrt-feeds

git clone --branch openwrt-25.12 https://github.com/openwrt/openwrt.git openwrt
cd openwrt; git checkout 12e56ac8d4bc056768c962796f55531a6da2b4cf; cd -;

tar xzf /home/ipsec/mtk-feeds-cache.tar.gz

\cp -r my_files/999-sfp-10-additional-quirks.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12

### tx_power check Ivan Mironov's patch - for defective BE14 boards with defective eeprom flash
\cp -r my_files/100-wifi-mt76-mt7996-Use-tx_power-from-default-fw-if-EEP.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic prepare

# BPI-R4 patches
\cp -r ../my_files/453-w-add-bpi-r4-nvme-dtso.patch target/linux/mediatek/patches-6.12/
\cp -r ../my_files/480-w-add-bpi-r4-nopcie2.patch target/linux/mediatek/patches-6.12/
\cp -r ../my_files/470-w-add-bpi-r4-leds-overlay.patch target/linux/mediatek/patches-6.12/
\cp -r ../my_files/450-w-nand-mmc-add-bpi-r4.patch package/boot/uboot-mediatek/patches/450-add-bpi-r4.patch
\cp -r ../my_files/451-w-add-bpi-r4-nvme.patch package/boot/uboot-mediatek/patches/451-add-bpi-r4-nvme.patch
\cp ../my_files/452-w-add-bpi-r4-nvme-rfb.patch package/boot/uboot-mediatek/patches/452-add-bpi-r4-nvme-rfb.patch
\cp ../my_files/454-w-add-bpi-r4-nvme-env.patch package/boot/uboot-mediatek/patches/454-add-bpi-r4-nvme-env.patch
\cp ../my_files/471-w-bpi-r4-led-uboot.patch package/boot/uboot-mediatek/patches/471-bpi-r4-led-uboot.patch
\cp ../my_files/481-w-add-bpi-r4-nopcie2-env.patch package/boot/uboot-mediatek/patches/481-add-bpi-r4-nopcie2-env.patch

# BPI-R4-Pro-8x patches
\cp -r ../my_files/bpi-r4-pro/patches-kernel/* target/linux/mediatek/patches-6.12/
\cp ../my_files/bpi-r4-pro/patches-uboot/471-add-bpi-r4-pro-8x.patch package/boot/uboot-mediatek/patches/
#\cp ../my_files/bpi-r4-pro/patches-uboot/472-add-bpi-r4-pro-8x-makefile.patch package/boot/uboot-mediatek/patches/
\cp ../my_files/bpi-r4-pro/uboot-mediatek-Makefile package/boot/uboot-mediatek/Makefile
\cp -r ../my_files/w-sd-nand-mmc-nvme-ddr4-filogic.mk target/linux/mediatek/image/filogic.mk
sed -i 's/mt7988a-bananapi-bpi-r4-nvme$/mt7988a-bananapi-bpi-r4-nvme mt7988a-bananapi-bpi-r4-leds mt7988a-bananapi-bpi-r4-nopcie2/' target/linux/mediatek/image/filogic.mk
mv target/linux/mediatek/image/filogic-extra.mk target/linux/mediatek/image/filogic-extra.mk.disabled

echo "CONFIG_BLK_DEV_NVME=y" >> target/linux/mediatek/filogic/config-6.12
echo "CONFIG_LED_TRIGGER_PHY=y" >> target/linux/mediatek/filogic/config-6.12

\cp -r ../my_files/999-fitblk-02-w-add-bpi-r4-nvme-fitblk.patch target/linux/mediatek/patches-6.12

\cp -r ../my_files/modemdata-main/ feeds/packages/utils/modemdata
\cp -r ../my_files/luci-app-modemdata-main/luci-app-modemdata/ feeds/luci/applications
\cp -r ../my_files/luci-app-lite-watchdog/ feeds/luci/applications
\cp -r ../my_files/luci-app-sms-tool-js-main/luci-app-sms-tool-js/ feeds/luci/applications

mkdir -p files/etc/uci-defaults
\cp -r ../my_files/99-set-hostname files/etc/uci-defaults/
chmod +x files/etc/uci-defaults/99-set-hostname

# FM350-GL: blacklist PCIe T7xx driver - modem works only via USB/RNDIS
mkdir -p files/etc/modules.d
\cp ../my_files/etc-files/modules.d/mtk-t7xx-blacklist files/etc/modules.d/

# LED: program mt7530 gphy port-LED registers at boot (green+amber, link+activity)
mkdir -p files/etc/init.d
\cp ../my_files/etc-files/init.d/mtk-led-fix files/etc/init.d/
chmod +x files/etc/init.d/mtk-led-fix
mkdir -p files/etc/uci-defaults
\cp ../my_files/etc-files/uci-defaults/95-mtk-led-fix-enable files/etc/uci-defaults/
chmod +x files/etc/uci-defaults/95-mtk-led-fix-enable

# FM350-GL: hotplug to restart network when a USB device appears
mkdir -p files/etc/hotplug.d/usb
\cp ../my_files/etc-files/hotplug.d/usb/25-fm350-init files/etc/hotplug.d/usb/
chmod +x files/etc/hotplug.d/usb/25-fm350-init

# FM350-GL: atc-fib-fm350_gl vendored locally (no external feed needed)
# the mrhaav feed pulls old uqmi/umbim that break the cmake build
\cp -r ../my_files/atc-fib-fm350_gl/ feeds/packages/net/atc-fib-fm350_gl
\cp -r ../my_files/luci-proto-atc feeds/luci/applications/luci-proto-atc

./scripts/feeds update -a
./scripts/feeds install -a

\cp ../my_files/fit.sh package/utils/fitblk/files/fit.sh

\cp -r ../my_files/qmi.sh package/network/utils/uqmi/files/lib/netifd/proto/
chmod -R 755 package/network/utils/uqmi/files/lib/netifd/proto
chmod -R 755 feeds/luci/applications/luci-app-modemdata/root
chmod -R 755 feeds/luci/applications/luci-app-sms-tool-js/root
chmod -R 755 feeds/packages/utils/modemdata/files/usr/share

\cp -r ../configs/my_defconfig-standard .config
make defconfig

mkdir -p staging_dir/target-aarch64_cortex-a53_musl/image/
\cp ../my_files/bootloader-mt7988-comb-8g/mt7988-spim-nand-comb-8g-bl2.img staging_dir/target-aarch64_cortex-a53_musl/image/
\cp ../my_files/bootloader-mt7988-comb-8g/mt7988-spim-nand-comb-8g-bl31.bin staging_dir/target-aarch64_cortex-a53_musl/image/
\cp ../my_files/bootloader-mt7988-comb-8g/mt7988-emmc-comb-8g-bl2.img staging_dir/target-aarch64_cortex-a53_musl/image/
\cp ../my_files/bootloader-mt7988-comb-8g/mt7988-emmc-comb-8g-bl31.bin staging_dir/target-aarch64_cortex-a53_musl/image/
\cp ../my_files/bootloader-mt7988-comb-8g/mt7988-sdmmc-comb-8g-bl2.img staging_dir/target-aarch64_cortex-a53_musl/image/
\cp ../my_files/bootloader-mt7988-comb-8g/mt7988-sdmmc-comb-8g-bl31.bin staging_dir/target-aarch64_cortex-a53_musl/image/

bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic build
