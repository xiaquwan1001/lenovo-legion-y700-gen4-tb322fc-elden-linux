# 外部动向扫描 2026-11-12b（窗口：2026-11-12 16:35 CST → 2026-11-12 17:35 CST）

只读侦察，不碰设备、不改既有文件、不 commit。作者：联网侦察子代理（lane C / 外部动向）。
基线 = `reports/external-scan-20261112.md`（窗口止 2026-11-12 16:35 CST）与 `reports/external-scan-20261109.md`。
**窗口长度仅 1 小时**，因此本份重点不是"新提交"，而是把基线两份**未覆盖的面**（内核 patchwork 侧、Droid-VM 线、事件流）补齐并做状态复核。

## 0. 结论先行

1. **两条 SM8750 上游新补丁直接命中我们本地树，且我们两处都还是旧值**：`llcc-qcom` 的 `LLCC_ISLAND1` 仍写 `bonus_ways = 0x7fffffff`（应 `res_ways`），`gcc-sm8750` 两个 USB GDSC 仍 `PWRSTS_OFF_ON`（应 `PWRSTS_RET_ON`）。两者都只在 **suspend** 路径上爆发，而我们 `build/m3v2-7.3rc7/.config` 与 `build/daily/.config` 都没有 `CONFIG_SUSPEND` ⇒ **当前不暴露，重启 suspend 线时必须先带上**（详见 §2-B1/B2）。
2. **同机型 CDSP/NPU 使能已被第三方做出来并公开源码**：`h0cheung/tb322fc-linux@4f0310aa` 带 `tb322fc-cdsp.patch`（改的正是 `sm8750-lenovo-elden.dts` 的 `&remoteproc_cdsp`，含 split 固件路径 `qcom/sm8750/cdsp.mdt`、cb@1 掩码展开、`nsessions=8`）。同时发现一条我们两份基线都漏掉的 **accepted** 上游修：`Fix iommu stream ID masks for CDSP compute CBs`（patch 14924748）—— 我们 `sm8750.dtsi` 里 cb@12/cb@14 仍是未修值。
3. **「不靠 UEFI 的同机型 Linux 引导」已存在且活跃**：`ArmadaOS-Freedom/armadaos-freedom`（197★，11-11 push）的 **kShimC** 把 4 MiB 菜单塞进 96 MiB 原厂 boot.img，保留原厂 ABL 链，菜单里选 Android / 机身 Linux / TF Linux / Recovery / Fastboot / 9008。⇒ 我们卡住的「flashed 形态只有 1 个 SimpleFileSystem」不是唯一路径的死结（§2-B4）。
4. **Android + Linux 共存也有同机型先例**：`BeeHiyok/Y700-Gen4_skyward`（11-11）把 Skyward 双系统移植到 TB322FC；机制 = 只重写「下一个启动槽的 boot + init_boot」，第二系统根是 /data 里的文件、/metadata 记中间态保证断电原子性（§1 #18/#19）。
5. **Mu/UEFI 生态窗口内零实质变化**：`mu_wide_platforms#12`（仍 10-29 零回应）、`#13`（仍 open、0 评论）、`retro98boy` 各仓停手、`Mu-Silicium`/`Device-Binaries`/`Aloha` 在本文窗口（`since=11-12T08:35Z`）**零提交**，仅 dependabot PR。Qcom/SM8750 参照点仍是 10-29 的 annibale 合并。
6. **两条口径纠正**：① `sm8750 ADSP fastrpc non-secure domain` 系列**是我们自己发的**（Qianhui Xu，已到 `v3`/`new`），不要当外部先例；② `Droid-VM/edk2-gunyah`、`crosvm` 的 `pushed_at` 变新（11-11）是 **wip/macOS 分支的假信号**，默认分支仍停在 10-10。

## 1. 逐条结果表

