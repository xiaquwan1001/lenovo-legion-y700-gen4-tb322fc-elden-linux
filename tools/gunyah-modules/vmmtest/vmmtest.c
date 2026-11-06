/* vmmtest — minimal Gunyah guest VM harness (userspace, no QEMU/crosvm).
 *
 * Chain: CREATE_VM -> register user memory region -> SET_DTB_CONFIG -> VM_START
 *        -> ADD_FUNCTION(VCPU 0) -> SET_BOOT_CONTEXT(PC/X0/SP) -> VCPU_RUN loop.
 * Guest payload (stub.bin) writes a magic then faults on an unmapped physical
 * address, so we can prove guest execution from the host side.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

#define GUNYAH_IOCTL_TYPE 'G'
#define GUNYAH_CREATE_VM		_IO(GUNYAH_IOCTL_TYPE, 0x0)
#define GH_VM_SET_USER_MEM_REGION	_IOW(GUNYAH_IOCTL_TYPE, 0x1, struct gh_mem_region)
#define GUNYAH_VM_SET_DTB_CONFIG	_IOW(GUNYAH_IOCTL_TYPE, 0x2, struct gh_dtb_config)
#define GUNYAH_VM_START			_IO(GUNYAH_IOCTL_TYPE, 0x3)
#define GUNYAH_VM_ADD_FUNCTION		_IOW(GUNYAH_IOCTL_TYPE, 0x4, struct gh_fn_desc)
#define GUNYAH_VM_SET_BOOT_CONTEXT	_IOW(GUNYAH_IOCTL_TYPE, 0xa, struct gh_boot_ctx)
#define GUNYAH_VCPU_RUN			_IO(GUNYAH_IOCTL_TYPE, 0x5)
#define GH_ANDROID_IOCTL_TYPE 'A'
#define GH_VM_ANDROID_LEND_USER_MEM	_IOW(GH_ANDROID_IOCTL_TYPE, 0x11, struct gh_mem_region)
#define GH_VM_ANDROID_SET_FW_CONFIG	_IOW(GH_ANDROID_IOCTL_TYPE, 0x12, struct gh_dtb_config)

struct gh_mem_region {
	uint32_t label;
	uint32_t flags;
	uint64_t guest_phys_addr;
	uint64_t memory_size;
	uint64_t userspace_addr;
};
struct gh_dtb_config {
	uint64_t guest_phys_addr;
	uint64_t size;
};
struct gh_fn_desc {
	uint32_t type;
	uint32_t arg_size;
	uint64_t arg;
};
struct gh_boot_ctx {
	uint32_t reg;
	uint32_t reserved;
	uint64_t value;
};
struct gh_vcpu_run {
	uint8_t immediate_exit;
	uint8_t padding[7];
	uint32_t exit_reason;
	union {
		struct {
			uint64_t phys_addr;
			uint8_t data[8];
			uint32_t len;
			uint8_t is_write;
			uint8_t resume_action;
		} mmio;
		struct {
			struct {
				uint16_t type;
				uint16_t padding;
				uint32_t reason_size;
				uint8_t reason[8];
			} exit_info;
			uint32_t status;
		} status;
		struct {
			uint64_t phys_addr;
			int64_t attempt;
			uint8_t resume_action;
		} page_fault;
	};
};

#define GUNYAH_FN_VCPU 1
#define GUNYAH_MEM_ALLOW_RWX 0x7
#define REG_SET_X   0
#define REG_SET_PC  1
#define REG_SET_SP  2
#define BOOT_REG(reg, idx) ((((reg) & 0xff) << 8) | ((idx) & 0xff))

static void die(const char *what)
{
	fprintf(stderr, "%s: %s\n", what, strerror(errno));
	exit(1);
}

int main(int argc, char **argv)
{
	const uint64_t gpa = 0x80000000ULL;
	const size_t sz = getenv("RAMSZ") ? strtoull(getenv("RAMSZ"), NULL, 0) : 0x800000ULL;
	const size_t dtb_off = getenv("DTBOFF") ? strtoull(getenv("DTBOFF"), NULL, 0) : 0x1000;
	const size_t stack_off = sz - 0x1000;
	uint8_t *ram;
	uint8_t stub[4096], dtb[4096];
	size_t stub_len = 0, dtb_len = 0;
	int dev, vm, vcpu, early_vcpu = -1;
	struct gh_mem_region reg = { 0 };
	struct gh_dtb_config dtbc;
	struct gh_fn_desc fn = { 0 };
	struct gh_boot_ctx ctx = { 0 };
	struct gh_vcpu_run *run;

	/* payloads: stub.bin / guest.dtb next to this binary (or via argv) */
	const char *stub_path = argc > 1 ? argv[1] : "./stub.bin";
	const char *dtb_path = argc > 2 ? argv[2] : "./guest.dtb";

	FILE *f = fopen(stub_path, "rb");
	if (!f) die(stub_path);
	stub_len = fread(stub, 1, sizeof(stub), f);
	fclose(f);
	f = fopen(dtb_path, "rb");
	if (!f) die(dtb_path);
	dtb_len = fread(dtb, 1, sizeof(dtb), f);
	fclose(f);
	printf("payload: stub %zu B, dtb %zu B\n", stub_len, dtb_len);

	dev = open("/dev/gunyah", O_RDWR);
	if (dev < 0) die("open /dev/gunyah");
	vm = ioctl(dev, GUNYAH_CREATE_VM, 0);
	if (vm < 0) die("GUNYAH_CREATE_VM");
	printf("vm fd = %d\n", vm);

	ram = mmap(NULL, sz, PROT_READ | PROT_WRITE,
		   MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE, -1, 0);
	if (ram == MAP_FAILED) die("mmap ram");
	memset(ram, 0, sz);

	if (getenv("IMAGE")) {
		/* H2: real guest kernel Image at base-address. */
		FILE *fi = fopen(getenv("IMAGE"), "rb");
		size_t n = 0, r;
		if (!fi) die(getenv("IMAGE"));
		while ((r = fread(ram + n, 1, sz - n, fi)) > 0) n += r;
		fclose(fi);
		printf("kernel Image: loaded %zu B at gpa+0\n", n);
	} else if (getenv("IMGHDR")) {
		/* H1: fake 64-byte ARM64 Image header at base, stub at +0x100. */
		uint64_t magic = 0x644d5241ULL;
		memcpy(ram + 0x38, &magic, 8);
		/* code0: branch forward to 0x1000+ (b .+0x1000) */
		uint32_t code0 = 0x14000400;
		uint64_t image_size = 0x800000ULL, flags = 0xA;
		memcpy(ram + 0x00, &code0, 4);
		memcpy(ram + 0x08, &image_size, 8);	/* text_offset=0 stays 0 */
		memcpy(ram + 0x10, &image_size, 8);
		memcpy(ram + 0x18, &flags, 8);
		memcpy(ram + 0x100, stub, stub_len);
		printf("fake Image header written, stub at gpa+0x100\n");
	} else {
		memcpy(ram, stub, stub_len);
	}
	memcpy(ram + dtb_off, dtb, dtb_len);

	if (!getenv("PVM2")) {
		reg.label = 1;
		reg.flags = GUNYAH_MEM_ALLOW_RWX;
		reg.guest_phys_addr = gpa;
		reg.memory_size = sz;
		reg.userspace_addr = (uint64_t)(uintptr_t)ram;
		if (ioctl(vm, GH_VM_SET_USER_MEM_REGION, &reg) < 0) die("SET_USER_MEM_REGION");
		printf("mem region: gpa %#llx size %#zx\n", (unsigned long long)gpa, sz);
	}

	dtbc.guest_phys_addr = gpa + dtb_off;
	dtbc.size = 0x1000;
	if (ioctl(vm, GUNYAH_VM_SET_DTB_CONFIG, &dtbc) < 0) die("SET_DTB_CONFIG");
	printf("dtb config: gpa %#llx size %#llx\n",
	       (unsigned long long)dtbc.guest_phys_addr, (unsigned long long)dtbc.size);

	if (getenv("PVM2")) {
		/* pVM mode: LEND guest RAM, LEND a separate fw region filled with
		 * the real pvmfw image, SET_FW_CONFIG, then VM_START. */
		const char *fw_path = getenv("PVMFW");
		size_t fw_sz = getenv("FWSZ") ? strtoull(getenv("FWSZ"), NULL, 0) : 0x100000;
		/* FWABOVE: default fw region sits right past RAM (our earlier shape).
		 * FWSTART=<addr> puts it where crosvm puts it: AARCH64_PROTECTED_VM_FW_START
		 * == AARCH64_PHYS_MEM_START - AARCH64_PROTECTED_VM_FW_MAX_SIZE == 0x7fc00000,
		 * i.e. BELOW the RAM base and outside the [base-address, size-max) layout. */
		const uint64_t fw_gpa = getenv("FWSTART") ? strtoull(getenv("FWSTART"), NULL, 0)
					: gpa + ((sz + 0x1fffffULL) & ~0x1fffffULL);
		uint8_t *fwm;
		int lend_ioctl = getenv("NOLEND") ? GH_VM_SET_USER_MEM_REGION
						 : GH_VM_ANDROID_LEND_USER_MEM;
		/* FWSHARE: fw region via SHARE, RAM still LEND. */
		int fw_ioctl = getenv("FWSHARE") ? GH_VM_SET_USER_MEM_REGION : lend_ioctl;

		fwm = mmap(NULL, fw_sz, PROT_READ | PROT_WRITE,
			   MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE, -1, 0);
		if (fwm == MAP_FAILED) die("mmap fw");
		memset(fwm, 0, fw_sz);
		if (fw_path && !getenv("FWZERO")) {
			FILE *ff = fopen(fw_path, "rb");
			size_t n;
			if (!ff) die(fw_path);
			n = fread(fwm, 1, fw_sz, ff);
			fclose(ff);
			printf("pvmfw: loaded %zu B into fw region\n", n);
		} else {
			printf("pvmfw: zero-filled fw region\n");
		}

		uint8_t *dtbseg = NULL;
		if (getenv("DTBSEP")) {
			/* Register a standalone page for the DTB, OUTSIDE the RAM range, so it
			 * is not simultaneously a demand-paged LEND binding (the driver puts
			 * RANGE_ID_IMAGE on the DTB parcel; overlap is a candidate root cause). */
			const uint64_t dtb_gpa = getenv("DTBGPA") ? strtoull(getenv("DTBGPA"), NULL, 0) : 0x90000000ULL;
			dtbseg = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE,
				      MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE, -1, 0);
			if (dtbseg == MAP_FAILED) die("mmap dtbseg");
			memcpy(dtbseg, dtb, dtb_len);
			reg.label = 3;
			reg.flags = GUNYAH_MEM_ALLOW_RWX;
			reg.guest_phys_addr = dtb_gpa;
			reg.memory_size = 0x1000;
			reg.userspace_addr = (uint64_t)(uintptr_t)dtbseg;
			if (ioctl(vm, lend_ioctl, &reg) < 0) die("LEND/SHARE dtb region");
			dtbc.guest_phys_addr = dtb_gpa;
			dtbc.size = 0x1000;
			if (ioctl(vm, GUNYAH_VM_SET_DTB_CONFIG, &dtbc) < 0) die("SET_DTB_CONFIG(dtbsep)");
			printf("DTBSEP: dtb registered standalone at %#llx\n", (unsigned long long)dtb_gpa);
		}
		reg.label = 1;
		reg.flags = GUNYAH_MEM_ALLOW_RWX;
		reg.guest_phys_addr = gpa;
		reg.memory_size = sz;
		reg.userspace_addr = (uint64_t)(uintptr_t)ram;
		if (ioctl(vm, lend_ioctl, &reg) < 0) die("LEND/SHARE guest RAM");
		printf("guest RAM registered (ioctl 0x%04x): gpa %#llx size %#zx\n",
		       lend_ioctl & 0xffff, (unsigned long long)gpa, sz);

		if (getenv("NOFWREG")) {
			printf("NOFWREG: no firmware region registered (crosvm --protected-vm-without-firmware shape)\n");
			goto after_fw;
		}
		reg.label = 2;
		reg.guest_phys_addr = fw_gpa;
		reg.memory_size = fw_sz;
		reg.userspace_addr = (uint64_t)(uintptr_t)fwm;
		if (ioctl(vm, fw_ioctl, &reg) < 0) die("LEND/SHARE fw region");
		printf("fw region ioctl 0x%04x\n", fw_ioctl & 0xffff);
		printf("fw region registered: gpa %#llx size %#zx\n",
		       (unsigned long long)fw_gpa, fw_sz);

		{
			struct gh_dtb_config fw = { .guest_phys_addr = fw_gpa, .size = fw_sz };
			if (!getenv("NOFWCFG")) {
			if (ioctl(vm, GH_VM_ANDROID_SET_FW_CONFIG, &fw) < 0) {
				int e = errno;
				fprintf(stderr, "SET_FW_CONFIG failed: %s (errno %d)\n",
					strerror(e), e);
				return 1;
			}
			printf("fw config: gpa %#llx size %#zx (pVM2 auth)\n",
			       (unsigned long long)fw.guest_phys_addr, fw_sz);
			} else
				printf("NOFWCFG: skipping SET_FW_CONFIG\n");
		}
	} else if (getenv("PVM")) {
		struct gh_dtb_config fw = { .guest_phys_addr = gpa + 0x2000, .size = 0x1000 };
		/* fake pvmfw payload: hypervisor will reject content, but we learn whether
		 * the pVM auth path gets further than the plain path (IRQ_INUSE). */
		if (ioctl(vm, GH_VM_ANDROID_SET_FW_CONFIG, &fw) < 0)
			die("SET_FW_CONFIG");
		printf("fw config: gpa %#llx size %#llx (pVM auth)\n",
		       (unsigned long long)fw.guest_phys_addr, (unsigned long long)fw.size);
	}
