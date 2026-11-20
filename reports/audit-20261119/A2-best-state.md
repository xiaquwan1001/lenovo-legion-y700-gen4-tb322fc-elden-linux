# A2 — 各子系统「历史最优」与最强可复现组合（主机侧，只读审计）

审计代理: A2-best-state / 生成时间: 2026-11-19 23:1x / 只读（零 git 写、零设备接触、零安装）
核验方式：仓库根已核 `git rev-parse --show-toplevel` = `/home/xuqianhui/y700-elden`（首条命令，零改动）；
来源 = `INDEX.md` §0、`reports/audit-20261119/A1-phase-timeline.md`、`reports/audit-20261119/A5-forks.md`、
`TASKS/README.md` §0/§1/§2/§7、`DEVICE/README.md` §1.1、`reports/README.md`。
设备现态一律**直接引用主会话 2026-11-19 22:37 起实测**（本文不 ssh、不重跑设备命令）。

> **存在性核实口径**：下表每行的「主机路径」都在本文写作时用 `ls -l` 核过一次（只列尺寸/时间，**未跑 sha256sum**）；
> 标「未取证」= 该路径不在盘上或本次未核（不猜）。
> **前任代理轨迹**：按要求定位了 `~/.pi/agent/sessions/.fabric/--home-xuqianhui-y700-elden--/`
> `2026-11-19T14-07-10-949Z_ea539eaa…jsonl`（前任 A2）与 `…14-07-11-034Z_d698c9f3…jsonl`（前任 A8），
> 但两文件各仅 ~10 KB、逐行解析后**只含 `message.role/model/usage` 元数据，正文（content/tool 结果）已缺失**
> ⇒ 前任结论**未取证、不可并入**；本文全部结论改为由 SSOT 文档 + 主机现存件重建。
> 另：`reports/audit-20261119/README.md` 列有 `A8-device-state.md`，本次 `ls` 该目录**无此文件**（未取证，不在本文引用）。

---

## 1. 分子系统「历史最优」表

### 1.1 内核 / DTB / boot.img

| 子系统 | 历史最优（判据） | 主机现存件（`ls -l` 核实） | 证据指针 |
|---|---|---|---|
| 内核（UTS + commit） | `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`；tag `vk192`；两枚提交 `5c72e9e838`（pstore/ram 守卫：拒绝与 initrd 重叠的 ramoops zone）+ `4bdf1711b5`（HEAD）。在机现态（22:37 实测）同此 UTS | 产物 `out/boot-elden-vk192.img` 85815296 B（Nov 16 12:16）；manifest `out/boot-elden-vk192.manifest`（记录 `kernel_release`、`kernel_payload_sha256=0a55e52c…`） | `DEVICE/README.md` §1.1「历史：在机 = 持久化的 vk192」；`out/boot-elden-vk192.manifest`；`reports/device-session-20261116-vk192.md`（存在，4462 B） |
| 内核源树 | **已丢失**：`build/`（37 G 内核树/worktree）+ `geekidos-linux/`（2.1 G 浅克隆）+ 软链 `linux` 于 2026-11-19 磁盘清理删除（删前导脏改动 `reports/build-m3v2-7.3rc7-dirty-20261119.patch`，提交 `0c98d793`） | `build/` 现只剩 `phoc-src-0.58.0`、`phoc-src-0.59~rc1`、`phosh-src-0.58.0`（已 ls 核实）；重建命令写在 | `versions/layout.tsv:42-49`（删除登记 + `git clone --filter=blob:none backup/git-slim-20261113/geekidos-all-20261113.bundle` 恢复三行命令）；影响 `reports/disk-cleanup-20261119-validation-impact.md`（9640 B，存在）；逐行登记 `versions/kernel-src-archive.tsv`（7176 B，存在） |
| 构建脚本 | `scripts/build-kernel.sh`（唯一入口：禁裸 `make`，否则按宿主 x86 重写 `.config`）；打包 = `scripts/build-boot.sh` + `scripts/build-manifest.sh` | `scripts/build-kernel.sh` 2535 B（Oct 27）、`scripts/build-boot.sh` 5882 B（Nov 19 16:14）、`scripts/build-manifest.sh` 6224 B（Nov 14）——**均存在** | `AGENTS.md`「内核构建只走 scripts/build-kernel.sh」；`versions/layout.tsv` |
| DTB | `sm8750-lenovo-elden.dtb`，`dtb_packed_sha256=89c9336d92e398adb76df0866f4bb53626a5af5d2eff91d9840a32ed0b9ec1dc`；打包源路径 `build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb`（**该树已删 ⇒ 源文件已丢失**，二进制值仍可从 boot.img 解出） | `out/vk188-bootfiles/elden.dtb`、`out/vk188-bootfiles/padded/elden.dtb` 存在（**属 vk188 代，非 vk192**，未 sha）；vk192 的 DTB 仅存于 | `out/boot-elden-vk192.manifest`（`dtb_packed_sha256` 行） |
| boot.img（持久件） | `boot_b` 自签 vk192：分区读回 `06c081ca…`；空载件 `bdf47f5f…`（96 MiB 分区件在 `bootslot-b/`） | `bootslot-b/boot_b.img`（`ls -l bootslot-b/boot_b*.img` 命中 9 个，最新 `boot_b-minbase-labellinux-20261119.img` 100663296 B Nov 18 20:08）；`out/boot-elden-vk192.img` 85815296 B | `DEVICE/README.md` §1.1（`06c081ca…` / `bdf47f5f…`）；`reports/device-session-20261116-vk192.md` |
| boot.img（桌面现役件） | `elden_root=LABEL=linux` 的最小根配套件（sha `7ea9370b…`，85815296 B） | `out/p2-minbase-20261118/boot-minbase-labellinux.img` 85815296 B（Nov 18 11:21）——**存在**；同件另存 `bootslot-b/boot_b-minbase-labellinux-20261119.img` | `INDEX.md` §0「卡什么」第 1 条（`7ea9370b…`）；`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` S4 |

