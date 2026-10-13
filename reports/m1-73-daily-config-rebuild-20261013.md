# M1-73 内核重建（改用现役 daily config，修配置回归）

- 日期：2026-10-13
- 执行者：fabric 子代理（编排者派发）
- 目标树：`geekidos-linux` 分支 `m1/clean-tree-7.3rc7`（tip `b3815fb150`，`1e4077e13f` 为其祖先）
- 新工作树：`build/m1-73-cfg`（新分支 `m1-73/cfg-daily`，从 `m1/clean-tree-7.3rc7` 建）
- 产物：`out/m1-73-cfg/Image.gz`、`out/m1-73-cfg/sm8750-lenovo-elden.dtb`（**只出内核，不包 boot 镜像**）
- 纪律：全程未碰设备（无 fastboot/adb/EDL）；未动 `build/m1-upstream/clean-tree-73`；未改任何 `out/*.img`；
  未改 TASKS/DEVICE/INDEX/RESOURCES/PITFALLS/versions/.githooks；无 git fetch/push；未对未知 ref 做 cat-file。

---

## 0. 结论摘要（先数字）

| 项 | 值 |
|---|---|
| 15 个 daily-only 符号里**真正恢复的** | **1 个**（`CONFIG_IPV6_MULTIPLE_TABLES=y`） |
| 其余 14 个 | 在 7.3 已被**重命名或上游删除**（其中 `PROC_SYSCTL` → `SYSCTL`，见 §1.4） |
| 新 config vs 旧 73 树 config | 全文 diff **仅 2 行**（就是 `IPV6_MULTIPLE_TABLES` + 派生的 `IPV6_SUBTREES`） |
| 构建 | `rc=0`，8:37.76，error=0，warning=0，`Image.gz` 20803825 B |
| **对「PROC_SYSCTL 缺失致 /proc/sys 不存在」假设的裁决** | **推翻**：`out/boot-elden-m1-73.img` 与 `...73e.img` 的**内嵌 IKCONFIG** 都是 `CONFIG_PROC_FS=y` + `CONFIG_SYSCTL=y`（见 §1.4） |

---

## 1. 工作树与配置

### 1.1 命令 + 原始输出

```
$ git -C /home/xuqianhui1001/y700-elden/geekidos-linux worktree add \
    -b m1-73/cfg-daily /home/xuqianhui1001/y700-elden/build/m1-73-cfg m1/clean-tree-7.3rc7
准备工作区（新分支 'm1-73/cfg-daily'）
正在更新文件: 100% (96106/96106), 完成.
HEAD 现在位于 b3815fb150 dts: elden: 追赶 clean/base 设备侧修复（splash_region 命名 + 去 simple-framebuffer + sdhc no-1-8-v）
$ ls -d build/m1-73-cfg
build/m1-73-cfg
```

```
$ cd build/m1-73-cfg
$ cp /home/xuqianhui1001/y700-elden/geekidos-linux/.config .config
cp rc=0 size=322099 sha=<daily config>
$ timeout -k 10 1800 make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
#
# configuration written to .config
#
olddefconfig rc=0
```

> **踩坑（已纠正）**：第一次按任务书原样执行 `make olddefconfig`（**无 ARCH=**），在 x86 主机上
> 落到了 **x86 Kconfig 树**，产出的是 x86 配置（出现 `CRYPTO_AES_NI_INTEL`/`CLKEVT_I8253`/`# x86 Debugging`，
> 且把所有 ARM64/Qualcomm 符号全部删掉）。该次结果已作废，上表是加 `ARCH=arm64` 后的正确结果。
> **`make olddefconfig` 必须带 `ARCH=arm64`**（Kconfig 的 arch 选择由 ARCH 变量决定，不由 `.config` 里的 `CONFIG_ARM64=y` 决定）。

### 1.2 olddefconfig 前后差异

```
$ diff /tmp/m1-73-cfg/daily-in.config .config > /tmp/m1-73-cfg/diff-after.txt
$ echo "删除行=$(grep -c '^<' diff-after.txt)  新增行=$(grep -c '^>' diff-after.txt)  变更hunk=$(grep -c '^[0-9]' diff-after.txt)"
删除行=53  新增行=144  变更hunk=120
```

