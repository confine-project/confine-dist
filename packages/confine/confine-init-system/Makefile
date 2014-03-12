# CONFINE firmware generator (http://confine-project.eu)
#
#    Copyright (C) 2011, 2012, 2013 Universitat Politecnica de Barcelona (UPC)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME := confine-init-system
PKG_VERSION := $(shell date -d "`git log -n 1 --pretty=%ci`" --utc "+r%Y%m%d.%H%M")
PKG_RELEASE := 1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/confine-init-system
  SECTION:=net
  CATEGORY:=Base system
  TITLE:=Init system for Confine
  URL:=http://confine-project.eu
  DEPENDS:= \
	+bash \
	+mount-utils \
	+block-mount \
	+sfdisk \
	+partx-utils \
	+kexec-tools
	+losetup

endef

define Package/confine-init-system/description
	Init system for Confine nodes, separate from the actual confine system
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-init-system/install
	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_DIR) $(1)/lib/preinit
	$(INSTALL_DIR) $(1)/sbin

	$(INSTALL_BIN) ./files/sbin/confine-init $(1)/sbin/confine-init
endef

$(eval $(call BuildPackage,confine-init-system))