### 1.2 rootfs（三代，物理互斥：同一 `linux17` 只能一版）

| 代 | 尺寸 / 包数 / label | 主机现存件（`ls -l`） | 证据指针 |
|---|---|---|---|
| **190 GiB 现役（最优）** | `/dev/sda17` 190 G、用 6.2 G；dpkg **1256**；label `linux` | **无主机镜像**（在线 `resize2fs` 出的，设备侧状态，非主机件）—— 未取证为主机文件 | `INDEX.md` §0 首条「现态（22:37 起实测）」；`DEVICE/README.md` §1.1；`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` S9（`resize2fs` 6 GiB→190 GiB） |
| **minbase 6 GiB（可复现起点）** | 6 GiB 稀疏（实占 2.1 G）、**160 包**、label `linux`、1510 个 `.ko`、44 M 固件、15 项门禁全绿、sha256 `d22c6a00…` | `out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img` **6442450944 B**（Nov 18 11:29）+ `.sha256`（130 B，内容核对 = `d22c6a00d5c2…3a5da764`）——**存在** | `INDEX.md` §0「卡什么」第 1 条 ③；构建器 `scripts/rootfs-minbase-build.sh`（1951 B，存在，需真 root，`podman`/`proot` 实测不行 = `PITFALLS #676`） |
| day-1 旧根 / 旧 `linux17` 数据 | **已丢失**：EDL 6 点采样（起点 73277435 及 +10/+50/+134/+275/+359 GiB）非零字节**全 0**；成因 = 原厂 `userdata`(449.7 GiB) 覆盖 + `fastboot -w` discard | 无（`ls` 无对应归档；`reports/linux-state-*` 只有审计 TSV 结论） | `INDEX.md` §0 深夜条首条；`DEVICE/README.md` §1.1「旧 `linux17` 根 fs 已确认丢失」；取证 `reports/bl-stuck-20261118-forensics.md`（17296 B，存在） |

### 1.3 桌面链 / GPU / 输入