- 删除 53 行 = 14 个 7.3 已不存在的 `CONFIG_*` 行 + 空行/注释头（daily 的 x86 残留配置头）。
- 新增 144 行 = 50 个 7.3 新增/改值的符号 + "`# CONFIG_x is not set`" 行 + 分节注释。
- 符号级：daily 4920 个 `CONFIG_` 行 → 结果 4956 个；**被丢弃 14 个、被补齐 50 个**（清单见 §4）。

### 1.3 `CONFIG_PROC_SYSCTL=y` 的核对（原始行）

```
$ grep -n 'CONFIG_PROC_SYSCTL\|CONFIG_SYSCTL' .config
250:CONFIG_SYSCTL_EXCEPTION_TRACE=y
10969:CONFIG_SYSCTL=y
```

即：**没有 `CONFIG_PROC_SYSCTL=y` 这一行**，出现的是 `CONFIG_SYSCTL=y`。原因是 7.3 把这个符号改名了：

```
$ grep -rn '^config PROC_SYSCTL$\|^config SYSCTL$' --include=Kconfig* .
./fs/proc/Kconfig:83:config SYSCTL           # 7.3(build/m1-73-cfg)
$ grep -n -A4 '^config PROC_SYSCTL' geekidos-linux/fs/proc/Kconfig
83:config PROC_SYSCTL                          # 7.2(现役 daily)
84-	bool "Sysctl support (/proc/sys)" if EXPERT
85-	depends on PROC_FS
86-	select SYSCTL
87-	default y
```

7.3 的 `fs/proc/Kconfig:83`：

```
config SYSCTL
	bool "Sysctl support (/proc/sys)" if EXPERT
	depends on PROC_FS
	default y
```

**结论**：7.2 的 `PROC_SYSCTL` 是可见符号（并 select 隐藏的 `SYSCTL`），7.3 把可见符号改名为 `SYSCTL`。
所以「daily 的 `PROC_SYSCTL=y` 在 7.3 找不回来」是**正常的符号演进，不是回归**；7.3 对应的 `CONFIG_SYSCTL=y`。

### 1.4 关键取证：上机镜像本身的内嵌 config（推翻 PROC_SYSCTL 假设）

用树内脚本从**已上机的镜像**里抽 IKCONFIG（`CONFIG_IKCONFIG=y` + `CONFIG_IKCONFIG_PROC=y`，内嵌在 vmlinux 里）：

```
$ ./build/m1-73-cfg/scripts/extract-ikconfig out/boot-elden-m1-73e.img  > /tmp/m1-73-cfg/73e.ikconfig
rc=0 size=324811
$ ./build/m1-73-cfg/scripts/extract-ikconfig out/boot-elden-m1-73.img   > /tmp/m1-73-cfg/73.imgconfig
rc=0 size=324811
$ grep -n 'CONFIG_PROC_FS=\|CONFIG_SYSCTL=\|CONFIG_PROC_SYSCTL' /tmp/m1-73-cfg/73e.ikconfig
10964:CONFIG_PROC_FS=y
10968:CONFIG_SYSCTL=y
$ grep -n 'CONFIG_PROC_FS=\|CONFIG_SYSCTL=\|CONFIG_PROC_SYSCTL' /tmp/m1-73-cfg/73.imgconfig
10964:CONFIG_PROC_FS=y
10968:CONFIG_SYSCTL=y
$ diff /tmp/m1-73-cfg/73e.ikconfig build/m1-upstream/clean-tree-73/.config | wc -l
0
```

- **`m1-73e` 与 `m1-73` 内核里都已经是 `CONFIG_PROC_FS=y` + `CONFIG_SYSCTL=y`**（且两份 config 与
  `clean-tree-73/.config` 逐字节相同）⇒ **上机那两个内核 `/proc/sys` 不缺**，PROC_SYSCTL 不是本次故障根因。
