# SPDX-License-Identifier: GPL-2.0-only
# Out-of-tree build for the gunyah kvcalloc-fix module.
#
#   make KDIR=/path/to/configured/kernel/build          # build
#   make KDIR=/path/to/configured/kernel/build modules_install
#   make clean
#
# KDIR must point at a kernel that has been configured and prepared
# (defconfig && modules_prepare) and whose CONFIG/struct gh_vm layout matches
# the running kernel. Defaults to this kernel tree.

KDIR ?= /home/qiuqiu/kernel/kernel_platform/common

obj-m += gunyah_kvcalloc_mod.o

# Pull in the private gunyah driver header (struct gh_vm / gh_vm_mem).
ccflags-y += -I$(KDIR)/drivers/virt/gunyah

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

modules_install:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules_install

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