| # | 条目 | URL | 日期 | 有无变化 | 可操作含义 |
|---|---|---|---|---|---|
| 1 | `sunflower2333/mu_wide_platforms#12`（我们提的 UFSDxe UEFI_DEVICE_ERROR） | https://github.com/sunflower2333/mu_wide_platforms/issues/12 | state=open，`updated_at=2026-10-29T04:19:30Z`，comments=7，**窗口内零活动** | 无 | 继续不等；解冻仍走 #13 路线 |
| 2 | `sunflower2333/mu_wide_platforms#13`（retro98boy UFS/SD 修法 PR） | https://github.com/sunflower2333/mu_wide_platforms/pull/13 | state=open，merged=false，comments=0，head=`cb76ad43`，`updated_at=2026-11-08T10:35:10Z` | 无 | 上游四天未裁决；要用自己 cherry-pick |
| 3 | `retro98boy/mu_wide_platforms`（addon / fix-ufs-and-sd / main） | https://github.com/retro98boy/mu_wide_platforms | repo `pushed_at=2026-11-09T07:44:30Z`；分支头 `lenovo-y700-gen4-addon` 停在 11-09T07:31Z 的 SMBIOS 修正（`4e8cf708`），`lenovo-y700-gen4-fix-ufs-and-sd`=`cb76ad43`（=#13 head）、`main`=`3e1d0520` | 无 | 上份 §1 #3 结论维持 |
| 4 | `Project-Silicium/Mu-Silicium` 主仓 | https://github.com/Project-Silicium/Mu-Silicium | `pushed_at=2026-11-10T21:24:44Z`，**`since=11-12T08:35Z` 零提交**；open PR 仅 dependabot #2186/#2187/#2188（11-10 开） | 无（相对 11-12 16:35 基线） | Qcom/SM8750 参照点仍是 10-29 的 annibale 合并 |
| 5 | `Project-Silicium/Device-Binaries` | https://github.com/Project-Silicium/Device-Binaries | `pushed_at=2026-11-10T15:13:48Z`，窗口内零提交；open PR 仅 #204（macan 二进制，10-30 开）；#203 已 merged（10-29，见基线更正） | 无 | SM8750（annibale）二进制已在 main，可直接取 UFSDxe.patched.efi |
| 6 | `Project-Aloha/mu_aloha_platforms` | https://github.com/Project-Aloha/mu_aloha_platforms | `pushed_at=2026-11-09T04:24:40Z`，窗口内零提交；同机型 PR #820 仍 `closed, merged=false`（updated 2026-11-09T02:06Z，13 评论） | 无 | 维护者「不收 sm8750」口径未变 |
| 7 | `retro98boy/qualcomm-devices` | https://github.com/retro98boy/qualcomm-devices | `pushed_at=2026-10-25T05:49:07Z` | 无 | 同上份 |
| 8 | `Droid-VM/edk2-gunyah` / `Droid-VM/crosvm` | https://github.com/Droid-VM/edk2-gunyah · https://github.com/Droid-VM/crosvm | **元数据有变**：`pushed_at` 分别 2026-11-11T07:30Z / 11-11T12:36Z（上份记 10-24/11-03）；但默认分支最新提交仍是 **2026-10-10**（`90c4d52c` / `849e05f1`）。事件流显示 11-09~11-10 的 push 全在 `wip/hackintosh`、`wip/virtio-mmio`、`macOS` 等非默认分支（HuJK / lateautumn233） | 有元数据变化，**实质无变化** | 仍是 macOS/XNU 虚拟化线；与 Linux ESP/UEFI 引导无关，裁决（不做 Gunyah VM）不变 |
| 9 | XNU/HakiOS 同族（`7Night-kqx/UniXNU-dada`、`IssacL04/UniXNU-Pagani_SM8750`、`superboyyy/hakios-arm64e-dada`） | https://github.com/7Night-kqx/UniXNU-dada · https://github.com/IssacL04/UniXNU-Pagani_SM8750 · https://github.com/superboyyy/hakios-arm64e-dada | push 分别 10-27 / 11-08 / 10-31；`hakios` 的 `updated_at=11-12T03:35Z` 只是 WatchEvent（新关注者），无提交 | 无实质变化 | 依旧全部 `fastboot boot`，无 flashed 形态经验 |
| 10 | `armbian/build`（同机型主线内核支持） | https://github.com/armbian/build | `pushed_at=2026-11-12T09:10:39Z`，窗口内唯一相关提交 `6fb0dc51`（rockchip-rk3588 panthor overlay，**非 SM8750**） | 有活动但无关 | PR #11044 结论（ABL 不能直启、须 EFI+GRUB）仍是外部对标基线 |
| 11 | **【新】soc: qcom: llcc-qcom: Reserve ISLAND1 ways on SM8750**（yzddMr6, 小米 Pad 8 Pro） | https://patchwork.kernel.org/patch/14971425/ | 2026-11-11T07:21:13Z，state=`new`，0 条评论 | **新，且我们本地树正在受影响状态** | 见 §2-B1：s2idle 时 LPASS 无票 → PS_HOLD 复位；一行 `bonus_ways→res_ways` 修掉 |
| 12 | **【新】clk: qcom: gcc-sm8750: Use retention for USB power domains**（Vladyslav Tymoshchuk, 一加 Pad 3） | https://patchwork.kernel.org/patch/14970417/ | 2026-11-10T21:33:46Z，state=`new`，**Abel Vesa 已 `Reviewed-by`（11-11T14:31Z）** | **新，且我们本地树仍是旧值** | 见 §2-B2：USB host 下 s2idle 回来 SMMU fault + xHCI 死；改两个 GDSC 为 `PWRSTS_RET_ON` |
| 13 | sm8750 ADSP fastrpc non-secure domain（**作者 Qianhui Xu = 我们自己**） | https://patchwork.kernel.org/patch/14971025/ | v1 `14959877` 11-07T03:26 `superseded` → v2 `14966246` 11-10T02:31 `superseded` → **v3 `14971025` 2026-11-11T03:57Z `new`** | 有变化（v2→v3）；**基线 11-09 §1 #16 把它当「非我方」是错的** | 是我们自己的系列在推进，不是外部先例；勿再当外部信号读 |
| 14 | `[v7,4/5] arm64: dts: qcom: sm8750: bind traceNoC on the platform bus`（Jie Gan） | https://patchwork.kernel.org/project/linux-arm-msm/list/?q=traceNoC | 2026-11-10T01:21Z，state=`new`（v1~v6 均 changes-requested/superseded） | 有变化（v7） | 仅 coresight/ETF 线；与我们的 UFS/显示/传感器无交叉，**不阻塞** |
| 15 | `arm64: dts: qcom: sm8750: Fix iommu stream ID masks for CDSP compute CBs`（Vinayak Katoch） | https://patchwork.kernel.org/patch/14924748/ | 2026-10-29T14:41Z，state=**accepted** | 无新变化（上两份未收录） | 我们的 7.3rc7 树**尚未含**此修（cb@12 `0x0c2c 0x20`、cb@14 `0x0c0e 0x20` 仍在）；开 CDSP 前必修 |
| 16 | linux-wireless：WCN7861/ath12k 相关 | https://patchwork.kernel.org/project/linux-wireless/list/ | 11-10~11-12 共 198 条；**无 WCN7861 定向件**；值得记的三条：`wifi: ath12k: report an aborted scan before cancel_hw_scan returns`（Vlad, 11-10T21:34Z, new）、`soc: qcom: qmi: Take responses and indications only from looked-up servers` + `ath12k: ignore WLFW servers on the local node`（Julius Bairaktaris, 11-11T08:06Z, new）、QCN9575 Wi-Fi 8 15 片（11-12T08:32Z，窗口前 3 分钟） | 无 WCN7861 专项；QMI/WLFW 两条针对 QRTR 多节点 | 与我们 WiFi 失联/roam 线弱相关（若出现「QRTR 拿错 WLFW 服务」症状再取） |
| 17 | **【新对象】`h0cheung/tb322fc-linux`** —— 同机型主线 Linux 发行版仓（9★） | https://github.com/h0cheung/tb322fc-linux | `pushed_at=2026-11-08T13:10:17Z`；最新提交 `4f0310aa` **npu: enable Y700 Gen 4 CDSP and package native FastRPC**（11-08T13:10Z） | **新（基线两份均无）** | 同机型现成的 CDSP/NPU 使能补丁 + fastrpc 打包：见 §2-B3 |
| 18 | **【新对象】`BeeHiyok/Y700-Gen4_skyward`** —— Skyward（Rust 写安卓 recovery + 双系统）的 TB322FC 移植 | https://github.com/BeeHiyok/Y700-Gen4_skyward | `pushed_at=2026-11-11T06:39:27Z`；`dcc48c32`「Charging, USB host and the bootloader restart」（11-11T06:37Z）；`f2faa56b` 完整源码树（11-09T05:59Z） | **新** | 同机型第三方已做到「Android + 第二系统共存」（双系统只重写 boot/init_boot，根在 /data 里的文件）；对我们是**备选路线存档**，不是主线 |
| 19 | `kirklin/skyward`（上游，391★） | https://github.com/kirklin/skyward | `pushed_at=2026-11-08T14:24:21Z`，10-25 建仓 | **新对象** | 其「How dual boot works」写清了机制：切换只写「下一个启动槽的 boot + init_boot」，步骤先落 /metadata 保证断电原子性；第二系统沿用已装系统的 vendor_boot/dtbo |
| 20 | **【新对象】`ArmadaOS-Freedom/armadaos-freedom`（197★）+ `-installer`** —— kShimC 多系统启动，支持 Y700 Gen 4/5 | https://github.com/ArmadaOS-Freedom/armadaos-freedom · https://github.com/ArmadaOS-Freedom/armadaos-freedom-installer | 主仓 `pushed_at=2026-11-11T11:09:23Z`；installer 2026-11-11T10:52:50Z | **新对象**（基线只见过 `corebear6010/armadaos-freedom#1` 这个 fork 线索） | kShimC = **不靠 UEFI 的 Linux 引导菜单**（塞进 96 MiB 原厂 boot.img 的 4 MiB runtime）；见 §2-B4 |
| 21 | **【新对象】`hashtagbasit/Zaviya`（346★）** SteamOS-on-ARM 平板/掌机 | https://github.com/hashtagbasit/Zaviya | `pushed_at=2026-11-12T06:46:26Z`（窗口前 2 小时） | **新** | 与我们 G3（Steam 游戏 / Box64+Wine 线）同域但 ARM 原生 SteamOS，不是 x86 模拟；命名上检索命中 TB322FC 属噪声 |
| 22 | 其余同机型新仓：`lenzhang/UniXNU-xiaomipad8pro`、`5aaee9/nixos-tb322fc-linux`、`loyldnguyen/Lenovo-TB322FC-BakaSU-Kernel` | https://github.com/lenzhang/UniXNU-xiaomipad8pro · https://github.com/5aaee9/nixos-tb322fc-linux · https://github.com/loyldnguyen/Lenovo-TB322FC-BakaSU-Kernel | push 分别 11-12T08:22Z / 11-07T19:43Z / 11-10T13:21Z | 新对象，低价值 | `xiaomipad8pro` = 同族 SM8750 的 XNU NativeUfs 工作（非 UEFI 存储栈，参考价值同上份 #12 判定）；另两个是系统打包/安卓内核，无主线增量 |

