# 发行版上游化可行性（Nura/pmaports · Mobian · Ubuntu Touch/UBports）— 2026-11-21

> 只读 lane 产出：未改 TASKS 正文、未动设备、未删任何 `out/` `backup/`。全部论断给 URL 或仓内路径；拿不到的标「未验证」。
> 本文只回答「能不能向他们提、提什么形状、缺什么、值多少」；不代替 `TASKS/README.md` §7（内核上游化 M 系列）的进度口径。

---

## A. 结论表（先给结论）

| 目标 | 能否提 | 提什么形状 | 前置缺口（我方） | 工作量 | 风险 |
|---|---|---|---|---|---|
| **Nura（原 postmarketOS）** `testing` | **能，但当前被政策挡死**：pmaports 明确禁止「全部或部分由生成式 AI 产生的贡献」，本 lane 的产出形态不可直接提 | `device/lenovo-elden/{APKBUILD,deviceinfo}`＋`firmware-*`＋走 SoC 共享内核包；`deviceinfo_flash_method=fastboot`、`deviceinfo_dtb=qcom/sm8750-lenovo-elden` | ① 贡献必须由作者人工撰写/逐行复核（政策）；② 内核要 LLVM 编译、版本 ≥ 最老在支持 LTS；③ UCM 不能走 forked `alsa-ucm-conf`；④ 无任何 SM8750 设备已进 pmaports（我们是第一个，无 SoC 先例可抄） | 8–12 人日（人工作者） | 中高：AI 政策=硬红线；SoC 无先例；`kconfig check --community` 未跑过 |
| **Nura `main`** | **不建议**（现实不可达） | 需 UEFI 启动、SoC 通用内核、5 人维护团队（多数为团队成员）、两地点 HW CI ≥3 台 | 全部缺；我们是单人单机 | ≥6 个月持续投入 | 高：门槛是组织级而非技术级 |
| **Mobian** | **能，而且是三家门槛最匹配的** | Debian 侧：`droid-juicer` 配置 + `mobian-recipes` 的 `devices/qcom/configs/<soc>.toml` + 带 Debian packaging 的 qcom 内核分支 | ① 内核要 **LTS**（Mobian 只给 stable/testing 发 LTS，我们用 7.3/7.4 非 LTS）；② 需要 `droid-juicer` 的 firmware 提取表；③ phoc/phosh 版本门（sid） | 6–10 人日（不含 LTS 重基） | 中低：AI 政策宽松（Debian GR 2026 选了「负责任使用」）；但需先解决 LTS 版本账 |
| **UBports / Ubuntu Touch（Android/Halium 路线）** | **不能**（路线根本冲突） | Halium = Android 内核 + vendor blob + libhybris；官方原文「Halium is an indispensible part of an Ubuntu Touch port」 | 我们**没有** Android 内核/Halium，也不打算有（G1 = 主线 Linux + 原厂固件正确驱动） | — | 高：等于把项目目标反过来做 |
| **UBports（Linux-based port 路线）** | **技术上有一条缝，但不值得现在走** | UBports 承认「Linux based ports」（x86/Librem 5/PinePhone/PineTab/Pinebook/RPi），走 `ubports/porting/community-ports` 的 `build.sh`+`overlay/`+`uboot/` 形状，桌面是 **Lomiri** | 全套 Lomiri 栈未在本机试过；我们是 phosh；移植仓无 SM8750 先例 | 15–30 人日 | 高：收益低（Lomiri 在 Adreno 830 上未验证），且与 G1 上游化不共享成果 |

**一句话**：**先 Mobian（形状最贴、政策允许），内核侧继续走 linux-arm-msm（三家都受益），Nura 只做「人工撰写」的 device 包准备，UBports 明确不提。**

---

## B. 逐家详述

### B1. Nura（原 postmarketOS，2026-09-27 改名）

**名称与仓库（重要，别再用旧名找文档）**
- 改名事实：`https://en.wikipedia.org/wiki/Nura_(operating_system)` —「**Nura**, formerly known as **postmarketOS** … On 27 September 2026 … renamed to Nura」。
- 仓库仍是 `https://gitlab.postmarketos.org/postmarketOS/pmaports`（文档正文自己引用该路径），文档站已迁 `https://docs.nura.eco/pmaports/main/`，wiki 已迁 `https://wiki.nura.eco/`。

