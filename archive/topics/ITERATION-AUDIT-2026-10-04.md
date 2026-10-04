# 迭代流程 / 版本控制 / 并发 审计 — 2026-10-04

> 目的：在**不追加新功能**的前提下，审计从最早可追溯的 vk34 至今的构建-验证链路，
> 找出「每次改动都要重编内核 + fastboot 往返」的真实成本来源，给出可落地的三层快环方案。
> 结论按「先数字、后细节」。本文件是**过程证据**（archive，只增不改）。

---

## 0. 一句话结论

| 维度 | 现状 | 问题等级 |
|---|---|---|
| 版本控制 | 顶层仓 58 commit **无 remote**；内核仓**浅克隆**；**vk34–39、vk43、vk49 无 commit**；无 vk↔sha 标签；boot 镜像**不可复现**（vk49 的打包命令已丢失） | 🔴 高 |
| 迭代流程 | 驱动 payload 绝大多数 `=y` → 改一行也全量重编内核；ccache **已装但缓存为 0**（未接入构建）；无 DTB-only 路径 | 🔴 高 |
| Linux→fastboot | `eldroid-bootctl reboot bootloader`（PSCI 钩子）**已通**；`flash-b.sh` 可在 Linux 内 dd 写 b 槽；但文档引用的 `scripts/cycle.sh` **不存在** | 🟢 基本就绪 |
| kexec 热重载 | `CONFIG_KEXEC_FILE=y` + `KEXEC_SIG` 关；arm64 加载器要**未压缩 `Image`**（已有，62MB）；kexec-tools **设备上已装**（持久根 `/usr/sbin/kexec`、Alpine rootfs `usr/sbin/kexec`） | 🟡 只差脚本与首测 |
| 并发 | `.pi/agents`(6) + `.pi/missions` 齐；无 `.pi/workflows/`；单台设备无互斥锁；API 双限流 | 🟡 中 |

**最高杠杆的单点改动**：把 payload 驱动 `y→m`（一次性全量重编），此后驱动改动进入 **scp+modprobe ≈ 30s** 环。
**第二杠杆**：接入 ccache（当前纯浪费）。

---

## 1. 版本控制审计（含证据）

### 1.1 顶层仓 `y700-elden`
- `git log --oneline | wc -l` = **58**；`git remote -v` = **空（0 行）** ⇒ **无异地备份**，磁盘即单点。
- 无 tag；`vkNN` 与 commit 的映射只存在于 commit message 文本里，不可机读。
- `.gitignore` L10-12：`/geekidos-linux/`（13G 内核树+产物）与 `/Y700-elden-linux/` 被顶层忽略。
  ⇒ 内核进度**名义上**以 `patches/` 为准，实际已经历一次真源迁移（见 1.3）。

### 1.2 内核仓 `geekidos-linux`
- `git rev-parse --is-shallow-repository` = **true**；`.git/shallow` 存在；最老 commit 是
  `ba28ec16f (grafted, origin/v7.2-elden)` ⇒ **上游历史截断**，无法自 v7.2 向上 bisect，GEEKiDoS 基底不可追溯。
- 我们的提交只覆盖 **vk40–vk48**，且分支命名与内容脱节：

| vk | commit | 说明 | out 镜像 |
|---|---|---|---|
| v34 | —（仅 `e72a036ed elden/vk34-recon` 反推） | 无真实提交 | （历史） |
| v35–v39 | — | 无提交；残留 `rootfs-thermal-vk36.cpio.gz`、`config-vk38-camera` | 部分 |
| v40 | `6ef87e6a8` | "现场状态，含未清理调试插桩，未收口" | vk40 / vk40re |
| v41 | `4b643f169` | PSCI SYSTEM_RESET2 vendor-reset（reboot bootloader/edl） | vk41-psci |
| v42 | `eb432f18a` | 干净重落 vk39 两项（音频+温控） | vk42 |
| **v43** | **无 commit** | 镜像存在（00:20）但树未提交 | vk43 |
| v44 | `26cc186e9` | DMIC capture | vk44 |
| v45 | `a923477be` | VA macro vdd-micb + DMIC rate | vk45 |
| v46 | `4c68eb5ed` | WCD939x codec 启用 | vk46 / vk46-ram |
| v47 | `bd114ca33` | WCD939x 采集（单 WCD link） | vk47 / vk47a |
| v48 | `5a70ade46` (HEAD) | WCD939x 耳机播放（未验证） | vk48 |
| **v49** | **无 commit** | 相机模块 + `.config`（内核源未变，KV 仍 `g5a70ade46a88`） | vk49 / boot_b-vk49 |

