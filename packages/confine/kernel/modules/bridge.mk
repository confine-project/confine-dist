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
	TITLE:=Linux Bridge support
	KCONFIG:=CONFIG_BRIDGE 
	FILES:= $(LINUX_DIR)/net/bridge/bridge.ko
endef

define KernelPackage/bridge/description
 Linux Bridge support
endef

$(eval $(call KernelPackage,bridge))

define KernelPackage/stp
	SUBMENU:=$(NETWORK_SUPPORT_MENU)
	DEFAULT:=m
	TITLE:=STP support
	KCONFIG:=CONFIG_STP
	FILES:=$(LINUX_DIR)/net/802/stp.ko
endef

$(eval $(call KernelPackage,stp))

define KernelPackage/llc
	SUBMENU:=$(NETWORK_SUPPORT_MENU)
	DEFAULT:=m
	TITLE:=LLC support
	KCONFIG:=CONFIG_LLC
	FILES:=$(LINUX_DIR)/net/llc/llc.ko
endef

$(eval $(call KernelPackage,llc))

