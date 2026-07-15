include $(TOPDIR)/rules.mk

PKG_VERSION:=1.0.0
PKG_MAINTAINER:=Clientik
PKG_LICENSE:=GPL-2.0-or-later

LUCI_TITLE:=LuCI page for the firmware OTA updater (this fork)
LUCI_DEPENDS:=+luci-base +fwupdate
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
