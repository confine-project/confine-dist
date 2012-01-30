#    
#    Thiss program is free software: you can redistribute it and/or modify
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
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Authors: Xavier León <xleon@ac.upc.edu>
#
# Copyright (C) 2011 Universitat Politecnica de Barcelona (UPC)
#                    CONFINE project

include $(TOPDIR)/rules.mk

PKG_NAME:=openvswitch
PKG_VERSION:=1.3.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://openvswitch.org/releases/
PKG_MD5SUM:=45e2ded1ee48f1e8490719deb270f2c3

PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/openvswitch
  SECTION:=utils
  CATEGORY:=Utilities
  DEFAULT:=y
  TITLE:=OpenVSwitch
  URL:=http://openvswitch.org
  DEPENDS:= +libopenssl
endef

define Package/openvswitch/description
	Open vSwitch is a production quality, multilayer virtual switch 
	licensed under the open source Apache 2.0 license. It is designed 
	to enable massive network automation through programmatic extension, 
	while still supporting standard management interfaces and protocols 
	(e.g. NetFlow, sFlow, SPAN, RSPAN, CLI, LACP, 802.1ag).
endef

define Build/Configure
	$(call Build/Configure/Default, --with-linux=$(LINUX_DIR) \
									--prefix=/usr \
									--enable-ssl)
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)
endef

define Package/openvswitch/install
	$(MAKE) -C $(PKG_BUILD_DIR) \
		PREFIX="/usr" \
		DESTDIR=$(PKG_INSTALL_DIR) \
		install
	$(INSTALL_DIR) $(1)/usr
	$(INSTALL_DIR) $(1)/lib/modules/$(LINUX_VERSION)
	$(CP) $(PKG_INSTALL_DIR)/usr/* $(1)/usr
	$(CP) $(PKG_BUILD_DIR)/datapath/linux/{brcompat_mod.ko,openvswitch_mod.ko} $(1)/lib/modules/$(LINUX_VERSION)
endef

$(eval $(call BuildPackage,openvswitch))