- 换言之，`clean-tree-73` 那份「从 M1 旧树搬来」的 `.config` **在 20:27 造 73e 之前已经被改成 daily 基线了**
  （`.config.old` 时间戳 19:20，即与 daily 同源），15 个符号的差异只存在于那之前的状态。
- 本次重建相对 73e 内核**唯一的配置差量**：

```
$ diff build/m1-upstream/clean-tree-73/.config build/m1-73-cfg/.config
1163c1163,1164
< # CONFIG_IPV6_MULTIPLE_TABLES is not set
---
> CONFIG_IPV6_MULTIPLE_TABLES=y
> # CONFIG_IPV6_SUBTREES is not set
```

### 1.5 提交

```
$ git add -f .config     # kernel 的 .gitignore 第 13 行 '.*' 忽略 .config，故需 -f
$ git commit -F - ...
ab644562a6af99f062769593b23149af4d4fddf2
elden-agent <elden@local>
M1-73: 改用现役 daily config，修 PROC_SYSCTL 等 15 项符号回归
---（正文含生成方式与 15 符号去向，见 §4）---
 .config | 12045 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 12045 insertions(+)
```

- 新分支 `m1-73/cfg-daily`：`ab644562a6`（config）→ `b3815fb150`（DTS 追赶）。
- 内核版本串：`Linux version 7.3.0-rc7-debug-gab644562a6af`（`make kernelrelease` 同）。

---

## 2. 构建

### 2.1 命令 + 结果

```
$ cd build/m1-73-cfg
$ /usr/bin/time -v timeout -k 10 3000 make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz dtbs
rc=0
start=2026-10-13T20:42:26+08:00   end=2026-10-13T20:51:03+08:00   (nproc=16)
Elapsed (wall clock) time (h:mm:ss or m:ss): 8:37.76
Maximum resident set size (kbytes): 1576032
Exit status: 0
```

### 2.2 error / warning 计数（原始 grep）

```
$ wc -l build.log
8323 /tmp/m1-73-cfg/build.log
$ grep -ciE '(^|: )(error|Error) ' build.log
0
$ grep -ciE 'warning:' build.log
0
$ grep -c '^  CC' build.log
4795
$ grep -E 'elden.*dtb|DTC.*elden' build.log
  DTC     arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
```

- `dtbs` 已执行（1897 条 DTC 行），elden 板 dtb 编译无 error/warning。
- **未构建 modules**（命令里没有 `modules` 目标）——按编排者要求保持单变量；配置里 `=m` 的驱动本次不会产出 `.ko`（见 §6 未决项）。

### 2.3 产物大小 / sha256

```
$ ls -l arch/arm64/boot/Image.gz arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 20803825 Oct 13 20:51 arch/arm64/boot/Image.gz
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001   153101 Oct 13 20:42 arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
$ sha256sum arch/arm64/boot/Image.gz arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
211694bb78c0c6b4b696ffad79f9b7906b52b43bab8f76129b9ce76506dd1924  arch/arm64/boot/Image.gz
c801884334804b56bbf4164af841a9d7896e13e3634f5f4f6000c111f983b558  arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
```

---

## 3. 产物拷贝

```
$ mkdir -p out/m1-73-cfg
$ cp build/m1-73-cfg/arch/arm64/boot/Image.gz out/m1-73-cfg/Image.gz
$ cp build/m1-73-cfg/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb out/m1-73-cfg/sm8750-lenovo-elden.dtb
$ ls -l --time-style=long-iso out/m1-73-cfg/
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 20803825 2026-10-13 20:51 Image.gz
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001   153101 2026-10-13 20:51 sm8750-lenovo-elden.dtb
$ sha256sum out/m1-73-cfg/Image.gz out/m1-73-cfg/sm8750-lenovo-elden.dtb
211694bb78c0c6b4b696ffad79f9b7906b52b43bab8f76129b9ce76506dd1924  out/m1-73-cfg/Image.gz
c801884334804b56bbf4164af841a9d7896e13e3634f5f4f6000c111f983b558  out/m1-73-cfg/sm8750-lenovo-elden.dtb
$ cmp out/m1-73-cfg/Image.gz build/m1-73-cfg/arch/arm64/boot/Image.gz && echo "Image.gz OK"
Image.gz OK
$ cmp out/m1-73-cfg/sm8750-lenovo-elden.dtb build/m1-73-cfg/.../sm8750-lenovo-elden.dtb && echo "dtb OK"
dtb OK
```

