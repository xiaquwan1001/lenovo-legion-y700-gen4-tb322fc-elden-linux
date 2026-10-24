# UEFI / Gunyah 考查（2026-10-24）：两项都仍是「不重启」，但各拿到一条新证据

> 触发：`TASKS/README.md` §4 **N1 + N2**（2026-10-24 用户定的下一步）。
> 本轮性质：**纯主机侧只读**（设备未接入：`fastboot devices` 空、`adb devices` 空、SSH 22 拒连 ⇒ 无任何设备侧动作）。
> 前序结论只作输入：`reports/uefi-restart-20261021.md`、`reports/gunyah-roadmap-20261021.md`。
> 证据等级：【已证实】= 本轮命令/API 输出可复核；【未证实】= 有线索无闭环；【推测】= 推理。

## 0. 结论先行

| 项 | 本轮裁决 | 一句话理由 | 新证据 |
|---|---|---|---|
| **UEFI（N1）** | **维持搁置** | 唯一决定项是**固件里的运行期表**（`0x402` 那条），只能由原厂 DXE 供给；原厂作者回答「firmware version related，需 UFSDxe 专用补丁」，我们的追问 3 天 0 回复；且即便解掉 `0x402`，还有独立的 `UFSSmmuConfig` 失败 | 我们 10-21 的静态分析贴仍是该 issue **最后一条**，无回复【已证实】 |
| **Gunyah（N2）** | **维持不立项**，但**阶段 0 探测值得做且待设备** | 主线至今无 `drivers/virt/gunyah`（今日复核 master 目录清单）；本机 hyp 固件**确实含完整 RM + RM-RPC**，所以「能不能用」是一个还没被真正问过的二值问题 | `hypvm.mbn`（8 MiB，sha256 `c3dbff5e…`）含 `gunyah-resource-manager` / `qcom,resource-manager-rpc@%016lx` / `rm_rpc_receive_from_rm` / `rm_vm_create`【已证实】 |

**替代优先序不变**：多内核选择 = kexec（已收口）> U-Boot > UEFI。

## 1. N1 UEFI

### 1.1 上游状态（今日复核）

- issue `sunflower2333/mu_wide_platforms#12` 仍 **Open**，活动只有两条：
  ① 2026-10-09 作者：「It's a problem related to firmware version. Need a special patch on UFSDxe.」；
  ② 2026-10-21 我方静态分析（`0x402` 不是 config tag；`UFS.c+2326` 是**独立**第二故障；撤回 `CPU_Vectors`/`UsbBusStart` 两条）。
- ⇒ **我们问的「专用补丁打在哪一层」至今无回答**（3 天）。这一条是重启 UEFI 的**唯一信息入口**，它没通，其余都是猜。

### 1.2 资产（今日复核，仍是「要重下」）

| 资产 | 状态 |
|---|---|
| `mu_wide_platforms`（1.0 G）/ `uefi-firmware-backup`（1.3 G）/ `edk2-*`（1.5 G）/ 7 个实验镜像 | **仍不存在**（`reports/assets-inventory-20261023.md` 同口径） |
| 原厂固件包 `~/下载/tb322fc/` | **在**：`uefi.elf` 5 242 880 B（sha256 `fc68d2f9…`）、`imagefv.elf` 2 097 152 B、`abl.elf` 1 048 576 B、`tools.fv` 1 048 576 B、`hypvm.mbn` 8 MiB、`xbl_s*.melf`、`XblRamdump.elf` |

### 1.3 本轮新做的静态工作（以及它为什么不够）

1. 四个厂商 blob 里 `UFS.c` / `ufs_error_log` / `UFSDxe` 字符串 **0 命中** ⇒ 厂商 DXE 模块是压缩存放的。
2. `imagefv.elf` 结构已解：LZMA 压缩段 GUID `EE4E5898-…` 位于 `0x1064`，LZMA 流起 `0x1078`，
   解出内层 FV **32 198 664 B**（FV 长 `0x1EB5000`、header `0x48`、GUID `7ac07354-…`）——**可解，已落 `/tmp/imagefv_inner.bin`**。
3. 但解出后仍 **`UFS.c` 0 命中**，首层 FV 的 FFS 表也未按标准布局线性枚举（数据区为填充态）⇒
   **厂商 UFSDxe 需要逐模块二级解压才能取到**（与 Mu 侧那两个 151 552 B 的 `UFSDxe.efi` 对应）。
