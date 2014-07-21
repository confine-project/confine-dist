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

PKG_NAME := confine-parted
PKG_VERSION := $(shell date -d "`git log -n 1 --pretty=%ci`" --utc "+r%Y%m%d.%H%M")
PKG_RELEASE := 1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/confine-parted
  SECTION:=net
  CATEGORY:=Base system
  TITLE:=Parted utilities for confine nodes
  URL:=http://confine-project.eu
  DEPENDS:= \
	+bash +wget +mount-utils \
	+block-mount +sfdisk +partx-utils

endef

define Package/confine-parted/description
	minimal Partition management utilities for Confine nodes
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-parted/install
	$(INSTALL_DIR) $(1)/usr
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/firstboot
	$(INSTALL_DIR) $(1)/lib
	$(INSTALL_DIR) $(1)/lib/upgrade
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d

	$(INSTALL_BIN) ./files/usr/sbin/confine.disk-parted $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/confine.sysupgrade $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/confine.remote-upgrade $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,confine-parted))