| 项 | 历史最优 | 主机现存件（`ls -l`） | 证据指针 |
|---|---|---|---|
| 桌面壳 | **greetd + phoc + phosh + phosh-osk-stub 四进程**（22:37 实测）；`deploy-desktop-shell.sh --check` = **MISS=0**；锁屏截图有顶栏/中文 | `scripts/deploy-desktop-shell.sh` 19545 B（Nov 19 17:12）——存在；手册 `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` 19375 B（Nov 19 17:58）——存在 | `INDEX.md` §0 首条与「13:20 桌面」条；`DEVICE/README.md` §1.1；`TASKS/sessions/2026-11-19-EDL到桌面端到端重建.md`（5203 B，存在） |
| GPU / Mesa | **Mesa 26.1.6（trixie-backports）= `Adreno (TM) 830` / GLES 3.2**；`glmark2-es2` **Score 2594** | 无主机镜像（版本在设备侧）；判据文本在 `DEVICE/README.md` §1.1 —— `grep 2594` 在该行命中 | `DEVICE/README.md` §1.1；`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` S12；坑 `PITFALLS #681–#685`（老 Mesa 不认 Adreno 830） |
| 自编 phoc/phosh（T20 电源键 + 撕裂） | phoc 0.59~rc1 / phosh 0.58.0 两枚自编件，`dpkg-divert` + `apt-mark hold` 固化 | `build/phoc-src-0.59~rc1/`、`build/phosh-src-0.58.0/`、`build/phoc-src-0.58.0/` 三个目录存在；安装器 `scripts/phoc-install.sh`（未逐一 ls，但 `scripts/build-phoc-arm64.sh` 7245 B 存在） | `INDEX.md` §0 第 5 条「桌面层两回归已闭环」；`PITFALLS #654`；`scripts/phoc-install.sh` |
| 桌面内自动验证 | **不可自动化**：内核未开 `CONFIG_INPUT_UINPUT` ⇒ 无 `/dev/uinput` ⇒ 锁屏必须人手滑开 | 配置片段 `patches/fragment-uinput.config` **336 B（Nov 13 11:36）存在**（= 重编内核即可开） | `INDEX.md` §0「卡点（需人）」；`patches/fragment-uinput.config` |
| 链路一条命令自检 | `scripts/zero-to-desktop-check.sh`（S5–S12 只读，输出每步 ok/MISS；`--dry-run` 主机可跑） | `scripts/zero-to-desktop-check.sh` 6704 B（Nov 19 14:07）——存在 | 脚本头注释（对应手册 S5–S12；退出码 0/1/3/2） |

### 1.4 外设与网络

