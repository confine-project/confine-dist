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

TIMESTAMP := $(shell date -u +%Y%m%d-%H%M)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
GIT_HASH := $(shell git rev-parse HEAD)

BUILD_DIR := openwrt
FILES_DIR := files
PACKAGE_DIR := packages
OWRT_FEEDS := feeds.conf.in
MY_CONFIGS := my_configs
DOWNLOAD_DIR := dl

#TARGET values: x86, ar71xx, realview
TARGET ?= x86
SUBTARGET ?= generic
# Some targets (not x86) need a profile.
PROFILE ?=
SPECIFICS ?= i586 #eg i586, i686, ATOM32
PARTSIZE ?= 256
MAXINODE ?= $$(( $(PARTSIZE) * 400 ))
PACKAGES ?= confine-community-lab confine-system confine-recommended
IMAGEBUILDER ?=
CONFIG := $(BUILD_DIR)/.config
KCONF := target/linux/$(TARGET)/config-3.10
KCONFIG := $(BUILD_DIR)/$(KCONF)

IMAGES = images
# This is a build sequence number automatically set by Jenkins.
BUILD_NUMBER ?= unknown
NIGHTLY_IMAGES_DIR ?= www
IMAGE ?= openwrt-$(TARGET)-$(SUBTARGET)-combined
IMAGE_TYPE ?= ext4
J ?= 1
V ?= 0
MAKE_SRC_OPTS = -j$(J) V=$(V)


define prepare_workspace
	git submodule update --init
	[ ! -d "$(DOWNLOAD_DIR)" ] && mkdir -p "$(DOWNLOAD_DIR)" || true
	rm -f $(BUILD_DIR)/dl
	ln -s "`readlink -f $(DOWNLOAD_DIR)`" "$(BUILD_DIR)/dl"
	rm -rf "$(BUILD_DIR)/files"
	mkdir -p $(FILES_DIR)
	ln -s "../$(FILES_DIR)" "$(BUILD_DIR)/files"
endef

define update_feeds
	cat $(OWRT_FEEDS) | sed -e "s|@PACKAGE_DIR@|`pwd`/$(PACKAGE_DIR)|" > $(BUILD_DIR)/feeds.conf
	@echo "Updating feeds"
	"$(BUILD_DIR)/scripts/feeds" update -a
	"$(BUILD_DIR)/scripts/feeds" install -a
endef

define create_configs
	@( echo "reverting $(KCONFIG) for TARGET=$(TARGET)" )
