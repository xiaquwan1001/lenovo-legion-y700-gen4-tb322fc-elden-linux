/*
 * as-client.c — Audio Share (mkckr0/audio-share) 的 Linux 客户端
 *
 * 为什么有它：上游只提供 Android 客户端（as-cmd 是服务端）。平板跑主线 Debian，
 * 要在 Linux 上收 PC 的系统声音，就得自己实现这套协议。
 *
 * 协议（逐字节依据 android-app/app/src/main/java/.../service/{NetClient,NetworkIO}.kt）：
 *   TCP 65530：
 *     1) client → srv  : int32le CMD_GET_FORMAT(1)
 *        srv → client  : int32le 1, int32le size, size 字节 protobuf AudioFormat
 *                        AudioFormat{ encoding=1(varint,1 f32/2 u8/3 s16/4 s24/5 s32),
 *                                     channels=2(varint), sample_rate=3(varint) }
 *     2) client → srv  : int32le CMD_START_PLAY(2)
 *        srv → client  : int32le 2, int32le id   (id>0)
 *     3) UDP：client 绑本地随机端口，先发 int32le id 到 srv:65530，
 *        之后服务端往该端口推原始 PCM 数据报（格式 = 步骤 1 的 AudioFormat）
 *     4) 心跳：srv 在 TCP 上发 int32le CMD_HEARTBEAT(3)，client 原样回 3；
 *        5 s 内没回会被服务端踢，所以本端 10 s 收不到心跳即重连。
 *   PWM 回放：把 PCM 直接喂 `pw-cat --playback --raw -`（PipeWire）。
 *
 * 用法： as-client <host> [port] [--verbose]
 * 退出码：只在参数错误/无法 spawn pw-cat 时非零；断线一律内部重连。
 */
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define CMD_NONE 0
#define CMD_GET_FORMAT 1
#define CMD_START_PLAY 2
#define CMD_HEARTBEAT 3

#define DEFAULT_PORT 65530
#define CONNECT_TIMEOUT_MS 3000
#define HEARTBEAT_TIMEOUT_MS 10000

static int g_verbose;

static void logmsg(const char *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);
	fprintf(stderr, "[as-client] ");
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
	va_end(ap);
	if (g_verbose)
		fflush(stderr);
}

static int64_t now_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void write_le32(uint8_t *p, uint32_t v)
{
	p[0] = v & 0xff;
	p[1] = (v >> 8) & 0xff;
	p[2] = (v >> 16) & 0xff;
	p[3] = (v >> 24) & 0xff;
}

static uint32_t read_le32(const uint8_t *p)
{
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) |
	       ((uint32_t)p[3] << 24);
}

/* 读满 n 字节；返回 0 成功，非 0 表示连接断开/超时（由 poll 控制） */
static int read_full(int fd, void *buf, size_t n)
{
	uint8_t *p = buf;
	while (n) {
		ssize_t r = read(fd, p, n);
		if (r == 0)
			return -1;
		if (r < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		p += r;
		n -= (size_t)r;
	}
	return 0;
}

static int write_full(int fd, const void *buf, size_t n)
{
	const uint8_t *p = buf;
	while (n) {
		ssize_t r = write(fd, p, n);
		if (r < 0) {
			if (errno == EINTR)
				continue;
			return -1;
		}
		p += r;
		n -= (size_t)r;
	}
	return 0;
}

static int send_cmd(int fd, uint32_t cmd)
{
	uint8_t b[4];
	write_le32(b, cmd);
	return write_full(fd, b, 4);
}

/* 带超时的 connect */
static int tcp_connect(const char *host, int port)
{
	struct addrinfo hints, *res = NULL, *ai;
	char portstr[16];
	int fd = -1;

	memset(&hints, 0, sizeof hints);
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	snprintf(portstr, sizeof portstr, "%d", port);
	if (getaddrinfo(host, portstr, &hints, &res) != 0 || !res) {
		logmsg("getaddrinfo(%s) 失败", host);
		return -1;
	}
	for (ai = res; ai; ai = ai->ai_next) {
		fd = socket(ai->ai_family, ai->ai_socktype | SOCK_CLOEXEC, ai->ai_protocol);
		if (fd < 0)
			continue;
		int flags = fcntl(fd, F_GETFL, 0);
		fcntl(fd, F_SETFL, flags | O_NONBLOCK);
		int rc = connect(fd, ai->ai_addr, ai->ai_addrlen);
		if (rc < 0 && errno == EINPROGRESS) {
			struct pollfd pfd = { .fd = fd, .events = POLLOUT };
			rc = poll(&pfd, 1, CONNECT_TIMEOUT_MS);
			if (rc <= 0) {
				close(fd);
				fd = -1;
				continue;
			}
			int err = 0;
			socklen_t len = sizeof err;
			getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len);
			if (err) {
				close(fd);
				fd = -1;
				continue;
			}
		} else if (rc < 0) {
			close(fd);
			fd = -1;
			continue;
		}
		fcntl(fd, F_SETFL, flags); /* 回到阻塞，读用 poll 控制 */
		break;
	}
	freeaddrinfo(res);
	return fd;
}