| 项 | 历史最优 | 证据指针（+ 现存件） |
|---|---|---|
| WiFi | `wlan0` = **ustcnet 114.214.230.246，默认路由经 wlan0**；`usb0` 192.168.7.1 保留 SSH（22:37 实测）。历史根因两条已闭环：候选榜塌缩 = NM 1.52 写死 bgscan（修 = `wifi-scan-refresh.service` 每 150 s 显式 RequestScan）；`ath12k` 早启 `-110` = 时序问题（修 = `ath12k-rescan.service`） | `INDEX.md` §0 首条；`TASKS/README.md` §1 G1-36 行（`scripts/wifi-scan-refresh.sh`、`reports/wifi-scan-stale-20261019.md` 7251 B 存在）；`reports/audit-20261119/A1` §(a)「网络与时钟」 |
| 音频 | G1-4 收口：tplg MI2S **SD0→SD1 线错**修复 + WCD939x 麦克风 bring-up；播放用户实听、`arecord/aplay -D default` rc=0。残余非阻塞 = Q33 冷起 20 s 读重试 | `TASKS/README.md` §1 G1-4 行、§5 Q33 行；现存件 `scripts/audio-tplg/{SM8750-Lenovo-Y700-Gen4.m4 4158 B,build.sh 547 B}`、`scripts/audio-ucm/{HiFi.conf 1655 B,Lenovo-Y700-Gen4.conf 119 B}`、`scripts/audio-alsa-init.sh` 3317 B —— **均存在** |
| 相机 STREAMING | 后摄 s5kjns **30.06 fps** / 前摄 gc08a8 **30.26 fps** 满帧 + 三个 AE 独立 bug（vk127，2026-10-18）；残余 = libcamera 不认 `MEDIA_ENT_F_FLASH`、flash LED NTC 温控（可选） | `reports/camera-linux-vk127-20261018-agc-rootcause.md` 4836 B（存在）；`TASKS/README.md` §1 G1-5 行 |
| 传感器 | G1-34 最优 = `/dev/fastrpc-adsp` 在 + `net.hadess.SensorProxy` accel/light/prox **三项 true**（vk185-adsp，2026-10-30）；上游形态 = M10（已投 1×250）。**11-19 新根上回退**：`hexagonrpcd` attach ADSP sensor PD 硬崩整机 + Debian 13 无 `libssc2` ⇒ 六件 mask 含 hexagonrpcd | `TASKS/README.md` §1 G1-34 行、§7 M10 行；`reports/debian-root-accounts-sensors-20261026.md` 4838 B（存在）；坑 `PITFALLS #692/#324`；`INDEX.md` §0 首条（mask 清单） |
| Waydroid（G2 主链） | G2 = **10/13**；C1 治本（`CONFIG_IPV6_MULTIPLE_TABLES`，vk103 出网 200）、C2 GMS 登录（人工验证）、C4 UDP 传感器 HAL、C5 容器相机真帧（10 帧 Y mean 107）、C6 音频、C10 马达透传、C11 中文 IME 均通；**C3 已实测收口**：SPIC `deviceRecognitionVerdict=[]` ⇒ BASIC/DEVICE/STRONG 三档全不满足（结构性：无 TEE），PIF 伪装未做 | `TASKS/README.md` §0 与 §2 C1/C2/C3/C4/C5/C6/C10/C11 行；`reports/c3-spic-verdict-20261115.md` 6246 B（存在）；`reports/waydroid-camera-provider-rootcause-20261019.md` 16340 B（存在） |
| UEFI（拓展，非主线） | **两形态都通**：① flashed（真根因 = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我方 DTB，清 `dtbo_a` 即通，2026-11-10）；② 间接 GRUB（真根因 = Mu UEFI 把 initrd buffer 分配进 DTB `ramoops@c2000000`，内核 t=0.0269 s 注册 printk 控制台写掉 initrd；修法 ① pstore/ram 拒绝重叠 zone 真机 A/B 通过 + 上游 3×250，2026-11-15/16）。11-14 夜第 2 轮间接形态判据 = cmdline `androidboot.serialno=51318dc0` 且无 ABL token，14 s 到 SSH、零写盘 | `INDEX.md` §0 第 4 条；`reports/uefi-dtbo-a-rootcause-20261110.md` 8259 B、`reports/uefi-grub-initrd-rootcause-20261115.md` 7969 B、`reports/pstore-ram-initrd-guard-20261116.md` 10980 B —— **均存在**；件 `out/uefi-20261104R-r1.img`、`out/uefi-20261104R21-hostdiag-r1.img` 各 67198976 B（存在）；QEMU 对照 `scripts/qemu-full-chain-smoke.sh` 4947 B（存在，单轮 ~35 s） |
| 安卓精简 v1/v2/v3（G2 共存线） | **v1 = 现役**（`super_min.img` 8.28 GiB，`/system` 5.0 GiB，读回 `e3d0d26f…` 逐字节一致，连续两发 `boot_completed=1`）；**v3 = 已造件未采用**（`system_a.img` 3920 MiB、`super_min_v3.img` 7109 MiB；删 41 预装池 + `etc/AI` + `bgmusic` + 18 leaf 包）；v2 = 仅方案。**上机 3 发均未进桌面，其中 2 发被 `misc` BCB=`boot-recovery` 污染 ⇒ 不作数** | 件：`out/android-slim-v3-20261119/new/{system_a.img 4110417920 B, super_min_v3.img 7454326784 B, SHA256SUMS 162 B}` —— 存在；v2b 臂 `out/android-slim-v2b-20261119/new/{system_a.img 5821693952 B, super_min_v3.img 9165602816 B}` —— 存在；脚本 `scripts/android-slim-v3-build.sh` 15674 B、`scripts/android-linux-coexist-check.py` 3801 B —— 存在 | `reports/android-slim-v3-20261119.md` 16385 B（存在）；`TASKS/sessions/2026-11-19-安卓共存契约与v3精简上机.md` 8090 B（存在）；`DEVICE/README.md` §1.7；`INDEX.md` §0 首条「下轮纪律」 |
| 共存契约 | Android = `super 90504..5857671` + `userdata 5972392..73277434`；Linux = `linux17 73277435..123871226` + `boot_b`；16 条目两两不重叠，`coexist-check rc=0`；实测刷安卓 3 次 Linux 全程可登 | `DEVICE/README.md` §1.7；`scripts/android-linux-coexist-check.py`（存在） |
| 上游补丁系列 | **我方主线合入 = 0**。**在飞**：mdss v5（答 sashiko 0xa000）、dsi-phy v2、pstore guard 3 枚、wl2868c v11（唯一收到人回：Rob 11-16 要求 v12 补回 R-b）、板 DTS 单提交 + gamma v2 + haptics v2 + dwc3 v9。**已发并归档**：Q28 证据回帖（MID `<179488903160.260870…@mail.ustc.edu.cn>`，三处归档正文逐字节同，`sha256 4fe84148…`）⇒ **在档未发件清零**。**等回复/暂不投**：camss CSIPHY 2.4.0 v2（6 门全绿，缺一次上机出流回归；等 Qualcomm CAMSS v8 落地再定）；M9 kexec LPI 已被 Marc Zyngier 否决并撤回；M7 结论 = 上游 `rpmhpd: Skip retention by default` 已含（不需我方补丁） | `INDEX.md` §0 第 6 条；`reports/upstream-status-20261113.md` 12860 B、`reports/upstream-replies-20261117.md` 19782 B（均存在）；`TASKS/README.md` §7 M1–M10 行；补丁件目录 `patches/upstream/`（`ls` 命中 60+ 系列，含 `camss-csiphy-24-v2-20261117/`、`dwc3-v10-20261118/`、`haptics-v3-20261118/`、`board-dts-single-20261113-sent-20261117/`） |
| G3（拓展） | Steam **登录界面 ✅**（2026-10-28 设备实测 3/3，截图判据 10-29 闭环）；游戏端到端未做 | `reports/g3-steam-20261028.md` 16795 B（存在）；`TASKS/README.md` §0 G3 行 |

