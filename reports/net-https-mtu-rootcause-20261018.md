# 设备网络：git / curl / apk 不通 —— 两个独立根因与长期修复

日期 2026-10-18 | 设备 U2，`7.3.0-rc7-debug-vk127` | 场景：手机热点（P40 Pro）+ USB-NCM 调试链路

---

## 0. 一页结论

| # | 现象 | 根因 | 修复 | 状态 |
|---|---|---|---|---|
| 1 | 所有 HTTPS 立即失败：`curl: (77) error adding trust anchors from file` / `git: Recv failure` / apk 校验失败 | `/etc/ca-certificates.conf` 是 **0 字节** ⇒ `update-ca-certificates` 每次写出 **0 字节** bundle ⇒ 设备零信任锚 | 恢复包内原版 conf（或从 `mozilla/` 重建）+ 重建 bundle；已入 `net-selfheal.sh` | ✅ **已修复并冷启动验证** |
| 2 | 修好信任链后仍有 **10–55% 随机失败**，仅 `gitlab.freedesktop.org` / `gitlab.gnome.org`（Fastly 段），国内站 0 失败 | 手机热点广播 **MTU 1500**，上游实际 **1400** 且不下发 ICMP frag-needed ⇒ **PMTU 黑洞**；TLS ClientHello 用后量子混合曲线 `X25519MLKEM768` 达 **1423 字节**，被拆「满 MSS 首段 + 213 字节尾段」，首段丢弃后连接卡死 | wlan0 MTU→1400 + 关 power_save；已入 `net-selfheal.sh` | 🟡 **已缓解（35%→~10%），未根治** |

**要点：`apk fix ca-certificates` 修不了问题 1**（见 §2.3），必须靠自愈脚本。

---

## 1. 问题 1：信任链（HTTPS 全废）

### 1.1 证据

```
# 修复前
/etc/ca-certificates.conf                    0 字节   (包内原版 4888)
/etc/apk/protected_paths.d/.../*.list        0 字节
/etc/ssl/certs/ca-certificates.crt           0 字节   ← 零信任锚
/usr/sbin/update-ca-certificates             → 写出 0 字节，rc=0（静默成功）

$ curl https://mirrors.ustc.edu.cn/
curl: (77) error adding trust anchors from file: /etc/ssl/certs/ca-certificates.crt
```

### 1.2 成因：8 个 `/etc` 配置被清成 0 字节

同批 0 字节文件（都是 `*.apk-new` 的活副本，说明是**解包/覆盖过程**把它们截断了）：

| 文件 | 包内原版 |
|---|---|
| `/etc/ca-certificates.conf` | 4888 |
| `/etc/apk/protected_paths.d/ca-certificates.list` | 152 |
| `/etc/ca-certificates/update.d/certhash` | 48（缺此文件 = 无 `c_rehash` 钩子） |
| `/etc/gtk-3.0/im-multipress.conf` | 890 |
| `/etc/xdg/autostart/at-spi-dbus-bus.desktop` | 316 |
| `/etc/xdg/autostart/gnome-keyring-{secrets,pkcs11}.desktop` | 8497 / 9056 |
| `/etc/xdg/Xwayland-session.d/00-at-spi` | 453 |

（`/etc/modules-load.d/camera.conf` 与 `/etc/xdg/xdg-desktop-portal-wlr/config` 也是 0 字节，但**包内原版本来就空**，不是故障。）

### 1.3 为什么 `apk fix` 修不了（关键陷阱）

`apk` 把 0 字节活文件视为**"用户已修改的配置文件"**，于是只再写一份 `.apk-new`，活文件原封不动：

```
$ : > /etc/ca-certificates.conf
$ apk fix ca-certificates
  Installing file to etc/ca-certificates.conf.apk-new      ← 只写 .apk-new
$ stat -c %s /etc/ca-certificates.conf /etc/ssl/certs/ca-certificates.crt
0
0                                                          ← 依旧全废
```

⇒ **重复 `apk fix` 是死循环**。必须显式 `mv *.apk-new → 活文件`，或在没有 `.apk-new` 时从 `/usr/share/ca-certificates/mozilla/` 重建 conf（`net-selfheal.sh` 两条路径都实现并各自实测通过）。

