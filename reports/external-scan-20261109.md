# 外部动向扫描 2026-11-09（窗口：2026-11-08 → 2026-11-09 14:30 CST）

只读侦察，不碰设备、不改仓库源码。作者：联网侦察子代理。

**结论先行**

1. **有外部先例解决「flashed 形态（写 `boot_a`）下 UEFI 枚举到 ESP 并起 GRUB」** —— 同机型（TB322FC / lenovo-elden）上的第三方（`retro98boy`）已实机跑通并写成公开指南；但他的形态与本机不同（见 §2），**没有任何公开材料记录 `fs=1` vs `fs=8` 这条枚举差异本身**，也没有人给出它的根因。
2. **上游 issue #12 自 2026-10-29 起零更新**（`updated_at=2026-10-29T04:19:30Z`）；但维护者 `sunflower2333` 2026-11-07 在别处给了新口径：UFS 问题是「Link State 处于 Sleep」，且「那个 repo 已有 y700 支持，只差一个可选 UFS 补丁」。
3. **UFS 在 SM8750/Y700 上已被两个独立第三方跑通**，且**都不需要打 `UFSDxe` 二进制补丁**：① 调整 `UFSDxe` 在 `APRIORI.inc` 里排到 `QRKSDxe` 之后；② 用源代码重写驱动（LLM 辅助，从内核驱动改写）。这两条直接否证我们「必须猜 patch 偏移」的假设。

---

## 1. 逐条结果表

