#
# Copyright (C) 2006-2008 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=fallocate-e2fsprogs
PKG_VERSION:=1.42.4
PKG_MD5SUM:=b6e296f210d642361b7394437ff0f318
PKG_RELEASE:=1

PKG_SOURCE:=e2fsprogs-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=@SF/e2fsprogs


PKG_BUILD_DIR:=$(BUILD_DIR)/fallocate-e2fsprogs

include $(INCLUDE_DIR)/package.mk


define Package/fallocate-e2fsprogs
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Filesystem
  TITLE:=fallocate-e2fsprogs
endef

define Package/fallocate-e2fsprogs/description
 fallocate binary (from e2fsprogs)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef


define Package/fallocate-e2fsprogs/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/fallocate $(1)/bin/fallocate-e2fsprogs
endef

$(eval $(call BuildPackage,fallocate-e2fsprogs))
