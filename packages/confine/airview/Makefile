#
# Copyright (C) 2006-2008 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=airview
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/airview

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/airview
 SECTION:=net
 CATEGORY:=Network
 TITLE:=airview for ubiquiti spectrum analyzer
endef

define Package/airview/description
 Reads ttyATM0 from airview and print it on stdout
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/airview/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/airview $(1)/bin/
endef

$(eval $(call BuildPackage,airview))