/* ---- protobuf AudioFormat 的最小解析（3 个 varint 字段，够用且不需要 libprotobuf） ---- */
struct audio_format {
	uint32_t encoding; /* 1 f32 / 2 u8 / 3 s16 / 4 s24 / 5 s32；0 = invalid */
	uint32_t channels;
	uint32_t sample_rate;
};

static int pb_varint(const uint8_t *buf, size_t len, size_t *off, uint64_t *out)
{
	uint64_t v = 0;
	int shift = 0;
	while (*off < len) {
		uint8_t b = buf[(*off)++];
		v |= (uint64_t)(b & 0x7f) << shift;
		if (!(b & 0x80)) {
			*out = v;
			return 0;
		}
		shift += 7;
		if (shift > 63)
			return -1;
	}
	return -1;
}

static int parse_audio_format(const uint8_t *buf, size_t len, struct audio_format *fmt)
{
	size_t off = 0;
	memset(fmt, 0, sizeof *fmt);
	while (off < len) {
		uint64_t key, val;
		if (pb_varint(buf, len, &off, &key))
			return -1;
		uint32_t field = (uint32_t)(key >> 3);
		uint32_t wire = (uint32_t)(key & 7);
		if (wire != 0) /* 只处理 varint 字段；本 message 全是 varint */
			return -1;
		if (pb_varint(buf, len, &off, &val))
			return -1;
		switch (field) {
		case 1: fmt->encoding = (uint32_t)val; break;
		case 2: fmt->channels = (uint32_t)val; break;
		case 3: fmt->sample_rate = (uint32_t)val; break;
		default: break;
		}
	}
	return 0;
}

static const char *encoding_name(uint32_t e)
{
	switch (e) {
	case 1: return "f32";
	case 2: return "u8";
	case 3: return "s16";
	case 4: return "s24";
	case 5: return "s32";
	default: return NULL;
	}
}

struct player {
	pid_t pid;
	int wfd;
};

static int player_start(const struct audio_format *fmt, struct player *p)
{
	char rate[16], ch[16];
	snprintf(rate, sizeof rate, "%u", fmt->sample_rate);
	snprintf(ch, sizeof ch, "%u", fmt->channels);
	const char *fp = encoding_name(fmt->encoding);
	if (!fp) {
		logmsg("不支持的 encoding=%u", fmt->encoding);
		return -1;
	}
	int pipefd[2];
	if (pipe(pipefd) < 0)
		return -1;
	pid_t pid = fork();
	if (pid < 0) {
		close(pipefd[0]);
		close(pipefd[1]);
		return -1;
	}
	if (pid == 0) {
		dup2(pipefd[0], STDIN_FILENO);
		close(pipefd[0]);
		close(pipefd[1]);
		signal(SIGPIPE, SIG_DFL);
		execlp("pw-cat", "pw-cat", "--playback", "--raw", "--format", fp,
		       "--rate", rate, "--channels", ch, "-", (char *)NULL);
		_exit(127);
	}
	close(pipefd[0]);
	p->pid = pid;
	p->wfd = pipefd[1];
	return 0;
}

