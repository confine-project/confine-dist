include $(TOPDIR)/rules.mk

PKG_NAME:=oonf-dlep
PKG_VERSION:=2012-06-15
PKG_REV:=1afce5f94242d97344c17e008278c171c88398bb
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
CMAKE_OPTIONS=-DOONF_DO_NOT_REGISTER_PACKAGE:Bool=true \
              -DOONF_LOGGING_LEVEL:String=debug \
              -DCMAKE_BUILD_TYPE:String=MinSizeRel \
              -DINSTALL_LIB_DIR:Path=lib/oonf \
              -DINSTALL_INCLUDE_DIR:Path=include/oonf \
              -DINSTALL_CMAKE_DIR:Path=lib/oonf \
              -DOONF_LIBNL:Path=nl-tiny

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
	DEPENDS:=+oonf-core-api +oonf-tools-api
endef

define Package/oonf-dlep-plugin-client
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP-client plugin
	DEPENDS:=+oonf-dlep
endef

define Package/oonf-dlep-plugin-service
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP-service plugin
	DEPENDS:=+oonf-dlep
endef

define Package/oonf-dlep-plugin-nl80211listener
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP mac82011 netlink listener
	DEPENDS:=+oonf-dlep +libnl-tiny
endef

define Package/oonf-dlep-plugin-layer2viewer
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP linklayer data viewer plugin
	DEPENDS:=+oonf-dlep
endef

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include -I${STAGING_DIR}/usr/include/libnl-tiny

define Package/oonf-dlep/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/bin/dlep \
		$(1)/usr/bin
endef

define Package/oonf-dlep-plugin-client/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/libdlep_dlep_client*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-dlep-plugin-service/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/libdlep_dlep_service*.so* \
		$(1)/usr/lib/oonf
	$(CP) \
		./etc/dlep.conf \
		$(1)/etc
	$(CP) \
		./etc/init.d/dlep \
		$(1)/etc/init.d
endef

define Package/oonf-dlep-plugin-nl80211listener/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/libdlep_nl80211_listener*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-dlep-plugin-layer2viewer/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/libdlep_layer2_viewer*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-dlep-plugin-service/postinst
#!/bin/sh
echo /usr/lib/oonf >> $${IPKG_INSTROOT}/etc/ld.so.conf
endef


$(eval $(call BuildPackage,oonf-dlep))
$(eval $(call BuildPackage,oonf-dlep-plugin-client))
$(eval $(call BuildPackage,oonf-dlep-plugin-service))
$(eval $(call BuildPackage,oonf-dlep-plugin-nl80211listener))
$(eval $(call BuildPackage,oonf-dlep-plugin-layer2viewer))