## 2. 上游变化能否省掉我们一条待办 / 新红线

### B1 llcc ISLAND1：s2idle 下 PS_HOLD 复位的确定解（**新红线，先记后用**）

- 上游：https://patchwork.kernel.org/patch/14971425/ （yzddMr6，2026-11-11T07:21Z，`new`，尚无评论）。
- 本地核对（`build/m3v2-7.3rc7/drivers/soc/qcom/llcc-qcom.c`，`sm8750_data[]` 内 `LLCC_ISLAND1`）：`max_cap = 7936` / `fixed_size = true` / **`bonus_ways = 0x7fffffff`**、**无 `res_ways`** —— 与上游报告的「坏表」逐字一致。
- 后果：`bonus_ways` 只在没人预留时才分配，`res_ways` 才属于该 slice 独占；v7.3 起 LPASS 宏编解码改用 PM clock framework 并在 runtime suspend 时放票 → 无人给 LPASS 投票 → s2idle 变成 PS_HOLD 复位（PMIC PON 只记 PS_HOLD、无 PMIC fault）。
- 与我们现存症状的对应：如果能复现，形状会是「s2idle 后复位 + PMIC PON 只记 `Reset by PSHOLD`」—— 正好撞上我们已经在查的两条：`PITFALLS #184/#182`（PSHOLD 复位源字段只说明 AP 侧拉低 PS_HOLD，不能据此判根因）与 `PITFALLS #572`（session 191，ABL 槽 retry 耗尽 → 切 `_b`）。两者叠在一起极易误判成「ABL 槽回退」或「UEFI 载荷失败」。
- **当前不影响我们**：`build/m3v2-7.3rc7/.config` 与 `build/daily/.config` 都**没有 `CONFIG_SUSPEND`**（只有 `CONFIG_PM=y`；PITFALLS #336/#348 记录过开 suspend 的历史失败）。
- **可省掉的待办**：将来重启 suspend 线时，**不要再从零 triage「s2idle 后 PS_HOLD 复位、cxsd 不增长」**——先打这一行（`bonus_ways → res_ways`，一个字段），再判其它因子。

