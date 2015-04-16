#
# Copyright (C) 2007-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
PKG_NAME:=libatomic
PKG_RELEASE:=1

PKG_MAINTAINER:=Felix Fietkau <nbd@openwrt.org>

include $(INCLUDE_DIR)/package.mk

ifneq ($(DUMP),1)
  LIBGCC_VERSION:=$(GCC_VERSION)
else
  LIBC_VERSION:=<LIBC_VERSION>
  LIBGCC_VERSION:=<LIBGCC_VERSION>
endif

define Package/libatomic
  SECTION:=libs
  CATEGORY:=Base system
  URL:=http://gcc.gnu.org/
  VERSION:=$(LIBGCC_VERSION)-$(PKG_RELEASE)
  DEPENDS:=+libgcc +libpthread
  TITLE:=Atomic support library
endef

define Package/libatomic/config
	menu "Configuration"
		depends on EXTERNAL_TOOLCHAIN && PACKAGE_libatomic

	config LIBATOMIC_ROOT_DIR
		string
		prompt "libatomic shared library base directory"
		depends on EXTERNAL_TOOLCHAIN && PACKAGE_libatomic
		default TOOLCHAIN_ROOT  if !NATIVE_TOOLCHAIN
		default "/"  if NATIVE_TOOLCHAIN

	config LIBATOMIC_FILE_SPEC
		string
		prompt "libatomic shared library files (use wildcards)"
		depends on EXTERNAL_TOOLCHAIN && PACKAGE_libatomic
		default "./lib/libatomic.so.*"

	endmenu
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

ifneq ($(BUILD_LIBGCC),)
  define Build/Compile/uClibc
	$(SCRIPT_DIR)/relink-lib.sh \
		"$(TARGET_CROSS)" \
		"$(wildcard $(TOOLCHAIN_DIR)/lib/libatomic.so)" \
		"$(wildcard $(TOOLCHAIN_DIR)/lib/libatomic.a)" \
		"$(patsubst $(TOOLCHAIN_DIR)/lib/%,$(PKG_BUILD_DIR)/%,$(wildcard $(TOOLCHAIN_DIR)/lib/libatomic*.so))" \
		$(BUILD_LIBGCC) \
		-Wl,-soname=libatomic.so.0
  endef
endif

define Build/Compile/Default
	$(call Build/Compile/libgcc)
	$(call Build/Compile/$(LIBC))
endef
Build/Compile = $(Build/Compile/Default)

ifeq ($(CONFIG_EXTERNAL_TOOLCHAIN),)
  define Package/libatomic/install
	$(INSTALL_DIR) $(1)/lib
	$(if $(CONFIG_TARGET_avr32)$(CONFIG_TARGET_coldfire),,$(CP) $(TOOLCHAIN_DIR)/lib/libatomic.so.* $(1)/lib/)
	for file in libatomic ; do \
		$(CP) \
			$(TOOLCHAIN_DIR)/lib/$$$$file.so.* \
			$(TOOLCHAIN_DIR)/lib/$$$$file.so.1.0.0 \
			$(1)/lib/; \
	done
  endef
endif

$(eval $(call BuildPackage,libatomic))
