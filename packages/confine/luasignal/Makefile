#
# Copyright (C) 2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luasignal
PKG_VERSION:=2012111210
PKG_REV:=ec8fe99edf07d3292e1dd45e25a4f43c88aa1e44

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=git://github.com/LuaDist/lua-signal.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=$(PKG_REV)


CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk


CMAKE_OPTIONS=-DLUA_LIBRARIES:Path=/usr/lib/lua

define Package/luasignal
  SUBMENU:=Lua
  SECTION:=lang
  CATEGORY:=Languages
  TITLE:=luasignal
  URL:=https://github.com/LuaDist/lua-signal
  DEPENDS:=+lua +librt
endef


define Package/luasignal/description
  luasignal enables signal handling in lua
endef

#define Build/Configure
#endef

#TARGET_CFLAGS += -I$(STAGING_DIR)/usr/lib/lua -I$(STAGING_DIR)/usr/include  -DLUA_USE_LINUX $(FPIC) -std=gnu99


define Package/luasignal/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/signal.so $(1)/usr/lib/lua
endef

$(eval $(call BuildPackage,luasignal))
