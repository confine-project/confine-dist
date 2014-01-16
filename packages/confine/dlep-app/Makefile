include $(TOPDIR)/rules.mk

PKG_NAME:=oonf-dlep
PKG_VERSION:=2014-01-15
PKG_RELEASE=$(PKG_SOURCE_VERSION)
PKG_REV:=e3d19699142444907759d1bf69800399a7332d04
PKG_RELEASE:=$(PKG_REV)

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://olsr.org/git/dlep_app.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=$(PKG_REV)

CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

#CMAKE_SOURCE_DIR=$(CURDIR)/../../
CMAKE_OPTIONS=-D OONF_DO_NOT_REGISTER_PACKAGE:Bool=true \
              -D OONF_LOGGING_LEVEL:String=debug \
              -D CMAKE_BUILD_TYPE:String=Debug \
              -D OONF_CUSTOM_STATIC_PLUGINS="cfgparser_compact cfgio_file nl80211_listener dlep_service layer2_viewer" \
              -D INSTALL_LIB_DIR:Path=lib/oonf \
              -D INSTALL_INCLUDE_DIR:Path=include/oonf \
              -D INSTALL_CMAKE_DIR:Path=lib/oonf \
              -D CMAKE_PREFIX_PATH=$(STAGING_DIR)/usr

PKG_BUILD_DEPENDS:=oonf-api

define Package/oonf-dlep/template
	SECTION:=net
	CATEGORY:=Network
	MAINTAINER:=Henning Rogge <hrogge@gmail.com>
	SUBMENU:=OLSR.org DLEP agent
	URL:=http://www.olsr.org/
endef

define Package/oonf-dlep
	$(call Package/oonf-dlep/template)
	TITLE:=DLEP-agent (executable for client and service) 
	DEPENDS:=+ldconfig +libnl-tiny +librt
endef

define Package/oonf-dlep-plugin-client
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP-client plugin
	DEPENDS:=oonf-dlep +oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-dlep-plugin-service
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP-service plugin
	DEPENDS:=oonf-dlep +oonf-api-core +oonf-api-subsystems +ldconfig
endef

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include

define Package/oonf-dlep/install
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) \
		$(PKG_INSTALL_DIR)/usr/bin/dlep \
		$(1)/usr/sbin
	$(INSTALL_BIN) \
		./files/dlep.init \
		$(1)/etc/init.d/dlep
	$(INSTALL_DATA) \
		./files/dlep.conf \
		$(1)/etc
endef

define Package/oonf-dlep/conffiles
/etc/dlep.conf
endef

define Package/oonf-dlep-plugin-client/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/libdlep_dlep_client*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-dlep-plugin-service/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/libdlep_dlep_service*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-dlep/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Adding /usr/lib/oonf to ld.so.conf ..."
	echo /usr/lib/oonf >> /etc/ld.so.conf
	echo "Running ldconfig ..."
	/sbin/ldconfig 2> /dev/null
fi
exit 0
endef

define Package/oonf-dlep-plugin-client/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Running ldconfig ..."
	/sbin/ldconfig 2> /dev/null
fi
exit 0
endef

define Package/oonf-dlep-plugin-service/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Running ldconfig ..."
	/sbin/ldconfig 2> /dev/null
fi
exit 0
endef

define Package/oonf-dlep/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Stopping DLEP service ..."
	/etc/init.d/dlep stop
fi
exit 0
endef

define Package/oonf-dlep/postrm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Removing /usr/lib/oonf from ld.so.cache ..."
	sed -i '/^\/usr\/lib\/oonf$$/d' /etc/ld.so.conf
	/sbin/ldconfig 2> /dev/null
fi
exit 0
endef

$(eval $(call BuildPackage,oonf-dlep))
$(eval $(call BuildPackage,oonf-dlep-plugin-client))
$(eval $(call BuildPackage,oonf-dlep-plugin-service))
