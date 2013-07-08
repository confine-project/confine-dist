include $(TOPDIR)/rules.mk

PKG_NAME:=libvirt
#PKG_VERSION:=1.0.4
#PKG_VERSION:=0.10.2
PKG_VERSION:=0.9.11
PKG_RELEASE:=3

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=http://libvirt.org/sources/
#v1.0.4
#PKG_MD5SUM:=97166bc42d7cacb037923907abe656ab
#v0.10.2
#PKG_MD5SUM:=a5e50860d9da238ba270b528411c4a0d
#v0.9.11
PKG_MD5SUM:=6e9fab115075a8fd21d9bd0d7e558a52

PKG_INSTALL:=1


include $(INCLUDE_DIR)/package.mk

define Package/libvirt
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=Libvirt Virtualization API
  URL:=http://libvirt.org
  DEPENDS:= +gnutls-utils +libgnutls +libgnutls-extra +libgnutls-openssl +certtool \
            +libdevmapper +libnl +libgcrypt +librpc +libxml2 +dmidecode \
            +gzip +tar

#TO DO: Check and remove unneeded dependencies

endef

TARGET_CFLAGS += -fno-stack-protector

CONFIGURE_VARS += BLKID_LIBS="-lblkid -luuid -lm" \
                  gl_cv_warn__fstack_protector_all=no \
                  gl_cv_warn_c__fstack_protector_all=no \
                  ac_cv_path_IP_PATH="/usr/sbin/ip" \
                  ac_cv_path_IPTABLES_PATH="/usr/sbin/iptables" \
                  ac_cv_path_IP6TABLES_PATH="/usr/sbin/ip6tables" \
                  ac_cv_path_EBTABLES_PATH="/usr/sbin/ebtables"


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
