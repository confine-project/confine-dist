include $(TOPDIR)/rules.mk

PKG_NAME:=oonf-api
PKG_VERSION:=2012-06-14
PKG_REV:=cf76ad67215c90489fd61d7210541017e1c954a
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
CMAKE_OPTIONS=-DOONF_DO_NOT_REGISTER_PACKAGE:Bool=true \
              -DOONF_LOGGING_LEVEL:String=warn \
              -DCMAKE_BUILD_TYPE:String=MinSizeRel \
              -DOONF_NO_TESTING:Bool=true \
              -DINSTALL_LIB_DIR:Path=lib/oonf \
              -DINSTALL_INCLUDE_DIR:Path=include/oonf \
              -DINSTALL_CMAKE_DIR:Path=lib/oonf

define Package/oonf-api/template
	SECTION:=net
	CATEGORY:=Network
	MAINTAINER:=Henning Rogge <hrogge@gmail.com>
	SUBMENU:=OLSR.org network framework
	URL:=http://www.olsr.org/
endef

define Package/oonf-common-api
	$(call Package/oonf-api/template) 
	TITLE:=Common-API (generic helpers functions) 
endef

define Package/oonf-config-api
	$(call Package/oonf-api/template) 
	TITLE:=Config-API (generic configuration library)
	DEPENDS:=+oonf-common-api
endef

define Package/oonf-rfc5444-api
	$(call Package/oonf-api/template) 
	TITLE:=RFC5444-API (generic parser/generator for RFC5444)
	DEPENDS:=+oonf-common-api
endef

define Package/oonf-core-api
	$(call Package/oonf-api/template) 
	TITLE:=Core-API (basic infrastructure/scheduler code)
	DEPENDS:=+oonf-common-api +oonf-config-api +oonf-rfc5444-api +librt
endef

define Package/oonf-tools-api
	$(call Package/oonf-api/template) 
	TITLE:=Tools-API (high level infrastructure)
	DEPENDS:=+oonf-common-api +oonf-config-api +oonf-rfc5444-api +oonf-core-api
endef

define Package/oonf-plugin-cfgio-file
	$(call Package/oonf-api/template) 
	TITLE:=File input/output configuration plugin
	DEPENDS:=+oonf-core-api +oonf-tools-api
endef

define Package/oonf-plugin-cfgparser-compact
	$(call Package/oonf-api/template) 
	TITLE:=Compact configurationf format plugin
	DEPENDS:=+oonf-core-api +oonf-tools-api
endef

define Package/oonf-plugin-httptelnet
	$(call Package/oonf-api/template) 
	TITLE:=HTTP to Telnet bridge plugin
	DEPENDS:=+oonf-core-api +oonf-tools-api
endef

define Package/oonf-plugin-remotecontrol
	$(call Package/oonf-api/template) 
	TITLE:=Remote debugging and configuration plugin
	DEPENDS:=+oonf-core-api +oonf-tools-api
endef

TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/oonf/common \
		       $(1)/usr/include/oonf/config \
	               $(1)/usr/include/oonf/rfc5444 \
	               $(1)/usr/include/oonf/core \
	               $(1)/usr/include/oonf/core/os_linux \
	               $(1)/usr/include/oonf/tools
        
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
		$(PKG_INSTALL_DIR)/usr/include/oonf/core/os_linux/*.h \
		$(1)/usr/include/oonf/core/os_linux
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/include/oonf/tools/*.h \
		$(1)/usr/include/oonf/tools

	$(INSTALL_DIR) $(1)/usr/lib/oonf/
	$(INSTALL_BIN) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/lib*.{so*,a} \
		$(1)/usr/lib/oonf/
	$(INSTALL_DATA) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/OONF*.cmake                                                  \
		$(1)/usr/lib/oonf/

#        $(INSTALL_DIR) $(1)/usr/lib/pkgconfig
#        $(INSTALL_DATA) \
#                $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/libusb.pc \
#                $(1)/usr/lib/pkgconfig/
endef

define Package/oonf-common-api/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_common*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-config-api/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_config*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-rfc5444-api/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_rfc5444*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-core-api/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_core*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-tools-api/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_tools*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-plugin-cfgio-file/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_cfgio_file*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-plugin-cfgparser-compact/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_cfgparser_compact*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-plugin-httptelnet/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_httptelnet*.so* \
		$(1)/usr/lib/oonf
endef

define Package/oonf-plugin-remotecontrol/install
	$(INSTALL_DIR) $(1)/usr/lib/oonf
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/oonf/liboonf_remotecontrol*.so* \
		$(1)/usr/lib/oonf
endef

$(eval $(call BuildPackage,oonf-common-api))
$(eval $(call BuildPackage,oonf-config-api))
$(eval $(call BuildPackage,oonf-rfc5444-api))
$(eval $(call BuildPackage,oonf-core-api))
$(eval $(call BuildPackage,oonf-tools-api))
$(eval $(call BuildPackage,oonf-plugin-cfgio-file))
$(eval $(call BuildPackage,oonf-plugin-cfgparser-compact))
$(eval $(call BuildPackage,oonf-plugin-httptelnet))
$(eval $(call BuildPackage,oonf-plugin-remotecontrol))