# This command restores OpenWrt's default configuration and adds answers
# to some options to avoid the configuration process asking for them.
	( cd $(BUILD_DIR) && git checkout -- $(KCONF) )
	@( echo "creating $(CONFIG) for SPECIFICS=$(SPECIFICS) TARGET=$(TARGET) SUBTARGET=$(SUBTARGET) PROFILE=$(PROFILE) PARTSIZE=$(PARTSIZE) MAXINODE=$(MAXINODE) PACKAGES=\"$(PACKAGES)\"" )
	@( echo "CONFIG_TARGET_$(TARGET)=y"           > $(CONFIG) )
	@( [ "$(SUBTARGET)" ] && echo "CONFIG_TARGET_$(TARGET)_$(SUBTARGET)=y" >> $(CONFIG) || true )
	@( [ "$(PROFILE)" ]   && echo "CONFIG_TARGET_$(TARGET)_$(SUBTARGET)_$(PROFILE)=y" >> $(CONFIG) || true )

	@( for PACKAGE in ${PACKAGES}; do echo "CONFIG_PACKAGE_$${PACKAGE}=y" >> $(CONFIG); done )
	@( [ -n "$(IMAGEBUILDER)" ] && echo "CONFIG_IB=y" >> $(CONFIG) || true )

        @( ! [ "with gdb" ] && \
                echo "CONFIG_PACKAGE_gdbserver=y"         >> $(CONFIG) && \
                echo "CONFIG_GDB=y"                       >> $(CONFIG) || true )

	@( ! [ "static binaries for confine slivers" ] && \
		echo "CONFIG_BUILD_STATIC_TOOLS=y"                                  >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_STATIC=y"                               >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_FEATURE_SH_STANDALONE=y"                >> $(CONFIG) && \
		echo "# CONFIG_BUSYBOX_CONFIG_ASH is not set"                       >> $(CONFIG) && \
		echo "# CONFIG_BUSYBOX_CONFIG_FEATURE_SH_IS_ASH is not set"         >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_FEATURE_SH_IS_NONE=y"                   >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_ARP=y"                                  >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_IP=y"                                   >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_FEATURE_IP_ADDRESS=y"                   >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_FEATURE_IP_LINK=y"                      >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_FEATURE_IP_ROUTE=y"                     >> $(CONFIG) && \
		echo "# CONFIG_BUSYBOX_CONFIG_FEATURE_IP_TUNNEL is not set"         >> $(CONFIG) && \
		echo "# CONFIG_BUSYBOX_CONFIG_FEATURE_IP_RULE is not set"           >> $(CONFIG) && \
		echo "# CONFIG_BUSYBOX_CONFIG_FEATURE_IP_SHORT_FORMS is not set"    >> $(CONFIG) && \
		echo "# CONFIG_BUSYBOX_CONFIG_FEATURE_IP_RARE_PROTOCOLS is not set" >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_IPCALC=y"                               >> $(CONFIG) && \
		echo "# CONFIG_BUSYBOX_CONFIG_FEATURE_IPCALC_FANCY is not set"      >> $(CONFIG) && \
		echo "CONFIG_BUSYBOX_CONFIG_FEATURE_IPCALC_LONG_OPTIONS=y"          >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_openssh-client=y"                              >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_openssh-sftp-server=y"                         >> $(CONFIG) || true )

	@( \
		echo "CONFIG_X86_USE_GRUB2=y" >> $(CONFIG) && \
		echo "CONFIG_TARGET_KERNEL_PARTSIZE=32" >> $(CONFIG) && \
		echo "CONFIG_TARGET_ROOTFS_PARTSIZE=$(PARTSIZE)" >> $(CONFIG) && \
		echo "CONFIG_TARGET_ROOTFS_MAXINODE=$(MAXINODE)" >> $(CONFIG) && \
		\
		echo "CONFIG_PACKAGE_libiptc=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_libgnutls-openssl=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_libdevmapper=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_libnl=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_libpcre=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_gnutls-utils=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_dmidecode=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_grub=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_certtool=y" >> $(CONFIG) && \
		\
		echo "CONFIG_PACKAGE_bridge=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_dnsmasq-dhcpv6=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_kmod-r6040=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_kmod-sis190=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_kmod-8021q=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_hdparm=y" >> $(CONFIG) && \
		echo "CONFIG_PACKAGE_bash-completion=y" >> $(CONFIG) && \
		true )