| # | 条目 | 来源 URL | 日期 | 有无变化（相对 2026-11-08 之前） | 对 UEFI 落地的可操作含义 |
|---|---|---|---|---|---|
| 1 | `mu_wide_platforms#12`（我们提的 UFSDxe 问题） | https://github.com/sunflower2333/mu_wide_platforms/issues/12 | updated **2026-10-29T04:19:30Z** | **无变化**（无新评论、未 close；最后一次是我们 10-29 那条 `0x402` 静态证明 + 两问） | 上游「层级判据」请求仍无答。**解冻条件不应再等这条**——见 #4/#5 已绕开它 |
| 2 | `mu_wide_platforms#13` **新 PR**：「Fix UFS and microSD for Lenovo Y700 Gen4」（作者 `retro98boy`，非我方） | https://github.com/sunflower2333/mu_wide_platforms/pull/13 | created **2026-11-08T10:35:10Z**，0 评论，open | **新出现（窗口内）** | **最高价值**：同机型 UFS 修法 = 把 `UFSDxe` 在 `APRIORI.inc` 里挪到 `QRKSDxe` 之后（不改二进制；或干脆从 APRIORI 摘掉让正常 dispatch 处理）。另有 `SdccDxe` 两处 24 字节补丁（跳过 SMMU 重配 + 把厂商通知 GUID 换成 `gMsStartOfBdsNotifyGuid`）。报告 UFS/SD 各 1 GiB 写读校验通过、UFS 与 SD 交替 8 连启动进 GRUB |
| 3 | `Project-Silicium/Mu-Silicium` 主仓 | https://github.com/Project-Silicium/Mu-Silicium | push **2026-11-08T20:49Z**，最新提交 `20b82927` Update ACPI Submodule | **有变化但与 SM8750/UFS 无关**：11-08 全天提交 = Exynos/galaxy a10/gta3xllte/DWC3/`SecureBootHandlerLib: close volumes and free notification buffers once (#2179)`/`Call SCM EBS Callback on EBS`(`44f6c98f`) | 两条与我们撞的墙相关：`#2179` 在 **ExitBootServices 前关卷/释放通知缓冲**（我们的 EB 段落死亡点之一，值得对照我们的 EB 前清单）；`44f6c98f` 在 **EBS 时调 SCM 回调**（同款修复 11-09 也进了 Aloha，见 #7） |
| 4 | `Project-Silicium/Device-Binaries#203`（annibale/K90 SM8750） | https://github.com/Project-Silicium/Device-Binaries/pull/203 | 评论 2026-10-29T20:06Z（窗口前，但结论对我们的 §1 #2 关键） | 无新变化 | 上游口径：**`UFSDxe` 的 Patch Nr.3 在 `PlatformType` PCD 设为 `WP`（而非 `LA`）时不需要**。这是我们 `PlatformType=LA` 之外一条未试的正交开关 |
| 5 | `Project-Aloha/mu_aloha_platforms` 主仓（`mu_wide_platforms` 的上游母体） | https://github.com/Project-Aloha/mu_aloha_platforms | push **2026-11-09T04:24Z** | **有变化**：`AndromedaPkg: BDS: Call SCM Exit BS callback on ExitBS` + `Call the callback on EBS`（2026-11-09T04:22/04:23）；`Haydn: MemoryMap`（11-08） | EBS 侧现在是**两个上游仓库同时在修**（Mu-Silicium `44f6c98f` + Aloha 11-09 两条）。我们 2026-11-07 的 EB 段崩溃排查应把这批 diff 当基线重读一遍 |
| 6 | `mu_aloha_platforms#820` **同机型 PR**「Initial support for the Lenovo Legion Y700 Gen4 (no ACPI, FDT platform for Linux)」（作者 `retro98boy`） | https://github.com/Project-Aloha/mu_aloha_platforms/pull/820 | created/closed **2026-11-07**（13 评论） | **新出现（窗口前 1 天，本次首见）**；**被维护者拒绝合并**（"This repo will not accept sm8750"），但代码留在其 fork | 内含**三条直接可用机制**（已拆成独立 commit，见 §3）：AVB footer 生成、BDS 后标记活动槽 successful、EFI boot picker（菜单应用）。维护者回复指路：提交到 `mu_wide_platforms`，且「y700 支持已在该仓库，只差可选 UFS 补丁」 |
| 7 | `retro98boy/mu_wide_platforms` 分支 `lenovo-y700-gen4-addon` | https://github.com/retro98boy/mu_wide_platforms/commits/lenovo-y700-gen4-addon | 提交 **2026-11-08 / 2026-11-09T04:13Z** | **新（窗口内）**，逐条：`initialize UFS after QRKS`（11-08）、`fix SD card detection and DMA`（11-08）、`add EFI boot picker`（11-08）、`use Aloha PMIC key mappings`（11-08，相当于我们的按钮映射）、`add AVB footer to ... boot image`（11-09）、`acknowledge successful ... boots`（11-09） | **我们缺口的镜像级对照件**：他的 `Library/MsPlatformDevicesLib/StorageConnect.c` 在 BDS 阶段**显式** `ConnectController` 非可发现 UFS 设备、再按 `ScsiIo` 逐 LUN 连接（`Lun >= 8` 跳过 RPMB/well-known），SD 用递归连接；注释写明「PartitionDxe owns partition-table validation」。这正是「什么时候/谁把 SimpleFileSystem 挂出来」的显式版本 |
| 8 | `retro98boy/qualcomm-devices` 同机型指南（EN/CN） | https://github.com/retro98boy/qualcomm-devices/blob/main/devices/lenovo-y700-gen4/README_EN.md | 仓库 push 2026-10-25；release `lenovo-y700-gen4`（`project_aloha_20261025.boot.img` 2026-10-25T07:15Z） | 无变化（本次核对内容已含 flashed 形态） | **flashed 形态的正向证据**：`fastboot flash boot_a project-aloha.img && fastboot reboot` → Aloha 扫 EFI 分区 → GRUB → Linux；UFS 侧 ESP = LUN0 **p17** `armbian_efi` 512 MiB，`parted` 显示 **Flags `boot, esp`**（即 ESP 类型 GUID + 标志），`dd` 写分区镜像后重启即可。`fastboot flash boot_a`/`fastboot boot` 失败后的唯一已知恢复法 = 回刷原厂 + 先让 Android 内核起一次再回 bootloader（作者注：原因未知） |
| 9 | `armbian/build#11044`（同机型主线内核支持） | https://github.com/armbian/build/pull/11044 | **merged 2026-10-21**，updated 2026-10-22 | 无新变化（已合入） | 明说「**Booting via ABL does not work, so this setup uses an EFI environment (Project Aloha) + GRUB**」；内核 7.2.11 + 回移 7.3 补丁；已支持 WiFi/BT、显示背光、触屏、扬声器、USB、SD、充电；SD 只能 PIO；**Android 与 Linux 目前无法共存**；相机/麦克风/传感器不支持。→ 与我们的 G1 进度可横向对标（他的「传感器不支持」正是我们 ADSP/SSC 线已推进的部分） |
| 10 | `Droid-VM/edk2-gunyah` | https://github.com/Droid-VM/edk2-gunyah | 最新提交 **2026-10-10**（repo push 元数据 2026-10-24） | **无变化** | 与 Gunyah 裁决一致（不做），仅留档 |
| 11 | `Droid-VM/crosvm` | https://github.com/Droid-VM/crosvm | 最新提交 **2026-10-10**（push 元数据 2026-11-03） | **无变化** | 同上。但 `Droid-VM` 组织其它仓 11-08 活跃（`UniXNU`、`macOS-DroidVM`、`droidvm-meta-repo`）——是 XNU/macOS 线，不涉及 Linux ESP |
| 12 | `7Night-kqx/UniXNU-dada`（SM8750 小米 15，README 称 UFS works） | https://github.com/7Night-kqx/UniXNU-dada | 最新提交 **2026-10-27**（`dada: userland reaches SpringBoard; add the UFS diagnostic log`） | **无变化**；README 无新措辞 | 其 UFS 是 **XNU 内核内建 `NativeUfs` 驱动**（10-23 连续 4 条：prime UIC / waitSet / NOP OUT），不是 UEFI 存储栈 ⇒ **对我们的 UEFI 枚举无参考价值**（只能作 UIC/link-up 时序参考） |
| 13 | 同族新仓 `IssacL04/UniXNU-Pagani_SM8750`（一加 13T / PKX110，SM8750） | https://github.com/IssacL04/UniXNU-Pagani_SM8750 | push **2026-11-08T05:57Z**（11-08 当天多张 boot.img） | **新（窗口内）** | 全部实机证据都是 **`fastboot boot`（"without flashing"）**，从不写分区 ⇒ 进一步说明：XNU/HakiOS 圈**没有**任何 flashed 形态经验可借 |
| 14 | `superboyyy/hakios-arm64e-dada`（小米 15 iOS 26） | https://github.com/superboyyy/hakios-arm64e-dada | 2026-10-31 | 无变化 | 无关（同样只用 `fastboot boot`） |
| 15 | 内核侧：我们的 `sm8750-lenovo-elden` 系列 | https://patchwork.kernel.org/project/linux-arm-msm/list/?q=lenovo-elden | v3 (10-31) → v4 (10-31) → v5 (11-02) → **v6 (2026-11-04，state=superseded)** | **有变化**：v6 状态为 `superseded`（v6 两片均已被后续版本取代；devicetree 侧标 `handled-elsewhere`） | 需确认 v7 是否已发出/是否进 `dt` 分支；投递节奏按 §7 逐次批准 |
| 16 | 内核侧：`arm64: dts: qcom: sm8750: mark the ADSP fastrpc node as non-secure domain` | https://patchwork.kernel.org/project/linux-arm-msm/list/ （2026-11-07，`new`） | **2026-11-07** | **新（窗口内，非我方）** | 直接关系我们 ADSP fastrpc / SSC 传感器线：ADSP fastrpc 节点被标为非安全域——若我们本地 DTS 与之冲突，将来 rebase 会撞；值得先读 |
| 17 | 内核侧：`arm64: dts: qcom: sm8750: describe all MDSS block resets` [v3,3/3] | 同 patchwork（2026-11-02，`new`） | 2026-11-02 | 有变化（v3） | 与我们面板/DPU 线同区，注意 reset 描述冲突面 |
| 18 | 内核侧：`iris` context bank 子节点 [v6,12/12] | 同 patchwork（2026-11-03，`new`） | 2026-11-03 | 有变化 | 相机/视频线，暂不阻塞 |
| 19 | 内核侧：ath12k / wcn7861 / WCN7861 新补丁 | linux-wireless 项目 2026-11-01 起 | 2026-11-01..09 | **无**（`project=linux-wireless&since=2026-11-01` 全量 250 条中无 `wcn78*` / SM8750 Wi-Fi 相关命中） | 我们的 WiFi 线暂无上游新件可蹭 |
| 20 | 内核侧：`TB322FC` / `Y700` 在 lore | lore.kernel.org 查询被 Anubis 挡（见附录）；以 patchwork `q=TB322FC`、`q=y700` 替代检索 | — | 无外部新线程（只有我们自己的 elden 系列） | — |
| 21 | GitHub 侧 `TB322FC` 命中 | https://github.com/search?q=TB322FC&type=issues | 11-08（`Gezi121/y700-yarp-build#1`）、11-04、10-29、10-23 | 有噪声级新命中 | `y700-yarp-build` = Android recovery/解密（SPU/TA）项目，与 UEFI 无关；`kalasyan/recompa#247` = Winlator 兼容性；`corebear6010/armadaos-freedom#1` = retro98boy 的 armada 发行版 fork（kShim MMU handoff），与我们的 x86 线远方相关 |
| 22 | 「ESP/GRUB 上引导主线内核的新工具/文章」 | ① `yzddmr6/android-mainline-port#1`「[Proposal] Document a Qualcomm UEFI-first path」（LG G8/SM8150）② `armbian/build#11044` ③ Linaro U-Boot for Qualcomm（2024 旧文） | ① 2026-10-25 → **closed 2026-10-27**（作者："这条路线没走通"）② 10-21 已合并 ③ 旧 | **无新工具** | 提案正文有一条与我们处境完全同构的判断：「**只有在设备 BDS 会扫描默认 EFI 路径、且 UEFI 已加载 FAT/分区驱动时**才用 FAT32 ESP + `BOOTAA64.EFI`」——即 fs 数量问题被外部当作「BDS 顺序/驱动加载」问题，而不是平台限制 |

