/*
 * reboot2 - reboot into a named mode ("bootloader", "recovery", ...).
 *
 * BusyBox reboot can only do a plain restart, so there is no way from the
 * Alpine bring-up rootfs to hand XBL a reboot reason and land in fastboot.
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/reboot.h>

int main(int argc, char **argv)
{
	const char *mode = argc > 1 ? argv[1] : "bootloader";

	sync();

	if (!strcmp(mode, "-h") || !strcmp(mode, "--help")) {
		fprintf(stderr, "usage: %s [bootloader|recovery|<mode>]\n", argv[0]);
		return 2;
	}

	syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
		LINUX_REBOOT_CMD_RESTART2, mode);

	perror("reboot");
	return 1;
}
