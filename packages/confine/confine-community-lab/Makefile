# CONFINE community-lab requirements (http://community-lab.net)
#
#    Copyright (C) 2015 Universitat Politecnica de Barcelona (UPC)
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

PKG_NAME:=confine-community-lab
PKG_RELEASE:=1
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/confine-community-lab
  SECTION:=net
  CATEGORY:=Base system
  TITLE:=Community-lab.net settings for confine nodes
  URL:=http://community-lab.net
  DEPENDS:= +confine-system
endef



define Package/confine-community-lab/description
	Community-lab.net settings for confine nodes
endef

define Package/confine-community-lab/conffiles
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-community-lab/install
	$(CP) -r ./files/etc                      $(1)/
endef


$(eval $(call BuildPackage,confine-community-lab))

