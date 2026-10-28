/* mjpgfeed.c — 把连续 MJPEG 字节流（stdin）按 SOI/EOI 切帧，
 * 用 V4L2 mmap 写端逐帧提交（bytesused = 真实帧长）到 /dev/video100。
 * 解决 v4l2-ctl --stream-from 按固定 sizeimage 切变长帧导致帧边界错乱。
 *
 * usage: mjpgfeed <device> <width> <height>
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <linux/videodev2.h>

#define NBUF 8
#define MAXFRAME (4*1024*1024)

static int xioctl(int fd, unsigned long req, void *arg) {
	int r;
	do { r = ioctl(fd, req, arg); } while (r == -1 && errno == EINTR);
	return r;
}

int main(int argc, char **argv) {
	if (argc < 4) { fprintf(stderr, "usage: %s <dev> <w> <h>\n", argv[0]); return 2; }
	const char *dev = argv[1];
	unsigned w = (unsigned)atoi(argv[2]), h = (unsigned)atoi(argv[3]);

	int fd = open(dev, O_RDWR);
	if (fd < 0) { perror("open"); return 1; }

	struct v4l2_format fmt; memset(&fmt, 0, sizeof(fmt));
	fmt.type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
	fmt.fmt.pix.width = w; fmt.fmt.pix.height = h;
	fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_MJPEG;
	fmt.fmt.pix.field = V4L2_FIELD_NONE;
	if (xioctl(fd, VIDIOC_S_FMT, &fmt) < 0) { perror("S_FMT"); return 1; }
	fprintf(stderr, "S_FMT ok: %ux%u fourcc=%c%c%c%c sizeimage=%u\n",
		fmt.fmt.pix.width, fmt.fmt.pix.height,
		fmt.fmt.pix.pixelformat & 0xff, (fmt.fmt.pix.pixelformat>>8)&0xff,
		(fmt.fmt.pix.pixelformat>>16)&0xff, (fmt.fmt.pix.pixelformat>>24)&0xff,
		fmt.fmt.pix.sizeimage);

	struct v4l2_requestbuffers req; memset(&req, 0, sizeof(req));
	req.count = NBUF; req.type = V4L2_BUF_TYPE_VIDEO_OUTPUT; req.memory = V4L2_MEMORY_MMAP;
	if (xioctl(fd, VIDIOC_REQBUFS, &req) < 0) { perror("REQBUFS"); return 1; }
	if (req.count < 2) { fprintf(stderr, "insufficient buffers\n"); return 1; }
	fprintf(stderr, "REQBUFS got %u\n", req.count);

	void **bufs = calloc(req.count, sizeof(void *));
	size_t *lens = calloc(req.count, sizeof(size_t));
	unsigned i;
	for (i = 0; i < req.count; i++) {
		struct v4l2_buffer b; memset(&b, 0, sizeof(b));
		b.type = V4L2_BUF_TYPE_VIDEO_OUTPUT; b.memory = V4L2_MEMORY_MMAP; b.index = i;
		if (xioctl(fd, VIDIOC_QUERYBUF, &b) < 0) { perror("QUERYBUF"); return 1; }
		lens[i] = b.length;
		bufs[i] = mmap(NULL, b.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, b.m.offset);
		if (bufs[i] == MAP_FAILED) { perror("mmap"); return 1; }
	}

	unsigned char *stream = malloc(MAXFRAME*2);
	unsigned char *frame  = malloc(MAXFRAME);
	size_t slen = 0; unsigned flen = 0; int inframe = 0;
	unsigned long frames = 0, dropped = 0;

	/* 选一条 buffer 当"当前可写"：先把所有 buffer 排队，用完再循环取回 */
	for (i = 0; i < req.count; i++) {
		struct v4l2_buffer b; memset(&b, 0, sizeof(b));
		b.type = V4L2_BUF_TYPE_VIDEO_OUTPUT; b.memory = V4L2_MEMORY_MMAP; b.index = i;
		b.bytesused = 0;
		if (xioctl(fd, VIDIOC_QBUF, &b) < 0) { perror("QBUF init"); return 1; }
	}

	enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
	if (xioctl(fd, VIDIOC_STREAMON, &type) < 0) { perror("STREAMON"); return 1; }
	fprintf(stderr, "STREAMON ok\n");

	size_t slen_off = 0;
	while (1) {
		/* 尽量读满 */
		if (slen < MAXFRAME) {
			ssize_t n = read(0, stream + slen, MAXFRAME);
			if (n <= 0) break;
			slen += (size_t)n;
		}
		/* 从 stream 里切帧 */
		size_t f = 0;
		int got = 0;
		while (f + 1 < slen) {
			if (!inframe) {
				if (stream[f] == 0xFF && stream[f+1] == 0xD8) { inframe = 1; flen = 0; }
				else { f++; continue; }
			}
			if (flen < MAXFRAME) frame[flen++] = stream[f];
			f++;
			if (inframe && flen >= 2 && frame[flen-2] == 0xFF && frame[flen-1] == 0xD9) {
				inframe = 0; got = 1; break;
			}
		}
		if (f) { memmove(stream, stream + f, slen - f); slen -= f; }
		if (!got) continue;

		/* 取一条已完成（或初始已排队）的 buffer */
		struct v4l2_buffer b; memset(&b, 0, sizeof(b));
		b.type = V4L2_BUF_TYPE_VIDEO_OUTPUT; b.memory = V4L2_MEMORY_MMAP;
		fd_set fds; FD_ZERO(&fds); FD_SET(fd, &fds);
		struct timeval tv = { 2, 0 };
		if (select(fd + 1, NULL, &fds, NULL, &tv) <= 0) { dropped++; continue; }
		if (xioctl(fd, VIDIOC_DQBUF, &b) < 0) { if (errno==EAGAIN) continue; perror("DQBUF"); break; }
		if (flen > lens[b.index]) { flen = (unsigned)lens[b.index]; dropped++; }
		memcpy(bufs[b.index], frame, flen);
		b.bytesused = flen; b.field = V4L2_FIELD_NONE;
		if (xioctl(fd, VIDIOC_QBUF, &b) < 0) { perror("QBUF"); break; }
		frames++;
		if ((frames % 30) == 0) fprintf(stderr, "frames=%lu dropped=%lu last=%u\n", frames, dropped, flen);
	}

	type = V4L2_BUF_TYPE_VIDEO_OUTPUT;
	xioctl(fd, VIDIOC_STREAMOFF, &type);
	fprintf(stderr, "done frames=%lu dropped=%lu\n", frames, dropped);
	return 0;
}
