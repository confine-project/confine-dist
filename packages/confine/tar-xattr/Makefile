#
# Copyright (C) 2008-2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=tar-xattr
PKG_VERSION:=1.28
PKG_RELEASE:=1
PKG_BUILD_DIR := $(BUILD_DIR)/tar-$(PKG_VERSION)

PKG_SOURCE:=tar-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=@GNU/tar
PKG_MD5SUM:=8f32b2bc1ed7ddf4cf4e4a39711341b0

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/tar-xattr
  SECTION:=utils
  CATEGORY:=Utilities
  DEPENDS:=+bzip2 +libattr +attr
  TITLE:=GNU tar with --xattrs support
  URL:=http://www.gnu.org/software/tar/
endef

define Package/tar-xattr/description
	Tar is a program for packaging a set of files as a
	single archive in tar format.
	This version adds extended attribute (xattrs) support.
endef

define Package/tar-xattr/postinst
#!/bin/sh
if [ -e $${IPKG_INSTROOT}/bin/tar ]; then
  rm -r $${IPKG_INSTROOT}/bin/tar;
fi
ln -sf /usr/bin/tar $${IPKG_INSTROOT}/bin/tar
endef

define Package/tar-xattr/postrm
#!/bin/sh
rm $${IPKG_INSTROOT}/bin/tar
ln -s busybox $${IPKG_INSTROOT}/bin/tar
$${IPKG_INSTROOT}/bin/tar 2>&1 | grep 'applet not found' > /dev/null 2>&1 && rm $${IPKG_INSTROOT}/bin/tar
exit 0
endef

MAKE_FLAGS += \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDLAGS)"

define Package/tar-xattr/install
	$(INSTALL_DIR) $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/tar $(1)/usr/bin/
endef

$(eval $(call BuildPackage,tar-xattr))