- 分支现状：
  - `elden/vk42-audio-thermal`（HEAD）实际线性携带 **vk40→vk41→vk42→vk44→vk45→vk46→vk47→vk48**（名实不符，且缺 vk43）。
  - 侧分支：`elden/vk41-psci-reboot`、`elden/v1-thermal-only`(f681b616a)、`elden/v2-audio-only`(951c5f1c2)、
    `elden/vk34-recon`(e72a036ed)、`elden/vk40-2026-10-03`。A/B 隔离做过（v1/v2 是好实践），但未 tag、未合并归档。
- `CONFIG_LOCALVERSION_AUTO=y` + `CONFIG_LOCALVERSION="-debug"` ⇒ KV = `7.2.0-debug-g<sha>[-dirty]`。
  好处：KV 自带 commit 溯源。**坑**：树一脏就多个 `-dirty`，模块 vermagic 随之变，热加载会失配。

### 1.3 `patches/` 与 git 的双真源问题
- `patches/elden-working-tree-*.patch` 已**过期**（`git diff --stat` 现在为空，说明工作树改动已入库）。
- 但仓里仍并存：`patches/0001..0011*.patch`（部分重构）、完整 working-tree patch、以及 git 提交。
  ⇒ 三份可能不一致的"补丁真源"。规则应明确：**已提交的 → 只在 git；未提交的候选 → 只在 `patches/candidate-*`**。

### 1.4 构建不可复现（最要命的一条）
`scripts/build-boot.sh` 默认 ramdisk 候选：
```
out/rootfs-overlaid.cpio.gz | out/rootfs.cpio.gz | out/rootfs-vk11.cpio.gz
```
**不含** `out/rootfs-overlaid-camera.cpio.gz`。而 vk49（92MB vs vk48 83MB）显然用了相机 ramdisk，
即由 `RAMDISK=...` 或 `ROOTARGS=` 覆盖构建，**该命令未被记录**。后果：vk49 无法用默认命令重建。
此外 `mkbootimg` 写入时间戳，未设 `SOURCE_DATE_EPOCH` ⇒ 逐字节不可复现。

### 1.5 版本控制改进建议（不新增功能）
1. **加 remote 并 push 顶层仓**（异地灾备）；顶层仓同时 push tag。
2. **内核仓去浅**：`git fetch --unshallow`（或 `--deepen`）。若网络不可，至少 `git log` 留档并记录已知基底 sha。
3. **补提交 tip**：把 vk43 与 vk49 的树状态各补一个 commit（`elden: vk43/vk49 ...`），关闭"镜像无源"缺口。
4. **打 tag**：`vkN` → sha，annotated 携带 `{KV, Image sha256, .config sha256, ramdisk sha256, boot.img sha256}`。
   已存在的 vk40–v48 全部回填。
5. **每镜像一份 manifest**：构建时写 `out/boot-elden-<vk>.manifest`（上述哈希 + `git describe --dirty` +
   mkbootimg argv + cmdline），并把 manifest（纯文本、KB 级）提交进仓。⇒ 任何 vk 可机读复现与审计。
6. **消歧补丁真源**：删除过期 `elden-working-tree` 补丁，`patches/` 只留 candidate；写一条规则进 `PITFALLS`。
7. **`build-boot.sh` 显式化**：ramdisk 必须显式（`RAMDISK=` 或 `--with-camera`），并设 `SOURCE_DATE_EPOCH`。
8. **KV 稳定性**：迭代期用固定 `CONFIG_LOCALVERSION`（不带 `-dirty` 漂移）或统一用 `git stash` 保持树干净，
   避免 vermagic 抖动破坏模块热加载。

---

## 2. 迭代流程审计

