# UEFI 可见性与 UFSDxe 代次差（lane E，2026-10-26）

日期：2026-10-26　范围：主机侧取证/补丁/重建；**不碰设备**（上机由父 agent 排他）。
Mu 树：`build/uefi-woa-prep/repos/7-mu-lenovo` @ `6b6ac42a`（沿用 10-24 环境，11 子模块全就位）。

## §0 结论

- **能补上可见性**：BootShim 跳转前 cache maintenance 确认缺失，已补最小补丁并完成编译验证 + 三枚镜像重建，代价 = 本次约 20 分钟（增量构建 15 s/枚），无环境坑。
- 镜像：**A2**（补丁 BootShim + 厂商 UFSDxe + Mu RmVmDxe）`251953b9db75521b7938808643e2fff3b8e29887cc2013eaab70a02517a4ebb6`；**N2**（纯 Mu 对照）`528702c67a37487177f2761832d2ae949f8042798a3e9dacbdd11e574a5b2f9f`。
- issue #12：仍 Open，最后活动 = 我方 2026-10-21 追问，作者 0 回复 ⇒ 不需要回帖。

## §1 BootShim/PrePi cache maintenance 静态取证

### 1.1 现状（补丁前）

**BootShim**（`BootShim/BootShim.S`，产物 `BootShim.bin` 160 B，反汇编核对）：
`_CopyLoop` 用裸 `ldp/stp` 把 payload 拷到 `UEFI_BASE=0xFF300000` 后直接 `br x5` ——
**全文件 0 条 cache 指令**（无 `dc cvac/civac`、无 `ic iallu`）。

**PrePi**（`Platforms/AndromedaPkg/PrePi/`，FVMAIN_COMPACT 首个 INF `PeiUniCore.inf`）：
- `ModuleEntryPoint.S`：`ArmPlatformPeiBootAction`（本平台 ArmPlatformHelper.S = **空 `ret`**）→
  `ArmDisableCachesAndMmu`（只清 SCTLR 的 M/C/I 位，**不 clean 脏行**）→ `ArmInvalidateInstructionCache`（= `ic iallu`，I-cache 有救）。
- `PrePi.c` CEntryPoint 末尾有 `InvalidateDataCacheRange(UefiFd.Address, UefiFd.Length)` —— **只 invalidate 不 clean**。

### 1.2 为何 XBL→UEFI 需要显式维护

XBL 将 boot image（gzip(BootShim‖fd)）解到内存后跳入 BootShim；跳入时 XBL 的 cache/MMU 状态不受我方控制。
若 D-cache 仍使能：BootShim 的 `stp` 写 UEFI_BASE 产生的**脏行**只到 PoU，DRAM 内容 = 旧值；
随后 PrePi 的 `InvalidateDataCacheRange`/运行期逐出会把**脏数据直接丢弃**（invalidate ≠ flush），
UEFI_BASE 处的 UEFI FD 数据损坏 → 「UEFI 早期死亡」的一类候选根因，且与 UFSDxe 无关。
即便 D-cache 已关，I-cache 仍可能缓存过时指令（同物理地址曾被执行）。
所以拷贝→执行这一跳的标准序列是：`dc civac`（逐 64 B 覆盖拷贝目标）→ `dsb sy` → `ic iallu` → `dsb sy` → `isb`。

### 1.3 补丁

`patches/uefi/0001-bootshim-add-dc-civac-ic-iallu-before-entry.patch`：
在 `_CopyLoop` 后、`_Entry` 前插入上述五步序列（循环 `dc civac, x5` 覆盖 UEFI_SIZE=4 MiB）。
编译验证：`./build_boot_shim.sh -b 0xff300000 -s 0x00400000` rc=0；
反汇编确认 `dc civac`（`d50b7e25`）循环 + `ic iallu`（`d508751f`）+ 双 `dsb` + `isb` 就位。
产物内嵌核对：A2/N2 的 img kernel gunzip 后 shim 段均含这两个编码 ✅（见 §2）。

## §2 重建结果（A2 / N2，均含 cache 补丁 BootShim）

构建命令同 10-24 canonical：`./build_uefi.py -d lenovo-y700g4 -t RELEASE`（增量 ~15 s/枚）。

| 项 | sha256 | 大小 |
|---|---|---|
| A2 `.img` | `251953b9db75521b7938808643e2fff3b8e29887cc2013eaab70a02517a4ebb6` | 2441216 |
| A2 `.fd` | `eb00db73f7e85a9d4471d2d3c1f0afc19b3cb6519eb7034ebfad874cae3c62a9`（= 10-24 A 的 fd，仅 BootShim 变化） | 4194304 |
| N2 `.img` | `528702c67a37487177f2761832d2ae949f8042798a3e9dacbdd11e574a5b2f9f` | 2441216 |
| N2 `.fd` | `6d51c190086b4164a3fc90761dd44a2b166f5b612f76b643d8b6cbaac227e696`（= 10-24 N 的 fd） | 4194304 |
| BootShim-cachefix.bin | `0c1bb4daf0619be805ac0a1d9c601c5f61abab4342959aa92ba5c484bc09ac57` | 160 |

