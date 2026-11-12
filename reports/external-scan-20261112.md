# 外部动向扫描 2026-11-12（窗口：2026-11-09 → 2026-11-12 16:35 CST）

只读侦察，不碰设备、不改仓库源码。作者：联网侦察子代理。
上一份 = `reports/external-scan-20261109.md`，本份只写增量/变化。
**后继**：本份 17:35 的续扫 = `reports/external-scan-20261112b.md`（该份补了内核 patchwork 侧与新同机型仓）；本份保留为其前置档。

## 0. 结论先行

1. **Mu/UEFI 生态本窗口零实质进展**：`mu_wide_platforms#12`（我们提的 UFSDxe `UEFI_DEVICE_ERROR`）十天零回应、`#13`（retro98boy UFS/SD 修法）仍 open 零评论、`retro98boy` 各仓 11-09 后停手 ⇒ **继续不等上游**，要用就自己 cherry-pick。
2. **SM8750 二进制已被上游收录（更正）**：`Device-Binaries#203`（Redmi K90 / annibale）**2026-10-29 已 merged**（原先读到的 `merged=null` 是读取口径问题）⇒ `annibale/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi` 在 `main`，可直接取来逐字节差分，不必再猜补丁偏移。
3. **`Mu-Silicium` 首个 SM8750 平台 = `Platforms/Xiaomi/annibalePkg`（Redmi K90）**：DTB 的 `compatible` 与 `msm-id` 属 `sun/sunp` 同族，Status.md 记 **Internal Storage ✅** ⇒ 对「SM8750 + UFS 在 UEFI 下能枚举」是直接反例证据（我们 issue #12 的墙不是硅片级不可解）。
4. **v4.1 release 对我们只有一条可蹭**：把 `UsbKbDxe` + `ConSplitter` 挂进 `ConIn`（annibale APRIORI 已有现成顺序可照抄）——与我们 UEFI 菜单/输入线同构；其余是 Exynos 线。
5. **Qcom 侧 11-08 之后零新提交**（`Mu-Silicium` 11-09~11-11 的 7 条全在 Exynos/三星线）；参照点仍是 10-29 的 annibale 合并。

## 1. 逐条结果表（增量）

