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
PKG_VERSION:=1.4.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://openvswitch.org/releases/
PKG_MD5SUM:=3847c60af329bfe81ff7220b9f489fa5

PKG_INSTALL:=1

PKG_BUILD_DEPENDS:=openssl

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/openvswitch
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=OpenVSwitch
  URL:=http://openvswitch.org
  DEPENDS:= +librt +libopenssl +openssl-util +kmod-openvswitch
endef

define Package/openvswitch/description
	Open vSwitch is a production quality, multilayer virtual switch 
	licensed under the open source Apache 2.0 license. It is designed 
	to enable massive network automation through programmatic extension, 
	while still supporting standard management interfaces and protocols 
	(e.g. NetFlow, sFlow, SPAN, RSPAN, CLI, LACP, 802.1ag).
endef

define Build/Configure
	$(call Build/Configure/Default, --prefix=/usr \
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
	$(INSTALL_DIR) $(1)/etc/openvswitch
	$(INSTALL_DIR) $(1)/etc/init.d

	$(INSTALL_BIN) ./files/ovs.init $(1)/etc/init.d/openvswitch

	$(CP) $(PKG_INSTALL_DIR)/usr/* $(1)/usr
endef

$(eval $(call BuildPackage,openvswitch))

NETWORK_SUPPORT_MENU:=Network Support

define KernelPackage/openvswitch
  SUBMENU:=$(NETWORK_SUPPORT_MENU)
  TITLE:=Openvswitch datapath kernel module.
  DEPENDS:=+kmod-bridge
  KCONFIG:=CONFIG_OPENVSWITCH
  FILES:=$(LINUX_DIR)/net/openvswitch/openvswitch.ko
  AUTOLOAD:=$(call AutoLoad,06,openvswitch)
endef

define KernelPackage/openvswitch/description
 Openvswitch datapath kernel module.
endef

$(eval $(call KernelPackage,openvswitch))   