### 1.4 修复与验证

```
conf 恢复 4888 字节 → update-ca-certificates → bundle 181724 字节 / 121 张证书
curl: ustc 200 / tuna 200 / github 200 / gitlab.freedesktop.org 302
```

---

## 2. 问题 2：PMTU 黑洞（残留 10–55% 随机失败）

### 2.1 排除项（都实测否证）

| 假设 | 否证 |
|---|---|
| 手机热点封锁 fd.o | TCP 握手到 4 个 Fastly IP **60/60 全通**（封锁会丢 SYN） |
| 设备侧链路丢包 | 到网关 100 包 **0% 丢包**；ustc/tuna/aliyun 各 100 包 **0% 丢包** |
| 热点 NAT 状态问题 | 同一热点下 ustc 12/12、github 8/8 全通 |
| SACK / offload / power_save 单因 | 逐个关掉均无显著改善（8–65% 波动，噪声内） |
| 仅 MTU 值错 | MTU 1200~1500 全试，仍 8–45% 失败（有改善但不消失） |

（注：`ping` 到境外目标主机侧也报 ~15% 丢包，但那是 ICMP 限速，**不能当数据面证据**；判断一律用 curl/git 实测。）

### 2.2 抓包定位（`tcpdump -ni wlan0`）

```
C→S  [.] seq 1:1361     len 1360      ← 满 MSS 段（ClientHello 首段）
C→S  [P.] seq 1361:1574 len  213      ← 尾段（RecordHeader 剩余）
S→C  [.] ack 1361                     ← 首段其实收到过
C→S  [P.] seq 1361:1574 len  213      ← 客户端重传尾段
S→C  [.] ack 1  sack 1 {1361:1574}     ← ACK 号回退 + 只承认尾段
C→S  [P.] seq 1361:1574 …             ← 无限重传，窗口永不推进
```

**诊断**：中间盒/热点的 SACK 与 ACK 状态不一致，客户端按照 `ack 1` 判断首段缺失，但重传的永远是尾段 ⇒ 死锁，直到 curl 超时。

### 2.3 后量子曲线放大了问题

```
$ openssl s_client -curves X25519MLKEM768 -tls1_3 -msg
>>> TLS 1.3, Handshake [length 058b], ClientHello     ← 1423 字节（> 1400 MTU）
$ openssl s_client -curves X25519          -tls1_3 -msg
>>> TLS 1.3, Handshake [length 00f3], ClientHello     ←  243 字节（单段）
```

实测（MTU 1400，各 40 次，curl 到 fd.o）：

| 曲线 | 成功 | 失败率 |
|---|---|---|
| `X25519MLKEM768`（默认） | 32/40 | **20%** |
| `X25519`（传统） | 39/40 | **2%** |

⇒ ClientHello 超过 MTU 是**主因**；但 git（35%）比 curl（10%）差很多，说明还有第二个因素（git 用多轮 `POST /git-upload-pack` + 大响应，更容易撞上中间盒的 ACK 回退）。

### 2.4 已落地的缓解

- `wlan0 mtu 1400`（实测上游 MTU，DF 扫描：1400 通过、1428 全失败）
- `iw dev wlan0 set power_save off`（ath12k 省电模式引入突发丢包）
- 由 `net-selfheal.sh` 幂等维护，NM dispatcher + OpenRC boot 双触发

**效果**：git 失败率 35% → **~10%**；`git clone` 基本可用（大仓库仍偶发失败，可重试）。**未根治**。

---

## 3. 长期修复落地

### 3.1 新增 `scripts/net-selfheal.sh`（幂等，`--check` 只报告）

三件事，全部实测：

1. **0 字节配置自愈**：扫 `/etc/**/*.apk-new`，活文件 0 字节/缺失 且包内原版有内容 → 恢复（`update.d/*` 755，其余 644）
2. **信任链**：conf 空则从 `mozilla/*.crt` 重建；bundle 缺失或比 conf 旧则 `update-ca-certificates`；校验证书数 >100
3. **PMTU**：wlan 接口 MTU > 1400 → 降到 1400；`power_save=on` → off