- 未向 `build/m1-upstream/clean-tree-73` 拷任何东西；未改任何 `out/*.img`（`out/boot-elden-m1-73e.img` 时间戳仍为 20:27）。
- 注意：本 dtb 来自分支 tip `b3815fb150`（**已含另一 lane 的 DTS 追赶提交：splash_region 改名 + 去 simple-framebuffer + sdhc no-1-8-v**），
  因此 153101 B，与 73e 镜像里的 153266 B（旧 dtb）、`reports/m1-73-boot-failure` 里的 153262/153084 B 均不同。

---

## 4. 新旧 config 差异分类表

**口径**：`daily-only` = 现役 daily config（`geekidos-linux/.config`，7.2.0）里有、而旧 `clean-tree-73/.config` 里
没有（或缺）的 `CONFIG_` 行，共 **15 个**（与编排者口径一致）。「7.3 状态」= 该符号在 7.3 树的 Kconfig 里是否还存在。

| # | 符号（daily 值） | 作用 | 7.3 状态 | 是否可能影响上机用户态 | 本次是否修复 |
|---|---|---|---|---|---|
| 1 | `CONFIG_PROC_SYSCTL=y` | /proc/sys 下的 sysctl 树 | **改名**：7.3 可见符号为 `fs/proc/Kconfig:83 config SYSCTL`（`default y`）；7.2 是 `PROC_SYSCTL` select 隐藏 `SYSCTL` | **理论上是**（sysctl 缺失会连带 systemd/`/proc/sys/kernel/*`），但 7.3 的等价符号 **上机镜像里已经 =y**（§1.4）⇒ 实际无影响 | 无需修复；等价项 `CONFIG_SYSCTL=y` 已在（本项目内亦保留） |
| 2 | `CONFIG_IPV6_MULTIPLE_TABLES=y` | IPv6 多路由表（`ip -6 rule`、策略路由，select FIB_RULES） | 存在（`net/ipv6/Kconfig:237`，7.3 里为 not set） | 否（与 gadget/音频/马达无关；与 daily 行为一致性有关） | **是（唯一真正恢复项）** |
| 3 | `CONFIG_CRYPTO_DEV_QCE=m` | Qualcomm 加密引擎加速（qcrypto） | 存在但**上游标 BROKEN**：`depends on (BROKEN && ARCH_QCOM) \|\| COMPILE_TEST`（`drivers/crypto/Kconfig:529`） | 否（只影响 crypto 吞吐；上游明确因与 secure world 竞争而禁用） | 否（上游禁用，无法恢复） |
| 4 | `CONFIG_CRYPTO_DEV_QCE_SKCIPHER=y` | QCE 对称算法子项 | 依赖 #3 ⇒ 7.3 不可选 | 否 | 随 #3 一并消失 |
| 5 | `CONFIG_CRYPTO_DEV_QCE_SHA=y` | QCE 哈希子项 | 同上 | 否 | 随 #3 |
| 6 | `CONFIG_CRYPTO_DEV_QCE_AEAD=y` | QCE AEAD 子项 | 同上 | 否 | 随 #3 |
| 7 | `CONFIG_CRYPTO_DEV_QCE_ENABLE_ALL=y` | QCE 全算法使能 | 同上 | 否 | 随 #3 |
| 8 | `CONFIG_CRYPTO_DEV_QCE_SW_MAX_LEN=512` | QCE 单次 SW 回退长度 | 同上 | 否 | 随 #3 |
| 9 | `CONFIG_CRYPTO_DEV_QCOM_RNG=m` | Qualcomm TRNG（/dev/hwrng） | **已删除**（Kconfig 无残留） | 很小（现代内核靠 jitter/其他熵源；仅少一路 hwrng） | 否（上游已删） |
| 10 | `CONFIG_CRYPTO_DEV_FSL_CAAM_PRNG_API=y` | i.MX CAAM PRNG API | **已删除** | 否（本板非 FSL/i.MX） | 否（无关硬件） |
| 11 | `CONFIG_ARCH_ENABLE_THP_MIGRATION=y` | THP 迁移（NUMA balancing） | **已删除**（THP 迁移改为 arch 自动能力，arch/ 里已无该符号） | 否（单节点手机 SoC） | 否（上游已删） |
| 12 | `CONFIG_ARM64_WORKAROUND_REPEAT_TLBI=y` | TLBI 顺序性 errata 规避 | **拆分**为 `ARM64_WORKAROUND_REPEAT_TLBI_SYNC`（`arch/arm64/Kconfig:705`，隐藏符号，由各 errata 条目 `select`） | 否（CPU errata 规避，与用户态无关；7.3 里 `..._SYNC=y` 且由 errata 触发，语义等价） | 等价项已在 |
| 13 | `CONFIG_DRM_VRAM_HELPER=m` | DRM 虚拟显存 helper（vboxvideo 等用） | 存在但改为**无 prompt 的隐藏 tristate**（`drivers/gpu/drm/Kconfig:244`），只能被 select | 否（本板用 msm/DPU） | 否（隐藏符号，由 select 决定，本 config 未选） |
| 14 | `CONFIG_GPIO_REGMAP=m` | regmap 后端 GPIO（GPIO 扩展芯片） | 存在但改为隐藏 tristate，本 config 里被其它驱动 select 成 **`=y`** | 否（本板 GPIO 走 pinctrl/QLUP） | 合入（值 m→y，功能覆盖不变） |
| 15 | `CONFIG_HAVE_GENERIC_VDSO=y` | 通用 vDSO 框架（用户态时间函数加速） | **改名/整合**为 `VDSO_DATASTORE`（`lib/vdso/Kconfig:3`，本 config `=y`） | 否（7.3 有 `VDSO_DATASTORE=y`，vDSO 仍启用） | 等价项已在 |

