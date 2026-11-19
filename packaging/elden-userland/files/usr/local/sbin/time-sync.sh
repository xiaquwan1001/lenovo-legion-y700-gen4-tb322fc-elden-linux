#!/bin/sh
# time-sync.sh — wait for network, step the clock from NTP, then keep chronyd
# disciplining it.
#
# Why: the TB322FC PMIC RTC is read-only for us (hwclock -w → RTC_SET_TIME
# fails with ENODEV; hwclock -r works), so the clock comes up at 1970-01-01 and
# a wrong clock breaks TLS/HTTPS (apk, git, web) and file timestamps.  chrony
# is therefore re-run on every boot once a default route exists.
#
# Called from /init right after net-up.sh (background), or manually.
set -u
LOG=/run/time-sync.log
# 串行化（2026-11-19）：/init 冷起会跑一次，usb0 路由就位时 usb0-host-route 又会补跑一次；
# 两次并发会互相抢 chronyd 的 pid 文件。拿不到锁就直接退出（另一次在补）。
exec 9>/run/time-sync.lock 2>/dev/null || true
command -v flock >/dev/null 2>&1 && { flock -n 9 || exit 0; }

# Asia/Shanghai (idempotent; rootfs rebuilds may drop /etc/localtime)
[ -e /usr/share/zoneinfo/Asia/Shanghai ] && \
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# wait up to ~90 s for a default route (WiFi net-up.sh or usb0)
i=0
while [ $i -lt 180 ]; do
	ip route show default 2>/dev/null | grep -q . && break
	sleep 0.5; i=$((i + 1))
done
echo "[time-sync] $(date -u) default route after ~$((i / 2))s" >>"$LOG"

# one-shot step (chronyd -q steps the system clock, then exits)
# 2026-11-19：**先停已跑着的 chronyd** —— 否则 `chronyd -q` 以
#   `Fatal error : Another chronyd may already be running` 退出、时钟一步不跳（实测：
#   Debian minbase 根上 `chronyd.service` 开机即起，本轮时钟停在 2026-04-13）。
if command -v systemctl >/dev/null 2>&1; then
	systemctl stop chronyd 2>/dev/null || true
else
	pkill -x chronyd 2>/dev/null || true
fi
# 重试（2026-11-19 加）：冷起时默认路由可能晚于本脚本就绪（实测：开机 90 s 内没网 ⇒
# 一次失败就永久错时钟，之后 apt 的 TLS 全 `certificate verify failed`）。最多 12 次 × 20 s。
# 判据用 **chronyd -q 的退出码**（失败=没网/没源），不用 `date +%Y` 之类日期阈值——
# 本机 RTC 冷起会给「镜像构建日 2026-04-13」而不是 1970，日期阈值判不出来（实测踩到）。
try=0; ntp_ok=1
while [ $try -lt 12 ]; do
	if timeout 90 chronyd -q "pool ntp.aliyun.com iburst" >>"$LOG" 2>&1; then ntp_ok=0; break; fi
	try=$((try + 1))
	sleep 20
done
echo "[time-sync] after step: $(date -u) (tries=$try ntp_ok=$ntp_ok)" >>"$LOG"

# 兜底（2026-11-19 立）：NTP 不通（UDP/123 被拦、chrony.conf 无源）时用 HTTP Date 头。
# 为什么不用 `date -s` 直接写死：要的是「真实当前时间」，HTTP 头就是权威源，代价 0。
if [ "$ntp_ok" -ne 0 ]; then
	hdr=$(timeout 15 curl -fsSI http://mirrors.ustc.edu.cn/debian/ 2>/dev/null \
		| tr -d '\r' | sed -n 's/^[Dd]ate: //p' | head -1)
	if [ -n "$hdr" ]; then
		date -u -s "$hdr" >>"$LOG" 2>&1
		echo "[time-sync] http-date step: $(date -u) (hdr=$hdr)" >>"$LOG"
	fi
fi

# keep it disciplined (RTC cannot be written, so no hwclock -w)
# 2026-11-19：优先交回 systemd（前面的 `systemctl stop chronyd` 停的是服务），否则裸起进程
# 会在 `systemctl restart chronyd` 时报 "Another chronyd may already be running"。
if command -v systemctl >/dev/null 2>&1; then
	systemctl start chronyd 2>/dev/null || true
fi
ps -eo comm 2>/dev/null | grep -qx chronyd || chronyd >>"$LOG" 2>&1
