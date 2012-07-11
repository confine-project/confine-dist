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

ifdef DEV
OWRT_GIT = gitosis@git.confine-project.eu:confine/openwrt.git
OWRT_PKG_GIT = gitosis@git.confine-project.eu:confine/packages.git
else
OWRT_GIT = http://git.confine-project.eu/confine/openwrt.git
OWRT_PKG_GIT = http://git.confine-project.eu/confine/packages.git
endif

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
KCONFIG = $(BUILD_DIR)/target/linux/x86/config-3.3
IMAGES = images
NIGHTLY_IMAGES_DIR ?= www
IMAGE = openwrt-x86-generic-combined
IMAGE_TYPE ?= squashfs
J ?= 1
V ?= 0
MAKE_SRC = -j$(J) V=$(V)
CONFINE_VERSION ?= testing

define prepare_workspace
	git clone $(OWRT_GIT) "$(BUILD_DIR)"
	git clone $(OWRT_PKG_GIT) "$(OWRT_PKG_DIR)"
	[ ! -d "$(DOWNLOAD_DIR)" ] && mkdir -p "$(DOWNLOAD_DIR)" || true
	rm -f $(BUILD_DIR)/dl || true
	ln -s "`readlink -f $(DOWNLOAD_DIR)`" "$(BUILD_DIR)/dl"
	rm -rf "$(BUILD_DIR)/files" || true
	ln -s "../$(FILES_DIR)" "$(BUILD_DIR)/files"
endef

define update_feeds
	cat $(OWRT_FEEDS) | sed -e "s|PATH|`pwd`/$(PACKAGE_DIR)|" > $(BUILD_DIR)/feeds.conf
	@echo "Updating feed $(1)"
	"$(BUILD_DIR)/$(1)/scripts/feeds" update -a
	"$(BUILD_DIR)/$(1)/scripts/feeds" install -a
endef

define copy_config
	cp -f "$(CONFIG_DIR)/owrt_config" $(CONFIG)
	cp -f "$(CONFIG_DIR)/kernel_config" $(KCONFIG)
	(cd "$(BUILD_DIR)" && make defconfig)
endef

define menuconfig_owrt
	make -C "$(BUILD_DIR)" menuconfig
	mkdir -p "$(MY_CONFIGS)"
	(cd "$(BUILD_DIR)" && scripts/diffconfig.sh) > $(MY_CONFIGS)/owrt_config
	@echo "New OpenWRT configuration file saved on $(MY_CONFIGS)/owrt_config"
endef

define kmenuconfig_owrt
	make -C "$(BUILD_DIR)" kernel_menuconfig
	mkdir -p $(MY_CONFIGS)
	cp -f $(KCONFIG) $(MY_CONFIGS)/kernel_config
	@echo "New Kernel configuration file saved on $(MY_CONFIGS)/kernel_config"
endef

define update_workspace
	git pull origin $(CONFINE_VERSION) && git checkout $(CONFINE_VERSION)
	(cd "$(BUILD_DIR)" && git pull && git checkout $(CONFINE_VERSION))
	(cd "$(OWRT_PKG_DIR)" && git pull && git checkout $(CONFINE_VERSION))
endef

define build_src
	make -C "$(BUILD_DIR)" $(MAKE_SRC)
endef

define post_build
	mkdir -p "$(IMAGES)"
	[ -f "$(BUILD_DIR)/bin/x86/$(IMAGE)-$(IMAGE_TYPE).img.gz" ] && gunzip "$(BUILD_DIR)/bin/x86/$(IMAGE)-$(IMAGE_TYPE).img.gz" || true
	cp -f "$(BUILD_DIR)/bin/x86/$(IMAGE)-$(IMAGE_TYPE).img" "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).img"
	cp -f "$(BUILD_DIR)/bin/x86/$(IMAGE)-ext4.vdi" "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).vdi"
	@echo 
	@echo "CONFINE firmware compiled, you can find output files in $(IMAGES)/ directory"
endef

define nightly_build
	$(eval REV_ID := $(shell git log -n 1 --format=oneline | cut -f1 -d' '))
	$(eval OWRT_REV_ID := $(shell cd $(BUILD_DIR); git log -n 1 --format=oneline | cut -f1 -d' '))
	$(eval PACKAGES_REV_ID := $(shell cd $(OWRT_PKG_DIR); git log -n 1 --format=oneline | cut -f1 -d' '))
	$(eval BUILD_ID := $(REV_ID)-$(OWRT_REV_ID)-$(PACKAGES_REV_ID))

	@echo $(BUILD_ID)
	
	mkdir -p "$(NIGHTLY_IMAGES_DIR)"
	cp -f "$(BUILD_DIR)/bin/x86/$(IMAGE)-$(IMAGE_TYPE).img.gz" "$(NIGHTLY_IMAGES_DIR)/CONFINE-openwrt-$(CONFINE_VERSION)-$(BUILD_ID).img.gz"
	ln -fs  "$(NIGHTLY_IMAGES_DIR)/CONFINE-openwrt-$(CONFINE_VERSION)-$(BUILD_ID).img.gz" "$(NIGHTLY_IMAGES_DIR)/CONFINE-openwrt-$(CONFINE_VERSION)-latest.img.gz"
endef


all: prepare 
	@echo "Using $(IMAGE_TYPE)."
	$(call build_src)
	$(call post_build)

nightly: prepare
	@echo "Using $(IMAGE_TYPE)."
	$(call build_src)
	$(call nightly_build)

target: prepare 
	$(call build_src)
	$(call post_build)

prepare: .prepared 

.prepared:
	@echo "Using $(IMAGE_TYPE)."
	@echo "Developer mode enabled"
	$(call prepare_workspace)
	$(call update_workspace)
	$(call update_feeds)
	$(call copy_config)
	@touch .prepared

sync: prepare 
	$(call update_feeds)
	$(call copy_config)

update: prepare
	$(call update_workspace)

menuconfig: prepare
	$(call menuconfig_owrt)

kernel_menuconfig: prepare
	$(call kmenuconfig_owrt)

clean:
	make -C "$(BUILD_DIR)" clean

dirclean:
	make -C "$(BUILD_DIR)" dirclean

distclean:
	make -C "$(BUILD_DIR)" distclean
	$(call copy_config)

help:
	@cat README
