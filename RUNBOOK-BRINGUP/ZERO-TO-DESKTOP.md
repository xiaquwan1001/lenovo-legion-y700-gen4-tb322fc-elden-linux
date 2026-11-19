# 从 EDL/fastboot 到可用桌面 —— 端到端重建链（2026-11-19 实测版）

> **本文件回答**：一块 TB322FC（elden）不管现在是原厂 Android、只剩 fastboot、还是半刷坏，
> **只靠主机 + EDL(9008) + fastboot + ssh**，怎么一步步把它变成「b 槽持久直启 → 完整 Linux → 能登入 → 出桌面」，
> 并且**每一步都能复跑、都有判据、都能溯源到证据**。
>
> 与兄弟文档的分工（别重复读）：
> | 文档 | 管什么 |
> |---|---|
> | `RUNBOOK-BRINGUP/README.md` | 首次上机全流程 Phase −1…6（从未动过的新机） |
> | `RUNBOOK-BRINGUP/LINUX-STATE-REPRO.md` | 「Linux 进度 = 8 项状态(A–H)」+ S0–S9 复现 + 卡 BL 误判防护（**状态视角**） |
> | `RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md` | 精简分区表设计 |
> | **本文件** | **今天的实际链路（EDL → 分区 → 启动件 → 起机 → 网络/时间 → 根扩容 → 基线 → 桌面 → GPU）**，
> 带「每步的失败形态」，供以后溯源「哪一环坏了、怎么回到已知好态」 |
>
> 纪律出处 = `.pi/AGENT-OPS.md`；坑号 = `PITFALLS/`；本次全账 = `TASKS/sessions/2026-11-19-EDL到桌面端到端重建.md`。

---

## 0. 链路总览（12 步，S1–S12）

```
[主机]                            [设备]                                  判据（可复跑）
S1 通道自证 + 只读取证     →  fastboot / adb / EDL 9008 三种入口           getvar product < 5 s
S2 GPT 手术表（LUN0/LUN4）  →  linux17 193 GiB + userdata 256.7 GiB；槽属性  主备 GPT 逐字节一致
S3 最小根写入（EDL）        →  ext4 @LBA 73277435，6 GiB                  qdl sha256 == 主机 sha
S4 boot.img 重打 + 刷 boot_b →  内核/DTB/cmdline=elden_root=LABEL=linux      读回 sha + manifest
S5 起机                     →  /init → systemd → usb-gadget → ssh          lsusb 1d6b:0104 + ssh 通
S6 显示（udev）             →  systemd-udevd → 模块自动加载 → DPU/DSI/DP 全 bound   /dev/dri/card0 + fb0
S7 网络（NCM + 主机 NAT）    →  默认路由 192.168.7.3 + DNS 上游              curl http=200
S8 时间（RTC 只读）          →  NTP step（失败退 HTTP Date）               date -u = 现时
S9 根扩容                   →  6 GiB → 190 GiB（在线 resize2fs）           df -h /
S10 日用基线                →  49 包 + locale/字体/IM/zram 配置            daily-baseline --check MISS=0
S11 桌面壳                  →  greetd → phoc → phosh（seatd 后端）         三进程 + grim 截图有顶栏
S12 GPU（可跳过但有代价）    →  Mesa 26.1.6（trixie-backports）= Adreno 830   eglinfo renderer
```

一句话记忆：**「EDL 管内容，fastboot 管启动，udev 管硬件，NCM 管网络，greetd 管桌面」**。
今天两次「看起来像内核坏了」的假象分别落在 S5（缺 `/init`）和 S6（缺 `udev`）。

---

## 1. 前置（设备无关，一次性）

```sh
cd ~/y700-elden
export SN=HA2EXB0E BLK=/dev/sda          # 另一单元改 SN；容量相关值一律现读 GPT
bash scripts/linux-state-audit.sh --host  # A–H 资产齐不齐、sha 对不对
pi-sudo probe                            # 免密特权通道自检（apt/ip/service 白名单）
```

主机工具：`~/edl/qdl/build/qdl`（EDL 写/读）、`fastboot`、`ssh`、`scripts/*`。
**所有 fastboot 命令带 `-s $SN`**（总线上可能有第二台机，`#371`）。

---

## 2. 分步：命令 / 判据 / 失败形态

### S1 通道自证 + 只读取证（不许写）