---

## 2. 专项：「有没有外部先例解决 flashed 形态 SP/ESP 枚举？」

**答：有先例（flashed 形态能枚举到 ESP 并起 GRUB），但没有人为 `fs=1` vs `fs=8` 这条差异留过记录。**

证据链（同机型 TB322FC）：

- `retro98boy/qualcomm-devices` §Installing Linux →「Installing via microSD」：
  `fastboot flash boot_a path-to-project-aloha.img && fastboot reboot`，随后「Project Aloha will scan the card's EFI partition, launch GRUB, and boot the kernel」；UFS 侧写 ESP 后「`dd` 写分区镜像 → reboot」即进 GRUB。**写盘形态（boot_a）下 ESP 被发现**。
- 同仓 release `lenovo-y700-gen4` 的 flashed 映像 `project_aloha_20261025.boot.img`（2026-10-25T07:15Z）配套 GPT 把 ESP 放在 **LUN0 p17**，`Flags = boot, esp`（即 ESP 类型 GUID）。
- `mu_wide_platforms#13`（11-08）：「Eight consecutive boots alternated between microSD and UFS. Each boot reached the expected root filesystem and EFI partition」——firmware 是 flashed 到 `boot_a` 的（他的流程无 `fastboot boot` 分支）。

**他为什么没撞墙 —— 与我们三个可 diff 的差异**（按可疑度排序）：

