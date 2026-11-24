/*
 * as-client.c — Audio Share (mkckr0/audio-share) Linux client
 *
 * Copyright 2024-2025 the audio-share contributors
 * Licensed under the Apache License, Version 2.0
 *
 * Why it exists: upstream ships a Windows/Linux *server* (`as-cmd`) and an
 * Android client only. This file is the other end of the wire for plain
 * Linux boxes (desktop, SBC, ARM tablet running a mainline-kernel distro).
 * It is intentionally dependency free: hand-rolled protobuf parsing and
 * PipeWire playback delegated to `pw-cat` (part of pipewire-bin).
 *
 * Wire protocol — byte-exact reference is the Android app sources
 * (android-app/.../service/{NetClient,NetworkIO}.kt) and docs/protocol.md.
 * All integers are little endian int32.
 *
 *   TCP (default port 65530):
 *     1) client -> srv : CMD_GET_FORMAT(1)
 *        srv -> client : 1, size, <size bytes protobuf AudioFormat>
 *                        AudioFormat{ encoding=1 (varint: 1=f32 2=u8 3=s16
 *                                                     4=s24 5=s32),
 *                                     channels=2 (varint),
 *                                     sample_rate=3 (varint) }
 *     2) client -> srv : CMD_START_PLAY(2)
 *        srv -> client : 2, id (id > 0)
 *     3) UDP: client binds an ephemeral port, sends `id` to srv:port once,
 *        afterwards the server pushes raw PCM datagrams to it.
 *     4) Heartbeat: srv sends CMD_HEARTBEAT(3) on TCP every 3 s, client must
 *        echo 3; a peer silent for 5 s is dropped by the server. This client
 *        treats 10 s without a heartbeat as a dead link and reconnects.
 *   Playback: PCM is piped straight into `pw-cat --playback --raw -` (PipeWire).
 *
 * Usage: as-client <host> [port] [--target <sink>] [--latency <ms>] [-v]
 * Exit status: non-zero only on bad arguments; link loss reconnects forever.
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
#define RECONNECT_DELAY_MS 3000

static int g_verbose;
static const char *g_target;  /* pw-cat --target (sink name or node id) */
static const char *g_latency; /* pw-cat --latency */

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

static void sleep_ms(int64_t ms)
{
	struct timespec ts = { .tv_sec = (time_t)(ms / 1000),
			       .tv_nsec = (long)(ms % 1000) * 1000000L };
	while (nanosleep(&ts, &ts) && errno == EINTR)
		;
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

/* Read exactly n bytes; 0 on success, -1 when the peer went away. */
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

/* connect() with a timeout, trying every address getaddrinfo() returns. */
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
		logmsg("getaddrinfo(%s) failed", host);
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
		fcntl(fd, F_SETFL, flags); /* back to blocking; poll() gates reads */
		break;
	}
	freeaddrinfo(res);
	return fd;
}

/* ---- minimal protobuf reader for AudioFormat (3 varint fields) ---- */
struct audio_format {
	uint32_t encoding; /* 1 f32 / 2 u8 / 3 s16 / 4 s24 / 5 s32; 0 = invalid */
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
		if (wire != 0) /* every field of this message is varint */
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
		logmsg("unsupported encoding=%u", fmt->encoding);
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
		const char *argv[32];
		int n = 0;
		argv[n++] = "pw-cat";
		argv[n++] = "--playback";
		argv[n++] = "--raw";
		argv[n++] = "--format";
		argv[n++] = fp;
		argv[n++] = "--rate";
		argv[n++] = rate;
		argv[n++] = "--channels";
		argv[n++] = ch;
		if (g_latency) {
			argv[n++] = "--latency";
			argv[n++] = g_latency;
		}
		if (g_target) {
			argv[n++] = "--target";
			argv[n++] = g_target;
		}
		argv[n++] = "-";
		argv[n] = NULL;
		execvp("pw-cat", (char *const *)argv);
		_exit(127);
	}
	close(pipefd[0]);
	/* Never block on the player: a stalled pw-cat (sink reconfigure, device
	 * resume) must not starve the TCP heartbeat or the session gets kicked. */
	int flags = fcntl(pipefd[1], F_GETFL, 0);
	fcntl(pipefd[1], F_SETFL, flags | O_NONBLOCK);
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
			sleep_ms(50);
		}
		kill(p->pid, SIGKILL);
		waitpid(p->pid, &st, 0);
	}
	p->wfd = -1;
	p->pid = -1;
}