### 2.1 现状成本
- `scripts/build-kernel.sh` 恒为 `make -j$(nproc) Image.gz dtbs` —— **改一个 `.c` 也重建 Image.gz，改 DTS 也连带内核目标**。
- 内核树 13G、现存 `.o` **10921** 个 ⇒ `make` 本可增量，但：
  - **ccache 装了没用**：`ccache -s` = 缓存 0.0 GiB；`build-kernel.sh` 的 `CROSS_COMPILE` 未包 ccache，`CC` 未覆盖。
  - 一旦 `make clean`/改 config（如 y→m 会连带大量目标）或换树，就是冷编译。
- payload 驱动**几乎全是 `=y`**（实测 `.config`）：

| 驱动 | 现态 | 建议 |
|---|---|---|
| SND_SOC_SC8280XP / WCD939X / QDSP6 / QCOM_Q6V5_PAS | `=y` | → `=m`（音频是当前热点） |
| BT_QCA / BT_HCIUART / ATH12K | `=y` | → `=m` |
| DRM_MSM / DRM_PANEL_NOVATEK_NT36536 | `=y` | → `=m` |
| INPUT_AW86927 / TOUCHSCREEN_NOVATEK_NVT36XXX_SPI | `=y` | → `=m` |
| I2C_QCOM_CCI / 相机 sensor / wl2868c | `=m` ✅ | 已模块化，保持 |
| USB_DWC3 / CONFIGFS / UFS / 串口 / clk/pinctrl/GCC | `=y` | **保持 =y**（rootfs 依赖） |

- **模块热加载已半通**：`scripts/package-camera-modules.sh`（打包+`depmod` 生成 `modules.dep.bin`）、
  `scripts/deploy-camera-modules.sh`（**不刷机不重启**，scp→depmod→按序 modprobe）、`scripts/camera-modules-load.sh`（加载器）。
  ⇒ 通用化这三件即得「30s 模块环」。缺的是：`make modules` 的**单模块增量**封装 与 通用（非相机）ROOTS 列表。

### 2.2 三层快环（设计，由快到慢）
- **环 0 · 模块环（最重要，目标 ~30s/次）**
  `scripts/mod-loop.sh <驱动名>`：`make M=<dir> modules` → `depmod` → scp → `rmmod/modprobe` → 采证。
  运行期内核固定不动（防 vermagic 失配），正是它逼我们只碰模块、不越界改核心。
- **环 1 · DT 环（目标 ~2min）**
  `scripts/iterate.sh --dtb-only`：若 `Image.gz` 哈希未变则**跳过内核构建**，只 `make dtbs` → `mkbootimg` → 签名 → `fastboot boot`。
  微扰可用 `CONFIG_OF_OVERLAY=y`（已开）走 configfs overlay，**零重启**先试再回写 DTS。
- **环 2 · 内核环（不可避免时）**
  `scripts/kexec-boot.sh`：见 §3。省掉 fastboot/ABL/AVB 往返。

### 2.3 ccache 接入（立即收益）
在 `build-kernel.sh` / `iterate.sh` 里：
```
export CROSS_COMPILE="ccache aarch64-linux-gnu-"
export CCACHE_DIR=$HOME/.cache/ccache-kernel-elden
ccache -M 20G
```
配合 `CONFIG_DEBUG_INFO` 关闭或 `-gz` 策略，重复构建（含改 config 引起的连带重编）可显著缩短。

---

## 3. Linux→fastboot 与 kexec 审计

### 3.1 Linux→fastboot（基本就绪）
- **`eldroid-bootctl reboot bootloader`** 已把 Linux→fastboot 打通（PSCI SYSTEM_RESET2 vendor reset，vk41）。
- `scripts/flash-b.sh`：在 **Linux 内 dd 写 b 槽**（免主机 fastboot），配 `sign-boot-b.sh` 完成 AVB 签名。
- **缺口**：文档/注释多处引用 `scripts/cycle.sh`，但该文件**不存在**（`ls` 空）——死引用，应清除或补实现。
- 建议：补 `scripts/to-fastboot.sh`（`sync` → 可选刷 boot_b → `reboot bootloader` → 轮询 `fastboot devices`），
  作为"需要必要刷写时"的统一入口。

