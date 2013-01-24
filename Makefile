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

ifdef DEV
OWRT_GIT ?= gitosis@git.confine-project.eu:confine/openwrt.git
OWRT_PKG_GIT ?= gitosis@git.confine-project.eu:confine/packages.git
else
OWRT_GIT ?= http://git.confine-project.eu/confine/openwrt.git
OWRT_PKG_GIT ?= http://git.confine-project.eu/confine/packages.git
endif

TIMESTAMP = $(shell date -u +%Y%m%d%H%M)
BUILD_DIR = openwrt
FILES_DIR = files
PACKAGE_DIR = packages
OWRT_PKG_DIR = $(PACKAGE_DIR)/openwrt
OWRT_FEEDS = feeds.conf.in
MY_CONFIGS = my_configs
DOWNLOAD_DIR = dl

#TARGET values: x86, ar71xx, realview
TARGET ?= x86
SUBTARGET ?= generic
PROFILE ?=
PARTSIZE ?= 900
MAXINODE ?= $$(( $(PARTSIZE) * 100 ))
PACKAGES ?= confine-system confine-recommended

CONFIG = $(BUILD_DIR)/.config
KCONF = target/linux/$(TARGET)/config-3.3
KCONFIG = $(BUILD_DIR)/$(KCONF)


IMAGES = images
NIGHTLY_IMAGES_DIR ?= www
IMAGE ?= openwrt-$(TARGET)-$(SUBTARGET)-combined
IMAGE_TYPE ?= ext4
J ?= 1
V ?= 0
MAKE_SRC_OPTS = -j$(J) V=$(V)
CONFINE_VERSION ?= testing

define prepare_workspace
	git clone $(OWRT_GIT) "$(BUILD_DIR)"
	cd $(BUILD_DIR) && git checkout $(CONFINE_VERSION)
	git clone $(OWRT_PKG_GIT) "$(OWRT_PKG_DIR)"
	cd $(OWRT_PKG_DIR) && git checkout $(CONFINE_VERSION)
	[ ! -d "$(DOWNLOAD_DIR)" ] && mkdir -p "$(DOWNLOAD_DIR)" || true
	rm -f $(BUILD_DIR)/dl
	ln -s "`readlink -f $(DOWNLOAD_DIR)`" "$(BUILD_DIR)/dl"
	rm -rf "$(BUILD_DIR)/files"
	ln -s "../$(FILES_DIR)" "$(BUILD_DIR)/files"
endef

define update_feeds
	cat $(OWRT_FEEDS) | sed -e "s|@PACKAGE_DIR@|`pwd`/$(PACKAGE_DIR)|" > $(BUILD_DIR)/feeds.conf
	@echo "Updating feed $(1)"
	"$(BUILD_DIR)/$(1)/scripts/feeds" update -a
	"$(BUILD_DIR)/$(1)/scripts/feeds" install -a
endef