after_fw:
	if (getenv("EARLY_VCPU")) {
		/* crosvm creates the vCPU (GH_VM_ADD_FUNCTION before GH_VM_START). */
		uint32_t eid = 0;
		fn.type = GUNYAH_FN_VCPU;
		fn.arg_size = sizeof(eid);
		fn.arg = (uint64_t)(uintptr_t)&eid;
		early_vcpu = ioctl(vm, GUNYAH_VM_ADD_FUNCTION, &fn);
		printf("EARLY_VCPU: ADD_FUNCTION(VCPU 0) -> %d%s\n", early_vcpu,
		       early_vcpu < 0 ? strerror(errno) : "");
	}
	if (ioctl(vm, GUNYAH_VM_START) < 0) die("VM_START");
	printf("VM_START ok\n");

	if (early_vcpu >= 0)
		vcpu = early_vcpu;
	else {
	fn.type = GUNYAH_FN_VCPU;
	{
		uint32_t id = 0;
		fn.arg_size = sizeof(id);
		fn.arg = (uint64_t)(uintptr_t)&id;
		vcpu = ioctl(vm, GUNYAH_VM_ADD_FUNCTION, &fn);
	}
	}
	if (vcpu < 0) die("ADD_FUNCTION(VCPU 0)");
	printf("vcpu fd = %d\n", vcpu);

	ctx.reg = BOOT_REG(REG_SET_PC, 0);
	ctx.value = gpa;
	if (ioctl(vm, GUNYAH_VM_SET_BOOT_CONTEXT, &ctx) < 0) die("BOOT_CONTEXT(PC)");
	ctx.reg = BOOT_REG(REG_SET_X, 0);	/* x0 = DTB */
	ctx.value = gpa + dtb_off;
	if (ioctl(vm, GUNYAH_VM_SET_BOOT_CONTEXT, &ctx) < 0) die("BOOT_CONTEXT(X0)");
	ctx.reg = BOOT_REG(REG_SET_SP, 0);
	ctx.value = gpa + stack_off;
	if (ioctl(vm, GUNYAH_VM_SET_BOOT_CONTEXT, &ctx) < 0) die("BOOT_CONTEXT(SP)");

	run = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, vcpu, 0);
	if (run == MAP_FAILED) die("mmap vcpu_run");

	printf("VCPU_RUN...\n");
	if (ioctl(vcpu, GUNYAH_VCPU_RUN, 0) < 0) die("VCPU_RUN");

	printf("exit_reason = %u\n", run->exit_reason);
	switch (run->exit_reason) {
	case 1: /* MMIO */
		printf("  MMIO phys=%#llx len=%u write=%u data=%02x%02x\n",
		       (unsigned long long)run->mmio.phys_addr, run->mmio.len,
		       run->mmio.is_write, run->mmio.data[0], run->mmio.data[1]);
		break;
	case 2: /* STATUS */
		printf("  STATUS status=%u exit_type=%u reason_size=%u reason=%02x%02x%02x%02x\n",
		       run->status.status, run->status.exit_info.type,
		       run->status.exit_info.reason_size,
		       run->status.exit_info.reason[0], run->status.exit_info.reason[1],
		       run->status.exit_info.reason[2], run->status.exit_info.reason[3]);
		break;
	case 3: /* PAGE_FAULT */
		printf("  PAGE_FAULT phys=%#llx attempt=%lld\n",
		       (unsigned long long)run->page_fault.phys_addr,
		       (long long)run->page_fault.attempt);
		break;
	}
	printf("guest magic at gpa+0: %02x%02x%02x%02x%02x%02x%02x%02x\n",
	       ram[0], ram[1], ram[2], ram[3], ram[4], ram[5], ram[6], ram[7]);
	return 0;
}