**门槛原文（引文）**
1. 分类判据 `https://docs.nura.eco/pmaports/main/packaging/device-categorization.html`
   - **Main**：「Boot via UEFI.」「Must use generic Nura kernels」「Must not depend on forked device-specific packages, such as forks of `alsa-ucm-conf`.」「A device maintainer team of at least 5 people … Hardware CI in at least two locations for (in total) at least 3 devices.」
   - **Community**：「Close-to-mainline kernel」「Kernel must pass `pmbootstrap kconfig check --community`, which includes working firewall」「Kernel must at least have been upgraded through 3 kernel releases」「Kernel version … may not be older than 6 months」。
   - **Testing**：「Must run a close-to-mainline kernel as new or newer than the oldest supported LTS release」「Kernel must be compiled with LLVM」「Port and dependencies build」「The device boots」。
   - **Downstream**（我们**不**属于这档）：「Device ports using vendor/downstream kernels … only advised to be used as a step towards using mainline」。
2. 包形状 `https://wiki.nura.eco/wiki/Porting_to_a_new_device`
   - 「device packages are placed under `device/{category}`, where `{category}` is the category (main/community/testing/downstream/archived)」；
   - 三个包：`device-vendor-codename`（含 `deviceinfo` + 可选配置如 udev / ALSA UCM）、`linux-vendor-codename`（或「devices running close-to mainline kernels usually use a **shared kernel package** for an SoC (`linux-postmarketos-...`)」）、`firmware-vendor-codename`。
3. **AI 政策（决定性的）** `https://docs.nura.eco/policies-and-processes/development/ai-policy.html`
   - 「**We forbid the use of generative AI tools in Nura.**」「Submitting contributions fully or in part created by generative AI tools to Nura.」「Recommending generative AI tools to other community members…」
   - 移植页顶部也重复该警告：`https://wiki.nura.eco/wiki/Porting_to_a_new_device` —「including the AI Policy, which bans the submission of patches made fully or in part using generative AI」。
4. SoC 现实接受度 `https://wiki.nura.eco/wiki/Qualcomm_Snapdragon_8_Elite_(SM8750)`
   - SoC 页 `Mainline = yes`，CPU/UFS/USB/Display/Audio/Video/Thermal/Pinctrl/Suspend 均 Works，Modem/GPS `Partial`，WiFi/BT/Camera `Untested`。
   - 列出的 SM8750 设备：`oneplus-dodge`、`oneplus-pagani`（**testing**）、`oneplus-ktm`、`samsung-pa1q`、`xiaomi-piano`、`nubia-slogan`；但 pagani 页面 `https://wiki.nura.eco/wiki/OnePlus_13s_(oneplus-pagani)` 明确写「**its device package has not yet been added to the Nura repositories** … Status: _WIP_」，且其内核是私有 fork `github.com/renhiyama/pagani-linux`。
   - ⇒ **现实结论：SM8750 在 pmaports 里目前 0 个成型 port**（未验证是否有人正在提 MR；wiki 层面是 0）。我们若提，是**该 SoC 的第一个包**：机会（无重复劳动）＋风险（无先例、reviewer 无参照、共享内核包 `linux-postmarketos-qcom-sm8750` 需要与别人共建）。

**我方现状对照**

| 门槛 | 我方有什么（路径） | 缺什么 |
|---|---|---|
| close-to-mainline 内核 | 自编 7.3/7.4 线，在机 `vk192`（`INDEX.md` §0）；板 DTS `patches/upstream/board-dts-single-20261113-sent-20261117/0001-*.patch`（183 行，`compatible = "lenovo,elden","qcom,sm8750"`，patchwork `14991580` state=new） | 1) **LLVM 编译**（我们一直 aarch64-linux-gnu GCC）；2) 版本 ≥ 最老在支持 LTS；3) 无「共享 SoC 内核包」形态（我们是设备树+局部补丁树） |
| deviceinfo / 包 | 无 APKBUILD 形态；有等价的设备事实：GPT 布局、`root=LABEL=linux17`、cmdline `elden_root=`（`RUNBOOK-BRINGUP/ZERO-TO-DESKTOP.md` S2/S4） | `deviceinfo` 全套字段（`deviceinfo_flash_method=fastboot`、`deviceinfo_dtb`、`deviceinfo_append_dtb`、`deviceinfo_chassis=tablet`）；`device-$vendor-$codename.md` 功能表 |
| 不 fork `alsa-ucm-conf` | 我们有**自己的** UCM2 与 tplg：`scripts/audio-ucm/{Lenovo-Y700-Gen4.conf,HiFi.conf}`、`scripts/audio-tplg/{SM8750-Lenovo-Y700-Gen4.m4,out/*.bin}` | 这些**必须先进上游 `alsa-ucm-conf`**（Nura main 明令不许 fork；testing/community 也强烈建议），否则只能塞进 device 包（可接受但不优雅） |
| AI 政策 | 我方成果大量由 agent 产出（本仓形态即如此） | **提 MR 的每一个字都必须由作者人工撰写并逐行负责**；这直接否掉「agent 代写 pmaports MR」这条路 |