---

## 2. 「最强可复现组合」（主机侧可重造的那一套）

### 2.1 组合定义（同时满足 显示 + SSH + 网络 + GPU + 桌面）

| 部件 | 取哪一件 | 现存路径 / 判据 |
|---|---|---|
| boot 件 | `elden_root=LABEL=linux` 最小根配套件，payload = vk192 内核（UTS `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`）+ DTB `89c9336d…` + ramdisk | `out/p2-minbase-20261118/boot-minbase-labellinux.img`（85815296 B，sha 声明 `7ea9370b…`）；同代空载件 `out/boot-elden-vk192.img`（85815296 B，sha `bdf47f5f…`）+ manifest `out/boot-elden-vk192.manifest` |
| rootfs | minbase 6 GiB（label `linux`，160 包）→ 上台 `resize2fs` 到 190 GiB → 日用基线 1256 包 | `out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`（6442450944 B，sha256 `d22c6a00…`，`.sha256` 在盘） |
| 桌面部署 | `scripts/deploy-desktop-shell.sh`（9 步幂等；`--check` 出 MISS）+ `scripts/zero-to-desktop-check.sh`（S5–S12 只读自检） | 两脚本均存在（19545 B / 6704 B） |
| 判据（收尾门） | `deploy-desktop-shell.sh --check` = **MISS=0**；四进程 greetd/phoc/phosh/phosh-osk-stub；Mesa 26.1.6 `Adreno (TM) 830`；`wlan0` 默认路由 + `usb0` SSH；1944 GiB 分区 `/` = `/dev/sda17` | 设备现态（22:37 实测，主会话）；手册 `RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` S5–S12 |

**为什么是这一套而不是 vk192 原持久件**：vk192 空载件（`bdf47f5f…`）本身只是内核/DTB/initrd 载体，能 SSH 能显示但没有桌面栈；
桌面栈是**根里的包 + udev + Mesa backports**（1.3 表），所以「最优可复现」= 同一内核 + 最小根 + 幂等部署脚本三件套。