```sh
pgrep -af "[f]astboot"                                   # 孤儿进程数（>0 先清）
timeout -k 5 20 fastboot -s $SN getvar product           # < 5 s 才算通道好（#658）
for v in current-slot slot-successful:b slot-unbootable:b slot-retry-count:b; do
  timeout -k 5 6 fastboot -s $SN getvar $v 2>&1 | head -1; done
timeout -k 5 20 fastboot -s $SN oem edl; sleep 6; lsusb | grep 05c6:9008   # 进 EDL
```
- EDL 一次会话只能做一件事：**多条 `qdl` 命令不能跨会话**（`#675`，会话结束设备即离开 9008）。
- 失败形态：`getvar` 卡 > 5 s ⇒ 先查孤儿 fastboot，别怀疑设备。

### S2 GPT（Linux 的空间从哪来）

```sh
# 只读：LUN0/LUN4 主备表
python3 scripts/slot-attr.py show --sn $SN         # 槽属性（双表对比）
python3 scripts/gpt-audit-tb322fc.py --dev <dump> --stock ~/文档/TB322FC_15.10.259
# 写前必做：快照 + 校验（P0-5）
python3 scripts/gpt-preflight.py snapshot --lun 0 --out /tmp/pre-write-snapshot.json
python3 scripts/gpt-preflight.py compare  --snapshot /tmp/pre-write-snapshot.json --new /tmp/gpt-new.bin
```
- 今天用的手术表：`linux17` **193 GiB @LBA 73277435**、`userdata` 256.7 GiB；**安卓侧分区一个不动**
  （`super`/`vbmeta_system`/`metadata`/`rawdump`/`pstoredump` 保留）⇒ 安卓实验面随时可回。
- 写后用 `qdl read` **回读主备两表逐字节比**（本次 `80ab46e5…` / `e5f79c0e…`）。
- 失败形态：只写主表不写备表 ⇒ ABL/TZ 读到旧表，现象是「分区大小没变」。`slot-attr.py` 双表报警就是防这个。
- 槽属性：`mark-successful b` 之后必须回读 `slot-successful:b = yes`（`#677`/`#678`：a 槽和 b 槽的 bit 语义不同，
  只能用同槽原厂基线比）。

### S3 最小根写入（EDL）

```sh
# 写 6 GiB 镜到 linux17 起始 LBA；镜像里必须已经有 /init、usb-gadget、udhcpd.conf（#680）
timeout -k 5 1800 ~/edl/qdl/build/qdl \
  write $BLK/73277435 out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img
# 设备端自证（不信退出码，#669）
timeout -k 5 1800 ~/edl/qdl/build/qdl sha256 $BLK/73277435+12582912
```
- 判据 = 设备端 sha256 == 主机 `sha256sum`（本次 `abf96ec4…`），速度参考 **43.4 MiB/s**。
- 失败形态：镜像缺 `/init` ⇒ S5 起得来但 **USB 完全不枚举**、只有背光，与内核坏无法区分（`#680`）。

### S4 启动件：boot.img 重打 → 刷 boot_b

```sh
bash scripts/build-boot.sh --kernel <Image> --dtb <elden.dtb> --ramdisk <rd> \
     --cmdline "… elden_root=LABEL=linux …" --out out/boot-elden-<tag>.img
# 重打链可信性判据（强证据）：同输入重打 == 原件逐字节（本次 bdf47f5f… == vk192）
timeout -k 5 60 fastboot -s $SN flash boot_b out/boot-elden-<tag>.img
timeout -k 5 60 fastboot -s $SN getvar slot-successful:b
```
- 零写盘试发：`fastboot boot <img>`（RAM 起，不落盘）；写盘后一定要 `qdl sha256 4/…` 或读回比。
- 失败形态：`fastboot boot` 落回 fastboot 而无串口/背光闪 ⇒ **不能**判「镜像是坏的」——
  先按 `scripts/build-boot.sh` 正规重打（手工改尾部 DTB 会被 ABL 拒，见 `TASKS/sessions/2026-11-19-显示nodp实验与RAM路径复核.md`）。

### S5 起机判据（别再说「设备坏了」）

```sh
lsusb | grep 1d6b:0104                       # gadget 枚举 = /init → usb-gadget 跑到了
pi-sudo ip-addr add 192.168.7.3/24 dev enx021e5eede102   # 主机侧（gadget 重建后地址必丢）
timeout -k 5 20 ssh -o StrictHostKeyChecking=no root@192.168.7.1 'uname -r; ps -p1 -o comm='
```
- 判据三连：`lsusb` 有 gadget、`ssh` 通、`ps -p1` = `systemd`。
- 无 gadget 时先看有没有 `ttyACM`（`scripts/acm-sh.py` 可以无网络进 root shell，OOB 兜底）。
- 失败形态与对应真因（今天两条都踩过）：
  | 现象 | 真因 |
  |---|---|
  | 只有背光、USB 不枚举、不闪 | 根里缺 `/init`/`usb-gadget`（`#680`） |
  | 只有背光、USB 枚举、ssh 通、无 `/dev/dri` | 根里缺 `udev`（`#681`） |