**最小可提交件（人工作者执行）**
1. `device/testing/device-lenovo-elden/APKBUILD`（`pkgname=device-lenovo-elden`、`depends` 含 `postmarketos-base`，`install` 安装 deviceinfo 与 udev 规则）
2. `device/testing/device-lenovo-elden/deviceinfo`：`deviceinfo_format_version="0"` / `name="Lenovo Legion Y700 Gen4"` / `manufacturer="Lenovo"` / `codename="lenovo-elden"` / `year="2025"` / `chassis="tablet"` / `dtb="qcom/sm8750-lenovo-elden"` / `flash_method="fastboot"` / `arch="aarch64"`
3. `device/testing/device-lenovo-elden/device-lenovo-elden.md`（功能表：哪些 works / 哪些 not）
4. 内核：`device/testing/linux-lenovo-elden/APKBUILD` 或接入 SoC 共享包（首选共享包，对齐 Main 的「generic kernels」方向）
5. `firmware-lenovo-elden`：只放「驱动 request、但 linux-firmware 没有」的条目；清单可直接取自 `rootfs/debian/elden-firmware/{paths.txt,paths-qcom.txt,local-extras.tsv}`（各 20/14/12 行）
6. 上游先行件：`alsa-ucm-conf` 里按 SoC/机型建目录（建议 `ucm2/Qualcomm/sm8750/…`，精确路径以其仓库现有约定为准——**未验证**），把 `scripts/audio-ucm/` 整理成该形状

**验收判据**：`pmbootstrap init` 能选到设备；`pmbootstrap build` 三包通过；`pmbootstrap kconfig check --community` 绿（若走 community）；设备 `pmbootstrap flasher flash_kernel` + 起机到 SSH（`docs.nura.eco` Testing 四条）。MR 侧：`device/{testing}` 路径 + 至少一名 reviewer 走完一致性清单（`postmarketos#24`）。

**工作量**：8–12 人日（人工作者；不含内核 LLVM 化与 SoC 共享包共建）。**风险**：AI 政策（硬红线）＞ SoC 无先例 ＞ 内核非 LLVM ＞ UCM fork 限制。

---

### B2. Mobian（Debian + Phosh 的「设备移植层」）

**它到底是什么**：Mobian 不是一个独立发行版的软件栈，而是 **Debian 上的移动设备移植 + 镜像构建层**：镜像由 `mobian-recipes` 生成，设备支持 = 「Debian 包 + 一份 recipes 配置 + 一份 droid-juicer 配置」，内核由 Mobian 打包（Debian packaging）。

**门槛原文**
- `https://wiki.debian.org/Mobian/Porting`：
  - 「Mobian images are built using [mobian-recipes]」「Mobian uses a mainline kernel and carries some patches that are being upstreamed, but are not yet in the mainline kernel. **Mobian does not package heavily device-specific kernels.**」
  - 「a good indicator … is the Nura Wiki [= 原 pmOS wiki]」。
  - 内核路径：「clone it locally … cherry-pick the "Add Debian packaging" commit e.g. from [salsa Mobian-team/devices/kernels/qcom-linux]」⇒ 这是**接受我们这种 close-to-mainline 设备内核**的明确入口（`debian/patches` + `gbp pq import`）。
  - 版本要求：「**Mobian ships LTS kernel versions** (e.g. 6.1/6.6/6.12/6.18) to stable and testing branches … please use the last available LTS kernel version」。
  - 设备接入：「Add the device to a locally cloned copy of Mobian-recipes … for a Qualcomm-based device, add the appropriate parameters to `devices/qcom/configs/wip.toml`」＋「write a config for **droid-juicer**, which will then extract those files」。