1. **他把「连接存储」写成显式 BDS 阶段代码**：`StorageConnect.c`（addon 分支 11-08）对非可发现 UFS 设备调 `ConnectController`，再按 `ScsiIo` 逐 LUN（`Lun<8`）连接，注释明确「PartitionDxe 负责分区表校验」。我们的 `TryEspBoot` 若在 UFS LUN 的 `SimpleFileSystem` 尚未挂出时 `LocateHandleBuffer(ByProtocol, SimpleFileSystem)` 一次，就会得到「只有 1 个 fs」（=FV 内建的那个），且**两形态时序不同**（`fastboot boot` 形态 ABL 已先驱动/UFS 已 init，flashed 形态没有）。这与 `PITFALLS #571`「枚举时机/顺序 或 ABL 传参」猜测一致，但外部给出了**具体形状**。
2. **UFS 驱动排序**：他 11-08 把 `UFSDxe` 挪到 `QRKSDxe` 之后（APRIORI）。我们 flashed 形态跑的是同一份 FD、同一份 UFS 驱动，但**形态不同 ⇒ DXE 起始状态不同**（flashed 形态 ABL 自己已用过 UFS 做 AVB 校验/加载分区）。Sleep 态 link 的差异正好落在「谁来先叫醒它」这一点上。
3. **槽状态**：他 11-09 加「BDS 连上存储后标记活动槽 successful（校验 GPT 主备两处）」，理由是「否则 ABL 会耗尽 retry 计数」——正是我们 `PITFALLS #191` 观察到的 `PSHOLD` 复位 → 回 `_b`。他 flashing 前还要求 boot 镜像带 **AVB footer**（`avbtool`，`bootpack.json` + `PostBuild.py` 16 行改动），否则 ABL 拒绝从 boot 分区起。