#resulting config is here:  /home/vct/confine-dist-bb/openwrt/build_dir/target-i386_i486_uClibc-0.9.33.2/linux-x86_generic/linux-3.10.49/.config

	@( \
	      ( [ "Confine defaults for all Kernel" ] && \
		grep -v "CONFIG_M486"  					$(KCONFIG) >> $(KCONFIG).tmp && mv $(KCONFIG).tmp $(KCONFIG) && \
		echo "# CONFIG_M486 is not set"					>> $(KCONFIG) && \
		grep -v "HIGHMEM"  					$(KCONFIG) >> $(KCONFIG).tmp && mv $(KCONFIG).tmp $(KCONFIG) && \
		echo "CONFIG_HIGHMEM=y"						>> $(KCONFIG) && \
		echo "# CONFIG_NOHIGHMEM is not set"				>> $(KCONFIG) && \
		echo "# CONFIG_HIGHPTE is not set"				>> $(KCONFIG) && \
		true ) )

	@( \
	      ( [ "Confine CPU governor for all Kernel" ] && \
		grep -v "CONFIG_CPU_FREQ"				$(KCONFIG) >> $(KCONFIG).tmp && mv $(KCONFIG).tmp $(KCONFIG) && \
		echo "CONFIG_CPU_FREQ=y"					>> $(KCONFIG) && \
		echo "# CONFIG_CPU_FREQ_DEFAULT_GOV_CONSERVATIVE is not set"	>> $(KCONFIG) && \
		echo "CONFIG_CPU_FREQ_DEFAULT_GOV_ONDEMAND=y"			>> $(KCONFIG) && \
		echo "# CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE is not set"	>> $(KCONFIG) && \
		echo "# CONFIG_CPU_FREQ_DEFAULT_GOV_POWERSAVE is not set"	>> $(KCONFIG) && \
		echo "# CONFIG_CPU_FREQ_DEFAULT_GOV_USERSPACE is not set"	>> $(KCONFIG) && \
		echo "# CONFIG_CPU_FREQ_GOV_CONSERVATIVE is not set"		>> $(KCONFIG) && \
		echo "CONFIG_CPU_FREQ_GOV_ONDEMAND=y"				>> $(KCONFIG) && \
		echo "CONFIG_CPU_FREQ_GOV_PERFORMANCE=y"			>> $(KCONFIG) && \
		echo "# CONFIG_CPU_FREQ_GOV_POWERSAVE is not set"		>> $(KCONFIG) && \
		echo "# CONFIG_CPU_FREQ_GOV_USERSPACE is not set"		>> $(KCONFIG) && \
		echo "CONFIG_CPU_FREQ_STAT=y"					>> $(KCONFIG) && \
		echo "CONFIG_CPU_FREQ_STAT_DETAILS=y"				>> $(KCONFIG) && \
		echo "CONFIG_CPU_FREQ_TABLE=y"					>> $(KCONFIG) && \
		true ) )

	@( \
	      ( echo "$(SPECIFICS)" | grep -q -e "^i686$$" && \
		grep -v "CONFIG_M686 is not set"		$(KCONFIG) >> $(KCONFIG).tmp && mv $(KCONFIG).tmp $(KCONFIG) && \
		echo "CONFIG_M686=y"					>> $(KCONFIG) && \
		echo "CONFIG_HIGHMEM64G=y"				>> $(KCONFIG) && \
		echo "# CONFIG_HIGHMEM4G is not set"			>> $(KCONFIG) && \
		echo "CONFIG_X86_MINIMUM_CPU_FAMILY=5"			>> $(KCONFIG) && \
		echo "CONFIG_X86_PAE=y"					>> $(KCONFIG) && \
		true ) \
|| \
	      ( echo "$(SPECIFICS)" | grep -q -e "^ATOM32$$" && \
		grep -v "CONFIG_MATOM is not set"		$(KCONFIG) >> $(KCONFIG).tmp && mv $(KCONFIG).tmp $(KCONFIG) && \
		echo "CONFIG_MATOM=y"					>> $(KCONFIG) && \
		echo "CONFIG_HIGHMEM64G=y"				>> $(KCONFIG) && \
		echo "# CONFIG_HIGHMEM4G is not set"			>> $(KCONFIG) && \
		echo "CONFIG_X86_MINIMUM_CPU_FAMILY=5"			>> $(KCONFIG) && \
		echo "CONFIG_X86_PAE=y"					>> $(KCONFIG) && \
		grep -v "CONFIG_NR_CPUS"  			$(KCONFIG) >> $(KCONFIG).tmp && mv $(KCONFIG).tmp $(KCONFIG) && \
		echo "CONFIG_NR_CPUS=2"					>> $(KCONFIG) && \
		echo "CONFIG_SMP=y" 					>> $(KCONFIG) && \
		echo "CONFIG_SCHED_SMT=y" 				>> $(KCONFIG) && \
		echo "# CONFIG_X86_BIGSMP is not set"			>> $(KCONFIG) && \
		echo "CONFIG_ARCH_DMA_ADDR_T_64BIT=y" 			>> $(KCONFIG) && \
		echo "CONFIG_ARCH_ENABLE_MEMORY_HOTPLUG=y"		>> $(KCONFIG) && \
		echo "CONFIG_ARCH_PHYS_ADDR_T_64BIT=y"			>> $(KCONFIG) && \
		echo "CONFIG_CPU_RMAP=y"				>> $(KCONFIG) && \
		echo "CONFIG_GENERIC_PENDING_IRQ=y"			>> $(KCONFIG) && \
		echo "CONFIG_MUTEX_SPIN_ON_OWNER=y"			>> $(KCONFIG) && \
		echo "CONFIG_PHYS_ADDR_T_64BIT=y"			>> $(KCONFIG) && \
		echo "CONFIG_RCU_STALL_COMMON=y"			>> $(KCONFIG) && \
		echo "CONFIG_RFS_ACCEL=y"				>> $(KCONFIG) && \
		echo "CONFIG_RPS=y"					>> $(KCONFIG) && \
		echo "CONFIG_SCHED_HRTICK=y"				>> $(KCONFIG) && \
		echo "CONFIG_SCHED_SMT=y"				>> $(KCONFIG) && \
		echo "CONFIG_STOP_MACHINE=y"				>> $(KCONFIG) && \
		echo "CONFIG_TREE_RCU=y"				>> $(KCONFIG) && \
		echo "CONFIG_USE_GENERIC_SMP_HELPERS=y"			>> $(KCONFIG) && \
		echo "CONFIG_X86_32_SMP=y"				>> $(KCONFIG) && \
		echo "CONFIG_X86_CMPXCHG64=y"				>> $(KCONFIG) && \
		echo "CONFIG_X86_HT=y"					>> $(KCONFIG) && \
		echo "CONFIG_XPS=y"					>> $(KCONFIG) && \
		true ) \
|| \
	      ( [ "Default (i586), works always" ] && \
		grep -v "CONFIG_M586 is not set"		$(KCONFIG) >> $(KCONFIG).tmp && mv $(KCONFIG).tmp $(KCONFIG) && \
		echo "CONFIG_M586=y"					>> $(KCONFIG) && \
		echo "CONFIG_HIGHMEM4G=y"				>> $(KCONFIG) && \
		echo "# CONFIG_HIGHMEM64G is not set"			>> $(KCONFIG) && \
		true ) \
)



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