### 2.2 A 段：零写盘 `fastboot boot` 验证（不改任何分区）

```bash
cd /home/xuqianhui/y700-elden
# 0) 先过 QEMU 对照（判 EFI-stub/initrd/fbcon 面，单轮 ~35 s；真外设面 QEMU 判不了）
timeout -k 3 120 bash scripts/qemu-full-chain-smoke.sh
# 1) 主机侧 USB-NCM 通道（设备在 fastboot 或系统内都先备好网络侧）
timeout -k 3 60 sudo scripts/ncm-host-up.sh
# 2) 零写盘起机（RAM 臂；件 = minbase 配套 boot 件）
timeout -k 3 120 fastboot boot out/p2-minbase-20261118/boot-minbase-labellinux.img
# 3) 起机后验活（判据：findmnt / = LABEL=linux；SSH 通；fb0 有字样）
timeout -k 3 30 ssh -o BatchMode=yes root@192.168.7.1 'findmnt -no SOURCE,FSTYPE /; uname -r; systemctl is-active graphical.target'
# 4) 一条命令链路自检（S5–S12，只读；--dry-run 可先在主机上验命令形状）
timeout -k 3 180 bash scripts/zero-to-desktop-check.sh
timeout -k 3 120 bash scripts/deploy-desktop-shell.sh --check     # 期望 MISS=0
```
零写盘臂的风险点（已登记）：`fastboot boot` 后要显式 `slot-attr.py mark-successful b` 并补 retry（`PITFALLS #672`）；
纯 RAM 变体（不启桌面/会话）不能当功能测试件（`PITFALLS #92/#93`）。

### 2.3 B 段：持久写入（只在设备窗口内、且 A 段绿之后做）

```bash
cd /home/xuqianhui/y700-elden
# 1) 最小根写入 linux17 起始 LBA（EDL；写前快照 GPT 主备表，写后设备端自证 sha，不信退出码）
timeout -k 3 900 scripts/edl-write-rootfs.sh        # 入口见 RUNBOOK S3（PITFALLS #669 双尺子）
# 2) 刷 b 槽（持久启动）
timeout -k 3 120 fastboot flash boot_b out/p2-minbase-20261118/boot-minbase-labellinux.img
timeout -k 3 60  fastboot --set-active=b && timeout -k 3 60 fastboot reboot
# 3) 上台扩容（6 GiB → 190 GiB）
timeout -k 3 60 ssh root@192.168.7.1 'resize2fs /dev/sda17 && df -h /'
# 4) 日用基线 + 桌面壳（幂等，可反复跑）
timeout -k 3 900 bash scripts/deploy-desktop-shell.sh
timeout -k 3 180 bash scripts/zero-to-desktop-check.sh
# 5) 槽位收口（否则下次掉电可能落回 a 槽）
timeout -k 3 60 python3 scripts/slot-attr.py mark-successful b
```
B 段前置 = **共存契约不动**（`super`/`userdata`/`metadata`/`boot_a` 零改动；`boot_b` + `linux17` 是我们的两件）；
A6 审计已登记「回退口径」：`linux` 起点 LBA 90504 与原 `super` 起点重叠的历史设计（GPT-minimal）已废，真回退 = 写回旧表 + 重刷官方 `super`
（`RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md` §4、`PITFALLS #673`）。

---

## 3. 距最优还差什么（≤5 条，每条 = 动作 + 依赖）

