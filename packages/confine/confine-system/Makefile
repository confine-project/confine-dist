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
	+grub2 \
	+bash \
	+lxc \
	+strace \
	+gawk \
	+ip +tc +iw \
	+ebtables \
	+tinc \
	+file \
	+losetup \
	+coreutils-readlink \
	+mount-utils \
	+px5g \
	+time \
	+ntpd \
	+block-mount +sfdisk +partx-utils \
	\
	+dropbearconvert \
	+openssh-keygen +openssl-util \
	+wget \
	\
	+lua \
	+luasignal \
	+luasocket \
	+luci \
	+luci-app-diag-core \
	+luci-app-firewall \
	+luci-i18n-english \
	+luci-lib-core \
	+luci-lib-ipkg \
	+luci-lib-json \
	+luci-lib-lmo \
	+luci-lib-nixio \
	+luci-lib-sys \
	+luci-lib-web \
	+luci-mod-admin-core \
	+luci-mod-admin-full \
	+luci-mod-rpc \
	+luci-proto-core \
	+luci-proto-ppp \
	+luci-sgi-cgi \
	+luci-sgi-uhttpd \
	+luci-ssl \
	+luci-theme-base \
	+luci-theme-openwrt \
	\
	+uclibcxx \
	+uhttpd \
	+uhttpd-mod-lua \
	+uhttpd-mod-tls \
	+uhttpd-mod-tls_cyassl \
	\
	+kmod-ebtables +kmod-ebtables-ipv4 +kmod-ebtables-ipv6 +kmod-ebtables-watchers \
	\
	+kmod-dummy \
	+kmod-fs-ext4 \
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
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-system/install
	$(eval BRANCH_GIT := $(shell git branch | grep ^* | cut -d " " -f 2))
	$(eval REV_GIT := $(shell git --no-pager log -n 1 --oneline | cut -d " " -f 1))

	$(INSTALL_DIR) $(1)/usr
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/lxc
	$(INSTALL_DIR) $(1)/lxc/scripts
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/dropbear
	$(CP) ./files/etc/uci-defaults/* $(1)/etc/uci-defaults/

	$(SED) 's,$$$$BRANCH,$(BRANCH_GIT),g'              $(1)/etc/uci-defaults/confine-banner.sh
	$(SED) 's,$$$$REV,$(REV_GIT),g'                    $(1)/etc/uci-defaults/confine-banner.sh
	$(CP)  ./files/lxc/scripts/openwrt-confine.sh      $(1)/lxc/scripts/
	$(CP)  ./files/lxc/scripts/debian-confine.sh       $(1)/lxc/scripts/
	$(CP)  ./files/etc/init.d/confine                  $(1)/etc/init.d/
	$(CP)  ./files/etc/config/confine-defaults         $(1)/etc/config/
	$(CP)  ./files/etc/config/confine-slivers          $(1)/etc/config/
	$(CP)  ./files/etc/config/confine-slice-attributes $(1)/etc/config/
	$(CP)  ./files/etc/confine-ebtables.lst            $(1)/etc/
	$(CP)  ./files/usr/sbin/confine.lib                $(1)/usr/sbin/
	$(CP)  ./files/usr/sbin/confine.udhcpc.test        $(1)/usr/sbin/
	$(CP)  ./files/usr/sbin/confine.functions          $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/confine.disk-parted $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/confine.sysupgrade $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/usr/sbin/confine.remote-upgrade $(1)/usr/sbin/
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
endef


$(eval $(call BuildPackage,confine-system))

