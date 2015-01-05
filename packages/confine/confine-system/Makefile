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

PKG_NAME:=confine-system
PKG_VERSION:=$(shell date -d "`git log -n 1 --pretty=%ci`" --utc "+r%Y%m%d.%H%M")
PKG_RELEASE:=1

#PKG_SOURCE_URL:=@SF/confine-system
#PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk


define Package/confine-system
  SECTION:=net
  CATEGORY:=Base system
  TITLE:=Basic system requirements for confine nodes
  URL:=http://confine-project.eu
  DEPENDS:= \
	+confine-parted \
	\
	+lxc \
	+lxc-attach \
	+lxc-autostart \
	+lxc-cgroup \
	+lxc-checkconfig \
	+lxc-clone \
	+lxc-common \
	+lxc-config \
	+lxc-console \
	+lxc-create \
	+lxc-destroy \
	+lxc-execute \
	+lxc-freeze \
	+lxc-hooks \
	+lxc-info \
	+lxc-ls \
	+lxc-lua \
	+lxc-monitor \
	+lxc-monitord \
	+lxc-snapshot \
	+lxc-start \
	+lxc-stop \
	+lxc-unfreeze \
	+lxc-unshare \
	+lxc-user-nic \
	+lxc-usernsexec \
	+lxc-wait \
	\
	\
	+veth +swconfig \
	+kmod-veth +kmod-macvlan +kmod-bridge +kmod-swconfig \
	+kmod-ipv6 \
	\
	+coreutils +coreutils-rm +coreutils-timeout \
	+coreutils-chroot +coreutils-sha1sum \
	+bzip2 +gzip +tar \
	\
	\
	+grub2 \
	+bash \
	+strace \
	+gawk \
	+ip +tc +iw \
	+wireless-tools \
	+ebtables \
	+tinc \
	+radvd \
	+file \
	+diffutils \
	+procps \
	+losetup \
	+coreutils-readlink \
	+coreutils-dd \
	+sysfsutils \
	+e2fsprogs \
	+fallocate-e2fsprogs \
	+mount-utils \
	+px5g \
	+time \
	+ntpd \
	+block-mount +sfdisk +partx-utils \
	\
	+dropbearconvert \
	+openssh-keygen +openssl-util \
	+wget \
	+curl \
	\
	+lua \
	+luasignal \
	+luasocket \
	+luci \
	+luci-app-diag-core \
	+luci-app-firewall \
	+luci-i18n-english \
	+luci-lib-json \
	+luci-lib-nixio \
	+luci-mod-admin-full \
	+luci-mod-rpc \
	+luci-proto-ppp \
	+luci-ssl \
	+luci-theme-openwrt \
	\
	+uclibcxx \
	+uhttpd \
	+uhttpd-mod-lua \
	+uhttpd-mod-tls \
	\
	+kmod-llc +kmod-loop \
	+kmod-sched +kmod-sched-core \
	+kmod-sit +kmod-stp \
	\
	+kmod-ebtables +kmod-ebtables-ipv4 +kmod-ebtables-ipv6 +kmod-ebtables-watchers \
	\
	+kmod-e1000e \
	+kmod-3c59x \
	+kmod-8139cp \
	+kmod-8139too \
	+kmod-atl1 \
	+kmod-atl1c \
	+kmod-atl1e \
	+kmod-atl2 \
	+kmod-b44 \
	+kmod-b43 \
	+kmod-dm9000 \
	+kmod-e100 \
	+kmod-e1000 \
	+kmod-et131x \
	+kmod-gigaset \
	+kmod-ne2k-pci \
	+kmod-pcnet32 \
	+kmod-r8169 \
	+kmod-atm \
	\
	+kmod-dummy \
	+kmod-gre \
	+kmod-fs-ext4 \
	+kmod-fs-vfat \
	\
	+kmod-usb-storage +kmod-usb-uhci +kmod-usb2 +kmod-usb-ohci +kmod-usb-core \
	+kmod-usb-hid \
	\
	+kmod-cfg80211 +kmod-mac80211 \
	+kmod-ath5k +kmod-ath9k \
	+kmod-ath9k-common +kmod-ath9k-htc

endef

define optional
  IGNORE_DEPENDS:= \
	+kmod-b43 \

  IGNORE_DEPENDS:= \
	@TARGET_x86 \
	+@BUSYBOX_CONFIG_FOLD \

endef

define Package/confine-system/description
	minimal system requirements for confine research devices (RDs)