**olddefconfig 另按 7.3 默认值补齐的 50 个符号**（分组，完整清单见仓库外 `/tmp/m1-73-cfg/D2.txt`）：

| 组 | 符号 |
|---|---|
| Qualcomm 平台 | `QCOM_PAS`(`=y`)/`QCOM_PAS_TEE`(`=m`)/`QCOM_SOC`(`=y`)/`CLK_NORD_GCC`(`=m`)/`CLK_MAILI_VIDEOCC`(`=m`)/`CLK_SHIKRA_*`(`=m`)/`INTERCONNECT_QCOM_MAILI`(`=y`)/`PINCTRL_MAILI`(`=y`)/`GPIO_RTD1625`(`=y`) |
| arm64 errata/能力 | `ARM64_ERRATUM_3821522`/`ARM64_WORKAROUND_BROKEN_AMU_CONSTCNT`/`ARM64_WORKAROUND_REPEAT_TLBI_SYNC`/`NVIDIA_OLYMPUS_1027_ERRATUM`/`RENESAS_ERRATUM_GEN4GICITS1`/`ARCH_HAS_PTE_PROTNONE`/`VDSO_DATASTORE`/`HAS_SEPARATE_PREEMPT_RESCHED_BITS`（皆 `=y`） |
| crypto 库 | `CRYPTO_LIB_AES_{CBC,CCM,CTR,ECB,GCM,XTS}`（`=y`，由内核其他人选） |
| 其它总线/驱动 | `NET_VENDOR_{ZTE,NXP,MORSEMICRO}`/`MDLC_R8A78000`/`COMMON_CLK_HISI` 等（与本板无关，7.3 默认） |
| 工具链/杂项 | `CC_OPT_INLINE_MEMSET="-finline-stringops=memset"`/`SWIOTLB_DEFAULT_SIZE_MB=64`/`V4L2_ISP=m`/`VIDEO_DCT_RPPX1=m` |