- 现实空缺（本 lane 现查，Salsa API）：`devices/qcom/configs/` 只有 `sc7280.toml sdm670.toml sdm845.toml sm6350.toml sm7150.toml wip.toml` — **无 sm8750**。与仓内旧结论一致：`reports/mobian-migration-plan-20261021.md` §0-1（「Mobian 支持设备列表无 SM8750 类」「不打包重设备特定内核」）。
- AI 政策（相对宽松，是我们唯一政治可行的）：Debian GR 2026 `https://www.debian.org/vote/2026/vote_002`，胜出选项为 **Option 5「Responsible Use of Generative AI」**；转述（The Register, 2026-08-30）：Debian「neither endorses nor prohibits」生成式 AI，「We encourage our contributors to disclose whether a contribution was made with AI assistance, but do not require them to do so」，「Contributors are expected to understand, review, test … AI-assisted output」。Mobian 本身未查到单独 AI 政策（未验证），按 Debian 口径执行。

**我方现状对照**

| 门槛 | 我方有什么 | 缺什么 |
|---|---|---|
| Debian 根 + Phosh | **已经就是这个形态**：Debian 13 trixie + systemd + greetd/phoc/phosh，1253 包；`rootfs/debian/daily-baseline.tsv` 标题即「Debian/Mobian 目标根」，多行直接写 `mobian-base Depends` / `mobian-phosh-base Depends` | 无（这是三家匹配度最高的一块） |
| 设备层 | `packaging/elden-userland/`（`services.tsv` 唯一真源 → 渲染 OpenRC **与** systemd 两份 unit，`files/`+`extra/` 二分，ELF 记 sha 可重建）；`scripts/deploy-desktop-shell.sh --check` = MISS=0 的 appliance 门 | 没有 Debian 二进制包形态（现在是「脚本推设备」） |
| 内核 | close-to-mainline 7.3/7.4 设备树 + 局部补丁（`patches/upstream/*`、`patches/local/*`） | **LTS 版本账**：Mobian 只发 LTS（6.12/6.18 线）；我们 7.3-rc/7.4-rc；且要转成 `debian/` packaging |
| firmware 提取 | `rootfs/debian/elden-firmware/`（`build.sh`+`name-map.tsv`+`paths-qcom.txt`，含「传感器 DSP 树在 `/usr/share/qcom/sm8750/LENOVO/TB322FC`」这类关键事实）；`local-extras.tsv` 记「源树没有但驱动会 request」的件（例：`qca/tmel_peach_20.elf` 缺 ⇒ 蓝牙控制器起不来） | 没有 `droid-juicer` 的 `configs/lenovo,elden.toml` |
| 包版本门 | 已实测结论：trixie 的 `iio-sensor-proxy 3.7` 无 SSC 后端 ⇒ 必须 sid/forky（`reports/mobian-migration-plan-20261021.md` §0-3） | 无（这是「用哪条 suite」的决策，不是缺口） |

**最小可提交件**
1. `mobian-recipes` MR：`devices/qcom/configs/sm8750.toml`（或先挂在 `wip.toml` 里一节）— 设备名、内核 .deb 名、dtb、根设备、flash 方式。
2. `droid-juicer` 配置：`configs/lenovo,elden.toml` — 从 stock `vendor`/`modem`/`persist` 分区提取 `qcom/sm8750/**`、`qca/*`、传感器 DSP 树到 `/usr/share/qcom/...`（直接照 `rootfs/debian/elden-firmware/` 的表翻译）。
3. 内核：`salsa.debian.org/Mobian-team/devices/kernels/qcom-linux` 的 `6.18-elden` 分支（cherry-pick 上游「Add Debian packaging」提交，再把 `debian/config` 换成我们的 fragment）。
4. 可选、但价值最高：把 `packaging/elden-userland/services.tsv` 的语义做成 Debian 包（`elden-userland`），让 Mobian 用户 `apt install` 而不是推脚本。

**验收判据**：`./build.sh -t qcom-wip -s`（或 `-t sm8750`）出 SSH 镜像并起机；`droid-juicer` 跑完后 `dmesg` 缺固件条目 = 0；内核分支须「LTS 版本 + `gbp pq` 可复现 + 只含正在上游化的补丁」。