**逐枚核对（img → gunzip → FV → LZMA(GUID `ee4e5898…` @0xd268) → ffs-extract）**：

| 镜像 | UFSDxe（GUID 0d35cd8e） | RmVmDxe（GUID 1d9cc582） |
|---|---|---|
| A2 | **`fa561bf11eb18f142b128f0335973f6c4a8d0241747ea581d5b3a56d601878d2`（厂商 ✅）** | `4733838ee33394d762002c6fd729369ca69c0b213fcdc843aaf3cd53161a6648`（Mu） |
| N2 | `00ae059f5b4a95fbe85dc9eb4c6d991c4ea5037f330cc8d3206951680a280ac1`（Mu） | `4733838e…`（Mu） |

另：A 配置重复构建一次 img sha 与首次完全一致（确定性再证）；内层 DXE FV 12 865 544 B。
产物：`reports/artifacts/uefi-visibility-20261026/`（img×2、fd×2、BootShim、manifest.sha256）。

## §3 issue #12 只读复核

`sunflower2333/mu_wide_platforms#12`（"SM8750 (Pakala) Lenovo Y700 Gen4: vendor UFSDxe fails UEFI_DEVICE_ERROR"）：
**Open**，2 条评论：作者 2026-10-09「firmware version dependent, need a special patch」；
`xiaquwan1001` 2026-10-21 三点静态追问。**作者其后 0 回复**（updated_at 停在 10-21）。
**判据**：我方追问已在队列上、无新增信息 ⇒ **不回帖**；需回帖的触发 = 作者实质回复（给层级答案）或出现 SM8750 枚举出 UFS 的第三方案例（同 10-24 解冻条件）。

## §4 上机实验单（父 agent 执行，零写盘）

前提：设备已解锁、`adb reboot bootloader` 后 `fastboot devices` 可见。

```
# E1. 校验镜像（应与 §2 一致）
sha256sum reports/artifacts/uefi-visibility-20261026/lenovo-y700g4-A2.img   # 251953b9…
sha256sum reports/artifacts/uefi-visibility-20261026/lenovo-y700g4-N2.img   # 528702c6…
# E2. 先 A2（厂商 UFSDxe，含 cache 修复）
fastboot boot reports/artifacts/uefi-visibility-20261026/lenovo-y700g4-A2.img
# E3. 对照 N2（纯 Mu）
fastboot boot reports/artifacts/uefi-visibility-20261026/lenovo-y700g4-N2.img
```

**判据**：
- J1 可见性：A2/N2 任一出现 UEFI 画面/日志（vs 10-24 无 cache 补丁镜像的早死基线）。**若 N2 出现而 10-24 C 不出现，cache maintenance 假说成立（强判据）**。
- J2 UFS：UEFI 侧 `map -r` 列出 UFS 卷 / Linux 侧 `dmesg | grep -i ufs`、`lsblk`。A2 期望 UFS 出现；N2 按旧记录无。
- J3 ASSERT：日志/pstore 不再出现 `ASSERT … UFS.c(2326)`。
- J4（可选，需 C2 时再提）：`/proc/device-tree/hypervisor/qcom,resource-manager-rpc` 出现 ⇒ 厂商 RmVmDxe 生效。本轮未产 C2（faster：把 RmVmDxe 换回厂商 blob 重建 15 s）。
- 任一早死：无输出/黑屏即断电重启退出，无写盘风险。

**可观测替代通道（早期死亡收窄）**：
1. UART：需设备侧串口（本机**无**已记录的 TB322FC UART 附件 ⇒ 不可行）。
2. logfs/AdvLogger：`AdvLoggerPkg` 已在 FV（Pakala.fdf:125），但需要能进 UEFI 且可读 log 分区才有输出 ⇒ 前提与死亡点冲突，弱通道。
3. 显示/背光：UEFI 起 panel 后亮屏即「活过 DXE 面板初始化」的零成本信号 ⇒ **本机最可行**（手机屏幕自带，无需附件）。

## §5 回退

- 全程零写盘：`fastboot boot` 仅载内存，长按电源 10 s 断电重启即回原 Android。
- 若曾刷写（不在本 lane），回退用 `DEVICE/` 备份镜像。
- 主机侧回退：`git -C build/uefi-woa-prep/repos/7-mu-lenovo checkout BootShim/BootShim.S`（补丁已留档 patches/uefi/）；A2/N2 原始 sha 见 manifest。
