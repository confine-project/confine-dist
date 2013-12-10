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

PKG_NAME:=confine-monitor
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/confine-monitor
  SECTION:=net
  CATEGORY:=Base system
  TITLE:=Monitoring tools for Confine System
  URL:=http://confine-project.eu
  DEPENDS:=+confine-system
endef

define Package/confine-monitor/description
	Monitoring tools for the nodes with Confine System
endef

define Build/Prepare
        mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-monitor/install
	$(INSTALL_DIR) $(1)/home/confine-monitor
	$(INSTALL_DIR) $(1)/home/confine-monitor/client
	$(INSTALL_DIR) $(1)/home/confine-monitor/common

	$(CP) ./files/client/* $(1)/home/confine-monitor/client/
	$(CP) ./files/common/* $(1)/home/confine-monitor/common/

	$(CP)  ./files/main.py $(1)/home/confine-monitor/
	$(INSTALL_BIN) ./files/manage.py $(1)/home/confine-monitor/
	$(CP)  ./files/runserver.py $(1)/home/confine-monitor/
endef

$(eval $(call BuildPackage,confine-monitor))