### S6 显示：`udev` 是整条链的总闸

```sh
ssh root@192.168.7.1 'systemctl is-active systemd-udevd; ls /dev/dri; \
  cat /sys/kernel/debug/device_component/ae01000.display-controller; dmesg | grep -c "bound ae94000.dsi"'
```
- 今天真因：minbase 根**没装 udev** ⇒ 模块零自动加载 ⇒ fastrpc/ath12k/音频链全缺 ⇒
  DP 组件 `defer` 拖死 DPU 聚合（`aggregate not bound`）⇒ 只有背光。
- 修复：`apt install udev && systemctl enable --now systemd-udevd`，然后 `modprobe fastrpc` 等按需加载。
- 判据：`/dev/dri/card0` + `/dev/fb0`、DPU aggregate `bound`、`/dev/fastrpc-adsp` 在、音频卡出现。
- **别做的实验**：摘 `dpu_intf0_out/remote-endpoint`（nodp）**不是**修复：控制臂证明改 DTB 后 USB 零枚举
  （`TASKS/sessions/2026-11-19-显示nodp实验与RAM路径复核.md`）。

### S7 网络：设备侧没有默认网关，主机侧 NAT 出口要选对

```sh
# 主机：NAT（注意出口 —— 本机默认路由是手机热点 192.168.42.129）
iptables -t nat -C POSTROUTING -s 192.168.7.0/24 -j MASQUERADE || \
  iptables -t nat -A POSTROUTING -s 192.168.7.0/24 -j MASQUERADE
sysctl -w net.ipv4.ip_forward=1
```
- 设备侧（**已固化成服务，见 S11 的 `deploy-desktop-shell.sh`**）：
  - `usb0-host-route.service`：常驻自愈循环，每 15 s 检查缺默认路由就补（只在宿主 ping 通时补）；
  - `/etc/systemd/resolved.conf.d/99-usb-dns.conf`：`DNS=223.5.5.5 202.38.64.18`（minbase 只有 stub，无上游）。
- 判据：设备 `timeout 15 curl -s -o /dev/null -w '%{http_code}' http://deb.debian.org/debian/` = 200，
  `resolvectl query deb.debian.org` 有结果。
- 失败形态：主机 NAT 误写 `-o eno1`（校园网口）⇒ 设备能解析但连不通；用 `tcpdump` 看实际出口。

### S8 时间：RTC 写不了，冷起时间必然是「镜像构建日」

```sh
ssh root@192.168.7.1 'date -u; sh /usr/local/sbin/time-sync.sh; date -u'
```
- 事实：PMIC RTC 对我们是**只读**（`hwclock -w` → ENODEV）⇒ 冷起时间为 2026-04-13（构建日，**不是 1970**）。
- `time-sync.sh`（本次修过）：等默认路由 → **先 `systemctl stop chronyd`**（否则 `chronyd -q` 报
  "Another chronyd may already be running" 并一步不跳）→ `chronyd -q` 重试 12×20 s →
  失败退 **HTTP `Date:` 头**（门槛用 `chronyd -q` 退出码，**不用**日期阈值）→ 交回 `systemctl start chronyd`。
- 已串行化（`flock /run/time-sync.lock`）：`/init` 冷起一次 + 路由就位补跑一次，不打架。
- 判据：`date -u` = 现时；`chronyc tracking` stratum > 0。
- 失败形态：时钟错 ⇒ apt 的 TLS 报 `certificate verify failed`（看起来像源坏了）。

### S9 根扩容（6 GiB → 190 GiB，一条命令）

```sh
ssh root@192.168.7.1 'blockdev --getsize64 /dev/sda17; resize2fs /dev/sda17; df -h /'
```
- ext4 支持**在线增长**；本次 6.25 GB → 190 GiB（`50593792` 4K 块），耗时 ~2 s。
- 判据：`df -h /` 的 Size ≈ 分区大小（193 GiB 分区 ⇒ 190 GiB fs）。

### S10 日用基线（包 + 配置，两件套）

```sh
bash scripts/mobian-daily-baseline.sh --check   # 先看缺什么
bash scripts/mobian-daily-baseline.sh           # 装 P0+P1（49 包）+ 配置
```
- 表：`rootfs/debian/daily-baseline.tsv`（P0/P1 装、P2 只登记）；配置：`rootfs/debian/daily-baseline.sh`
  （sudo NOPASSWD / locale zh_CN / 字体 / fcitx5 unit / zram 门 / GPU devfreq）。