static void player_stop(struct player *p)
{
	if (p->wfd >= 0)
		close(p->wfd);
	if (p->pid > 0) {
		kill(p->pid, SIGTERM);
		int st;
		for (int i = 0; i < 20; i++) {
			if (waitpid(p->pid, &st, WNOHANG) == p->pid)
				return;
			usleep(50000);
		}
		kill(p->pid, SIGKILL);
		waitpid(p->pid, &st, 0);
	}
	p->wfd = -1;
	p->pid = -1;
}

/* 一次会话：握手 + UDP 收流。返回时调用方重连。 */
static void run_session(const char *host, int port)
{
	uint8_t b4[4];
	uint32_t cmd;

	int tfd = tcp_connect(host, port);
	if (tfd < 0) {
		logmsg("TCP 连不上 %s:%d", host, port);
		return;
	}
	logmsg("TCP 已连 %s:%d", host, port);

	/* 1) GET_FORMAT */
	if (send_cmd(tfd, CMD_GET_FORMAT)) {
		close(tfd);
		return;
	}
	if (read_full(tfd, b4, 4)) {
		close(tfd);
		return;
	}
	cmd = read_le32(b4);
	if (cmd != CMD_GET_FORMAT) {
		logmsg("GET_FORMAT 回包异常 cmd=%u", cmd);
		close(tfd);
		return;
	}
	if (read_full(tfd, b4, 4)) {
		close(tfd);
		return;
	}
	uint32_t sz = read_le32(b4);
	if (sz == 0 || sz > 4096) {
		logmsg("AudioFormat 尺寸异常 %u", sz);
		close(tfd);
		return;
	}
	uint8_t *pb = malloc(sz);
	if (!pb || read_full(tfd, pb, sz)) {
		free(pb);
		close(tfd);
		return;
	}
	struct audio_format fmt;
	if (parse_audio_format(pb, sz, &fmt)) {
		logmsg("AudioFormat 解析失败");
		free(pb);
		close(tfd);
		return;
	}
	free(pb);
	logmsg("格式：encoding=%s(%u) channels=%u rate=%u",
	       encoding_name(fmt.encoding) ? encoding_name(fmt.encoding) : "?",
	       fmt.encoding, fmt.channels, fmt.sample_rate);

	/* 2) START_PLAY */
	if (send_cmd(tfd, CMD_START_PLAY)) {
		close(tfd);
		return;
	}
	if (read_full(tfd, b4, 4)) {
		close(tfd);
		return;
	}
	cmd = read_le32(b4);
	if (cmd != CMD_START_PLAY) {
		logmsg("START_PLAY 回包异常 cmd=%u", cmd);
		close(tfd);
		return;
	}
	if (read_full(tfd, b4, 4)) {
		close(tfd);
		return;
	}
	uint32_t id = read_le32(b4);
	if ((int32_t)id <= 0) {
		logmsg("START_PLAY id 无效 %d", (int32_t)id);
		close(tfd);
		return;
	}
	logmsg("播放会话 id=%d", (int32_t)id);

	/* 3) UDP 通道：绑定后先发 id */
	struct sockaddr_in srv;
	memset(&srv, 0, sizeof srv);
	srv.sin_family = AF_INET;
	srv.sin_port = htons((uint16_t)port);
	if (inet_pton(AF_INET, host, &srv.sin_addr) != 1) {
		struct addrinfo hints, *res = NULL;
		memset(&hints, 0, sizeof hints);
		hints.ai_family = AF_INET;
		hints.ai_socktype = SOCK_DGRAM;
		if (getaddrinfo(host, NULL, &hints, &res) != 0 || !res) {
			close(tfd);
			return;
		}
		srv.sin_addr = ((struct sockaddr_in *)res->ai_addr)->sin_addr;
		freeaddrinfo(res);
	}
	int ufd = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
	if (ufd < 0) {
		close(tfd);
		return;
	}
	struct sockaddr_in local;
	memset(&local, 0, sizeof local);
	local.sin_family = AF_INET;
	local.sin_addr.s_addr = htonl(INADDR_ANY);
	local.sin_port = 0;
	if (bind(ufd, (struct sockaddr *)&local, sizeof local) < 0) {
		close(ufd);
		close(tfd);
		return;
	}
	uint8_t idb[4];
	write_le32(idb, id);
	if (sendto(ufd, idb, 4, 0, (struct sockaddr *)&srv, sizeof srv) < 0) {
		logmsg("UDP 发 id 失败：%s", strerror(errno));
		close(ufd);
		close(tfd);
		return;
	}

	/* 4) 起播放器 */
	struct player pl = { .pid = -1, .wfd = -1 };
	if (player_start(&fmt, &pl)) {
		logmsg("pw-cat 起不来");
		close(ufd);
		close(tfd);
		return;
	}

	int64_t last_hb = now_ms();
	int64_t last_stat = last_hb, bytes = 0;
	uint8_t *pcm = malloc(65536);
	int rc = 0;

	while (1) {
		if (g_verbose && now_ms() - last_stat >= 2000) {
			logmsg("已收 PCM %lld 字节", (long long)bytes);
			last_stat = now_ms();
		}
		if (now_ms() - last_hb > HEARTBEAT_TIMEOUT_MS) {
			logmsg("心跳超时（%.0f s），重连",
			       (double)(now_ms() - last_hb) / 1000.0);
			break;
		}
		struct pollfd pfds[2] = {
			{ .fd = tfd, .events = POLLIN },
			{ .fd = ufd, .events = POLLIN },
		};
		int pr = poll(pfds, 2, 500);
		if (pr < 0) {
			if (errno == EINTR)
				continue;
			logmsg("poll 失败：%s", strerror(errno));
			break;
		}
		if (pr == 0)
			continue;

		if (pfds[0].revents & (POLLIN | POLLHUP | POLLERR)) {
			if (read_full(tfd, b4, 4)) {
				logmsg("TCP 断开");
				break;
			}
			cmd = read_le32(b4);
			if (cmd == CMD_HEARTBEAT) {
				last_hb = now_ms();
				if (send_cmd(tfd, CMD_HEARTBEAT)) {
					logmsg("回心跳失败");
					break;
				}
			} else if (g_verbose) {
				logmsg("忽略 CMD=%u", cmd);
			}
		}
		if (pfds[1].revents & POLLIN) {
			struct sockaddr_in from;
			socklen_t fl = sizeof from;
			ssize_t n = recvfrom(ufd, pcm, 65536, 0, (struct sockaddr *)&from, &fl);
			if (n > 0 && from.sin_addr.s_addr == srv.sin_addr.s_addr) {
				bytes += n;
				if (pl.wfd >= 0 && write_full(pl.wfd, pcm, (size_t)n)) {
					logmsg("写 pw-cat 失败：%s", strerror(errno));
					break;
				}
			}
		}
	}

	free(pcm);
	player_stop(&pl);
	close(ufd);
	close(tfd);
	(void)rc;
}

int main(int argc, char **argv)
{
	const char *host = NULL;
	int port = DEFAULT_PORT;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--verbose") || !strcmp(argv[i], "-v")) {
			g_verbose = 1;
		} else if (!strcmp(argv[i], "--help") || !strcmp(argv[i], "-h")) {
			printf("用法: as-client <host> [port] [--verbose]\n");
			return 0;
		} else if (!host) {
			host = argv[i];
		} else {
			port = atoi(argv[i]);
			if (port <= 0 || port > 65535) {
				fprintf(stderr, "端口无效：%s\n", argv[i]);
				return 2;
			}
		}
	}
	if (!host) {
		fprintf(stderr, "用法: as-client <host> [port] [--verbose]\n");
		return 2;
	}

	signal(SIGPIPE, SIG_IGN);
	logmsg("目标 %s:%d", host, port);
	while (1) {
		run_session(host, port);
		sleep(3);
	}
	return 0;
}
