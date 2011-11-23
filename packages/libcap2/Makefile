#
# Copyright (C) 2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libcap
PKG_VERSION:=2.21
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/
PKG_MD5SUM:=61966ef40f2dee8731b69db895e4548d

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/libcap2
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=libcap2
  URL:=http://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/
  MENU:=1
endef

define Package/libcap2/description
	TODO
endef

MAKE_FLAGS += \
    CFLAGS="$(TARGET_CFLAGS)" \
    BUILD_CC="$(CC)" \
    BUILD_CFLAGS="$(HOST_FPIC) -I$(PKG_BUILD_DIR)/libcap/include" \
    CFLAGS="$(TARGET_CFLAGS)" \
    LD="$(TARGET_CC)" \
    LDFLAGS="$(TARGET_LDFLAGS) -shared" \
    INDENT="| true" \
    PAM_CAP="no" \
    LIBATTR="no" \
    DYNAMIC="yes" \
    lib="lib"

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/* $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/lib/* $(1)/usr/lib/
endef

define Package/libcap2/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/lib/libcap.so* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,libcap2))