**工作量**：6–10 人日（不含 LTS 重基；LTS 重基按 `kernel-downstream-replay` 技能另算 5–8 人日）。**风险**：中低。主要风险是 LTS 版本账（我们所有在机验证都在 7.3/7.4 线上，换 LTS 要重跑一遍功能门）。

---

### B3. Ubuntu Touch / UBports

**硬性前提（必须说清，不含糊）**
- `https://docs.ubports.com/en/latest/porting/introduction/Intro.html`：
  - 「a Hardware Abstraction Layer (HAL) which needs to be built for each specific device … This component is called **Halium**」；
  - 「**Halium is an indispensible part of an Ubuntu Touch port**」；
  - 「Each port of Ubuntu Touch has to be based on one of the available Halium versions and vendor blobs from the corresponding Android version」；
  - 「Thus an Ubuntu Touch port is composed of: the UT rootfs · **Halium** (contained in the boot and system images) · the vendor blobs」。
  - 另：「All new ports of UT to Android devices should follow the Halium process.」（`https://docs.ubports.com/en/latest/systemdev/kernel-hal.html`）
- ⇒ **UBports 的「Android 设备」路线 = Android 下游内核 + Android vendor 层 + libhybris 桥**。这与我方 G1（主线 Linux、正确驱动原厂固件、向上游提交）**方向相反**：走 Halium 意味着把我们已上游化的 DTS/驱动弃用、换回厂商 Android 内核，并让用户态经 hybris 调 Android HAL。**结论：不谈。**

**唯一的技术缝（存在但不建议）**
- 同一页 `kernel-hal.html` 有第三组：「**Linux based ports** refers to devices where a Linux kernel is used without any Android parts.」列出的设备：Desktop PC (x86)、Librem 5、Pinebook、PinePhone、PineTab、Raspberry Pi。
- 这些 port 的**实际形状**不是 `deviceinfo`+`debian/`，而是 `ubports/porting/community-ports/<device>` 里的 `build.sh` + `build/`（`build-tarball-mainline.sh`、`deb-to-bootimg.sh`、`mk-scr.sh` 等）+ `overlay/` + `uboot/`（本 lane 现查 `https://gitlab.com/api/v4/projects/ubports%2Fporting%2Fcommunity-ports%2Fpinephone/repository/tree`）。组织位置：`https://gitlab.com/ubports/porting` → `community-ports` / `reference-device-ports` 两个组。
- 桌面是 **Lomiri**（不是 phosh）：我们全栈（greetd→phoc→phosh→osk-stub，见 `scripts/deploy-desktop-shell.sh` 头注释与判据）要整套换掉。
- 我方缺口：Lomiri 在 Adreno 830 / SM8750 上**从未验证**；UBports 社区无 SM8750 先例；porter 社区支持走 Telegram `@ubports_porting` 与论坛 porting 版（同上 Intro 页「Getting community help」）。

**结论**：Android 路线 = **不能提**；Linux-based 路线 = **可以但不值得**（15–30 人日换一个未验证的 Lomiri 栈）。若未来要做，最小件是 `community-ports/sm8750-elden/{build.sh,build/,overlay/}` 一份 + 设备页进 `devices.ubuntu-touch.io`。

---

## C. 我们手里最有价值的三件（按对方接受概率排序）

1. **elden 板 DTS / 上游化系列（内核侧）** — 已 SENT 状态：板 DTS v7（patchwork `14991580`，`patches/upstream/board-dts-single-20261113-sent-20261117/`）、`wl2868c v12` **已合入 `regulator.git for-7.5`**（`84e67d2ee13f` binding + `602f57223457` driver，见 `TASKS/README.md` §7 头条）、dwc3 v10（`patches/upstream/dwc3-v10-20261120/SENT.md`，4 封 250/lore 4/4）、M8 MDSS reset 3 枚、M10 fastprc v3。
   - 为什么对三家都是净增益：**任何发行版都只消费 mainline DTS/驱动**；一旦 `sm8750-lenovo-elden.dts` 进树，Nura 的 `deviceinfo_dtb`、Mobian 的 dtb 包、甚至 UBports 的 Linux-based port 全部零成本受益。这是唯一「一份工作三家收」的资产。
