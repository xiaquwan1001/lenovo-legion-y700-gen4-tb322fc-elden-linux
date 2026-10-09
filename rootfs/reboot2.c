/*
 * reboot2 - reboot into a named mode ("bootloader", "recovery", ...).
 *
 * BusyBox reboot can only do a plain restart, so there is no way from the
 * Alpine bring-up rootfs to hand XBL a reboot reason and land in fastboot.
 *
 * SAFETY: with no argument this does a NORMAL reboot (LINUX_REBOOT_CMD_RESTART),
 * never a mode reboot.  An earlier version defaulted to "bootloader", which
 * silently sent the device to fastboot whenever a bare `reboot2` was used.
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/reboot.h>

int main(int argc, char **argv)
{
	const char *mode = argc > 1 ? argv[1] : NULL;

	if (mode && (!strcmp(mode, "-h") || !strcmp(mode, "--help"))) {
		fprintf(stderr,
			"usage: %s [<mode>]\n"
			"  no argument = normal reboot\n"
			"  modes: bootloader|recovery\n", argv[0]);
		return 2;
	}

	sync();

	/* No argument MUST NOT fall through to fastboot: a bare `reboot2`
	 * used to default to "bootloader" and silently land the device in
	 * fastboot.  Only an explicit mode hands XBL a reason string.
	 */
	if (mode)
		syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
			LINUX_REBOOT_CMD_RESTART2, mode);
	else
		syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
			LINUX_REBOOT_CMD_RESTART, 0);

	perror("reboot");
	return 1;
}
