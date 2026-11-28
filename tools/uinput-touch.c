/* uinput-touch — 在 /dev/uinput 上造一个虚拟多点触控屏并注入 tap/swipe/arc。
 * 用法: uinput-touch tap X Y [W H]         （W H = 屏幕分辨率，默认 1904x3042）
 *       uinput-touch swipe X1 Y1 X2 Y2 [steps] [W H]
 *       uinput-touch hold-swipe X1 Y1 X2 Y2 [attach_ms] [steps]
 *       uinput-touch hold-arc   X1 Y1 X2 Y2 [attach_ms] [steps] [bow]
 *   hold-arc 走二次贝塞尔：控制点 = 弦中点 + bow * 单位法向（默认 bow = 弦长的 25%），
 *   用来复现拇指的弧形轨迹（直线 swipe 的弦角会掩盖 lisgd 的方向死区）。
 * 为什么需要：phosh 只在「最后一次输入是触摸」时才展开 OSK（ydotool 造的是鼠标+键盘，
 * 反而被当成硬件键盘 ⇒ 键盘永不展开，且需要 ignore-hw-keyboards=true 才不压制）。
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>

static int fd;
static int SW = 1904, SH = 3042;

static void emit(int type, int code, int val) {
	struct input_event ev;
	memset(&ev, 0, sizeof ev);
	ev.type = type; ev.code = code; ev.value = val;
	if (write(fd, &ev, sizeof ev) != sizeof ev) { perror("write"); }
}

static void syn(void) { emit(EV_SYN, SYN_REPORT, 0); }

static void setup(void) {
	fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	if (fd < 0) { perror("open /dev/uinput"); exit(1); }
	ioctl(fd, UI_SET_EVBIT, EV_ABS);
	ioctl(fd, UI_SET_EVBIT, EV_KEY);
	ioctl(fd, UI_SET_EVBIT, EV_SYN);
	ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH);
	ioctl(fd, UI_SET_KEYBIT, BTN_TOOL_FINGER);
	ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT);
	ioctl(fd, UI_SET_ABSBIT, ABS_MT_SLOT);
	ioctl(fd, UI_SET_ABSBIT, ABS_MT_TRACKING_ID);
	ioctl(fd, UI_SET_ABSBIT, ABS_MT_POSITION_X);
	ioctl(fd, UI_SET_ABSBIT, ABS_MT_POSITION_Y);
	ioctl(fd, UI_SET_ABSBIT, ABS_X);
	ioctl(fd, UI_SET_ABSBIT, ABS_Y);

	struct uinput_abs_setup as;
	memset(&as, 0, sizeof as);
	as.absinfo.maximum = 65535;
	as.code = ABS_MT_POSITION_X; ioctl(fd, UI_ABS_SETUP, &as);
	as.code = ABS_MT_POSITION_Y; ioctl(fd, UI_ABS_SETUP, &as);
	as.code = ABS_X; ioctl(fd, UI_ABS_SETUP, &as);
	as.code = ABS_Y; ioctl(fd, UI_ABS_SETUP, &as);
	as.absinfo.maximum = 9; as.absinfo.minimum = 0;
	as.code = ABS_MT_SLOT; ioctl(fd, UI_ABS_SETUP, &as);
	as.absinfo.maximum = 65535; as.absinfo.minimum = -1;
	as.code = ABS_MT_TRACKING_ID; ioctl(fd, UI_ABS_SETUP, &as);

	struct uinput_setup us;
	memset(&us, 0, sizeof us);
	snprintf(us.name, UINPUT_MAX_NAME_SIZE, "elden-virtual-touch");
	us.id.bustype = BUS_VIRTUAL; us.id.vendor = 0x1; us.id.product = 0x2;
	ioctl(fd, UI_DEV_SETUP, &us);
	if (ioctl(fd, UI_DEV_CREATE) < 0) { perror("UI_DEV_CREATE"); exit(1); }
	usleep(400000);	/* 让 libinput/phoc 认到设备 */
}

static int to_x(int px) { return px * 65535 / SW; }
static int to_y(int py) { return py * 65535 / SH; }

