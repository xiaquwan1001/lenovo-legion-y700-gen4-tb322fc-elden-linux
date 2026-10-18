# 四十九、设备网络「HTTPS 全废 / git 随机失败」= 0 字节证书配置 + 手机热点 PMTU 黑洞

日期 2026-10-18 | 设备 U2 `7.3.0-rc7-debug-vk127` | 完整报告 `reports/net-https-mtu-rootcause-20261018.md`

**一句话**：设备上"网络坏了"其实是**两个独立故障叠加**——① `/etc/ca-certificates.conf` 被清成 0 字节 ⇒ 信任锚全空 ⇒ 所有 HTTPS 立即失败；② 手机热点广播 MTU 1500 而上游实际 1400 且不下发 ICMP frag-needed ⇒ PMTU 黑洞，且 TLS 后量子混合曲线把 ClientHello 撑到 1423 字节正好跨 MTU，触发连接死锁。

---

## #340：0 字节的 `/etc` 配置文件 ⇒ 设备零信任锚（HTTPS 全废）

**现象**（有欺骗性：看起来像网络/DNS/证书过期）：

```
curl: (77) error adding trust anchors from file: /etc/ssl/certs/ca-certificates.crt
git:  fatal: unable to access 'https://…': Recv failure: Connection reset by peer
apk:  TLS 校验失败
```

**根因链**：

```
/etc/ca-certificates.conf              0 字节（包内原版 4888）
      ↓
/usr/sbin/update-ca-certificates       读 conf 得到空列表，写出 0 字节，rc=0（静默成功！）
      ↓
/etc/ssl/certs/ca-certificates.crt     0 字节 ⇒ 零信任锚 ⇒ 全站 HTTPS 失败
```

同批 0 字节的还有 7 个文件（`protected_paths.d/ca-certificates.list`、`update.d/certhash`、`gtk-3.0/im-multipress.conf`、3 个 `xdg/autostart/*.desktop`、`Xwayland-session.d/00-at-spi`），每个旁边都躺着**内容完好的同名 `.apk-new`** —— 说明是一次解包/覆盖过程把活文件截断了，不是包本身坏。

**★ 判据（最省时间的一条）**：

```sh
find /etc -type f -size 0 | xargs -r ls -l          # 先找 0 字节配置
find /etc -name '*.apk-new' | wc -l                 # 旁边是否有完好的原版
grep -c BEGIN /etc/ssl/certs/ca-certificates.crt    # 应 >100，0 就是本条
```

**★ 最大陷阱：`apk fix` 修不了，且会骗你以为修了**

`apk` 把 0 字节活文件当成**"用户已修改的配置文件"**，于是只再写一份 `.apk-new`，活文件原封不动：

```
$ : > /etc/ca-certificates.conf && apk fix ca-certificates
  Installing file to etc/ca-certificates.conf.apk-new     ← 只写 .apk-new
$ stat -c %s /etc/ca-certificates.conf /etc/ssl/certs/ca-certificates.crt
0
0            ← 依旧全废
```

⇒ 必须显式 `mv *.apk-new → 活文件`；若 `.apk-new` 也没了就按 Alpine 的做法从
`/usr/share/ca-certificates/mozilla/*.crt` 一行一个重建 conf（`net-selfheal.sh` 两条路径都实现并各自实测）。

**修法**（已是 `scripts/net-selfheal.sh` 的一部分，幂等）：

```sh
# 1. 0 字节 + 有 .apk-new ⇒ 直接换回
for n in $(find /etc -name '*.apk-new'); do l=${n%.apk-new}
  [ -s "$l" ] && continue; [ -s "$n" ] && mv -f "$n" "$l"; done
# 2. conf 空且无 apk-new ⇒ 从 mozilla 重建；然后重建 bundle
/usr/sbin/update-ca-certificates
```

验收：bundle 181724 字节 / 121 张证书；`curl https://mirrors.ustc.edu.cn/` → 200。

---

## #341：手机热点 PMTU 黑洞 + TLS 后量子 ClientHello 超 MTU ⇒ git 随机失败

