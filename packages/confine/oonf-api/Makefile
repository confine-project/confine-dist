include $(TOPDIR)/rules.mk

PKG_NAME:=oonf-api
PKG_VERSION:=2014-04-01
PKG_REV:=9f2e4942a8e7f5e2cf8373a18959b3b9ecd2a292
PKG_RELEASE:=$(PKG_REV)

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://olsr.org/git/oonf_api.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_VERSION:=$(PKG_REV)

CMAKE_INSTALL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

#CMAKE_SOURCE_DIR=$(CURDIR)/../../
CMAKE_OPTIONS=-D OONF_DO_NOT_REGISTER_PACKAGE:Bool=true \
              -D OONF_LOGGING_LEVEL:String=debug \
              -D OONF_NO_TESTING:Bool=true \
              -D INSTALL_LIB_DIR:Path=lib/oonf \
              -D INSTALL_INCLUDE_DIR:Path=include/oonf \
              -D INSTALL_CMAKE_DIR:Path=lib/oonf \
              -D OONF_LIB_GIT=$(PKG_REV)

define Package/oonf-api/template
	SECTION:=net
	CATEGORY:=Network
	MAINTAINER:=Henning Rogge <hrogge@gmail.com>
	SUBMENU:=OLSR.org network framework
	URL:=http://www.olsr.org/
endef

define Package/oonf-api
	$(call Package/oonf-api/template) 
	TITLE:= Build OONF-API static libraries
	BUILDONLY:=1
endef

define Package/oonf-api-common
	$(call Package/oonf-api/template) 
	TITLE:=Common-API (generic helpers functions)
endef

define Package/oonf-api-config
	$(call Package/oonf-api/template) 
	TITLE:=Config-API (generic configuration library)
	DEPENDS:=+oonf-api-common
endef

define Package/oonf-api-rfc5444
	$(call Package/oonf-api/template) 
	TITLE:=RFC5444-API (generic parser/generator for RFC5444)
	DEPENDS:=+oonf-api-common
endef

define Package/oonf-api-core
	$(call Package/oonf-api/template) 
	TITLE:=Core-API (basic infrastructure/scheduler code)
	DEPENDS:=+oonf-api-common +oonf-api-config +librt
endef

define Package/oonf-api-subsystems
	$(call Package/oonf-api/template) 
	TITLE:=OONF subsystems (high level infrastructure)
	DEPENDS:=+oonf-api-common +oonf-api-config +oonf-api-rfc5444 +oonf-api-core
endef

define Package/oonf-plugin-cfgio-file
	$(call Package/oonf-api/template) 
	TITLE:=File input/output configuration plugin
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-plugin-cfgparser-compact
	$(call Package/oonf-api/template) 
	TITLE:=Compact configurationf format plugin
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-plugin-eth-listener
	$(call Package/oonf-api/template) 
	TITLE:=Ethernet speed detector
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-plugin-httptelnet
	$(call Package/oonf-api/template) 
	TITLE:=HTTP to Telnet bridge plugin
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-plugin-layer2-viewer
	$(call Package/oonf-api/template) 
	TITLE:=Telnet viewer for layer2 data
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-plugin-link-config
	$(call Package/oonf-api/template) 
	TITLE:=Manual configuration of layer2 link data
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-plugin-nl80211-listener
	$(call Package/oonf-api/template) 
	TITLE:=Probing plugin for nl80211
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +libnl-tiny +ldconfig
endef

define Package/oonf-plugin-plugin-controller
	$(call Package/oonf-api/template) 
	TITLE:=Remote loading and unloading of plugins
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

define Package/oonf-plugin-remotecontrol
	$(call Package/oonf-api/template) 
	TITLE:=Remote debugging and configuration plugin
	DEPENDS:=+oonf-api-core +oonf-api-subsystems +ldconfig
endef

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include -I${STAGING_DIR}/usr/include/libnl-tiny

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/oonf/common \
		       $(1)/usr/include/oonf/config \
	               $(1)/usr/include/oonf/rfc5444 \
	               $(1)/usr/include/oonf/core \
	               $(1)/usr/include/oonf/core/os_generic \
	               $(1)/usr/include/oonf/subsystems \
	               $(1)/usr/include/oonf/subsystems/os_linux
        
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/common/*.h \
		$(1)/usr/include/oonf/common
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/config/*.h \
		$(1)/usr/include/oonf/config
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/rfc5444/*.h \
		$(1)/usr/include/oonf/rfc5444
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/core/*.h \
		$(1)/usr/include/oonf/core
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/core/os_generic/*.h \
		$(1)/usr/include/oonf/core/os_generic
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/subsystems/*.h \
		$(1)/usr/include/oonf/subsystems
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/subsystems/os_linux/*.h \
		$(1)/usr/include/oonf/subsystems/os_linux

	$(INSTALL_DIR) $(1)/usr/lib/oonf/
	$(INSTALL_BIN) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/lib*.{so*,a} \
		$(1)/usr/lib/oonf/
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/OONF*.cmake                                                  \
		$(1)/usr/lib/oonf/
endef

define Package/oonf-api-common/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_common*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-api-config/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_config*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-api-rfc5444/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_rfc5444*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-api-core/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_core*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-api-subsystems/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_subsystems*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-cfgio-file/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_cfgio_file*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-cfgparser-compact/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_cfgparser_compact*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-httptelnet/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_httptelnet*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-eth-listener/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_eth_listener*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-layer2-viewer/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_layer2_viewer*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-link-config/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_link_config*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-nl80211-listener/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_nl80211_listener*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-plugin-controller/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_plugin_controller*.so* $(1)/usr/lib/oonf
endef

define Package/oonf-plugin-remotecontrol/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_remotecontrol*.so* $(1)/usr/lib/oonf
endef

$(eval $(call BuildPackage,oonf-api))
$(eval $(call BuildPackage,oonf-api-common))
$(eval $(call BuildPackage,oonf-api-config))
$(eval $(call BuildPackage,oonf-api-rfc5444))
$(eval $(call BuildPackage,oonf-api-core))
$(eval $(call BuildPackage,oonf-api-subsystems))
$(eval $(call BuildPackage,oonf-plugin-cfgio-file))
$(eval $(call BuildPackage,oonf-plugin-cfgparser-compact))
$(eval $(call BuildPackage,oonf-plugin-eth-listener))
$(eval $(call BuildPackage,oonf-plugin-httptelnet))
$(eval $(call BuildPackage,oonf-plugin-layer2-viewer))
$(eval $(call BuildPackage,oonf-plugin-link-config))
$(eval $(call BuildPackage,oonf-plugin-nl80211-listener))
$(eval $(call BuildPackage,oonf-plugin-plugin-controller))
$(eval $(call BuildPackage,oonf-plugin-remotecontrol))
