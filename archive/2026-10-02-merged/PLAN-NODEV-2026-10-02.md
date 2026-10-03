# 不上机任务清单 — 2026-10-02（**设备无关版**）

> 入口：`INDEX.md` §M；总纲：`MISSION-SCOPE.md`。
> **本文不针对“新机”**：以下准备对**任一 TB322FC 单元**都成立（同型号物理等价，唯一差异 = 容量）。
> 台账：`DEVICES.md`（U1 = `HA2ABH62` 12+256；U2 = 16+512 到货待登记）。

---

## 0. 一句话

**内核 / AOSP / Mesa 构建链在主机会部就位**（交叉 gcc-15、openjdk-11、meson/ninja、ccache、avbtool、mkbootimg、dtc 都在），
**Waydroid Mesa 26.1.8 产物已构建并校验通过**，**Win-x86 离线资产已预置**。
真正需要设备才能做的只有：**GPT dump + EDL 全量备份 + 上机刷写/验收**（**任一处于相应状态的单元均可执行**）。

同型号单元间的**唯一硬差异 = UFS 容量 → GPT 分区布局不同**；手术/逆手术脚本已按「**读实际 GPT**」参数化，
每单元只需一份自己的 dump。**不得跨容量档复用 GPT 二进制。**

---

## 1. A 轨 — 主机可做（现在就能做）

| ID | 任务 | 产出 / 验收 | 命令 / 脚本 | 状态 |
|---|---|---|---|---|
| **A1** | 编「到货基线」内核 | ✅ **`out/boot-elden-vk40.img`**（持久根）+ **`out/boot-elden-vk40-ram.img`**（纯 RAM）；全套模块 `out/modules-7.2.0-debug-gba28ec16f01f-dirty.tar.gz`（strip 20M/1484 个）；config 快照 `patches/config-vk40-bringup` | `build-kernel.sh`→`build-boot.sh`；`ROOTARGS= →RAM 版` | ✅ 完成（补丁 0001–0011 全在树） |
| **A2** | Waydroid Mesa 部署包 | `~/mesa-out/mesa-vendor-26.1.8_waydroid_arm64_only.tar.gz`（已校验 sha256 全 OK、含 DRM chip-id 魔数） | `sha256sum -c manifest.txt` | ✅ 已就绪 |
| **A3** | Waydroid 镜像就位 | GAPPS `system.zip`(1.17G) + MAINLINE `vendor.zip`(77M) 在 `~/下载/` | — | ✅ 已就绪 |
| **A4** | 单元 bring-up kit | ✅ `BRINGUP-UNIT-2026-10-02.md`（**设备无关、容量参数化**）+ `scripts/gpt-dump.sh` + b 槽签名包 `bootslot-b/boot_b_vk40{,-ram}.img` | 本文件 §3 / `BRINGUP-UNIT-*.md` | ✅ 完成 |
| **A5** | 持久 rootfs 归档复核 | `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz`（3.3G/30852 项）可无损恢复 | `tar tzf` 抽验 | ✅ 归档 tar/gzip 完好 |
| **A6** | Win-x86 chroot 预置 | `pkgs-x86/`：ubuntu-base-arm64、hangover 11.16、box64 0.4.5、Strings | `win-x86-rootfs.sh build`（主机侧仅解包） | 🟡 资产全备，脚本可预演 |
| **A7** | 基准脚本预编 | ✅ task-7 一键：`scripts/bench-run.sh`（CPU/mem/disk/GLES/Vulkan，工具自适应+温控采样）+ `scripts/bench-install.sh`（apk 装 sysbench/stress-ng/vkmark/fio） | `sh bench-run.sh` | ✅ 完成（主机冒烟通过） |
| **A8** | TF 卡 A/B 方案 | 换卡对比脚本 + 判据（不动设备） | 承接 `TF卡-2026-09-30.md` | ⬜ 低优先 |
| **A9** | 相机 `.ko` 打包校验 | `out/camera-modules/` **20 个 `.ko`** + tar（20/20）齐 | `modinfo` / tar 抽验 | ✅ vermagic=`7.2.0-debug-gba28ec16f01f-dirty`（**与 A1 新内核必须同版本，否则 .ko 不加载**） |
| **A10** | 文档/INDEX | `MISSION-SCOPE.md`、`DEVICES.md`、`ANDROID-COMPAT-PLAN.md`、`BRINGUP-UNIT-2026-10-02.md`、`ROUTE-DECISION`(v2)、INDEX | — | ✅ 完成（2026-10-02 任务定位重写） |
| **A11** | **G2-S2** Debian guest rootfs | 下 `cloud.debian.org` nocloud **arm64** rootfs（~0.6–2 GB） | `net-egress.sh` / USTC | ⬜ 待做 |
| **A12** | **G2-S2** guest 内核 | 带 **`CONFIG_DMA_RESTRICT_POOL`** 的 arm64 内核（microdroid_defconfig 思路） | `build-kernel.sh` 变体 | ⬜ 待做 |
| **A13** | **G2-S2** 磁盘工具 | `qemu-img`/`virt-resize` | `sudo apt install qemu-utils` | ⬜ 需 sudo |
| **A14** | **G2** 传感器注入原型（`uinput`+UDP sensord） | 补 SLPI 缺口；见 `ANDROID-COMPAT-PLAN.md` §4.1 / T3 | 新写 `scripts/eldroid-sensord.*` | ⬜ 新增（主机可先写） |
| **A15** | **G2** 兼容层验收用例集 | 5 维打分表 + 用例（Play 登录/陀螺/视频通话/DP） | `ANDROID-COMPAT-CASES.md` | ⬜ 新增（主机可先写） |