/* One session: handshake, then receive PCM until the link dies. */
static void run_session(const char *host, int port)
{
	uint8_t b4[4];
	uint32_t cmd;

	int tfd = tcp_connect(host, port);
	if (tfd < 0) {
		logmsg("cannot connect TCP %s:%d", host, port);
		return;
	}
	logmsg("TCP connected %s:%d", host, port);

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
		logmsg("unexpected GET_FORMAT reply cmd=%u", cmd);
		close(tfd);
		return;
	}
	if (read_full(tfd, b4, 4)) {
		close(tfd);
		return;
	}
	uint32_t sz = read_le32(b4);
	if (sz == 0 || sz > 4096) {
		/* Upstream sends an empty AudioFormat when its capture thread has no
		 * audio endpoint (see README "Extra Setups for No Audio Endpoint"). */
		logmsg("bad AudioFormat size %u (server has no audio endpoint?)", sz);
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
		logmsg("failed to parse AudioFormat");
		free(pb);
		close(tfd);
		return;
	}
	free(pb);
	logmsg("format: encoding=%s(%u) channels=%u rate=%u",
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
		logmsg("unexpected START_PLAY reply cmd=%u", cmd);
		close(tfd);
		return;
	}
	if (read_full(tfd, b4, 4)) {
		close(tfd);
		return;
	}
	uint32_t id = read_le32(b4);
	if ((int32_t)id <= 0) {
		logmsg("invalid START_PLAY id %d", (int32_t)id);
		close(tfd);
		return;
	}
	logmsg("play session id=%d", (int32_t)id);

	/* 3) UDP channel: bind, then announce the id */
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
		logmsg("failed to send UDP id: %s", strerror(errno));
		close(ufd);
		close(tfd);
		return;
	}

	/* 4) start the player */
	struct player pl = { .pid = -1, .wfd = -1 };
	if (player_start(&fmt, &pl)) {
		logmsg("cannot spawn pw-cat");
		close(ufd);
		close(tfd);
		return;
	}

	int64_t last_hb = now_ms();
	int64_t last_stat = last_hb, bytes = 0;
	size_t dropped = 0;
	uint8_t *pcm = malloc(65536);
	if (!pcm) {
		player_stop(&pl);
		close(ufd);
		close(tfd);
		return;
	}

	while (1) {
		if (g_verbose && now_ms() - last_stat >= 2000) {
			logmsg("received %lld bytes of PCM%s", (long long)bytes,
			       dropped ? " (dropped: player back-pressure)" : "");
			last_stat = now_ms();
		}
		if (now_ms() - last_hb > HEARTBEAT_TIMEOUT_MS) {
			logmsg("heartbeat timeout (%.0f s), reconnecting",
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
			logmsg("poll failed: %s", strerror(errno));
			break;
		}
		if (pr == 0)
			continue;

		if (pfds[0].revents & (POLLIN | POLLHUP | POLLERR)) {
			if (read_full(tfd, b4, 4)) {
				logmsg("TCP closed");
				break;
			}
			cmd = read_le32(b4);
			if (cmd == CMD_HEARTBEAT) {
				last_hb = now_ms();
				if (send_cmd(tfd, CMD_HEARTBEAT)) {
					logmsg("failed to echo heartbeat");
					break;
				}
			} else if (g_verbose) {
				logmsg("ignoring CMD=%u", cmd);
			}
		}
		if (pfds[1].revents & POLLIN) {
			struct sockaddr_in from;
			socklen_t fl = sizeof from;
			ssize_t n = recvfrom(ufd, pcm, 65536, 0, (struct sockaddr *)&from, &fl);
			if (n > 0 && from.sin_addr.s_addr == srv.sin_addr.s_addr) {
				bytes += n;
				/* Best effort: if the player cannot keep up, drop audio
				 * rather than block the receive loop (keeps heartbeats). */
				size_t off = 0;
				while (pl.wfd >= 0 && off < (size_t)n) {
					ssize_t w = write(pl.wfd, pcm + off, (size_t)n - off);
					if (w > 0) {
						off += (size_t)w;
					} else if (w < 0 && errno == EINTR) {
						continue;
					} else if (w < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
						dropped += (size_t)n - off;
						break;
					} else {
						logmsg("write to pw-cat failed: %s", strerror(errno));
						n = 0;
						goto session_done;
					}
				}
			}
		}
	}

session_done:
	if (g_verbose)
		logmsg("session ended after %lld bytes", (long long)bytes);
	free(pcm);
	player_stop(&pl);
	close(ufd);
	close(tfd);
}

static void usage(FILE *out)
{
	fprintf(out,
		"usage: as-client <host> [port] [options]\n"
		"  -t, --target <name>   play into this PipeWire sink (pw-cat --target)\n"
		"  -l, --latency <ms>    requested sink latency (pw-cat --latency)\n"
		"  -v, --verbose         log PCM byte counters\n"
		"  -h, --help            show this help\n");
}

int main(int argc, char **argv)
{
	const char *host = NULL;
	int port = DEFAULT_PORT;

	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--verbose") || !strcmp(argv[i], "-v")) {
			g_verbose = 1;
		} else if (!strcmp(argv[i], "--help") || !strcmp(argv[i], "-h")) {
			usage(stdout);
			return 0;
		} else if (!strcmp(argv[i], "--target") || !strcmp(argv[i], "-t")) {
			if (++i >= argc) {
				usage(stderr);
				return 2;
			}
			g_target = argv[i];
		} else if (!strcmp(argv[i], "--latency") || !strcmp(argv[i], "-l")) {
			if (++i >= argc) {
				usage(stderr);
				return 2;
			}
			g_latency = argv[i];
		} else if (!host) {
			if (argv[i][0] == '-') {
				usage(stderr);
				return 2;
			}
			host = argv[i];
		} else {
			char *end = NULL;
			long p = strtol(argv[i], &end, 10);
			if (!end || *end || p <= 0 || p > 65535) {
				fprintf(stderr, "invalid port: %s\n", argv[i]);
				return 2;
			}
			port = (int)p;
		}
	}
	if (!host) {
		usage(stderr);
		return 2;
	}

	signal(SIGPIPE, SIG_IGN);
	logmsg("target %s:%d", host, port);
	while (1) {
		run_session(host, port);
		sleep_ms(RECONNECT_DELAY_MS);
	}
	return 0;
}
