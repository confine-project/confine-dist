include $(TOPDIR)/rules.mk

PKG_NAME:=oonf-dlep
#PKG_VERSION:=2012-06-15
#PKG_REV:=1afce5f94242d97344c17e008278c171c88398bb
PKG_VERSION:=2012-10-19
PKG_REV:=d8f9b60b99e335e865bc3f8d6dedbab757a48ff2#
PKG_RELEASE:=$(PKG_REV)

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://olsr.org/git/dlep_app.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=$(PKG_REV)


CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

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
	DEPENDS:=+oonf-core-api +oonf-tools-api +ldconfig
endef

define Package/oonf-dlep-plugin-client
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP-client plugin
	DEPENDS:=oonf-dlep +ldconfig
endef

define Package/oonf-dlep-plugin-service
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP-service plugin
	DEPENDS:=oonf-dlep +oonf-dlep-plugin-nl80211listener +ldconfig
endef

define Package/oonf-dlep-plugin-nl80211listener
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP mac82011 netlink listener
	DEPENDS:=oonf-dlep +ldconfig +libnl-tiny
endef

define Package/oonf-dlep-plugin-layer2viewer
	$(call Package/oonf-dlep/template) 
	TITLE:=DLEP linklayer data viewer plugin
	DEPENDS:=oonf-dlep +ldconfig
endef

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include -I${STAGING_DIR}/usr/include/libnl-tiny

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

define Package/oonf-dlep-plugin-nl80211listener/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Running ldconfig ..."
	/sbin/ldconfig 2> /dev/null
fi
exit 0
endef

define Package/oonf-dlep-plugin-layer2viewer/postinst
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
$(eval $(call BuildPackage,oonf-dlep-plugin-nl80211listener))
$(eval $(call BuildPackage,oonf-dlep-plugin-layer2viewer))