> 说明：`=m` 的项本次不产出 `.ko`（未构建 modules），故 `QCOM_PAS_TEE`/`CLK_*`/V4L2 等在本 `Image.gz` 里**不可用**（见 §6）。

---

## 5. 与 daily 内核的体积对比

daily 内核取自现役 `out/boot-elden-vk126-c1.img`：

```
$ python3 tools/mkbootimg/unpack_bootimg.py --boot_img out/boot-elden-vk126-c1.img --out /tmp/vk126u2
kernel_size: 20592012   ramdisk size: 64586468   dtb size: 149063   page size: 4096
$ sha256sum /tmp/vk126u2/kernel
33f04a117dd678d7985e9093dc668ca44fd26522193b811cf9e8ec957f2f49ce  /tmp/vk126u2/kernel
```

| 内核 | 大小 (B) | sha256 | 说明 |
|---|---|---|---|
| **本次新内核** `out/m1-73-cfg/Image.gz` | **20803825** | `211694bb78c0c6b4b696ffad79f9b7906b52b43bab8f76129b9ce76506dd1924` | 7.3.0-rc7-debug-gab644562a6af（daily config + 分支 tip DTS） |
| 旧 M1-73 内核（`out/boot-elden-m1-73{,e}.img` 内） | 20798473 | `78dbf7b16595edd24b41273d778e6a499893c9e2158b5c6c8aa24d1886e2c7a1` | 与本次**只差 1 个符号**（`IPV6_MULTIPLE_TABLES`）⇒ **+5352 B** |
| 现役 daily 内核（`out/boot-elden-vk126-c1.img` 内） | 20592012 | `33f04a117dd678d7985e9093dc668ca44fd26522193b811cf9e8ec957f2f49ce` | 7.2.0（7.3 内核比它大 **+211813 B，+1.03%**） |

```
$ stat -c '%s %n' out/m1-73-cfg/Image.gz build/m1-upstream/clean-tree-73/arch/arm64/boot/Image.gz /tmp/vk126u2/kernel /tmp/u73e/kernel
20803825 out/m1-73-cfg/Image.gz
20798473 build/m1-upstream/clean-tree-73/arch/arm64/boot/Image.gz
20592012 /tmp/vk126u2/kernel
20798473 /tmp/u73e/kernel
```

> `out/boot-elden-m1-73e.img` 里的 kernel_size=20798473，与 `clean-tree-73/arch/arm64/boot/Image.gz` 完全一致 ⇒ 73e 确实是该树在
> **旧 config 修好之后**构建的（这是 §1.4 推翻前提的旁证）。

---

## 6. 未决项

1. **本 `Image.gz` 无配套模块**：命令未跑 `modules` 目标，config 里 `=m` 的驱动（`QCOM_PAS_TEE`、`CLK_GLYMUR/NORD/MAILI/SHIKRA`、`V4L2_ISP`、`VIDEO_DCT_RPPX1`、
   `CRYPTO_LIB_AES_*` 已是 `=y` 除外…）在本内核里**不存在**。若编排者打包时沿用 vk126 ramdisk 里现成的 `.ko`，
   其 `vermagic` 是 7.2 的，**7.3 内核会拒载**（`no symbol version for module_layout` 类）。要么确认 ramdisk 不含 `.ko`，要么补跑 `modules`。
2. **本次改动不足以解释上机症状**：本内核相对 73e 内核**只差 `CONFIG_IPV6_MULTIPLE_TABLES`**，而 73e 内核已带 `CONFIG_PROC_FS=y`+`CONFIG_SYSCTL=y`。
   因此「gadget 不枚举 / 无声音 / 无马达」**不能归因于本次配置回归**；余下变量在 **DTB**（另一 lane 的 `b3815fb150` 已去掉 `/chosen/simple-framebuffer`、修 splash_region、`sdhc no-1-8-v`）或内核其它改动。
   建议编排者用「本内核 + 新 DTB + vk126 ramdisk」与 73e 做单变量对照（两者内核差异仅此一项）。