4. ⇒ 结论：**「厂商 UFSDxe 里到底请求不请求 `0x402` 那张表」这个关键问题，本轮仍没答上**；
   要答得写一个 FFS/LZMA 递归提取器（估 1–2 h）再反汇编。

### 1.4 如果将来重启，最小路径（按成本排序）

| 顺序 | 动作 | 成本 | 判据 |
|---|---|---|---|
| 1 | 等/催 issue #12 回答「补丁打在哪一层」 | 0 | 有实质回答即解冻 |
| 2 | 写 FFS 递归解压器，取出厂商 UFSDxe + 注册该表的那个驱动，反汇编比对 | 1–2 h | 能说出「表由谁注册、条目 `0x402` 的布局」 |
| 3 | 重下 Mu（1.0 G + 1.3 G）+ clang-21/nuget 工具链 + 设备在有 UFS 的前提下 `fastboot boot` 验证 | 天级 | UFS 枚举出 boot device |
| 4 | `UFSSmmuConfig`（`UFS.c+2326`）单独一条链——需要厂商 SMMU 驱动配合 | 未估 | 两条同时绿才算通 |

**裁决**：不动手。**解冻条件**（任一）：issue #12 给出层级答案 / 出现 SM8750 上 UEFI 真正枚举出 UFS 的第三方案例 / 需要「启动菜单」而 kexec 不可用时。

## 2. N2 Gunyah

### 2.1 主线状态（今日复核）

- GitHub API 列 `torvalds/linux:drivers/virt`（`master`）= `Kconfig Makefile acrn coco fsl_hypervisor.c nitro_enclaves steal_governor.c vboxguest vmgenid.c`
  ⇒ **没有 `gunyah/`**【已证实】。上游公开最新仍是 **v17（2024-02-22）**；高通 2024-08 博文「close to being accepted」之后无合并。
- 本机三棵树（`build/m1-73`、`linux`、`build/m3v2-7.3rc7`）`drivers/virt/` 各 4 个目录、`gunyah` **0** 文件【已证实】。

### 2.2 本轮新证据：hyp 固件里 Gunyah + RM 是齐全的

`strings ~/下载/tb322fc/hypvm.mbn`（8 MiB，sha256 `c3dbff5ec7080633e923c37749e04aa7831b5bc7e997174b263c3fbc0878b108`）：

```
gunyah-resource-manager              qcom,resource-manager-1-0
qcom,resource-manager                qcom,resource-manager-rpc@%016lx
Resource Manager version: %s (%s)    rm_rpc_receive_from_rm / rm_rpc_fifo_reply
rm_vm_create ret=%d                  Failed: to bind dbl virq
Hyp assign: Failed to send to Resource Manager
```

⇒ **EL2 侧是 Gunyah，且 RM 带 RPC 通道（dbl + rm_rpc fifo）**【已证实】。
这推翻不了「主线没驱动」，但把「本机有没有 Gunyah」从「DT 有个保留区」提升到「**固件里有完整实现**」。

### 2.3 我们的内核侧探测点已就绪（一个二值问题）

`build/m1-73/drivers/firmware/qcom/qcom_scm.c:2497 qcom_scm_gunyah_wdt_init()`（`probe` 第 2942 行调用）：

- 前置 `CONFIG_HAVE_ARM_SMCCC_DISCOVERY` —— 我们的 config 是 **`=y`**【已证实】；
- 判据 `arm_smccc_hypervisor_has_uuid(c1d58fcd-a453-5fdb-9265-ce36673d5f14)`；
- 成立且 DT 无 `qcom,kpss-wdt`/`arm,sbsa-gwdt` 时注册 **`gunyah-wdt`** 平台设备。

⇒ **零成本探测**（`reports/gunyah-roadmap-20261021.md` 阶段 0）：
`ls /sys/bus/platform/devices | grep -i gunyah` + `dmesg | grep -iE 'gunyah|hypervisor'` + `ls /proc/device-tree | grep -i hypervisor`。
**注意**：`dmesg | grep gh_rm` 无意义（树里没这个驱动），不要再用它当反证。

### 2.4 为什么仍不立项（成本账不变）

| 缺少件 | 状态 |
|---|---|
| 主线 `drivers/virt/gunyah`（v17，约 6.7 kLOC） | 要自己 port 到 7.3 + QCOM platform hooks |
| guest 固件（`edk2-gunyah*` 三仓，2.0 G） | 不在盘，可重下 |
| VMM（`qemu-for-gunyah` / crosvm） | 不在盘；`backup/avf/bin/crosvm` 是 **bionic（`/system/bin/linker64`）**，glibc/musl 主线跑不了；自编需 `cargo`（未装） |
| 下游驱动源码 `drivers/virt/gunyah`（6.6.104） | 不在盘（stock-src 里 0 命中） |