2. **音频 UCM2 + tplg 源码** — `scripts/audio-ucm/{Lenovo-Y700-Gen4.conf,HiFi.conf,install.sh}`、`scripts/audio-tplg/{SM8750-Lenovo-Y700-Gen4.m4,build.sh,out/*.bin}`。
   - 净增益：`alsa-ucm-conf` 是**发行版中立的独立上游**，Nura main 明确要求「不许 fork 设备专属 `alsa-ucm-conf`」⇒ 上游接收即是他们想要的形状；Mobian/Debian 也直接吃 `alsa-ucm-conf` 包。SM8750 目前上游 UCM 无 Lenovo 条目。
3. **firmware 需求清单 + 传感器/SSC 运行配方** — `rootfs/debian/elden-firmware/{paths.txt,paths-qcom.txt,local-extras.tsv,name-map.tsv}`（含「传感器 DSP 树在 `/usr/share/qcom/sm8750/LENOVO/TB322FC`」「`qca/tmel_peach_20.elf` 缺 ⇒ 蓝牙起不来」这两条别人要踩很久的坑）+ 技能 `y700-adsp-ssc-sensors-bringup`（hexagonrpcd / `/dev/fastrpc-adsp` / QRTR svc 400 / `iio-sensor-proxy` 三项）。
   - 净增益：对 Mobian 而言这**就是** `droid-juicer` 配置的现成输入；对 Nura 是 `firmware-*` 包 + `device-*.md` 的功能表素材。不含任何厂商源码，只是「哪些文件、从哪个分区、缺了会怎样」的知识。

（备选第四：`packaging/elden-userland/` 的 `services.tsv → OpenRC+systemd 双渲染` 方法论。价值高但**不是任何一家的入库形状**，只能作为 Debian 包或设备页文档输出。）

---

## D. 明确不该提的

按 `reports/upstream-policy-20261013.md` 的分类，以下**一律不进任何发行版上游**：

| 类别 | 具体件 | 依据 |
|---|---|---|
| **Q3 违例（策略冒充硬件事实）** | panel `force_hz` module_param、DSI timing `dev_info` 打印、`btqca.c` `tlv_nvm->data[1] &= ~0x01`、`ath12k/mhi.c` MHI 超时 90s→3s、Q28 `dsi_cmd_delay_us` cmdline | `reports/upstream-policy-20261013.md` §3 |
| **下游隔离层（永不进上游包）** | `dm-default-key` + fscrypt wrappedkey（C2）、高通私有 DPU/DSC/PHY/GGX init（C3）、`psci.c` 板级 `SYSTEM_RESET2` 钩子（B1）、`audioreach.c` 全局 `apm_src_port`（C1）、11 个发行版 `.config` 片段（D6） | 同上 §4/§6 |
| **`patches/local/` 全部** | `20261113-daily-worktree`、`20261115-dl-cam-hw-interfaces`、`aw86927-chipdata-20261027`、`b5-resoc-20261027/28`、`rpmhpd-drop-presync-floor-20261027`、`uefi-initrd-probe-20261115` | 目录本身就是「本地」语义 |
| **设备策略件** | `cam-mode.sh`（相机/熄屏互斥的安全策略）、`q28-boot-watchdog`、`kexec` 钩子（M9 已被 Marc Zyngier 否：`TASKS` §7 M9-收口）、`reboot2`/`eldroid-bootctl`/slot 手术脚本、`deploy-desktop-shell.sh` 整脚本 | M7 判据 ③ 明确「`cam-mode.sh`/零相机 cmdline 等策略件不进任何上游包」 |
| **仅本机有意义的** | `qbootctl` 槽位管理、`/init` 生命线脚本、`audio-share/as-client.c`（对上上游是另一项目的客户端实现，应提到 `mkckr0/audio-share`，不是发行版）、`fcitx5-indicator.py`（可考虑提到 fcitx5，非发行版） | 见 `packaging/elden-userland/README.md` 的「发行版无关用户态」定位 |

**另外两条操作纪律**：① 不要把**未过评审的内核补丁**放进 device 包当 `patches/`（Mobian 明说只收「正在上游化」的补丁，Nura 的 close-to-mainline 语义相同）；② Nura 侧任何文字都不要由 agent 生成（政策原文见 B1）。

---

## E. 建议顺序