**现象**：信任链修好后，`git clone/ls-remote` 对 `gitlab.freedesktop.org` / `gitlab.gnome.org` **10–55% 随机失败**，报 `Recv failure: Connection reset by peer` 或 `HTTP 500`；而 `mirrors.ustc.edu.cn`、`github.com` **0 失败**。

**★ 排除过程（这些都要先做，否则会误判成"热点封锁"）**：

| 假设 | 否证证据 |
|---|---|
| 热点封锁 Fastly | TCP 握手到 4 个 Fastly IP **60/60 全通**（真封锁会丢 SYN） |
| 设备链路质量 | 到网关 100 包 **0% 丢**；ustc/tuna/aliyun 各 100 包 **0% 丢** |
| 热点 NAT/状态 | 同热点下 ustc 12/12、github 8/8 全通 |
| 单纯 MTU 值错 | MTU 1200/1300/1400/1500 全试，仍 8–45% 失败（有改善不消失） |
| SACK / offload / power_save | 逐个关均无显著改善（在噪声内） |

⚠ **`ping` 到境外目标主机侧也报 ~15% 丢包，那是 ICMP 限速，不能当数据面证据**。判断一律用 `curl`/`git` 实测成功率。

**★ 抓包定位**（`tcpdump -ni wlan0`）——决定性证据：

```
C→S  [.]  seq 1:1361     len 1360     ← 满 MSS 段（ClientHello 首段）
C→S  [P.] seq 1361:1574  len  213     ← 尾段
S→C  [.]  ack 1361                    ← 首段其实收到过
C→S  [P.] seq 1361:1574  len  213     ← 客户端重传"尾段"
S→C  [.]  ack 1  sack 1 {1361:1574}    ← ★ ACK 号回退，只承认尾段
C→S  … 无限重传尾段，窗口永不推进 → 超时
```

**★ 量化（MTU 1400，各 40 次 curl 到 fd.o）**：

| TLS 曲线 | ClientHello | 成功 |
|---|---|---|
| `X25519MLKEM768`（OpenSSL 3.5 默认，后量子混合） | **1423 B**（>1400，必然拆两段） | 32/40 = **80%** |
| `X25519`（传统） | 243 B（单段） | 39/40 = **98%** |

确认介质：`openssl s_client -curves X -tls1_3 -msg` 看 `Handshake [length …]`。

**★ 真实路径 MTU 用 DF 扫描量（不要信接口上的 1500）**：

```sh
for s in 1472 1420 1400 1392 1372; do
  ping -4 -c1 -W1 -M do -s $s <目标IP> >/dev/null 2>&1 \
    && echo "-s $s OK (mtu $((s+28)))" || echo "-s $s FAIL"; done
# 本机实测：1400 通过，1428 全失败 ⇒ 真实 MTU 1400（v6 侧是 1380）
```

**已落地缓解**（`net-selfheal.sh`）：`wlan0 mtu 1400` + `power_save off`。
效果 git 失败 35% → ~10%，**未根治**（大仓库 clone 仍偶发，可重试）。剩余方向见报告 §4。

---

## #342：修完不等于修好——冷启动验证是必须的

本轮自愈能力**在冷启动路径上单独验证**，而不是"跑一次成功就宣布修好"：

```
# 注入故障态（MTU→1500、conf/bundle 清 0、power_save on）→ reboot
# 重启后 ~70s
mtu     = 1400              ✅ 自动降
conf    = 4854 bytes        ✅ 自动重建
bundle  = 181724 / 121 certs ✅ 自动重建
/run/net-selfheal.log: problems=0
curl https://mirrors.ustc.edu.cn/ → 200  ✅
```

触发点双保险：OpenRC `local`（等 wlan0 UP，最多 120 s）+ `NetworkManager/dispatcher.d/50-net-selfheal`（接口 up / connectivity-change）。**只挂 boot 会漏掉"开机时 wlan0 还没起来"这一类**。

**★ 回灌纪律**：设备侧改完必须同时更新 `rootfs/build-rootfs.sh`（helper 清单）与 `rootfs/persistent-overlay/`（`usr-local-sbin.tar.gz`、`etc-local.d.tar.gz`、新 `etc-NM-dispatcher.tar.gz`、`restore.sh`），否则重刷镜像即丢失。
