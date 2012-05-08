# 
# Copyright (C) 2006-2008 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lxc
PKG_RELEASE:=1
PKG_SOURCE_URL:=@SF/lxc

PKG_VERSION:=0.7.5
PKG_MD5SUM:=cf001ad3f465b17d48dfd623b0011e73

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/kernel.mk

define Package/lxc
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=LXC userspace tools
  URL:=http://lxc.sourceforge.net/

  DEPENDS:= +libcap2 +bash +@BUSYBOX_CONFIG_GETOPT \
            +ip +coreutils +coreutils-rm \
            +perl +perlbase-complete +perlbase-base +perlbase-getcwd +perlbase-getopt +perlbase-sys 


# TODO:
# remove bash dependencie, ensure availability of 
# $BASHPID (needed by /etc/init.d/lxc), getopt (full version), ...
# 

endef

define Package/lxc/description
	Userspace tools to manage linux containers
endef

define Build/Configure
$(call Build/Configure/Default,--with-linuxdir=$(LINUX_DIR))
endef

define Package/lxc/install

	$(INSTALL_DIR) $(1)/lxc
	$(INSTALL_DIR) $(1)/lxc/images
	$(INSTALL_DIR) $(1)/lxc/templates
	$(INSTALL_DIR) $(1)/lxc/scripts
	$(INSTALL_DIR) $(1)/cgroup

	$(INSTALL_DIR) $(1)/usr/bin	
	$(INSTALL_DIR) $(1)/usr/sbin	
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/lib/lxc/
	$(INSTALL_DIR) $(1)/usr/lib/lxc/rootfs
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config

	$(CP) ./files/etc/init.d/lxc           $(1)/etc/init.d/
	$(CP) ./files/etc/config/lxc           $(1)/etc/config/
	$(CP) ./files/etc/config/lxc           $(1)/etc/config/lxc.orig
	$(CP) ./files/lxc/scripts/openwrt.sh   $(1)/lxc/scripts/
	$(CP) ./files/lxc/scripts/debian.sh    $(1)/lxc/scripts/
	$(CP) ./files/usr/sbin/lxc.checkconfig $(1)/usr/sbin/
	$(CP) ./files/usr/sbin/lxc.functions   $(1)/usr/sbin/
	$(CP) ./files/usr/sbin/lxc.lib         $(1)/usr/sbin/
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_help
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_create
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_start
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_stop
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_remove
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_purge

	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-attach $(1)/usr/bin/lxc-attach
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-cgroup $(1)/usr/bin/lxc-cgroup
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-checkconfig $(1)/usr/bin/lxc-checkconfig
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-checkpoint $(1)/usr/bin/lxc-checkpoint
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-clone $(1)/usr/bin/lxc-clone
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-console $(1)/usr/bin/lxc-console
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-create $(1)/usr/bin/lxc-create
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-destroy $(1)/usr/bin/lxc-destroy
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-execute $(1)/usr/bin/lxc-execute
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-freeze $(1)/usr/bin/lxc-freeze
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-info $(1)/usr/bin/lxc-info
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-init $(1)/usr/bin/lxc-init
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-kill $(1)/usr/bin/lxc-kill
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-ls $(1)/usr/bin/lxc-ls
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-monitor $(1)/usr/bin/lxc-monitor
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-netstat $(1)/usr/bin/lxc-netstat
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-ps $(1)/usr/bin/lxc-ps
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-restart $(1)/usr/bin/lxc-restart
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-setcap $(1)/usr/bin/lxc-setcap
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-start $(1)/usr/bin/lxc-start
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-stop $(1)/usr/bin/lxc-stop
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-restart $(1)/usr/bin/lxc-restart
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-unfreeze $(1)/usr/bin/lxc-unfreeze
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-unshare $(1)/usr/bin/lxc-unshare
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-version $(1)/usr/bin/lxc-version
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/lxc/lxc-wait $(1)/usr/bin/lxc-wait

	$(CP)  $(PKG_BUILD_DIR)/src/lxc/liblxc* $(1)/usr/lib/
	ln -s liblxc.so $(1)/usr/lib/liblxc.so.0
endef

$(eval $(call BuildPackage,lxc))
