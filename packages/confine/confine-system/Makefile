# CONFINE firmware generator (http://confine-project.eu)
#
#    Copyright (C) 2011 Universitat Politecnica de Barcelona (UPC)
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

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=confine-system
PKG_RELEASE:=1
#PKG_SOURCE_URL:=@SF/confine-system
#PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/confine-system
  SECTION:=net
  CATEGORY:=Base system
  TITLE:=Basic system requirements for confine nodes
  URL:=http://confine-project.eu
  DEPENDS:= \
	@TARGET_x86 \
	+bash \
	+lxc \
	+awk \

endef

define optional
	+ebtables \
	+iptables \
	+tinc \
endef

define Package/confine-system/description
	minimal system requirements for confine research devices (RDs)
endef

define Package/confine-system/conffiles

endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-system/install
	$(CP) -rva  ./files/* $(1)/
endef


$(eval $(call BuildPackage,confine-system))

