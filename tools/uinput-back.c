/* uinput-back — 只广告 KEY_BACK 的短生命周期虚拟键盘，发一次 press+release 即销毁。
 *
 * 用途（D13 边缘侧滑返回 PoC，路线①）：
 *   lisgd 读触摸屏 evdev 判边缘滑动 → 调本工具 → KEY_BACK 命中 phoc 既有
 *   org.gnome.desktop.wm.keybindings close（XF86Back）。
 *
 * 关键约束（phoc 0.46 src/input-device.c:304-341 的 is_keyboard 判据）：
 *   只广告 KEY_BACK，不广告 KEY_A/KEY_ENTER/KEY_SPACE —— 否则会被当成硬件键盘，
 *   phoc 打 KEYBOARD 能力，phosh-osk-stub 压掉 OSK。也不设 INPUT_PROP_DIRECT、
 *   不广告 EV_REL（不装成鼠标/触摸屏）。
 *
 * 用法:
 *   uinput-back                 发一次 KEY_BACK press+release 后退出
 *   uinput-back --repeat N      发 N 次（默认 1），每次间隔 --delay-ms（默认 100）
 *   uinput-back --delay-ms MS   两次按键之间的间隔（也是 UI_DEV_CREATE 后的等待时间下限参考）
 *   uinput-back --list          只打印设备将广告的名字与能力，不创建设备、不按键
 *   uinput-back --dry-run       完整流程但不真正写 /dev/uinput（只打印动作）
 *   uinput-back --help
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>

#define DEFAULT_DELAY_MS 100
#define CREATE_SETTLE_MS 400	/* UI_DEV_CREATE 后等 libinput/phoc 认到设备并装好 keymap（计划附录 B） */

static const char *DEV_NAME = "elden-back";

static void die(const char *what)
{
	fprintf(stderr, "uinput-back: %s: %s\n", what, strerror(errno));
	exit(1);
}

static void print_capabilities(void)
{
	printf("device name : %s\n", DEV_NAME);
	printf("id          : bustype=BUS_VIRTUAL vendor=0x1 product=0x3\n");
	printf("evbits      : EV_KEY, EV_SYN\n");
	printf("keys        : KEY_BACK (code %d, from linux/input-event-codes.h)\n", KEY_BACK);
	printf("props       : none (no INPUT_PROP_DIRECT, no INPUT_PROP_BUTTONPAD)\n");
	printf("not advertised: EV_ABS/EV_REL/EV_SW, no letters/enter/space\n");
}

/* dry_run=1 时只打印将要发生的事。fd<0 表示 dry-run。 */
static void emit(int fd, int dry_run, int type, int code, int value)
{
	if (dry_run) {
		printf("dry-run: emit type=%d code=%d value=%d\n", type, code, value);
		return;
	}
	struct input_event ev;
	memset(&ev, 0, sizeof ev);
	ev.type = type;
	ev.code = code;
	ev.value = value;
	if (write(fd, &ev, sizeof ev) != sizeof ev)
		die("write input_event");
}

static void send_key(int fd, int dry_run, int code)
{
	emit(fd, dry_run, EV_KEY, code, 1);
	emit(fd, dry_run, EV_SYN, SYN_REPORT, 0);
	emit(fd, dry_run, EV_KEY, code, 0);
	emit(fd, dry_run, EV_SYN, SYN_REPORT, 0);
}

static void usage(FILE *out)
{
	fprintf(out,
		"usage: uinput-back [--repeat N] [--delay-ms MS] [--list] [--dry-run] [--help]\n"
		"  --repeat N     send N KEY_BACK press+release pairs (default 1)\n"
		"  --delay-ms MS  delay between repeats (default %d)\n"
		"  --list         print device name/capabilities only; create nothing\n"
		"  --dry-run      full flow without touching /dev/uinput\n", DEFAULT_DELAY_MS);
}

int main(int argc, char **argv)
{
	long repeat = 1;
	long delay_ms = DEFAULT_DELAY_MS;
	int list_only = 0, dry_run = 0;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--repeat") && i + 1 < argc) {
			repeat = strtol(argv[++i], NULL, 10);
			if (repeat < 1 || repeat > 1000) {
				fprintf(stderr, "uinput-back: --repeat out of range (1..1000): %s\n", argv[i]);
				return 2;
			}
		} else if (!strcmp(argv[i], "--delay-ms") && i + 1 < argc) {
			delay_ms = strtol(argv[++i], NULL, 10);
			if (delay_ms < 0 || delay_ms > 10000) {
				fprintf(stderr, "uinput-back: --delay-ms out of range (0..10000): %s\n", argv[i]);
				return 2;
			}
		} else if (!strcmp(argv[i], "--list")) {
			list_only = 1;
		} else if (!strcmp(argv[i], "--dry-run")) {
			dry_run = 1;
		} else if (!strcmp(argv[i], "--help") || !strcmp(argv[i], "-h")) {
			usage(stdout);
			return 0;
		} else {
			fprintf(stderr, "uinput-back: unknown argument: %s\n", argv[i]);
			usage(stderr);
			return 2;
		}
	}

	if (list_only) {
		print_capabilities();
		return 0;
	}

	if (dry_run) {
		printf("dry-run: would open /dev/uinput and create \"%s\" (KEY_BACK only)\n", DEV_NAME);
		printf("dry-run: would wait %d ms after UI_DEV_CREATE\n", CREATE_SETTLE_MS);
		for (long n = 0; n < repeat; n++)
			send_key(-1, 1, KEY_BACK);
		printf("dry-run: would UI_DEV_DESTROY and exit\n");
		return 0;
	}

	int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	if (fd < 0)
		die("open /dev/uinput (run as root or add udev rule)");

	if (ioctl(fd, UI_SET_EVBIT, EV_KEY) < 0)
		die("UI_SET_EVBIT EV_KEY");
	if (ioctl(fd, UI_SET_EVBIT, EV_SYN) < 0)
		die("UI_SET_EVBIT EV_SYN");
	if (ioctl(fd, UI_SET_KEYBIT, KEY_BACK) < 0)
		die("UI_SET_KEYBIT KEY_BACK");
	/* 故意不做: UI_SET_PROPBIT(INPUT_PROP_DIRECT)、EV_REL/EV_ABS、字母/回车/空格 */

	struct uinput_setup us;
	memset(&us, 0, sizeof us);
	snprintf(us.name, UINPUT_MAX_NAME_SIZE, "%s", DEV_NAME);
	us.id.bustype = BUS_VIRTUAL;
	us.id.vendor = 0x1;
	us.id.product = 0x3;
	if (ioctl(fd, UI_DEV_SETUP, &us) < 0)
		die("UI_DEV_SETUP");
	if (ioctl(fd, UI_DEV_CREATE) < 0)
		die("UI_DEV_CREATE");
	usleep(CREATE_SETTLE_MS * 1000);	/* 等 phoc/libinput 认到设备并装好 keymap */

	for (long n = 0; n < repeat; n++) {
		send_key(fd, 0, KEY_BACK);
		if (n + 1 < repeat && delay_ms > 0)
			usleep(delay_ms * 1000);
	}
	usleep(100 * 1000);

	if (ioctl(fd, UI_DEV_DESTROY) < 0)
		fprintf(stderr, "uinput-back: UI_DEV_DESTROY: %s\n", strerror(errno));
	close(fd);
	return 0;
}