### 3.2 kexec 热重载（只差脚本+首测）
已核实的前置条件**全部满足**：
- `CONFIG_KEXEC_FILE=y`，`# CONFIG_KEXEC_SIG is not set` ⇒ 未签名镜像可载。
  `CONFIG_KEXEC`（旧 syscall）未置 ⇒ 必须走 **kexec_file_load**（kexec-tools 自动/`-s`）。
- arm64 `arch/arm64/kernel/kexec_image.c:image_probe()` 只认 **未压缩 ARM64 `Image`**（校验 `ARM64_IMAGE_MAGIC`）。
  已有 `linux/arch/arm64/boot/Image`（62 MB）。**`Image.gz` 不能用于 kexec**。
- kexec-tools **设备上已装**：持久根 `/usr/sbin/kexec`；Alpine rootfs `usr/sbin/kexec`（199KB）。

建议 `scripts/kexec-boot.sh`：
```
Image=/.../linux/arch/arm64/boot/Image
DTB=/.../sm8750-lenovo-elden.dtb
kexec -s -l "$Image" --dtb="$DTB" [--initrd="$RAMDISK"] --command-line="$CMDLINE"
kexec -e
```
风险与纪律：
- 单变量首测：先用**已知可启的同源 Image**验证 `kexec -e` 能起，再拿新内核上。失败时 kexec 失败会保留当前内核运行（安全）；
  若新内核 panic，watchdog/slot 回退兜底。
- SoC 级外设（UFS/PCIe/WiFi/相机）可能在 kexec 后未干净复位 —— 属"可接受的降级"：kexec 用于**快速验证核心内核**，
  正式签刷仍走 fastboot。需在首测里逐项采证。

---

## 4. 并发审计与建议

- **资产**：`.pi/agents/` 6 角色（audio-graphopen/camera/proxy-waydroid/smoke/thermal/win-x86-poc）+ `.pi/missions/` 10 份背景。
  无 `.pi/workflows/`（确定性编排脚本未沉淀）。
- **约束**：
  - API **双限流**：20 请求/滚动窗口 + 每 key $30/3h 预算（见全局记忆）。并发子代理须 ≤3，且注意同 key 共享。
  - **设备是唯一串行资源**：并行 agent 若同时 SSH/modprobe/重启会互相破坏。需**设备互斥锁**（`flock` 或 mkdir lock，经 SSH）。
  - 宿主构建是 CPU 争用点：`make -j$(nproc)` 同时跑多份会互相拖慢；应串行化构建或按 ccache 受益。
- **建议**：
  1. 加 `scripts/device-lock.sh`（`flock ~/.cache/elden-device.lock`）供所有上机脚本 source。
  2. 沉淀 `.pi/workflows/`：如「多候选内核并行构建（宿主）+ 串行上机验收」的确定性编排。
  3. 明确角色边界：**宿主侧可并行**（构建/静态分析），**设备侧严格串行**。

---

## 5. vk34→vk49 版本账（供回填 tag/commit）

```
v34  无commit(反推 e72a036ed)   v35-v39 无commit
v40  6ef87e6a8  v41 4b643f169   v42 eb432f18a   v43 无commit
v44  26cc186e9  v45 a923477be   v46 4c68eb5ed   v47 bd114ca33
v48  5a70ade46(HEAD)            v49 无commit(相机模块+.config, KV=g5a70ade46a88)
```
设备当前（审计时）跑 **vk46**（`uname -r = 7.2.0-debug-g4c68eb5ed4e3-dirty`），根 `/dev/sda17`；
`/lib/modules` 仅存旧 KV `7.2.0-debug-gba28ec16f01f-dirty` ⇒ **持久根模块与运行内核失配**（模块环必须先 depmod 当前 KV）。

---

## 6. 行动清单（建议顺序，均"审计/整理"范畴，未实施）

