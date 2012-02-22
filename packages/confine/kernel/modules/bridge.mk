#
# Copyright (C) 2006-2011 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

NETWORK_SUPPORT_MENU:=Network Support

define KernelPackage/bridge
	SUBMENU:=$(NETWORK_SUPPORT_MENU)
	DEFAULT:=m
	TITLE:=Ethernet bridging support
	DEPENDS:=+kmod-stp
	KCONFIG:= \
		CONFIG_BRIDGE \
		CONFIG_BRIDGE_IGMP_SNOOPING=y
	FILES:= $(LINUX_DIR)/net/bridge/bridge.ko
endef

define KernelPackage/bridge/description
 Kernel module for Ethernet bridging
endef

$(eval $(call KernelPackage,bridge))

define KernelPackage/stp
	SUBMENU:=$(NETWORK_SUPPORT_MENU)
	DEFAULT:=m
	TITLE:=Ethernet Spanning Tree Protocol support
	KCONFIG:=CONFIG_STP
	FILES:=$(LINUX_DIR)/net/802/stp.ko
endef

define KernelPackage/stp/description
 Kernel module for Ethernet Spanning Tree
endef

$(eval $(call KernelPackage,stp))

