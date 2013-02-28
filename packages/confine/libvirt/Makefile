include $(TOPDIR)/rules.mk

PKG_NAME:=libvirt
PKG_VERSION:=1.0.2
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://libvirt.org/sources/
PKG_MD5SUM:=7e268ed702c4331d393e5b43449cae13

PKG_INSTALL:=1


include $(INCLUDE_DIR)/package.mk

define Package/libvirt
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Libvirt Virtualization API
  URL:=http://libvirt.org
  DEPENDS:= +gnutls-utils +libgnutls +libgnutls-extra +libgnutls-openssl +certtool \
            +libdevmapper +libnl +libgcrypt +librpc +libxml2 \
            +gzip +tar

endef

TARGET_CFLAGS += -fno-stack-protector

CONFIGURE_VARS += BLKID_LIBS="-lblkid -luuid" gl_cv_warn_c__fstack_protector_all=no

define Package/libvirt/description
	Libvirt is an open source API, daemon and management tool for managing platform virtualization.
endef

define Build/Configure
	$(call Build/Configure/Default,--with-yajl=no --with-macvtap=no --with-lxc=yes)
endef

define Package/libvirt/install
	$(CP) $(PKG_INSTALL_DIR)/etc $(1)/
	$(CP) $(PKG_INSTALL_DIR)/usr $(1)/

#	$(CP) $(PKG_INSTALL_DIR)/var $(1)/ # Cannot do so use an init script
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/libvirt-init $(1)/etc/init.d/
endef

$(eval $(call BuildPackage,libvirt))
