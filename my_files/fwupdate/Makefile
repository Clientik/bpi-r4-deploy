include $(TOPDIR)/rules.mk

PKG_NAME:=fwupdate
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Clientik
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/fwupdate
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Firmware OTA updater (this fork's GitHub releases)
  DEPENDS:=+curl +jsonfilter +ca-bundle
  PKGARCH:=all
endef

define Package/fwupdate/description
  Self-contained OTA updater. `fw-update check/list/install` compares the
  running build (stamped in /etc/fork-release) against the fork's GitHub
  releases and installs the matching sysupgrade image. Loosely coupled:
  removing this package (and luci-app-fwupdate) removes the whole feature.
endef

define Package/fwupdate/conffiles
/etc/config/fwupdate
endef

define Build/Compile
endef

define Package/fwupdate/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/fw-update $(1)/usr/sbin/fw-update
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/fwupdate.config $(1)/etc/config/fwupdate
endef

$(eval $(call BuildPackage,fwupdate))