define create_configs
	@( echo "reverting $(KCONFIG) for TARGET=$(TARGET)" )
	( cd $(BUILD_DIR) && git checkout -- $(KCONF) && \
		echo "# CONFIG_MSI_LAPTOP is not set"     >> $(KCONF) && \
		echo "# CONFIG_COMPAL_LAPTOP is not set"  >> $(KCONF) && \
		echo "# CONFIG_SAMSUNG_LAPTOP is not set" >> $(KCONF) && \
		echo "# CONFIG_INTEL_OAKTRAIL is not set" >> $(KCONF) )
	@( echo "creating $(CONFIG) for TARGET=$(TARGET) SUBTARGET=$(SUBTARGET) PROFILE=$(PROFILE) PARTSIZE=$(PARTSIZE) MAXINODE=$(MAXINODE) PACKAGES=\"$(PACKAGES)\"" )
	@( echo "$(TARGET)" | grep -q -e "^x86$$" -e "^ar71xx$$" -e "^realview$$" && \
		echo "CONFIG_TARGET_$(TARGET)=y"           > $(CONFIG) && \
		echo "CONFIG_KERNEL_CGROUPS=y"            >> $(CONFIG) && \
		echo "CONFIG_KERNEL_NAMESPACES=y"         >> $(CONFIG) )
	@( [ "$(SUBTARGET)" ] && \
		echo "CONFIG_TARGET_$(TARGET)_$(SUBTARGET)=y" >> $(CONFIG) || true )
	@( [ "$(PROFILE)" ] && \
		echo "CONFIG_TARGET_$(TARGET)_$(SUBTARGET)_$(PROFILE)=y" >> $(CONFIG) || true )
	@( [ "$(PARTSIZE)" ] && \
		echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$(PARTSIZE)" >> $(CONFIG) && \
		echo "CONFIG_TARGET_ROOTFS_MAXINODE=$(MAXINODE)" >> $(CONFIG) || true )
	@( for PACKAGE in ${PACKAGES}; do echo "CONFIG_PACKAGE_$${PACKAGE}=y" >> $(CONFIG); done )
	@( echo "created $(CONFIG) before calling defconfig:" && cat $(CONFIG) )
	@make -C "$(BUILD_DIR)" defconfig > /dev/null
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
	[ -f $(KCONFIG) ] && cp -f $(KCONFIG) $(MY_CONFIGS)/kernel_config
	@echo "New Kernel configuration file saved on $(MY_CONFIGS)/kernel_config"
endef

define update_workspace
	git checkout $(CONFINE_VERSION) && git pull origin $(CONFINE_VERSION)
	(cd "$(BUILD_DIR)" git checkout $(CONFINE_VERSION) && git pull )
	(cd "$(OWRT_PKG_DIR)" && git checkout $(CONFINE_VERSION) && git pull )
endef

define build_src
	make -C "$(BUILD_DIR)" $(MAKE_SRC_OPTS)
endef


define post_build
	mkdir -p "$(IMAGES)"
#	[ -f "$(BUILD_DIR)/bin/$(TARGET)/$(IMAGE)-$(IMAGE_TYPE).img.gz" ] && gunzip "$(BUILD_DIR)/bin/$(TARGET)/$(IMAGE)-$(IMAGE_TYPE).img.gz" || true
#	cp -f "$(BUILD_DIR)/bin/$(TARGET)/$(IMAGE)-$(IMAGE_TYPE).img" "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).img"
#	cp -f "$(BUILD_DIR)/bin/$(TARGET)/$(IMAGE)-ext4.vdi" "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).vdi"
	cp -f "$(BUILD_DIR)/bin/$(TARGET)/$(IMAGE)-$(IMAGE_TYPE).img.gz" "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).img.gz"
	ln -fs "CONFINE-owrt-$(TIMESTAMP).img.gz" "$(IMAGES)/CONFINE-owrt-current.img.gz"
	@echo 
	@echo "CONFINE firmware compiled, you can find output files in $(IMAGES)/ directory"
endef

define nightly_build
	$(eval REV_ID := $(shell git log -n 1 --format=format:%h))
	$(eval OWRT_REV_ID := $(shell cd $(BUILD_DIR); git log -n 1 --format=format:%h))
	$(eval PACKAGES_REV_ID := $(shell cd $(OWRT_PKG_DIR); git log -n 1 --format=format:%h))

	$(eval BUILD_ID := $(BUILD_NUMBER)-$(REV_ID)-$(OWRT_REV_ID)-$(PACKAGES_REV_ID))

	@echo $(BUILD_ID)

	mkdir -p "$(NIGHTLY_IMAGES_DIR)"
	cp -f "$(BUILD_DIR)/bin/$(TARGET)/$(IMAGE)-$(IMAGE_TYPE).img.gz" "$(NIGHTLY_IMAGES_DIR)/CONFINE-openwrt-$(CONFINE_VERSION)-$(BUILD_ID).img.gz"
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
	$(call prepare_workspace)
	$(call update_workspace)
	$(call update_feeds)
	$(call create_configs)
	@touch .prepared

sync: prepare 
	$(call update_feeds)
	$(call create_configs)

update: prepare
	$(call update_workspace)

menuconfig: prepare
	$(call menuconfig_owrt)

kernel_menuconfig: prepare
	$(call kmenuconfig_owrt)

confclean: prepare
	$(call create_configs)


clean:
	make -C "$(BUILD_DIR)" clean

dirclean:
	make -C "$(BUILD_DIR)" dirclean

distclean:
	make -C "$(BUILD_DIR)" distclean
	$(call create_configs)

mrproper:
	rm -rf "$(BUILD_DIR)"
	rm -rf "$(OWRT_PKG_DIR)"
	rm -rf "$(DOWNLOAD_DIR)"
	rm -f .prepared

help:
	@cat README
