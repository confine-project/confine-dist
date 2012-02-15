#
# Copyright (C) 2006-2008 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=broadcastflood
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/broadcastflood

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/broadcastflood
 SECTION:=net
 CATEGORY:=Network
 TITLE:=broadcast flooder
endef

define Package/broadcastflood/description
 Send UDP broadcast packets like crazy on the network
 in order to saturate the channel.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/broadcastflood/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/broadcastflood $(1)/bin/
endef

$(eval $(call BuildPackage,broadcastflood))