endef

define Package/confine-system/conffiles
/etc/config/confine
/etc/config/confine-slivers
/etc/config/confine-slice-attributes
/etc/config/lxc
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-system/install

	$(INSTALL_DIR) $(1)/home
	$(INSTALL_DIR) $(1)/home/lxc
	$(INSTALL_DIR) $(1)/home/lxc/images
	$(INSTALL_DIR) $(1)/home/lxc/templates
	$(INSTALL_DIR) $(1)/cgroup

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/usr/lib/lxc/
	$(INSTALL_DIR) $(1)/usr/lib/lxc/rootfs
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/lxc
	$(INSTALL_DIR) $(1)/etc/lxc/scripts
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config

	$(CP) ./files/etc/init.d/lxc           $(1)/etc/init.d/
	$(CP) ./files/etc/config/lxc           $(1)/etc/config/
	$(CP) ./files/etc/config/lxc           $(1)/etc/config/lxc.orig
	$(CP) ./files/etc/lxc/scripts/openwrt.sh   $(1)/etc/lxc/scripts/
	$(CP) ./files/etc/lxc/scripts/debian.sh    $(1)/etc/lxc/scripts/
	$(CP) ./files/usr/sbin/lxc.functions   $(1)/usr/sbin/
	$(CP) ./files/usr/sbin/lxc.lib         $(1)/usr/sbin/
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_help
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_create
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_start
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_stop
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_remove
	ln -sf lxc.lib                         $(1)/usr/sbin/lxc_purge

	$(INSTALL_DIR) $(1)/usr
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/home/lxc
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/lxc
	$(INSTALL_DIR) $(1)/etc/lxc/scripts
	$(INSTALL_DIR) $(1)/etc/firstboot
	$(INSTALL_DIR) $(1)/etc/anyboot
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/dropbear
	$(INSTALL_DIR) $(1)/etc/uci-defaults

	$(CP) ./files/etc/firstboot/*                      $(1)/etc/firstboot
	chmod +x $(1)/etc/firstboot/*
	$(CP)  ./files/etc/lxc/scripts/openwrt-confine.sh  $(1)/etc/lxc/scripts/
	$(CP)  ./files/etc/lxc/scripts/debian-confine.sh   $(1)/etc/lxc/scripts/
	$(CP)  ./files/etc/init.d/confine                  $(1)/etc/init.d/
	$(CP)  ./files/etc/config/confine-defaults         $(1)/etc/config/
	$(CP)  ./files/etc/config/confine-slivers          $(1)/etc/config/
	$(CP)  ./files/etc/config/confine-slice-attributes $(1)/etc/config/
	$(CP)  ./files/etc/confine-ebtables.lst            $(1)/etc/
	$(CP)  ./files/usr/sbin/confine.lib                $(1)/usr/sbin/
	$(CP)  ./files/usr/sbin/confine.udhcpc.test        $(1)/usr/sbin/
	$(CP)  ./files/usr/sbin/confine.functions          $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/confine
	$(CP)  ./files/usr/lib/lua/confine/*.lua           $(1)/usr/lib/lua/confine
	$(CP)  ./files/etc/screenrc                        $(1)/etc/

	ln -sf confine.lib  $(1)/usr/sbin/confine_help
	ln -sf confine.lib  $(1)/usr/sbin/confine_info
	ln -sf confine.lib  $(1)/usr/sbin/confine_node_enable
	ln -sf confine.lib  $(1)/usr/sbin/confine_node_disable
	ln -sf confine.lib  $(1)/usr/sbin/confine_daemon_stop
	ln -sf confine.lib  $(1)/usr/sbin/confine_daemon_continue
	ln -sf confine.lib  $(1)/usr/sbin/confine_daemon_update
	ln -sf confine.lib  $(1)/usr/sbin/confine_sliver_allocate
	ln -sf confine.lib  $(1)/usr/sbin/confine_sliver_deploy
	ln -sf confine.lib  $(1)/usr/sbin/confine_sliver_undeploy
	ln -sf confine.lib  $(1)/usr/sbin/confine_sliver_start
	ln -sf confine.lib  $(1)/usr/sbin/confine_sliver_stop
	ln -sf confine.lib  $(1)/usr/sbin/confine_sliver_remove
	ln -sf confine.lib  $(1)/usr/sbin/confine_sliver_dump_overlay
endef


$(eval $(call BuildPackage,confine-system))

