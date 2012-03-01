# CONFINE firmware generator (http://confine-project.eu)
#
#    Copyright (C) 2011 Universitat Politecnica de Barcelona (UPC)
#
#    Thiss program is free software: you can redistribute it and/or modify
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

OWRT_GIT = git@github.com:confine-project/openwrt.git
OWRT_PKG_GIT = git@github.com:confine-project/packages.git
OWRT_GIT_RO = git://github.com/confine-project/openwrt.git
OWRT_PKG_GIT_RO = git://github.com/confine-project/packages.git
TIMESTAMP = $(shell date +%d%m%y_%H%M)
BUILD_DIR = openwrt
FILES_DIR = files
PACKAGE_DIR = packages
OWRT_PKG_DIR = $(PACKAGE_DIR)/openwrt
OWRT_FEEDS = feeds.conf
CONFIG_DIR = configs
MY_CONFIGS = my_configs
DOWNLOAD_DIR = dl
CONFIG = $(BUILD_DIR)/.config
KCONFIG = $(BUILD_DIR)/target/linux/x86/config-default
IMAGES = images
IMAGE = openwrt-x86-generic-combined
J ?= 1
V ?= 0
MAKE_SRC = -j$(J) V=$(V)

define prepare_workspace
	[ ! -d $(DOWNLOAD_DIR) ] && mkdir -p $(DOWNLOAD_DIR) || true
	cat $(OWRT_FEEDS) | sed -e "s|PATH|`pwd`/$(PACKAGE_DIR)|" > $(BUILD_DIR)/feeds.conf
	rm -f $(BUILD_DIR)/dl
	ln -s `readlink -f $(DOWNLOAD_DIR)` $(BUILD_DIR)/dl
endef

define update_feeds
	@echo "Updating feed $(1)"
	$(BUILD_DIR)/$(1)/scripts/feeds update -a
	$(BUILD_DIR)/$(1)/scripts/feeds install -a
endef

define copy_config
	cp -f $(CONFIG_DIR)/owrt_config $(CONFIG)
	cp -f $(CONFIG_DIR)/kernel_config $(KCONFIG)
	(cd $(BUILD_DIR) && make defconfig)
endef

define copy_files
	mkdir -p $(BUILD_DIR)/files
	cp -rf $(FILES_DIR)/* $(BUILD_DIR)/files/
endef

define menuconfig_owrt
	make -C $(BUILD_DIR) menuconfig
	mkdir -p $(MY_CONFIGS)
	(cd $(BUILD_DIR) && scripts/diffconfig.sh) > $(MY_CONFIGS)/owrt_config
	@echo "New OpenWRT configuration file saved on $(MY_CONFIGS)/owrt_config"
endef

define kmenuconfig_owrt
	make -C $(BUILD_DIR) kernel_menuconfig
	mkdir -p $(MY_CONFIGS)
	cp -f $(KCONFIG) $(MY_CONFIGS)/kernel_config
	@echo "New Kernel configuration file saved on $(MY_CONFIGS)/kernel_config"
endef

define build_src
	make -C $(BUILD_DIR) $(MAKE_SRC)
endef

define post_build
	mkdir -p $(IMAGES)
	[ -f $(BUILD_DIR)/bin/x86/$(IMAGE)-squashfs.img.gz ] && gunzip $(BUILD_DIR)/bin/x86/$(IMAGE)-squashfs.img.gz || true
	cp -f $(BUILD_DIR)/bin/x86/$(IMAGE)-squashfs.img $(IMAGES)/CONFINE-owrt-$(TIMESTAMP).img
	cp -f $(BUILD_DIR)/bin/x86/$(IMAGE)-ext4.vdi $(IMAGES)/CONFINE-owrt-$(TIMESTAMP).vdi
	@echo 
	@echo "CONFINE firmware compiled, you can find output files in $(IMAGES)/ directory"
endef


all: prepare sync
	$(call build_src)
	$(call post_build)

prepare: .prepared

.prepared:
	git clone $(OWRT_GIT) openwrt
	git clone $(OWRT_PKG_GIT) packages/openwrt
	$(call prepare_workspace)
	@touch .prepared

prepare_jenkins: .prepared_jenkins

.prepared_jenkins:
	git clone $(OWRT_GIT_RO) openwrt
	git clone $(OWRT_PKG_GIT_RO) packages/openwrt
	$(call prepare_workspace)
	@touch .prepared_jenkins

sync: prepare
	$(call update_feeds)
	$(call copy_files)
	$(call copy_config)

jenkins_fast: prepare_jenkins
	(cd $(BUILD_DIR) && git pull)
	(cd $(OWRT_PKG_DIR) && git pull)
	$(call update_feeds)
	$(call build_src)
	$(call post_build)

menuconfig: prepare
	$(call menuconfig_owrt)

kernel_menuconfig: prepare
	$(call kmenuconfig_owrt)

clean:
	make -C $(BUILD_DIR) clean

dirclean:
	make -C $(BUILD_DIR) dirclean

distclean:
	make -C $(BUILD_DIR) distclean
	$(call copy_files)
	$(call copy_config)

help:
	@cat README