define set_version
# Never change the order of these values (processed by confine node system)!!!
	mkdir -p $(FILES_DIR)/etc
	: > $(FILES_DIR)/etc/confine.version
	echo "$(TIMESTAMP)" >> $(FILES_DIR)/etc/confine.version
	echo "$(GIT_BRANCH)" >> $(FILES_DIR)/etc/confine.version
	echo "$(GIT_HASH)" >> $(FILES_DIR)/etc/confine.version
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
	cp -f $(FILES_DIR)/etc/confine.version "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).version"
	[ -n "$(IMAGEBUILDER)" ] && cp -f $(BUILD_DIR)/bin/$(TARGET)/OpenWrt-ImageBuilder-$(TARGET)*.tar.bz2 $(IMAGES)/CONFINE-ImageBuilder-$(TIMESTAMP).tar.bz2 || true
	cat "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).img.gz"|md5sum|sed -e "s/\ \ -//" >> "$(IMAGES)/CONFINE-owrt-$(TIMESTAMP).version"

	ln -fs "CONFINE-owrt-$(TIMESTAMP).version" "$(IMAGES)/CONFINE-owrt-current.version"
	ln -fs "CONFINE-owrt-$(TIMESTAMP).img.gz" "$(IMAGES)/CONFINE-owrt-current.img.gz"
	@echo
	@echo "CONFINE firmware compiled, you can find output files in $(IMAGES)/ directory"
endef

define nightly_build
	$(eval REV_ID := $(shell git log -n 1 --format=format:%h))
	$(eval OWRT_REV_ID := $(shell cd $(BUILD_DIR); git log -n 1 --format=format:%h))
	$(eval PACKAGES_REV_ID := $(shell cd $(BUILD_DIR)/feeds/packages; git log -n 1 --format=format:%h))

	$(eval BUILD_ID := $(BUILD_NUMBER)-$(REV_ID)-$(OWRT_REV_ID)-$(PACKAGES_REV_ID))

	@echo $(BUILD_ID)

	$(eval CONFINE_VERSION := $(shell git branch | grep ^* | cut -d " " -f 2))

	mkdir -p "$(NIGHTLY_IMAGES_DIR)"
	cp -f "$(BUILD_DIR)/bin/$(TARGET)/$(IMAGE)-$(IMAGE_TYPE).img.gz" "$(NIGHTLY_IMAGES_DIR)/CONFINE-openwrt-$(CONFINE_VERSION)-$(BUILD_ID).img.gz"
	ln -fs  "$(NIGHTLY_IMAGES_DIR)/CONFINE-openwrt-$(CONFINE_VERSION)-$(BUILD_ID).img.gz" "$(NIGHTLY_IMAGES_DIR)/CONFINE-openwrt-$(CONFINE_VERSION)-latest.img.gz"
endef


all: target

target: prepare
	$(call set_version)
	$(call build_src)
	$(call post_build)

nightly: prepare
	$(call set_version)
	$(call build_src)
	$(call nightly_build)

prepare: .prepared

.prepared:
	@echo "Using $(IMAGE_TYPE)."
	$(call prepare_workspace)
	$(call update_feeds)
	$(call create_configs)
	@touch .prepared

sync: prepare
	$(call update_feeds)
	$(call create_configs)


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
	rm -f .prepared
	rm -rf "$(DOWNLOAD_DIR)"
	git submodule foreach 'find . -mindepth 1 -maxdepth 1 | xargs rm -rf'


help:
	@cat README