| # | 差什么（现状判据） | 动作 | 依赖 |
|---|---|---|---|
| 1 | **桌面内验证不能自动化**：内核未开 `CONFIG_INPUT_UINPUT`（无 `/dev/uinput`），锁屏必须人手滑 | 走 `scripts/build-kernel.sh` 整套 + `patches/fragment-uinput.config`（336 B 在盘）重编并部署整套 `/lib/modules/<UTS>`，再 `deploy-desktop-shell.sh --check` 回归 | 设备窗口（要重刷 b 槽）+ 主机编译资源（`make -j26`） |
| 2 | **传感器在新根回归**：`hexagonrpcd` attach ADSP sensor PD 硬崩整机、Debian 13 无 `libssc2`（现被 mask） | 先建取证通道（串口 / ramoops 窗），再自建 `libssc` + `-Dssc=true`；核上保留 M10 形态（`qcom,non-secure-domain`，已投） | 设备窗口 + 人（串口/取证窗）+ 上游（M10 接受） |
| 3 | **安卓 v3 未进桌面**（G2 共存主卡点）：3 发未进，其中 2 发 BCB=`boot-recovery` 污染 | 按已定序 S1–S5：清 BCB + 读回校验 → 原厂 `metadata.img` → 原厂 `super` 对照 → 二分 v2b → 带 `console=ttyGS0` 的 boot 件拿日志 | 设备窗口（每步都是写盘动作，需用户放行）+ 人（读 logfs/pstoredump） |
| 4 | **上机出流回归缺失**，卡住唯一成体系的待投系列 camss CSIPHY 2.4.0 v2（6 门全绿） | 一次 s5kjns/gc08a8 30 fps 出流回归；并盯 `SM8750 CAMSS v8` 是否落地（落则删本系列 binding 枚） | 设备窗口 + 用户裁决（是否允许「无实测」声明）+ 上游 |
| 5 | **内核源树已删** ⇒ `versions/vk-kernel-identity.tsv` 的 `src_ref/src_tag` 不可核（§5d 75 行 WARN） | 按 `versions/layout.tsv:47-49` 三条命令从 `backup/git-slim-20261113/geekidos-all-20261113.bundle` 重克隆 + 软链，再重跑身份核对（**禁重跑** `scripts/vk-identity.py` 全量写表，按 `AGENTS.md` 版本账纪律） | 主机侧（无设备）；磁盘空间 + 时间（~37 G 树重建） |

---

## 4. 取证清单（本文引用件的一次性 `ls -l` 结果，未 sha）

| 路径 | 尺寸 | 结论 |
|---|---|---|
| `INDEX.md` / `TASKS/README.md` / `reports/README.md` | 54765 / 185010 / 77879 | 存在 |
| `reports/audit-20261119/A1-phase-timeline.md` / `A5-forks.md` | 20725 / 33296 | 存在（README.md 8262 B 亦在） |
| `scripts/build-kernel.sh` / `build-boot.sh` / `build-manifest.sh` | 2535 / 5882 / 6224 | 存在 |
| `scripts/rootfs-minbase-build.sh` / `deploy-desktop-shell.sh` / `zero-to-desktop-check.sh` / `qemu-full-chain-smoke.sh` | 1951 / 19545 / 6704 / 4947 | 存在 |
| `out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`（+ `.sha256`） | 6442450944（130） | 存在 |
| `out/p2-minbase-20261118/boot-minbase-labellinux.img` | 85815296 | 存在 |
| `out/boot-elden-vk192.img` / `out/boot-elden-vk192.manifest` | 85815296 / 2895 | 存在 |
| `bootslot-b/boot_b*.img` | 9 件，各 100663296 | 存在（最新 `…-minbase-labellinux-20261119.img`） |
| `out/android-slim-v3-20261119/new/{system_a,super_min_v3}.img` | 4110417920 / 7454326784 | 存在 |
| `out/android-slim-v2b-20261119/new/{system_a,super_min_v3}.img` | 5821693952 / 9165602816 | 存在 |
| `patches/fragment-uinput.config` | 336 | 存在 |
| `scripts/audio-tplg/SM8750-Lenovo-Y700-Gen4.m4` 等 4 件 | 4158/547/1655/119 | 存在 |
| `out/uefi-20261104R-r1.img` / `…R21-hostdiag-r1.img` | 67198976 ×2 | 存在 |
| `versions/{layout.tsv,kernel-src-archive.tsv,vk-kernel-identity.tsv}` | 4972 / 7176 / 57741 | 存在（`build/` 内核树已不存在，仅 phoc/phosh 三目录） |
| 前任轨迹 jsonl ×2 | 10831 / 10139 | 存在但**正文缺失（仅元数据）⇒ 结论未取证** |
| `reports/audit-20261119/A8-device-state.md` | — | **不存在**（未取证，本文不引用其内容） |