### B2 gcc-sm8750 USB GDSC：s2idle + USB host 的 SMMU fault（**可直接采用**）

- 上游：https://patchwork.kernel.org/patch/14970417/ （Vladyslav Tymoshchuk，2026-11-10T21:33Z，**Abel Vesa `Reviewed-by` 于 11-11T14:31Z**）→ 进 `clk-next` 概率高。
- 本地核对（`build/m3v2-7.3rc7/drivers/clk/qcom/gcc-sm8750.c`）：`gcc_usb30_prim_gdsc`、`gcc_usb3_phy_gdsc` 均 `PWRSTS_OFF_ON`（行 2943 / 2955），上下文与上游 diff 的 index 行完全对齐 ⇒ **能干净 apply**。
- 症状：host 模式下 dwc3 是 wakeup source，保留控制器状态，但 genpd 把两个 USB GDSC 真关掉 → resume 回来 `arm-smmu ... fsr=0x402` + `WARNING: Host System Error` → xHCI 判死，**之后 device 模式也一起废到重启**。
- 修法：两个 GDSC 改 `PWRSTS_RET_ON`（与 SM8650 / X1E80100 一致）。
- 与我们：同样受 `CONFIG_SUSPEND=n` 保护而暂不暴露；一旦做 suspend，这是**同一条待办里的第二个必带补丁**（否则 USB 口在 resume 后死，会被误判成 dwc3/PHY 驱动问题）。

