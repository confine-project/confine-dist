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

PKG_NAME:=confine-recommended
PKG_RELEASE:=1
#PKG_SOURCE_URL:=@SF/confine-recommended
#PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/confine-recommended
  SECTION:=net
  CATEGORY:=Base system
  TITLE:=Toolcollection for confine nodes
  URL:=http://confine-project.eu
  DEPENDS:= \
	+confine-system \
	\
	+oonf-dlep \
	\
	+openvswitch \
	+kmod-openvswitch \
	\
	+screen \
	+coreutils-dd \
	+lm-sensors +lm-sensors-detect \
	+usbutils +binutils +patch +pciutils \
	\
	+libiwinfo-lua \
	\
	+python +python-mini \
	\
	+ruby +ruby-core \
	+ruby-dl +ruby-erb +ruby-gems +ruby-irb +ruby-openssl +ruby-rake \
	+ruby-readline +ruby-rexml +ruby-webrick +ruby-xmlrpc \
	+ruby-yaml +ruby-zlib \
	\
	+bash +nano +less +fdisk \
	+less +vim \
	+bzip2 \
	\
	+e2fsprogs \
	+sysfsutils \
	+kmod-fs-vfat \
	\
	+radvd \
	+hostapd \
	+wpad \
	+wireless-tools +iw \
	+wide-dhcpv6-client +wide-dhcpv6-control \
	+wide-dhcpv6-server \
	+openvpn \
	+6in4 +6to4 \
	+iptables +ip6tables \
	+kmod-ip6tables \
	\
	+iputils-arping +iputils-clockdiff \
	+iputils-ping +iputils-tracepath \
        +mtr \
	+iperf +mtr +netcat +netperf \
	+tcpdump \
	+netcat \
	+nmap +lsof \
	+horst \
	+ipv6calc \
	+bmon +bwm \
	\
	+snmp-utils +snmpd +ifstat +iftop +fping +ethtool \
	+airview +broadcastflood \
	\
	+htop \
	+debootstrap \
	\
	+kmod-usb-storage +kmod-usb-uhci +kmod-usb2 +kmod-usb-ohci +kmod-usb-core \
	+kmod-usb-hid \
	\
	+usbip +usbip-client +usbip-server \
	\
	+kmod-usb-net \
	+kmod-usb-net-asix \
	+kmod-usb-net-cdc-ether \
	+kmod-usb-net-dm9601-ether \
	+kmod-usb-net-hso \
	+kmod-usb-net-kaweth \
	+kmod-usb-net-mcs7830 \
	+kmod-usb-net-pegasus \
	+kmod-usb-net-rndis \
	+kmod-usb-net-sierrawireless \
	\
	+kmod-ipip \
	+kmod-iptunnel4 +kmod-ip6-tunnel +kmod-iptunnel6 \
	+kmod-tun \
	+kmod-nls-base \
	\
	+kmod-llc +kmod-loop \
	+kmod-sched +kmod-sched-core \
	+kmod-sit +kmod-stp \
	\
	+kmod-p54-common \
	+kmod-p54-usb \
	+kmod-rt2500-usb \
	+kmod-rt2800-lib \
	+kmod-rt2800-pci \
	+kmod-rt2x00-lib \
	+kmod-rt2x00-pci \
	+kmod-rt2x00-usb \
	+kmod-rt73-usb \
	+kmod-zd1211rw \
	\
	+kmod-hid \
	+kmod-input-core \
	\
	+kmod-bonding \
	+kmod-ipsec \
	+kmod-ipsec4 \
	+kmod-ipsec6 \
	\
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

endef

define optional
  IGNORE_DEPENDS:= \
	+kmod-e1000e \

CONFIG_PACKAGE_kmod-hfcmulti=y
CONFIG_PACKAGE_kmod-hfcpci=y
CONFIG_PACKAGE_kmod-ifb=y
CONFIG_PACKAGE_kmod-libphy=y
CONFIG_PACKAGE_kmod-natsemi=y
CONFIG_PACKAGE_kmod-siit=y
CONFIG_PACKAGE_kmod-sis190=y
CONFIG_PACKAGE_kmod-sis900=y
CONFIG_PACKAGE_kmod-skge=y
CONFIG_PACKAGE_kmod-sky2=y
CONFIG_PACKAGE_kmod-solos-pci=y
CONFIG_PACKAGE_kmod-switch-ip17xx=y
CONFIG_PACKAGE_kmod-tg3=y
CONFIG_PACKAGE_kmod-isdn4linux=y
CONFIG_PACKAGE_kmod-misdn=y
CONFIG_PACKAGE_kmod-ppp=y
CONFIG_PACKAGE_kmod-pppoe=y
CONFIG_PACKAGE_kmod-pppox=y
CONFIG_PACKAGE_kmod-bcma=y
CONFIG_PACKAGE_kmod-eeprom-93cx6=y
CONFIG_PACKAGE_kmod-input-evdev=y
CONFIG_PACKAGE_kmod-mmc=y
CONFIG_PACKAGE_kmod-rfkill=y
CONFIG_PACKAGE_kmod-ssb=y

CONFIG_PACKAGE_kmod-usb-acm=y
CONFIG_PACKAGE_kmod-usb-atm=y
CONFIG_PACKAGE_kmod-usb-atm-cxacru=y
CONFIG_PACKAGE_kmod-usb-atm-speedtouch=y
CONFIG_PACKAGE_kmod-usb-atm-ueagle=y
CONFIG_PACKAGE_kmod-usb-cm109=y
CONFIG_PACKAGE_kmod-usb-serial=y
CONFIG_PACKAGE_kmod-usb-serial-ark3116=y
CONFIG_PACKAGE_kmod-usb-serial-belkin=y
CONFIG_PACKAGE_kmod-usb-serial-ch341=y
CONFIG_PACKAGE_kmod-usb-serial-cp210x=y
CONFIG_PACKAGE_kmod-usb-serial-cypress-m8=y
CONFIG_PACKAGE_kmod-usb-serial-ftdi=y
CONFIG_PACKAGE_kmod-usb-serial-ipw=y
CONFIG_PACKAGE_kmod-usb-serial-keyspan=y
CONFIG_PACKAGE_kmod-usb-serial-mct=y
CONFIG_PACKAGE_kmod-usb-serial-mos7720=y
CONFIG_PACKAGE_kmod-usb-serial-motorola-phone=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_kmod-usb-serial-oti6858=y
CONFIG_PACKAGE_kmod-usb-serial-pl2303=y
CONFIG_PACKAGE_kmod-usb-serial-sierrawireless=y
CONFIG_PACKAGE_kmod-usb-serial-visor=y
CONFIG_PACKAGE_kmod-usb-serial-wwan=y

endef


define Package/confine-recommended/description
	Toolcollection for confine nodes
endef

define Package/confine-recommended/conffiles

endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/confine-recommended/install
endef


$(eval $(call BuildPackage,confine-recommended))