- 判据：`--check` 尾行 `MISS=0`。本次首跑 `MISS=21 → MISS=1`（唯一剩项 = 桌面用户不存在，由 S11 建）。

### S11 桌面壳：`scripts/deploy-desktop-shell.sh`（本次新增，幂等 + `--check`）

```sh
bash scripts/deploy-desktop-shell.sh --check   # 只报告
bash scripts/deploy-desktop-shell.sh           # 收敛到「有桌面」
```
它按顺序保证（每条都有 `ok/MISS/FIX` 行）：

| # | 保证 | 关键事实 |
|---|---|---|
| 1 | 包集：`phosh phoc greetd seatd gnome-session-bin phosh-osk-stub libglib2.0-bin gnome-settings-daemon upower dbus-x11` | `phosh-osk-stub` 必装：phosh 会话 `RequiredComponents` 含 `sm.puri.OSK0`，缺它 = `gnome-session-failed` + 黑底转圈（`#682`） |
| 2 | 桌面用户 `xuqianhui1001`（uid 1001，组 video/render/…） | `rootfs/debian/ensure-desktop-user.sh`；greetd `initial_session` 没有这个用户就只打一行 error |
| 3 | `/usr/local/sbin/elden-session-user`（与仓内逐字节同） | 必须 `LIBSEAT_BACKEND=seatd`（logind 后端 ⇒ 会话被 deactivate ⇒ phoc 释放 DRM ⇒ 面板挂死） |
| 4 | `time-sync.sh` 同源 | 见 S8 |
| 5 | `/etc/greetd/config.toml` appliance 模式 + `zz-elden.conf` drop-in | 覆盖 Debian `greetd-phrog` 的图形 greeter（否则停在登录界面） |
| 6 | 软合成开关 `/etc/elden-soft-render` | 仅当 Mesa 不认 Adreno 830 时；判据 = journal `fd_pipe_new2` |
| 7 | `usb0-host-route.service` 自愈 + resolved DNS 上游 | 见 S7 |
| 8 | `gpu-devfreq-tune.service`（min_freq 525 MHz / poll 10 ms） | daily-baseline §5 只写运行时，重启即回 160 MHz ⇒ 首绘卡顿（T19） |
| 9 | 会话现态：greetd active + `phoc`/`phosh`/`phosh-osk-stub` 三进程 + `grim` 截图 > 20 KB | 截图落设备 `/tmp/desk-deploy.png`，可 `scp` 回主机目视 |

- 起不来的两种典型与处置（都在脚本里判）：
  - greetd `start-limit-hit` + journal `MESA: error: fd_pipe_new2: unsupported GPU id 0x0` ⇒ `touch /etc/elden-soft-render`（pixman）；
  - journal `Unable to find required component 'sm.puri.OSK0'` ⇒ 装 `phosh-osk-stub`。
- 上机后是**锁屏**（「向上滑动以解锁」）；没有 `/dev/uinput`（内核未开 `CONFIG_INPUT_UINPUT`）⇒ **解锁必须人手滑**。

### S12 GPU（性能档）：Mesa 版本决定有没有硬件渲染

```sh
# 判据：phoc 打开 renderD128 = GL 渲染在跑；否则是 pixman 软合成（帧率低）
ssh root@192.168.7.1 'ls -l /proc/$(pidof phoc)/fd | grep -c renderD128'
runuser -u xuqianhui1001 -- env XDG_RUNTIME_DIR=/run/user/1001 WAYLAND_DISPLAY=wayland-0 \
  eglinfo | grep "renderer"
```
- 事实：**Debian 13 trixie 自带 Mesa 25.0.7 的 freedreno 不认识 Adreno 830**（`chip id 0xe844050000`）⇒
  phoc GL 后端起不来（`#683`）。两条路：
  1. `touch /etc/elden-soft-render`（pixman 软合成，桌面能用但帧率低）；
  2. **推荐**：`trixie-backports` 的 **Mesa 26.1.6** ⇒ `OpenGL ES 3.2 … Adreno (TM) 830`。
```sh
echo "deb https://mirrors.ustc.edu.cn/debian trixie-backports main contrib non-free" \
  > /etc/apt/sources.list.d/backports.list
apt-get update
apt-get install -y --no-install-recommends -t trixie-backports \
  mesa-libgallium libgl1-mesa-dri libegl-mesa0 libglx-mesa0 libgbm1 mesa-vulkan-drivers \
  libglapi-mesa libosmesa6
rm -f /etc/elden-soft-render && systemctl restart greetd
```
- 出分（本次，GPU 路径）：`glmark2-es2-wayland -b :duration=4 build` → **Score 2594**，分项 FPS 1453–2967（窗口档）。
  对照：pixman 软合成（上一档）同机明显掉帧，用户目视即「帧率很低」。