> **A1 是最大的一块**，也是到货当天的关键路径。注意：内核树当前 `.config` 是 `-debug` 构建，
> 需先确定"正式基线 config"（建议以 `patches/config-vk38-camera` + thermal + audio 0011 的补丁为准），
> 构建前先备份 `.config`，**绝不跑 `olddefconfig` 之外的无 ARCH 的 make**（见 PITFALLS）。
> ⚠️ **vermagic 耦合**：相机 20 个 `.ko` 是 `7.2.0-debug-gba28ec16f01f-dirty`；A1 若改 `CONFIG_LOCALVERSION`
> 或内核版本，必须**整套重编 `.ko`**（`scripts/deploy-camera-modules.sh` + camera 片段）。

---

## 2. B 轨 — 需上机（**任一处于相应状态的单元**，步骤见 `BRINGUP-UNIT-2026-10-02.md`）

按顺序，每步都有回退：

| # | 步骤 | 说明 |
|---|---|---|
| B1 | 开机、记 `serialno`/`hwboardid`/`current-slot`；开 USB 调试，`adb reboot bootloader`；**写入 `DEVICES.md` 台账** | 确认是 `TB322FC_SM8750P_*`（**不限容量档**） |
| B2 | **EDL/fastboot 备份**：b 槽原厂三件套 + **本单元 GPT 双表 dump** → `backup/<SN>-<容量>/` | 救砖基线，**做任何手术前必做** |
| B3 | `fastboot boot out/boot-elden-vk40.img`（RAM 启动，零写入）验证显示/触屏/网/SSH | 保底通道，不碰分区 |
| B4 | GPT 手术：`gpt-surgery-tb322fc.py` 作用于 **B2 的本单元 dump**（`--linux-gib` 按容量档），dd 写回 | 脚本已按实际 GPT 参数化，与容量档无关 |
| B5 | 恢复持久 rootfs 到新 Linux 分区（A5 归档） | 或先跑 vk40 的 rootfs ramdisk |
| B6 | Waydroid（G2-S1）：部署 A2 Mesa 包 + 验证 A1 内核 netd（`XFRM_USER`/`IP6_NF_FILTER`） | 承接 `WAYDROID-*` / `PROXY-WAYDROID-*` / `ANDROID-COMPAT-PLAN` T1 |
| B7 | 音频听力确认（G1#4）、相机出流（G1#5）、task-7 基准 | G1 验收矩阵缺口 |
| B8 | （可选）Android root / 过环境（SUSFS 内核 + KSU 栈）——把该单元切到「Android+root」状态 | `env-pass/` 资产包**可装任一单元** |

---

## 3. sudo 部署清单（主机）

> 结论：**内核 / AOSP / Mesa 构建链已齐，无需新装任何包**。以下仅"可选/遗留"。

| 项 | 命令 | 必要性 |
|---|---|---|
| **fstab 补 `nofail`**（/mnt/Samsung 掉盘会卡开机） | `sudo bash scripts/fix-fstab-samsung.sh`（幂等/自动备份/自带校验） | **建议做**（遗留项） |
| `python3-pycryptodome`（avbtool 签名用） | `sudo apt install -y python3-pycryptodome` | 可选（主线上机走 dd/fastboot boot，不需 AVB 签；SUSFS 内核在 CI 签） |
| `qemu-user-static binfmt-support debootstrap` | `sudo apt install -y qemu-user-static binfmt-support debootstrap` | 可选（跑 `win-x86-rootfs.sh debootstrap` 交叉构建才需要；直接下载 ubuntu-base 已够） |
| `device-tree-compiler` | `sudo apt install -y device-tree-compiler` | 可选（树内有 `linux/scripts/dtc/dtc`） |
| `pigz lz4` | `sudo apt install -y pigz lz4` | 可选（加速 rootfs 压缩） |

> 设备侧 Alpine 包（`iptables-legacy`/`libip4tc`/`libip6tc`/`dnsmasq`/`lxc`/`waydroid`/`python3` 等）
> **不用 sudo**，且已含在 A5 的 rootfs 归档里；如需补装我按 `apk` 离线包准备。

---

## 4. 待确认（v2：只剩设备无关的参数）

1. ~~新平板角色~~ → **作废**：同型号设备等价，**不按机器分角色**（`MISSION-SCOPE.md` §2）。
2. **本次上机目标**：只到「RAM 零写盘验收」还是走到「持久 Linux + Waydroid」？
3. **`LINUX_GIB`**：512G 档 128 GiB（建议）/ 256G 档 65 GiB；**a 槽 Android 默认保住**（G2-S0 兼容下限）。
4. A1/A2/A3/A4/A5/A7/A9/A10 ✅；A6/A8 待办；**A11–A13（G2-S2 预置）+ A14/A15（G2 新项）待做（均不碰设备）**。
