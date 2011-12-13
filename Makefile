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

OWRT_SVN = svn://svn.openwrt.org/openwrt/trunk
OWRT_SVN_REV = -r r28942
TIMESTAMP = $(shell date +%d%m%y_%H%M)
BUILD_DIR = src
FILES_DIR = files
PACKAGE_DIR = packages
CONFIG_DIR = configs
MY_CONFIGS = my_configs
CONFIG = $(BUILD_DIR)/.config
KCONFIG = $(BUILD_DIR)/target/linux/x86/config-*
IMAGES = images
IMAGE = openwrt-x86-generic-combined-squashfs.img
J ?= 1
V ?= 0
MAKE_SRC = -j$(J) V=$(V)

define checkout_src
	svn --quiet co $(OWRT_SVN_REV) $(OWRT_SVN) $(BUILD_DIR)
	@if [ ! -d dl ]; then mkdir dl; fi
	rm -rf $(BUILD_DIR)/dl || true
	ln -s ../../dl $(BUILD_DIR)/dl
endef

define update_feeds
	@echo "Updating feed $(1)"
	./$(BUILD_DIR)/$(1)/scripts/feeds update -a
	./$(BUILD_DIR)/$(1)/scripts/feeds install -a
endef

define copy_config
	cp -f $(CONFIG_DIR)/owrt_config $(CONFIG)
	cp -f $(CONFIG_DIR)/kernel_config $(KCONFIG)
endef

define copy_files
	[ ! -d $(BUILD_DIR)/files ] && mkdir -p $(BUILD_DIR)/files || true
	cp -rf $(FILES_DIR)/* $(BUILD_DIR)/files/
endef

define copy_packages
	cp -rf $(PACKAGE_DIR)/* $(BUILD_DIR)/package/
endef

define menuconfig_owrt
	make -C $(BUILD_DIR) menuconfig
	[ ! -d $(MY_CONFIGS) ] && mkdir -p $(MY_CONFIGS) || true
	cp -f $(CONFIG) $(MY_CONFIGS)/owrt_config
endef

define kmenuconfig_owrt
        make -C $(BUILD_DIR) kernel_menuconfig
        [ ! -d $(MY_CONFIGS) ] && mkdir -p $(MY_CONFIGS) || true
        cp -f $(KCONFIG) $(MY_CONFIGS)/kernel_config
endef

define build_src
	make -C $(BUILD_DIR) $(MAKE_SRC)
endef

define post_build
        [ ! -d $(IMAGES) ] && mkdir $(IMAGES) || true
	[ -f $(BUILD_DIR)/bin/x86/$(IMAGE).gz ] && gunzip $(BUILD_DIR)/bin/x86/$(IMAGE).gz || true
        cp -f $(BUILD_DIR)/bin/x86/$(IMAGE) $(IMAGES)/CONFINE-owrt-$(TIMESTAMP).img
        @echo 
        @echo "CONFINE firmware compiled, you can find output files in $(IMAGES)/ directory"
endef


all: checkout
	$(call build_src)
	$(call post_build)

checkout: .checkout

.checkout:
	$(call checkout_src)
	$(call update_feeds)
	$(call copy_config)
	$(call copy_files)
	$(call copy_packages)
	@touch .checkout

sync:
	$(call copy_files)
	$(call copy_packages)

menuconfig: checkout
	$(call menuconfig_owrt)
        
kernel_menuconfig: checkout
	$(call kmenuconfig_owrt)

clean:
	[ -d "$(BUILD_DIR)" ] && rm -rf $(BUILD_DIR)/* || true
	rm -f .checkout || true

help:
	@cat README