**没有任何外部材料**讨论 `SimpleFileSystem` 数量在两形态间从 8 变 1；XNU/HakiOS 圈全部只用 `fastboot boot`（`IssacL04/UniXNU-Pagani_SM8750` 每条证据都注明 "without flashing"），Aloha 维护者也只维护 Windows 线、明确不收 sm8750。

---

## 3. 可直接借鉴的四个机制（都已定位到 commit/文件）

| 机制 | 位置 | 一句话 |
|---|---|---|
| UFS 排序修法（无二进制补丁） | `retro98boy/mu_wide_platforms@lenovo-y700-gen4-addon` commit `PakalaPkg: initialize UFS after QRKS on Lenovo Y700 Gen4`（2026-11-08T08:23Z）；PR #13 同内容（改 `APRIORI.inc` / `DXE.dsc.inc` / `DXE.inc` 各 1–2 行） | `UFSDxe` 排到 `QRKSDxe` 之后；或从 APRIORI 摘掉交给正常 dispatch |
| 显式连接存储 + 逐 LUN 挂分区 | `Platforms/PakalaPkg/Device/lenovo-y700g4/Library/MsPlatformDevicesLib/StorageConnect.c`（76 行）+ `MsPlatformDevicesLib.c/.h/.inf`，`DXE.dsc.inc +1` | BDS 阶段 `EldenConnectStorage()`：UFS 逐 LUN（跳过 `Lun>=8`），SD 递归连接 |
| 槽 successful 标记 | 同分支 `Library/MsPlatformDevicesLib/AndroidBootSlot.c`（248 行，通过厂商 UFS LUN4 路径定位两个 boot 分区并校验 GPT 主备后写） | 防 ABL retry 耗尽回退 `_b` |
| AVB footer 打包 | 同分支 `bootpack.json`(+15) / `PakalaPkg/PythonLibs/PostBuild.py`(+16) / `scripts/install_avbtool.sh`(+17) | flashed 形态 ABL 接受 boot 镜像的前置条件 |

附带两条工程口径：
- **按钮映射**：同分支 `PakalaPkg: use Aloha PMIC key mappings`（`Drivers/PmicKeysDxe/`，只读 SPMI；音量键=方向、电源=Enter、长按音量=Tab/Esc，单 keypad provider 避免重复事件）——与我们屏上菜单按键方案同构，可对照我们 11-08 的菜单闭环。
- **`SdccDxe` 两处 24 字节补丁**（PR #13）：跳过 SMMU 重配（`0x5570` 改 `mov w0,#0; ret`）+ 把厂商等待的 QcomBds 通知 GUID `B7972C36-…` 换成 `gMsStartOfBdsNotifyGuid`（`0x1A0A8`）——若我们将来要让 SD 与 UFS 共存于 BDS 前，这是最短路径。

---

## 4. 附录：检索基础设施状态（供后续复跑）

- `web_search` 主通道：Firecrawl **配额耗尽 HTTP 402**（`plan credits resetting at 2026-11-20T11:37:46Z`）⇒ 目前落到 Brave/Exa。`provider=browser`（本地 Firefox headless）可用。
- **lore.kernel.org 现被 Anubis（"Making sure you're not a bot", v1.26.2）拦截**：`curl`（任何 UA）→ 403 / Anubis 挑战页；headless Firefox 也过不去（PoW 未完成）。⇒ **内核侧改用 `patchwork.kernel.org` API 1.3**（`?project=linux-arm-msm&since=…&until=…&per_page=300`、`?q=lenovo-elden`），可用且带 state（`new`/`superseded`/`handled-elsewhere`/`accepted`）。注意 `per_page` 上限约 250，且默认按日期升序，**长窗口需分片**（本次按 11-01/11-03/11-06 分三段）。
- GitHub：匿名 API 已被共享出口 IP 打到 429/403；本机 `gh` 已登录（`xiaquwan1001`）⇒ 全部走 `gh api`（repos/commits/issues/pulls/files/search）。组织名注意：用户口径的 `Mu-Silicium` 实际是 **`Project-Silicium`**，`mu_wide_platforms` 在 **`sunflower2333`** 个人名下，母体是 **`Project-Aloha/mu_aloha_platforms`**。