---

## 3. 一页速查（从 fastboot 到桌面）

```sh
cd ~/y700-elden; export SN=HA2EXB0E
# 1) 起机（内核/根都已在盘上）
timeout -k 5 30 fastboot -s $SN reboot; sleep 45
# 2) 主机侧网络
pi-sudo ip-addr add 192.168.7.3/24 dev enx021e5eede102
# 3) 验活
timeout -k 5 20 ssh -o StrictHostKeyChecking=no root@192.168.7.1 'uname -r; ps -p1 -o comm=; date -u'
# 4) 链路自检（网络/时间/桌面/Gpu 全在一处）
bash scripts/deploy-desktop-shell.sh --check
# 5) 有缺就收敛
bash scripts/mobian-daily-baseline.sh && bash scripts/deploy-desktop-shell.sh
# 6) 截图目视（非黑底转圈 = 桌面壳活着）
scp root@192.168.7.1:/tmp/desk-deploy.png /tmp/desk.png
```

---

## 4. 回退矩阵（每步的「后悔药」）

| 步 | 回退动作 | 资产 |
|---|---|---|
| S2 GPT | 刷回写前快照（`gpt-preflight.py snapshot` 的 json + 表 bin） | `backup/HA2EXB0E-16+512/edl-apply-readback-20261118-200922/pre-write-*.bin` |
| S3 根 | 原厂 `userdata`/`super` 未动 ⇒ 重刷 super 即回 Android；Linux 根重写只需换镜像 | `out/min-restore-20261119/*.img` |
| S4 启动件 | `fastboot flash boot_b bootslot-b/boot_b.img`（vk192 自签件 `06c081ca…`） | `bootslot-b/`、`out/boot-elden-vk192.img`（`bdf47f5f…`） |
| S5–S8 系统配置 | 全是根内文件 ⇒ `debugfs`/`resize2fs` 前先 `e2fsck -fy` 回滚镜像，或重写 S3 | — |
| S11 桌面 | `systemctl disable --now greetd` 回纯 ssh 维护态；`rm /etc/elden-soft-render` 回 GL 档 | — |
| S12 Mesa | `apt-get install -t trixie mesa-*`（或删 backports.list + 重装 25.0.7） | 包管理器可逆 |

---

## 5. 溯源表（本次每个数字的证据）

| 事实 | 值 | 证据 |
|---|---|---|
| linux17 起点 LBA / 体量 | 73277435 / 193 GiB | `TASKS/sessions/2026-11-19-主线恢复最小Linux与显示定位.md`、GPT 主备 sha |
| 最小根写入速度 / sha | 43.4 MiB/s / `abf96ec4…` | 同上（`out/min-restore-20261119/*.sha256`） |
| boot_b 件 sha | `740d431b…` | 同上；重打链对照 `out/boot-elden-test-ctrl.img` = `bdf47f5f…` |
| 显示真因 = 缺 udev | DPU/DSI/DP/GPU 全 bound、fb0 1904×3040 | `TASKS/sessions/2026-11-19-显示修复=minbase缺udev.md` |
| 根扩容 | 6.25 GB → 190 GiB（50593792 块） | 本会话命令输出 |
| 日用基线 | 49 包、`MISS=21 → 1` | `scripts/mobian-daily-baseline.sh` 输出 |
| 桌面壳 | greetd active + 3 进程 + 截图 78–141 KB | `scripts/deploy-desktop-shell.sh` 输出、`/tmp/desk-y700.png` |
| 时钟修复 | `chronyd -q` step 18955589 s；冷起模拟通过 | `/run/time-sync.log`（tries=0 ntp_ok=0） |
| GPU | `Adreno (TM) 830` / Mesa 26.1.6 / glmark2 2594 | `eglinfo`、`glmark2-es2-wayland` 输出 |
| 软合成负档 | phoc `fd_pipe_new2 unsupported GPU id 0x0` | `journalctl -t phoc` |

---

## 6. 三个「看起来像硬件坏了」的假象（记住它们的判据）

1. **只有背光 + USB 不枚举** → 根里缺 `/init`/`usb-gadget`（`#680`），不是内核/硬件。
2. **只有背光 + USB 枚举 + 无 `/dev/dri`** → 根里缺 `udev`（`#681`），不是 DTB/DP 布线。
3. **桌面黑底转圈** → 缺 `sm.puri.OSK0`（`#682`）或 Mesa 不认 GPU（`#683`），不是显示器。
