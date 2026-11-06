#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#define GUNYAH_IOCTL_TYPE 'G'
#define GUNYAH_CREATE_VM _IO(GUNYAH_IOCTL_TYPE, 0x0)
int main(void) {
	int fd = open("/dev/gunyah", O_RDWR);
	if (fd < 0) { printf("open: %s\n", strerror(errno)); return 1; }
	errno = 0;
	int vm = ioctl(fd, GUNYAH_CREATE_VM);
	printf("GUNYAH_CREATE_VM -> %d (errno=%d %s)\n", vm, errno, strerror(errno));
	if (vm >= 0) close(vm);
	close(fd);
	return vm < 0;
}