1. **第 0 步（今天就能做，且三家都受益）：把内核侧那三件收口。** 板 DTS v7 无回复 ⇒ 准备 v8（同时补 `Documentation/…/bindings/arm/qcom.yaml` 的 `lenovo,elden` 条目，那是 `board-dts-single-20261113-sent-20261117/README.md` §3 记的 3 条 W 之一）；`alsa-ucm-conf` 的 `Qualcomm/sm8750/Lenovo-Y700-Gen4` 整理成可提 MR 的形状；`droid-juicer`/`firmware-*` 的清单落成机器可读表。**这三件的产出物同时是 B1、B2 的前置件**——这是「先做哪一步能让后两家也受益」的答案：**内核 DTS + 上游 UCM**。
2. **第 1 个发行版 MR：Mobian。** 理由三条：① 形状最贴（我们已经是 Debian+Phosh+systemd，`rootfs/debian/daily-baseline.tsv` 本来就写「Debian/Mobian 目标根」）；② 政策允许（Debian GR Option 5）；③ 门槛是文件级而非组织级（`wip.toml` + `droid-juicer` config 就能起步，不需要 5 人团队）。**先做「不碰内核」的那半**：`droid-juicer` 配置 + recipes 条目 ⇒ 用**现有**自编内核先出镜像（Mobian 允许 close-to-mainline 分支，只是 stable/testing 偏好 LTS）。LTS 重基作为第二阶段独立决策。
3. **第 2 个：Nura 的 `testing` 设备包，但只由作者人工撰写。** 顺序上放在 Mobian 之后，因为它的产出（deviceinfo / UCM 上游化 / firmware 清单）与 Mobian 那半**复用**，边际成本最低；且我们是 SM8750 第一个包，晚一步反而能参考别人的 SoC 共享内核包形状。**不要把 agent 产出直接贴进 pmaports MR**（政策红线，会连人一起被 escalate）。
4. **不提 UBports。** 若真要碰，只做「Linux-based port」的探路结论记录，不投入实现：它与 G1 不共享成果，且 Lomiri 在 SM8750 上零验证。

---

## F. 未验证 / 待核

- SM8750 是否已有人正在向 pmaports 提 MR（wiki 层面 0 个成型包，GitLab MR 搜索未做）。
- UBports 是否有 AI 政策（docs/forum 检索未见，标「未验证」）。
- Mobian 是否有独立于 Debian GR 的 AI 政策（未验证；按 Debian 口径推定）。
- Mobian 当前 `wip.toml` 是否接受「无 LTS 内核」的临时设备（Porting 页只说 stable/testing 偏好 LTS，staging 区允许非 LTS：原文「some not-LTS kernel versions can be made available in the staging section of the repository」⇒ 有缝，但未验证流程）。
- `pmbootstrap kconfig check --community` 对我们在用 `.config` 的实际结果（未跑）。

■ 结束

---

## 复核（主会话抽验，2026-11-21 12:2x）

三处一手来源逐条抽验，**全部成立**：

1. **改名 + 名字**：`nura.eco/blog/2026/09/27/nura-rename/`（项目官方 blog）「From now on this project is known as Nura!」
   + `en.wikipedia.org/wiki/Nura_(operating_system)`「Nura, formerly known as postmarketOS … On 27 September 2026」。
   仓库现址 `gitlab.nura.eco/nura/pmaports`（Wikipedia 信息框原样）。
2. **AI 政策（决定性）**：`docs.nura.eco/policies-and-processes/development/ai-policy.html` 首段原文
   「**We forbid the use of generative AI tools in Nura.**」+「Submitting contributions fully or in part created by
   generative AI tools to Nura.」⇒ 报告中"被政策挡死"的判定成立，且比报告写的更绝对（连"推荐 AI 工具给社区成员"都在禁列）。
3. **Mobian 形状**：`wiki.debian.org/Mobian/Porting` 原文「Mobian uses a mainline kernel … Mobian does **not** package
   heavily device-specific kernels」+「Mobian ships LTS kernel versions (e.g. 6.1/6.6/6.12/6.18) … please use the last
   available LTS kernel version」+ 实操链「droid-juicer configs → mobian-recipes `devices/qcom/configs/wip.toml` →
   `./build.sh -t qcom-wip -s`」⇒ 报告给的"第 1 个 MR = droid-juicer 配置 + wip.toml"与官方流程逐字吻合。

**一处口径补充**：Mobian 的 Porting 页把「Nura Wiki」作为"该设备能否跑 mainline"的对照入口 ⇒ 即使不向 Nura 投件，
**Nura wiki 的 SM8750 设备列表仍是我们的对照基准**（`wiki.nura.eco/wiki/Qualcomm_Snapdragon_8_Elite_(SM8750)`）。