### B3 同机型 CDSP/NPU：省掉「从零写 elden CDSP 使能」这条待办

- `h0cheung/tb322fc-linux@4f0310aa`（2026-11-08T13:10Z）带 `obs/kernel-source/tb322fc-cdsp.patch`（48 行）+ `docs/npu.md` + `obs/fastrpc/*`（udev 规则、spec、`tb322fc.yaml`）。
- 补丁直接改的是**同一个文件** `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` 的 `&remoteproc_cdsp`：
  - `firmware-name` 从 `qcom/sm8750/LENOVO/elden/cdsp.mbn`/`cdsp_dtb.mbn` 换成**上游风格 split 固件** `qcom/sm8750/cdsp.mdt` + `cdsp_dtb.mdt`；
  - `status = "okay"`；
  - `compute-cb@1` 的 `0x0c01 0x40` 掩码展开为 4 条显式 stream（作者注：SM8750 无法表达继承来的 `0x40` SID 掩码）；
  - `qcom,nsessions = <8>`，其余 `compute-cb@2..14` 全 `disabled`（只保留「与 stock CDSP 固件一起验证过」的那个 CB）。
- 我们现状：`sm8750-lenovo-elden.dts` **完全没有 `&remoteproc_cdsp` 覆盖**（CDSP 保持 dtsi 默认），`sm8750.dtsi` 里 `compute-cb@12` 的 `0x0c2c 0x20`、`compute-cb@14` 的 `0x0c0e 0x20` **仍是未修值**。
- 同时发现一条**已 accepted 的上游修**（我们两份基线都漏了）：`arm64: dts: qcom: sm8750: Fix iommu stream ID masks for CDSP compute CBs`（Vinayak Katoch，https://patchwork.kernel.org/patch/14924748/ ，2026-10-29T14:41Z，`accepted`）—— 改的正是 cb@12/cb@14 这两处。
- 结论：**开 CDSP/NPU 时不要照抄 h0cheung 的手工展开**，正确顺序 = 先 cherry-pick 14924748（accepted），再叠他自己的 cb@1/nsessions 设备级部分 + 固件路径。

### B4 kShimC：'flashed 形态 ESP 枚举' 不是唯一路径（**战略选项，先归档**）

- `ArmadaOS-Freedom/armadaos-freedom`（197★，2026-11-11T11:09Z）的 kShimC：把 4 MiB runtime 塞进 **96 MiB 原厂 boot.img**（header v4、ramdisk_size 0、带 AVB footer），保留原厂 ABL 链，运行时出一个 LVGL 菜单：Android / 机身 Linux / TF 卡 Linux / 诊断 Recovery / Fastboot / **9008 EDL**。源码在 `devices/lenovo-tb323fu/boot/kshim-success-source`，Gen4 配置 `tb322fc_android_defconfig`、打包入口 `devices/lenovo-tb322fc/boot/build_android_boot.py`。
- 对我们三个直接含义：
  1. **不依赖 UEFI** 的同机型 Linux 引导已存在且有源 ⇒ 我们卡住的「flashed 形态只有 1 个 SimpleFileSystem」不是硬件/ABL 限制造成的死路，只是 UEFI 路线的一条分支；
  2. 它明文要求「截取的内核必须是 raw ARM64 `Image`（`ARM\x64` 在 0x38），不能是 gzip」—— **与我们 `PITFALLS` 的双层压缩陷阱（`1f8b 0808`）独立互证**；
  3. 「Android 与 Linux 共存」在外部已被做成菜单（Android 基座留在 boot.img，Linux 载荷来自机身/TF）—— 上份引用的 armbian#11044「无法共存」只是他那条路线的结论。
