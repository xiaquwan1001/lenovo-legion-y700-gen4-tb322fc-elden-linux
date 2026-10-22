// Diagnostic: map the DSI controller MMIO window from userspace and dump the
// registers that Q28 hinges on (STATUS0, INTR_CTRL, TRIG_DMA, CTRL, ...).
// Diagnostic only; never ship.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

int main(int argc, char **argv)
{
	unsigned long base = 0, off;
	void *p;
	int fd, i;
	off_t phys;

	if (argc < 3) {
		fprintf(stderr, "usage: %s <dsi_phys_base> <off> [off...]\n", argv[0]);
		return 2;
	}
	base = strtoul(argv[1], NULL, 0);
	fd = open("/dev/mem", O_RDONLY | O_SYNC);
	if (fd < 0) { perror("open /dev/mem"); return 1; }
	p = mmap(NULL, 0x40000, PROT_READ, MAP_SHARED, fd, (off_t)base);
	if (p == MAP_FAILED) { perror("mmap"); return 1; }

	printf("base=0x%lx\n", base);
	for (i = 2; i < argc; i++) {
		off = strtoul(argv[i], NULL, 0);
		printf("  [0x%05lx] = 0x%08x\n", off,
		       *(volatile unsigned int *)((char *)p + off));
	}
	return 0;
}