⇒ **判定口径**：阶段 0 阴性 ⇒ 永久关闭；阶段 0 阳性 ⇒ 才有「port v17 + 一个 VMM」的周级投入可谈，且仍要先答「拿它做什么」（AVF/受保护 VM 在无签名链的解锁机上收益有限）。

## 3. 本轮未做 / 需要设备

| 缺什么 | 原因 | 补做条件 |
|---|---|---|
| Gunyah 阶段 0 实机探测 | 设备未接入（`fastboot`/`adb` 均空、SSH 拒连） | 用户接 USB 并起主线 Linux，跑 §2.3 三条命令（5 min） |
| UEFI 厂商 UFSDxe 反汇编 | 需先写 FFS 递归解压器（1–2 h） | 用户决定是否投这 1–2 h |

## 4. 复现命令

```bash
# mainline 是否已有 gunyah
gh api repos/torvalds/linux/contents/drivers/virt --jq '.[].name'
# 本机三树
ls build/m1-73/drivers/virt linux/drivers/virt build/m3v2-7.3rc7/drivers/virt
# hyp 固件里的 RM
strings -n 5 ~/下载/tb322fc/hypvm.mbn | grep -iE 'gunyah-resource-manager|rm_rpc|rm_vm_create|resource-manager-rpc'
# 厂商固件压缩结构（本轮已解）
python3 - <<'PY'
import lzma; d=open('/home/xuqianhui/下载/tb322fc/imagefv.elf','rb').read()
out=lzma.decompress(d[0x1078:], format=lzma.FORMAT_ALONE); print(len(out))
PY
```

## 5. 追加（同日，`scripts/ffs-extract.py` 落地后）：厂商 DXE 不在 UEFI FV 里，而在 **XBL** 里

> 报告初稿曾假设「厂商 UFSDxe 可从 `uefi.elf` / `imagefv.elf` 里取出来和 Mu 版比对」。**这个假设是错的**，本条更正。

新工具 `scripts/ffs-extract.py`（FV/FFS/section 递归 + GUID-defined LZMA 段）实测：

| blob | 顶层结构 | 内含模块 |
|---|---|---|
| `uefi.elf`（5 242 880 B） | 一个 FV（base `0x1000`，len `0x2a8000`） | **SEC**(TE 307 400 B) + `uefiplat.cfg`(561 B) + **2 个 SMM_CORE**（LZMA 段）——**没有任何 DXE_DRIVER** |
| `imagefv.elf`（2 097 152 B） | 单个 LZMA 段（GUID 在 `0x1064`、流起 `0x1078`） | 解出内层 FV **32 198 664 B**，内容是**开机 logo BMP 集**（`battery_symbol_*` / `tsys_thermal_*` / `main_logo1.bmp`…），无 PE32 |
| `tools.fv` / `abl.elf` | 各 1 个 FV，内容为 SMM_CORE | 无 DXE |
| **`xbl_s.melf`（3 670 016 B）** | ELF32 shim（2 个 PT_LOAD，共 `0x884` B）+ 3.5 MB 打包体 | 打包体内 `ufs_error_log` 在 `0xd1541`、`ufs_` 串在 `0xc497c` ⇒ **厂商 UFS/UFSDxe 逻辑在 XBL 里** |

**影响**：

1. 「取厂商 UFSDxe 与 Mu 版逐字节比对」这条路**成本高于重下 Mu**（XBL 是 3.5 MB 打包体，需高通自有打包/压缩格式解包，且无公开格式文档）。
2. 这正好强化 §1 的「不投」结论：连**取证**都要先解开专有打包，而唯一的信息入口（issue #12 的层级答复）依然 0 回复。
3. 若将来重启 UEFI，§1.4 的顺序应改为：① 先拿 issue 答复 → ② 再决定「重下 Mu（1 G+1.3 G）」还是「逆 XBL 打包」——**后者不优先**。

**工具**：`scripts/ffs-extract.py <blob> [--out DIR] [--grep STR]`（纯 stdlib，纯只读；已能解析 FV header/ext header 链、FFS 文件、UI/PE32/GUID-defined-LZMA 段）。