### 3.2 触发点（双保险）

| 触发 | 文件 | 时机 |
|---|---|---|
| OpenRC boot | `/etc/local.d/elden-bringup.start` | 等 wlan0 UP 后（最多 120s）跑一次 |
| NM dispatcher | `/etc/NetworkManager/dispatcher.d/50-net-selfheal` | 接口 `up` / `connectivity-change` |

### 3.3 冷启动验证（关键：不是"改完就宣称修好"）

```
# 注故障态 → reboot
ip link set wlan0 mtu 1500
: > /etc/ca-certificates.conf; : > /etc/ssl/certs/ca-certificates.crt
iw dev wlan0 set power_save on

# 重启后（~70s 回来）
mtu     = 1400                       ✅ 自动降
conf    = 4854 bytes                 ✅ 自动重建
bundle  = 181724 bytes / 121 certs   ✅ 自动重建
/run/net-selfheal.log: problems=0
curl https://mirrors.ustc.edu.cn/ → 200   ✅
```

### 3.4 已回灌仓库（避免重刷镜像丢失）

| 位置 | 改动 |
|---|---|
| `scripts/net-selfheal.sh` | 新增（真源） |
| `rootfs/build-rootfs.sh` | helper 清单加 `net-selfheal.sh` |
| `rootfs/persistent-overlay/usr-local-sbin.tar.gz` | 加入 `net-selfheal.sh`（内容 diff 仅此一项） |
| `rootfs/persistent-overlay/etc-local.d.tar.gz` | 更新（含 boot 触发） |
| `rootfs/persistent-overlay/etc-NM-dispatcher.tar.gz` | 新增（含 dispatcher 触发） |
| `rootfs/persistent-overlay/restore.sh` | 装 dispatcher + 立即跑一次 |

### 3.5 设备侧备份

`/root/netfix-backup-20261018/`：8 个 `.apk-new` 原件、`/etc/ca-certificates.conf`、bundle、`elden-bringup.start` 原件。

---

## 4. 未解 / 下一步

1. **残留 10% 失败未根治**。候选方向（按性价比排序）：
   - **让 ClientHello 不跨 MTU**：`openssl.cnf` 加 `Groups = X25519:P-256:P-384` 排除 MLKEM（实测 curl 20%→2%，但 git 未改善 → 需再验）
   - 抓 NM 的上游 DHCP（若热点哪天开始下发 MTU option 就能自动跟随）
   - 判断中间盒在热点侧还是运营商侧：需要**非热点出口**对照（校园网有线不能出校，未完成 → 下次有条件时做）
2. **为什么 8 个 `/etc` 文件被清成 0 字节**未定。线索：`fsync`/`tar` 解包中断、或 ext4 `needs_recovery`（本次启动 `EXT4-fs (sda17): recovery complete`）。建议下次检查 `tar --overwrite` 的部署脚本与 UFS 掉电。
3. `CONFIG_SUSPEND=y` 启动即死（vk128/vk129）仍悬置（见 `reports/suspend-enable-vk128-vk129-fail-20261018.md`）。

---

## 5. 复现命令

```sh
# 诊断
ssh root@192.168.7.1 '/usr/local/sbin/net-selfheal.sh --check; echo rc=$?'

# 一键修
ssh root@192.168.7.1 '/usr/local/sbin/net-selfheal.sh'

# 量化 HTTPS（改前/改后对比用）
ssh root@192.168.7.1 'ok=0;bad=0; for i in $(seq 20); do \
  curl -sS -o /dev/null --max-time 15 https://gitlab.freedesktop.org/users/sign_in \
  && ok=$((ok+1)) || bad=$((bad+1)); done; echo "ok=$ok bad=$bad"'

# 确认真实路径 MTU（DF 扫描）
ssh root@192.168.7.1 'for s in 1472 1420 1400 1392 1372; do \
  ping -4 -c1 -W1 -M do -s $s 151.101.3.52 >/dev/null 2>&1 \
  && echo "-s $s OK (mtu $((s+28)))" || echo "-s $s FAIL"; done'
```