| # | 条目 | 来源 URL | 日期 | 有无变化（相对 2026-11-09） | 可操作含义 |
|---|---|---|---|---|---|
| 1 | `sunflower2333/mu_wide_platforms#12`（UFSDxe issue） | https://github.com/sunflower2333/mu_wide_platforms/issues/12 | state=open, updated **2026-10-29T04:19:30Z**, comments=7（`gh api repos/sunflower2333/mu_wide_platforms/issues/12`，2026-11-12） | **无变化**（仍无上游回应） | 继续不等它；解冻走 #13 路线 |
| 2 | `sunflower2333/mu_wide_platforms#13`（retro98boy UFS/SD fix PR） | https://github.com/sunflower2333/mu_wide_platforms/pull/13 | state=**open 未 merge**，0 评论，updated 2026-11-08T10:35:10Z（`gh api .../pulls/13`，2026-11-12） | **无变化**（未合、无新评论） | 等维护者裁决；我们可先在其 fork 上对照 |
| 3 | `retro98boy/mu_wide_platforms` 分支 `lenovo-y700-gen4-addon` | https://github.com/retro98boy/mu_wide_platforms/commits/lenovo-y700-gen4-addon | 新增 1 条：`4e8cf708 PakalaPkg: correct Lenovo Y700 Gen4 SMBIOS product fields`（**2026-11-09T07:31:57Z**）；分支头 = `4e8cf708`（`gh api .../commits?sha=lenovo-y700-gen4-addon`，2026-11-12） | **小增量**（SMBIOS 产品字段修正；与 11-09 04:13 的 AVB footer/slot successful 相比只多这一条） | 机制面无新增；他的分支 11-09 后即停 |
| 4 | `retro98boy/qualcomm-devices`（同机型指南+release） | https://github.com/retro98boy/qualcomm-devices | pushed_at=**2026-10-25T05:49Z**（`gh api repos/retro98boy/qualcomm-devices`，2026-11-12） | **无变化** | 上份 §2/§3 的借鉴清单仍有效 |
| 5 | `Project-Silicium/Mu-Silicium` 主仓 | https://github.com/Project-Silicium/Mu-Silicium | pushed_at **2026-11-10T21:24Z**（`gh api`，2026-11-12）；11-08 20:49 之后新增：`#2184` S5E7885 DWC3、`#2185` a10 ACPI、gta3xllte/onyx 状态更新（全 Exynos 线）；**`6b3d90b7` Version 4.1（2026-11-01）** | **有变化但零 SM8750/UFS/EBS 新件** | 无可蹭；4.1 打版说明上游节奏正常 |
| 6 | `Project-Aloha/mu_aloha_platforms` | https://github.com/Project-Aloha/mu_aloha_platforms | pushed_at **2026-11-09T04:24:40Z**（`gh api`，2026-11-12） | **无新变化**（最后两条仍是上份已录的 11-09 04:22/04:23 EBS 回调） | 上份 #5 结论维持 |
| 7 | `Project-Silicium/Device-Binaries` | https://github.com/Project-Silicium/Device-Binaries | pushed_at **2026-11-10T15:13Z**；PR#203（annibale/K90 SM8750）state=closed（updated 2026-10-31T21:32Z，merged=null）；PR 列表 10-30 后无新 PR（`gh api .../pulls?sort=updated`，2026-11-12） | **有变化**：主分支 11-10 有非 PR 直接 push；**#203 关闭且未合并**（上份记录为 open/updated 10-29） | #203 关闭细节见 §2 表 #8；SM8750 二进制未被上游收 |
| 8 | **【更正】** `Project-Silicium/Device-Binaries#203`（annibale / Redmi K90 SM8750） | https://github.com/Project-Silicium/Device-Binaries/pull/203 | `state=closed, merged=true, merged_at=2026-10-29T20:10:01Z, merged_by=Robotix22, merge_commit=9f4dbfd7`（`gh api repos/.../pulls/203`，2026-11-12） | **更正骨架第 7 行**：不是「关闭且未合并」，而是 **10-29 就合并了**；骨架当时读到的 `merged=null` 应视为读取时机/字段口径问题。388 文件全在 `annibale/` 下（`annibale/QcomPkg/...`、`annibale/ArmPkg/...`） | **SM8750 二进制已被上游收录**，包含 `annibale/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi` ⇒ 我们不必只靠自己猜 UFSDxe 补丁偏移 |
| 9 | **Mu-Silicium 首个 SM8750 平台**：`Platforms/Xiaomi/annibalePkg`（Xiaomi Redmi K90） | https://github.com/Project-Silicium/Mu-Silicium/commit/4bd8ae83 · https://github.com/Project-Silicium/Mu-Silicium/blob/main/Status.md | commit `4bd8ae83`「annibale: Initial support for Xiaomi Redmi K90 (#2168)」**2026-10-29T20:25:10Z** | **新（本仓从未记录）**。`Resources/DTBs/annibale.dts`：`model = "Qualcomm Technologies, Inc. Annibale based on SM8750"`、`compatible = "qcom,sun-mtp","qcom,sun","qcom,sunp-mtp","qcom,sunp","qcom,mtp"`、`qcom,msm-id = <0x100026a …>`（即 **sun/sunp = SM8750/SM8750P 同族**）。Status.md 该机型：Display ✅ / **Internal Storage ✅** / Side Buttons ✅ / USB Device ✅ / Mass Storage ✅ / USB Host ❌ / Windows Boot ❌ / Linux Boot ❌ | **这是「SM8750 + UFS 在 UEFI 下能枚举」的上游样本**（对我们 issue #12 的 UEFI_DEVICE_ERROR 是直接反例）；`Resources/Configs/annibale.toml`：`base=0xA7100000 size=0x300000`、`requires_kernel_header=true`、`append_dtb=true`、`header_version=4` |
| 10 | annibale 的 UFSDxe 补丁样本（可逐字节差分） | https://raw.githubusercontent.com/Project-Silicium/Device-Binaries/main/annibale/QcomPkg/Drivers/UFSDxe/ | 两文件均在 `main`（2026-11-12 取） | **新**：`UFSDxe.efi` 155648 B `sha256=65e41121…f54e`；`UFSDxe.patched.efi` 159744 B `sha256=1d37e8d7…e9e6`。`cmp -l` 只报 **29 处字节差异**，其余全部相同，且 patched 尾部**多出 4096 B ARM64 代码块**（`xxd -s 0x26000`：`e9031f2a 09a41239 e1031f2a 5aacff97 80000035 e00313aa 71afff97`；首条 `mov w9,wzr; strb w9,[x0,#0x4b4]` = 「把某标志/超时字节清零」型 trampoline）。`UFSDxe.inf` 第 20 行 `PE32\|UFSDxe.patched.efi\|*` | 补丁形态**不是**上游 PR#13 那种「改 APRIORI 顺序」，而是「原地改 + 追加 trampoline 代码段」的二进制补丁 ⇒ **可以直接 diff 出偏移**，比我们猜 `Patch Nr.3` 省事。同时说明：annibale 的 PmicDxe 是 `PmicDxeLa`（= PlatformType **LA**）却 UFS ✅ ⇒ 上游 Device-Binaries#203 评论里「LA 下需要 Patch Nr.3、WP 下不需要」与我们撞的墙不矛盾，**LA 是能通 UFS 的** |
| 11 | `Project-Silicium/Mu-Silicium` v4.1 release 内容 | https://github.com/Project-Silicium/Mu-Silicium/releases/tag/v4.1 | tag `v4.1`，published **2026-11-01T21:32:03Z**, created 2026-11-01T21:31:54Z（`gh api repos/.../releases`，2026-11-12） | **新（骨架只说"4.1 打版"，未拆内容）**。Code Changes 14 条，对我们有含义的 3 条：① **Added USB Keyboard to `ConIn`**（wljf817）② `RamManagerDxe` 真正打印 RAM Range ③ `Disabled PSCI_MEM_PROTECT KEP Patch for Nicobar`。Device Changes 含 **Added Support for `annibale`（wljf817）**、gts9wifi、dreamlte、ginkgo/lime/garnet 修 boot | ①与我们 UEFI 菜单/输入线同构（把 USB KBD 挂进 ConIn 只需在 APRIORI 加 `UsbKbDxe` + `ConSplitter` —— annibale 的 APRIORI 已有 `MdeModulePkg/Bus/Usb/UsbKbDxe.inf`，可照抄顺序）；其余是 Exynos 线，无可蹭 |
| 12 | `Mu-Silicium` 主仓 11-09 → 11-11 提交 | https://github.com/Project-Silicium/Mu-Silicium/commits/main | pushed_at **2026-11-10T21:24:44Z**, updated 2026-11-11T18:31:37Z；新提交 7 条：`73daadd9` DWC3 for S5E7885/gta3xllte (#2184, 11-09T18:32)、`3429d03f` a10 ACPI (#2185)、`97b11820` onyx 更新、`d8553620`/`c375cbe5`/`46e4ac08` gta3xllte status+Exynos7885 表（11-10T17:2x-17:36） | **有变化但全是 Exynos/三星线**；Qcom 侧 11-08 之后零新提交。11-10 后只有 3 个 dependabot PR（#2186/#2187/#2188）open | 无可蹭；**Qcom/SM8750 的参照点仍是 10-29 的 annibale 那次合并** |
| 13 | `sunflower2333/mu_wide_platforms` #12 / #13 与 `retro98boy` 分支 | https://github.com/sunflower2333/mu_wide_platforms · https://github.com/retro98boy/mu_wide_platforms | #12 `state=open updated_at=2026-10-29T04:19:30Z comments=7`；#13 `state=open merged=false updated_at=2026-11-08T10:35:10Z comments=0`；retro98boy 分支头 = `4e8cf708`（**2026-11-09T07:31:57Z**），repo `pushed_at=2026-11-09T07:44:30Z`（全部 `gh api`，2026-11-12） | **无变化**（#12 十天零回应；#13 仍未 merge、零评论；retro98boy 11-09T07:44 后停手）。**新信息 = 分支清单**：除 `lenovo-y700-gen4-addon`(4e8cf708) 外还有 `lenovo-y700-gen4-fix-ufs-and-sd`(cb76ad43, = PR#13 head) 与 `main`(3e1d0520) | 维持「不等 #12」；PR#13 自 11-08 无更新 ⇒ 别指望上游短期裁决，要用就自己 cherry-pick |
## 2. 上游变化能否省掉我们一条待办 / 新红线

- **不能省**：本窗口没有一条能直接替掉我们待办的上游件；`#13` 未合入 ⇒ UFSDxe 修法仍是我们自己的事。
- **有价值的三条**：① `annibale` 证明 SM8750+UFS 在 UEFI 可枚举（墙不是硬件级）② `UFSDxe.patched.efi` 可直接差分出偏移 ③ `UsbKbDxe`+`ConSplitter` 的 APRIORI 顺序可照抄到我们菜单线。
- **无新红线**。

## 3. 检索基础设施状态

- 通道：`gh api`（仓库/提交/PR/issue 元数据）+ `raw.githubusercontent.com`（取 EFI 二进制做 `cmp -l` 差分）；patchwork API 由并行的邮件 lane 负责，本 lane 未重复。
- 失败/降级：无。骨架里 `- DONE` 占位符已于 2026-11-12 由主线清理（骨架是「先落盘再补内容」纪律的产物，内容此前只写进了表格）。