- 未做裁决：是否要走 kShimC 替换/并行于 Project Aloha+UEFI，属主线取舍，本报告只存档证据与入口。

### B5 无需行动但必须记的两条口径纠正

- **ADSP fastrpc non-secure 系列是我们自己的**（提交者 Qianhui Xu，v1 11-07 → v2 11-10 `superseded` → **v3 11-11T03:57Z `new`**）。基线 11-09 §1 #16 写成「非我方」，若照那份当外部先例读会误判。
- `Droid-VM/edk2-gunyah`、`crosvm` 的 `pushed_at` 变新（11-11）**不代表**默认分支有进展：仍在 10-10 的提交，新增活动只在 `wip/hackintosh`、`wip/virtio-mmio`、`macOS` 分支。以后看这两个仓要读 `commits` 而不是 `pushed_at`。

## 3. 检索基础设施状态

**用了哪些通道（全部 API 化，未调用 `web_search`/`web_fetch`）**

| 通道 | 用途 | 状态 |
|---|---|---|
| `gh api repos/<o>/<r>` | pushed_at / updated_at / open_issues_count 批量元数据（13 个关注对象） | ✅ 正常，无 429（本机 `gh` 登录 `xiaquwan1001`） |
| `gh api .../commits?since=…` | 窗口内提交扫描（11 个仓） | ✅ 正常 |
| `gh api .../events` | 区分真提交 vs fork/watch/分支 push | ✅ 对本文关键（#8 Droid-VM 假信号就靠它识破） |
| `gh api .../issues?state=…&sort=updated` · `.../pulls` | #12/#13、#820、Mu-Silicium/Device-Binaries PR 状态 | ✅ 正常 |
| `gh api -X GET search/repositories` / `search/commits` | 发现基线两份都没收录的新仓（5 个） | ✅ 可用；`search/code` 未用（需特殊权限，改用 search/commits 代替） |
| `patchwork.kernel.org/api/1.3/patches/?project=…&since=…&order=date` | 内核侧增量（linux-arm-msm 111 条 / linux-wireless 198 条覆盖 11-10~11-12） | ✅ 正常，`per_page=250` 未触顶 |
| `.../patches/?project=<p>&q=<词>` | sm8750 / lenovo-elden / ISLAND1 / traceNoC / iommu | ⚠️ **必须带 `project=`**，否则 400 `Searches must be limited with one of these parameters: project, series` |
| `.../patches/<id>/` | 取 `content`（提交说明）+ `diff`（逐行补丁）—— 本报告 §2 的全部技术结论都来自这里 | ✅ 关键通道 |
| `.../patches/<id>/comments/` | 找 `Reviewed-by` / 维护者意见 | ✅（llcc 那条 0 评论；gcc-sm8750 拿到 Abel Vesa 的 Reviewed-by） |

**失败与降级**

- **patchwork 的 `/patch/<id>/mbox/` 已被 Anubis 拦**：返回 200 但内容是 7044 B 挑战页（`techaro.lol-anubis-cookie-verification` cookie），拿不到 mbox。降级路线 = `api/1.3/patches/<id>/` 的 `content` + `diff` 两个字段（信息完整，够写结论）。
- `lore.kernel.org` 仍不可用（上份已记 Anubis 拦截），本文全程未试图绕过；但 `patchwork` 的 `patch.url` 里含 `list_archive_url`，可当 lore 的替代锚点。
- `pushed_at` 不可当活跃度指标（反例：Droid-VM 两仓、`sunflower2333/mu_wide_platforms` 的 `pushed_at` 停在 10-01 却有 11-10 的 issue 活动）⇒ 一律双读 `commits`/`events`。
- 窗口只有 1 小时（下份请拉长到 ≥ 12 h，否则 GitHub 侧必然是空集）：真正有产出的都是**基线两份未覆盖的面**（内核 patchwork、同机型第三方新仓），而不是窗口内的新提交。