| # | 动作 | 收益 | 风险 |
|---|---|---|---|
| V1 | 顶层仓加 remote + push；打 vk40–v48 tag；补 vk43/vk49 commit | 灾备 + 溯源 | 无 |
| V2 | 内核仓 `--unshallow` | 可向上 bisect | 网络 |
| V3 | 每镜像 manifest + 提交 | 可复现/审计 | 无 |
| V4 | 清过期 working-tree patch，`patches/` 只留 candidate | 消除双真源 | 无 |
| I1 | 接入 ccache | 构建提速 | 无 |
| I2 | `scripts/mod-loop.sh` 通用模块热加载环 | 30s/次 | 需先有 `=m` |
| I3 | `elden-dev.config`：payload 驱动 y→m（保启动路径 =y） | 一次性全量后进入快环 | 需一次全量重编+验收 |
| I4 | `scripts/iterate.sh --dtb-only` | DTB 改动 2min | 无 |
| K1 | `scripts/kexec-boot.sh` + 同源首测 | 免 fastboot 换核 | SoC 外设复位未知 |
| F1 | `scripts/to-fastboot.sh`；清除 `cycle.sh` 死引用 | 统一刷写入口 | 无 |
| C1 | `scripts/device-lock.sh`；沉淀 `.pi/workflows/` | 并发安全 | 无 |

> 建议先做 **V1–V3 + I1**（纯整理、零风险、立即见效），再按 **I2→I3** 打开模块快环，
> **K1** 与 **I4** 并行验证，最后 **F1/C1** 收尾。

---

## 7. 实施落地（2026-10-04 同日）— 本文档§1–§6 的行动项已部分执行

### 勘误
- §1/§5/§6 称「`scripts/cycle.sh` 不存在、死引用」——**错误**。`cycle.sh` 存在于**仓库根**（不在 `scripts/`），
  `--soft/--fastboot/--dtbo/--recover/--wait` 齐全。正确表述：`cycle.sh --soft` 在 b 槽直启后**不再落 fastboot**，
  `--fastboot`（misc BCB）**ABL 不认**（PITFALLS #65/#66）；可靠路径是 PSCI vendor reset（vk41+）。

### 已落地
| 项 | 产物 | 状态 |
|---|---|---|
| I1 ccache | `scripts/env-build.sh`（`CROSS_COMPILE="ccache aarch64-linux-gnu-"`，缓存 `~/.cache/ccache-elden`，20G） | ✅ 接入 `build-kernel.sh`/`mod-loop.sh`/`iterate.sh` |
| V3 manifest | `scripts/build-manifest.sh`（内核/DTB/config/ramdisk 哈希 + cmdline + mkbootimg argv + 两个 git HEAD） | ✅ `build-boot.sh` 每次自动生成 `out/boot-elden-<ver>.manifest` |
| V1a tag | 内核仓 `vk41 vk42 vk44 vk45 vk46 vk47 vk48` 已打；`vk43`/`vk49` 无 commit，**诚实留白** | ✅ |
| I2 模块环 | `scripts/mod-loop.sh`（编 `M=<dir>` → depmod → scp → rmmod/modprobe；KV 不符则拒绝） | ✅ |
| I3 模块化 | `patches/fragment-modular.config`（音频/ATH12K/触觉/触屏/背光；实测 y→m 无 bool 子项拉回）<br>`patches/fragment-modular-video.config`（DRM/panel，**可选**，牺牲启动早期显示） | ✅ 待一次性全量重编 |
| I4/kernel/dtb | `scripts/iterate.sh {mod\|dtb\|kernel\|ram} [--kexec\|--boot\|--flash]` | ✅ |
| K1 kexec | `scripts/kexec-boot.sh`（file-based，未压缩 Image，默认复用设备 cmdline；`--load-only` 先验） | ✅ 待首测 |
| F1 fastboot | `scripts/to-fastboot.sh`（PSCI vendor reset；`--flash` 先在 Linux 内 dd boot_b） | ✅ |
| C1 并发 | `scripts/device-lock.sh` + 三个设备脚本自锁（flock，`DEVICE_LOCK_HELD` 防嵌套死锁） | ✅ 互斥已本机验证 |

### 未落地（仍待办）
- **V1b remote + push**：等 GitLab 项目路径；**V2 unshallow**；**V4** 清过期 `patches/elden-working-tree-*.patch`。
- **I3 验收**：应用片段需一次全量重编（ccache 暖后约一次；耗时以 `build.sh` 实测为准）。
- **K1 首测**：`kexec-boot.sh --load-only` → 已知可启内核 → 才正式 `kexec -e`。
- 顶层仓 `scripts/` 与根目录 `build.sh/pack.sh/cycle.sh` 的**入口收敛**（目前根脚本保留兼容）。