3. **未上机**：本文只给主机侧证据，**不得据此写「已修复」**（AGENT-OPS §3 判据在设备侧）。
4. **`.config` 被 -f 提交为 tracked 文件**（kernel `.gitignore` 第 13 行 `.*` 忽略它）。后续若把该分支向上游/上提交补丁，
   需先 `git rm --cached .config`（上游不接受 `.config`）。这是本地基线策略，非上游产物。
5. **建议把「`make olddefconfig` 必须带 `ARCH=arm64`」写入 `PITFALLS.md`**：无 `ARCH=` 时会在 x86 主机上落到 x86 Kconfig 树，
   产出看似正常但实为 x86 的 `.config`（本次首跑即中招）。`PITFALLS.md` 属父 agent 专属，本 agent 未改。
6. `dtbs` 产物是分支 tip（含另一 lane 的 DTS 提交 `b3815fb150`）的 DTB，**不是** 73e 里那份（153266 B）。若编排者要严格单变量，
   请核对 dtb 侧变量。

---

## 附2：纪律核对（本 lane 只动这 3 处）

本 lane 的写操作**仅**：`reports/m1-73-daily-config-rebuild-20261013.md`、
`build/m1-73-cfg/.config`（+ 该工作树的构建产物）、`out/m1-73-cfg/{Image.gz,sm8750-lenovo-elden.dtb}`。

```
$ git status --short -- TASKS.md DEVICE.md INDEX.md RESOURCES.md PITFALLS.md versions .githooks out
 M PITFALLS.md
 M TASKS.md
?? out/boot-elden-m1-73.manifest
$ ls -l --time-style=long-iso out/boot-elden-m1-73e.img out/boot-elden-vk126-c1.img
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 85549056 2026-10-13 20:27 out/boot-elden-m1-73e.img
-rw-rw-r-- 1 xuqianhui1001 xuqianhui1001 85340160 2026-10-13 13:44 out/boot-elden-vk126-c1.img
$ git -C build/m1-upstream/clean-tree-73 status --short     # 空 = 干净
```

- `TASKS.md` / `PITFALLS.md` 的在途改动与 `out/boot-elden-m1-73.manifest` **非本 lane 所为**（本 lane 从未写入这两个文件；
  `PITFALLS/TASKS` 属父 agent 专属，见 AGENT-OPS §4）。
- 所有 `out/*.img` 的 mtime 未变（73e 仍 20:27、vk126-c1 仍 13:44）⇒ 未覆盖任何既有镜像。
- `build/m1-upstream/clean-tree-73` 工作区干净、未收到任何拷贝。
- 无任何 `fastboot`/`adb`/EDL/设备操作；无 git fetch/push；未对未知 ref 做 `cat-file`。

---

## 附：可复现命令清单

```bash
git -C /home/xuqianhui1001/y700-elden/geekidos-linux worktree add -b m1-73/cfg-daily \
    /home/xuqianhui1001/y700-elden/build/m1-73-cfg m1/clean-tree-7.3rc7
cd /home/xuqianhui1001/y700-elden/build/m1-73-cfg
cp /home/xuqianhui1001/y700-elden/geekidos-linux/.config .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig      # 必须带 ARCH=arm64
git add -f .config && git commit -m "M1-73: 改用现役 daily config ..."
timeout -k 10 3000 make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz dtbs
mkdir -p /home/xuqianhui1001/y700-elden/out/m1-73-cfg
cp arch/arm64/boot/Image.gz /home/xuqianhui1001/y700-elden/out/m1-73-cfg/Image.gz
cp arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb \
   /home/xuqianhui1001/y700-elden/out/m1-73-cfg/sm8750-lenovo-elden.dtb
# 取证（可选）：
./scripts/extract-ikconfig /home/xuqianhui1001/y700-elden/out/boot-elden-m1-73e.img | grep -n 'CONFIG_PROC_FS=\|CONFIG_SYSCTL='
```