static void touch_down(int px, int py) {
	emit(EV_ABS, ABS_MT_SLOT, 0);
	emit(EV_ABS, ABS_MT_TRACKING_ID, 1);
	emit(EV_ABS, ABS_MT_POSITION_X, to_x(px));
	emit(EV_ABS, ABS_MT_POSITION_Y, to_y(py));
	emit(EV_ABS, ABS_X, to_x(px));
	emit(EV_ABS, ABS_Y, to_y(py));
	emit(EV_KEY, BTN_TOUCH, 1);
	emit(EV_KEY, BTN_TOOL_FINGER, 1);
	syn();
}

static void touch_move(int px, int py) {
	emit(EV_ABS, ABS_MT_POSITION_X, to_x(px));
	emit(EV_ABS, ABS_MT_POSITION_Y, to_y(py));
	emit(EV_ABS, ABS_X, to_x(px));
	emit(EV_ABS, ABS_Y, to_y(py));
	syn();
}

static void touch_up(void) {
	emit(EV_ABS, ABS_MT_SLOT, 0);
	emit(EV_ABS, ABS_MT_TRACKING_ID, -1);
	emit(EV_KEY, BTN_TOUCH, 0);
	emit(EV_KEY, BTN_TOOL_FINGER, 0);
	syn();
}

int main(int argc, char **argv) {
	if (argc < 4) { fprintf(stderr, "usage: %s tap X Y | swipe X1 Y1 X2 Y2 [steps] | hold-swipe X1 Y1 X2 Y2 [attach_ms] [steps] | hold-arc X1 Y1 X2 Y2 [attach_ms] [steps] [bow]\n"
		"  hold-swipe: 建好设备后先等 attach_ms（默认 6000）让 lisgd 之类的 daemon 认到该 evdev 节点，再发 swipe\n"
		"  hold-arc:   同上，但轨迹是弦 + 法向 bow（默认 25%% 弦长）的二次贝塞尔曲线\n", argv[0]); return 2; }
	int hold = !strcmp(argv[1], "hold-swipe") || !strcmp(argv[1], "hold-arc");
	int arc = !strcmp(argv[1], "hold-arc");
	int swipe = hold || !strcmp(argv[1], "swipe");
	int x1 = atoi(argv[2]), y1 = atoi(argv[3]);
	int x2 = swipe ? atoi(argv[4]) : 0, y2 = swipe ? atoi(argv[5]) : 0;
	int steps = (swipe && !hold && argc > 6) ? atoi(argv[6]) : 12;
	int attach_ms = (hold && argc > 6) ? atoi(argv[6]) : 6000;
	char *env;
	if ((env = getenv("VS_W"))) SW = atoi(env);
	if ((env = getenv("VS_H"))) SH = atoi(env);
	/* 弧线参数：把弦中点沿法向推开 bow 像素（正负决定弧的哪一侧）。 */
	double dx = x2 - x1, dy = y2 - y1;
	double len = sqrt(dx * dx + dy * dy);
	double bow = (arc && argc > 8) ? atof(argv[8]) : (arc ? 0.25 * len : 0);
	double cx = (x1 + x2) / 2.0, cy = (y1 + y2) / 2.0;
	if (arc && len > 0) { cx += bow * (-dy) / len; cy += bow * dx / len; }
	setup();
	if (hold) {
		fprintf(stderr, "%s: device up, waiting %d ms for daemons to attach\n",
			arc ? "hold-arc" : "hold-swipe", attach_ms);
		usleep(attach_ms * 1000);
	}
	touch_down(x1, y1);
	if (swipe) {
		for (int i = 1; i <= steps; i++) {
			double t = (double)i / steps;
			int px, py;
			if (arc) {
				/* B(t) = (1-t)^2*P0 + 2(1-t)t*C + t^2*P2 */
				double u = 1.0 - t;
				px = (int)lround(u * u * x1 + 2 * u * t * cx + t * t * x2);
				py = (int)lround(u * u * y1 + 2 * u * t * cy + t * t * y2);
			} else {
				px = x1 + (x2 - x1) * i / steps;
				py = y1 + (y2 - y1) * i / steps;
			}
			touch_move(px, py);
			usleep(20000);
		}
	} else usleep(60000);
	touch_up();
	usleep(120000);
	ioctl(fd, UI_DEV_DESTROY);
	close(fd);
	return 0;
}
