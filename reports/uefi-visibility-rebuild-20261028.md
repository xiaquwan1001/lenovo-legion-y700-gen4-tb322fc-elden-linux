# UEFI「早期可见性」复现件重制（lane E0/E1/E2，2026-10-28）

日期：2026-10-28　范围：**纯主机**（不上机、不 fastboot、不 ssh 设备、不写任何 boot 槽/分区）。
结论口径：只允许「已构建/未构建」「已证/未证实/未上机」。**构建成功 ≠ 能亮屏**。

---

## §0 结论（先数字）

| 项 | 结果 |
|---|---|
| **E0 复现 10-05 基线** | **已构建**（`header_version=0` + BootShim **无** cache 维护补丁 + Mu 原版 UFSDxe） |
| E0 镜像 | `lenovo-y700g4-E0-v0.img`，**2 441 216 B**，sha256 `987bcde9bafc7ccfb244956acb805bd7fb3e4e7cbbad72dfbc4c5b5f327a16f2` |
| E0 payload（gunzip 后） | **4 194 416 B**，sha256 `90b17286b453bb0643487c33dace6a1b7baf21dc31fdabc72be3b7f835f7238c` |
| **E1（E0 + dodge patched UFSDxe）** | **已构建**，取件 sha256 **与派工单给定值逐字节一致** |
| E1 镜像 | `lenovo-y700g4-E1-v0.img`，**2 445 312 B**，sha256 `1ae201c2d518672dc2715e2553396c6bd1fbf13c7c4804fc0ee9ed1f74f96540` |
| E1 payload | **4 194 416 B**，sha256 `c5b82bef4321c557292dfd044a94b764715d89c3706a42e4baa69448d98f205b` |
| **BootShim 是否含 `dc civac`** | **不含**（判定见 §2.3；`d50b7e25` 命中 0 次，反汇编 `_Start`…`_Dead` 共 12 条指令，无任何 cache 维护） |
| 上机 | **未上机**（本轮纯主机） |
| E2 tiny DXE | **① 不需要**（dodge 二进制已覆盖 sleep→wakeup + gear check 前唤醒）；② 若要自写，最小 ~120 行 C，**风险：写错 UFS UIC 寄存器可致 UFS 链路不可恢复**（详见 §4） |

> **对派工单的唯一更正**：`/home/xuqianhui/ext-repos/mu` **不能**构建 Y700g4 —— 它是 Mu-Silicium 主仓（`Platforms/{Asus,LG,Lenovo,OnePlus,…}`），**没有 `Platforms/PakalaPkg/Device/`、没有 `lenovo-y700g4` 设备包、没有 `build_cfg/`**。
> 实际使用的是 `build/uefi-woa-prep/repos/7-mu-lenovo`（= `mu_wide_platforms@6b6ac42a` 完整拷贝，含设备包 + `build_cfg/sm8750.json`）。详见 §1。

---

## §1 构建树与环境（复现入口）

### 1.1 树的选择

| 候选 | 判定 |
|---|---|
| `/home/xuqianhui/ext-repos/mu`（派工单指定） | ❌ **不可用**：`ls Platforms/` = `Asus LG Lenovo Motorola Nintendo Nothing OnePlus Qualcomm Realme Samsung Xiaomi ZTE`；`Silicon/Qualcomm/PakalaPkg/` 只有 `Library/` + `PakalaPkg.dsc.inc`，**无 `Device/`**；`find -iname '*y700g4*'` 只命中一张 PNG |
| `/home/xuqianhui/ext-repos/mu-dodge` | 只是 dodge 的 4 个 UFSDxe 文件（`UFSDxe.{efi,patched.efi,inf,depex}`），非构建树 |
| **`/home/xuqianhui/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo`** | ✅ **本轮使用**：`git log -1` = `6b6ac42a ci: allow DEBUG build type via workflow_dispatch input`；设备包 `Platforms/PakalaPkg/Device/lenovo-y700g4/` 完整（APRIORI.inc / DXE.inc / DXE.dsc.inc / Defines.dsc.inc / PcdsFixedAtBuild.dsc.inc / PatchedBinaries / Binaries / Library / DeviceTreeBlob / ACPI） |

### 1.2 环境（已就位，无需重装）

- `stuart_build` = `~/.local/bin/stuart_build`（Python 3.14.4，`edk2toolext` 可导入）
- clang/llvm **21**：`/usr/lib/llvm-21/bin/`（`CLANG_BIN` **必须带结尾斜杠**，见 `reports/uefi-experiment-build-20261024.md`）
- `aarch64-linux-gnu-gcc`、`mono`、`iasl`（`~/.local/bin`）、`ccache`
- nuget ext-dep 全部 `was found!`（`mu_nasm` / `mu-uncased` / `edk2-acpica-iasl` / `Mu-Basetools` / `mu-uncrustify-release`）

### 1.3 两个必须先修的坑（本轮实测，**都会静默失败**）

**坑 A：`stuart_build` 路径在本机不通** —— 报 `CRITICAL - Build failed`，4 秒结束，**真实错误被吞**（BUILDLOG 尾部只有 504 行 `warning: Unrecognized content` 噪音）。
根因是 `stuart` 传给 BaseTools 的 `build` 命令里 `Trim` 找不到（`make: Trim: 没有那个文件或目录` ⇒ `error 7000` ⇒ `error F002`）。
⇒ **绕过 stuart，直接调 BaseTools `build`**，并显式把 `BaseTools/BinWrappers/PosixLike` 加进 `PATH`（`Trim` 就在那里）。可用脚本：`/tmp/e0-direct-build.sh`（关键片段见 §1.4）。

**坑 B：`-n 26` 会让 clang 段错误** —— 26 并发下 `NetworkPkg/UefiPxeBcDxe/PxeBcDhcp6.c` 编译时
`clang: error: clang frontend command failed with exit code 139`（SIGSEGV）⇒ `error 7000 / F002`。
改成 **`-n 12`** 后**同一份源码一次通过**（`BUILD_RC=0`）。这是本轮**唯一**的非确定性构建失败。
（注：`bash build_uefi.py` 内部默认不传 `-n`，因此不会踩这个坑；手工调 `build` 才要小心。）

### 1.4 可复现构建命令（本轮实际执行）

```bash
cd /home/xuqianhui/y700-elden/build/uefi-woa-prep/repos/7-mu-lenovo
export CLANG_BIN=/usr/lib/llvm-21/bin/            # 结尾斜杠必须有
export CLANGPDB_BIN=/usr/lib/llvm-21/bin
export CLANGPDB_AARCH64_PREFIX=aarch64-linux-gnu-
export PYTHON_COMMAND=python3
export WORKSPACE=$PWD
export PACKAGES_PATH="$PWD:$PWD/Platforms:$PWD/MU_BASECORE:$PWD/Common/MU:$PWD/Common/MU_TIANO:$PWD/Common/MU_OEM_SAMPLE:$PWD/Silicon/Arm/MU_TIANO:$PWD/Features/DFCI:$PWD/Features/CONFIG:$PWD/Binaries:$PWD/Silicon/QC/Sm8750"
export EDK_TOOLS_PATH=$PWD/MU_BASECORE/BaseTools
export EDK_TOOLS_BIN=$PWD/MU_BASECORE/BaseTools/Bin/Mu-Basetools_extdep/Linux-x86
export CONF_PATH=$PWD/Conf
export PATH="$EDK_TOOLS_BIN:$PWD/MU_BASECORE/BaseTools/BinWrappers/PosixLike:$HOME/.local/bin:$PATH"

# BootShim：10-05 口径 = 无 cache 维护补丁
bash build_boot_shim.sh -b 0xFF300000 -s 0x00400000

# FD：RELEASE + NOSB（= USE_SCREEN_FOR_SERIAL_OUTPUT=1）
bash MU_BASECORE/BaseTools/BinWrappers/PosixLike/build \
  -p PakalaPkg/PakalaNoSb.dsc -b RELEASE -t CLANGPDB -n 12 -a AARCH64 \
  -y $PWD/Build/PakalaPkg/RELEASE_CLANGPDB/BUILD_REPORT.TXT \
  -Y PCD -Y DEPEX -Y FLASH -Y BUILD_FLAGS -Y LIBRARY -Y FIXED_ADDRESS -Y HASH \
  -D SHARED_CRYPTO_PATH=$PWD/MU_BASECORE/CryptoPkg/Binaries/edk2-basecrypto-driver-bin_extdep \
  -D BUILDID_STRING=Unknown -D MEMORY_PROTECTION=TRUE -D SHIP_MODE=FALSE \
  -D TARGET_DEVICE=lenovo-y700g4 -D FDT=y700g4.dtb
# 产物：Build/PakalaPkg/RELEASE_CLANGPDB/FV/SM8750_EFI.fd  (4 194 304 B)
```

耗时：**约 44 s**（第二次增量；首次同参数约 45 s 含 AutoGen）。日志：`logs/e0-direct2-20261028.log`、`logs/e1-direct-20261028.log`。

> **`USE_SCREEN_FOR_SERIAL_OUTPUT` 证据**：编译命令行里逐字出现 `-DUSE_SCREEN_FOR_SERIAL_OUTPUT=1 -DUSE_MEMORY_FOR_SERIAL_OUTPUT=0`，来源 `Platforms/PakalaPkg/PakalaNoSb.dsc:31`（`Pakala.dsc:31` 是 `0`，所以必须用 **NoSb** 这个 dsc）。
> 同一行还出现 `Building ... Platforms/AndromedaPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.inf [AARCH64]` ⇒ **早期可见性通道在本次产物中确实编入**。

---

## §2 E0 · 复现 10-05 基线

### 2.1 10-05 的真实构建参数（从会话原文反查，非记忆）

| 事实 | 证据 |
|---|---|
| 10-05 上机的镜像是 **CI 产物**，不是本地产物 | 会话 `2026-10-05T02-47-29-424Z` 记录 `out/uefi-lenovo-y700g4/PakalaPkg/ci_artifacts/lenovo-y700g4/lenovo-y700g4_NOSB.img` sha256 **`9607a394f0e8bad6b911a72094aea0957f7830e942b93f90da5893845541cc9a`**，2 441 216 B |
| 该镜像结构 | `header_version=3`、`ramdisk_size=0`、kernel gzip→4 194 416 B、`code0=0x10000381`、`magic@56=ARMd`、`_FVH@152`、PE/MZ count 42 |
| 当时的 UFSDxe | **Mu 原版**（`00ae059f…`，151 552 B）；dodge 版（`e76b555f…`，155 648 B）**当轮才刚取到、未使用** |
| 当时的 BootShim | **无 cache 维护补丁** —— 补丁是 **2026-10-26** 才加的（`reports/uefi-n2-v0-attempt-20261026.md` §1） |
| 当时的 dsc | `PakalaNoSb.dsc`（`USE_SCREEN_FOR_SERIAL_OUTPUT=1`） |
| **v3 vs v0 的矛盾** | 10-05 是 **v3** 且 ABL **真跳了**（屏出字）；10-24/26 结论是「本机 ABL 静默忽略 v3」（`PITFALLS #387`）。⇒ 这个矛盾**至今未解释**（见 §6）。本轮按派工单要求仍产 **v0**（v0 已证会真交棒，是**更保守**的选择） |

### 2.2 E0 构建步骤（本轮）

1. 确认 `BootShim/BootShim.S` 为 **HEAD 版（无 cache 补丁）**：
   `git checkout -- BootShim/BootShim.S`（此前被上一轮中断的进程清空成 0 字节，`wc -c` = 0 → 恢复后 742 B）。
2. `build_boot_shim.sh -b 0xFF300000 -s 0x00400000` → `SHIM_RC=0`
3. 直接调 BaseTools `build`（§1.4）→ `BUILD_RC=0`
4. 组装 `bootpayload.bin = BootShim.bin ‖ SM8750_EFI.fd` → `gzip -9`
5. `scripts/mkbootimg.py --header_version 0 --pagesize 4096 --base 0x0 --kernel_offset 0x8000 --cmdline ""`（`--ramdisk` 必须给，用 0 字节占位）

### 2.3 逐件记录（E0）

| 件 | 大小 | sha256 |
|---|---|---|
| `BootShim/BootShim.bin` | **112 B** | `054e114d431d52ff06f38084339a4709b0692bfc6846f0d58c2f4b40ed3b8945` |
| `SM8750_EFI.fd`（E0） | **4 194 304 B** | `5d60efd104eb5880dd6bc7e8769055d4c31eed9229073ec5e1e0229533c28ddf` |
| payload 原始（shim+fd） | **4 194 416 B** | `90b17286b453bb0643487c33dace6a1b7baf21dc31fdabc72be3b7f835f7238c` |
| `e0-bootpayload.bin`（gzip） | 2 436 681 B | `98511db91fc69a9f7112a10c9ec9dd2a7b3ae81c565a63161d99541dabcb7028` |
| **`lenovo-y700g4-E0-v0.img`** | **2 441 216 B** | **`987bcde9bafc7ccfb244956acb805bd7fb3e4e7cbbad72dfbc4c5b5f327a16f2`** |
| payload 内 UFSDxe（Mu 原版，构建输入） | 151 552 B | `00ae059f5b4a95fbe85dc9eb4c6d991c4ea5037f330cc8d3206951680a280ac1` |

**BootShim 是否含 `dc civac` —— 判定命令与结果**：

```
$ sha256sum BootShim/BootShim.bin
054e114d431d52ff06f38084339a4709b0692bfc6846f0d58c2f4b40ed3b8945  BootShim/BootShim.bin

$ for p in d50b7e25 d508751f; do printf "%s: " $p; xxd -p BootShim/BootShim.bin | tr -d '\n' | grep -o "$p" | wc -l; done
d50b7e25: 0          # DC CIVAC x0
d508751f: 0          # IC IALLU

$ llvm-objdump -d --triple=aarch64 BootShim/BootShim.elf
  _Head:  adr x1, _Payload ; b _Start
  _StackBase/_StackSize: .quad 0xFF300000 / 0x00400000 (+ ARMd magic @0x38)
  _Start: mov x4,x1 ; ldr x5,=_StackBase ; cmp x4,x5 ; b.eq _Entry ; ldr x6,=_StackSize
  _CopyLoop: ldp x2,x3,[x4],#16 ; stp x2,x3,[x5],#16 ; subs x6,x6,#16 ; b.ne _CopyLoop
  _Entry: br x5
  _Dead:  b _Dead
```

⇒ **结论：`dc civac` 命中 0 次，`ic iallu` 命中 0 次，整个 `.text` 只有 12 条指令、无任何 cache 维护** —— 与 10-05 基线一致（cache 补丁是 10-26 才加的）。
（对照：`reports/artifacts/uefi-visibility-20261026/BootShim-cachefix.bin` = **160 B**，sha256 `0c1bb4da…`，含 `d50b7e25` / `d508751f`。）

**镜像结构自检（`scripts/grubfat-inspect.sh`）**：

```
FILE: lenovo-y700g4-E0-v0.img  (2441216 B)
  sha256 987bcde9…a16f2
  [Android boot] magic=ANDROID! header_version=0
    kernel_size=2436681 ramdisk_size=0 cmdline=b''
    -> gzip decompressed 4194416 B
    code0=0x10000381  magic@56=0x644d5241 (arm64 Image (ARMd))
    UEFI FV '_FVH'@ payload 152  (PE/MZ count 33)
    => [判定] 该 boot.img 内核段是一个'arm64 壳 + 内嵌 UEFI 卷'
```

解包回读（payload sha 与组装值逐字节一致）：
```
payload sha256 90b17286b453bb0643487c33dace6a1b7baf21dc31fdabc72be3b7f835f7238c len 4194416
shim  sha256 054e114d…  fd sha256 5d60efd1…
```

> **E0 状态：已构建。未上机。**

---

## §3 E1 · dodge `UFSDxe.patched.efi` 换入

### 3.1 取件（网络今日多次 TLS eof，按派工单两步走）

| 法 | 结果 |
|---|---|
| 直连 `--noproxy '*'` 第 1 次 | `curl: (35) Recv failure: 连接被对方重置` |
| 直连 第 2 次 | `curl: (7) Failed to connect to raw.githubusercontent.com port 443` |
| **`https_proxy=http://127.0.0.1:7890` 第 1 次** | ✅ **成功** |

| 件 | 大小 | sha256 | 与派工单期望 |
|---|---|---|---|
| `UFSDxe.patched.efi` | **155 648 B** | **`e76b555f7c855784cc03303ae1044c69b24f04f214a320a8e2ea101b4f3c85ef`** | ✅ **逐字节一致** |

### 3.2 换入方式（用 `UFSDxe.inf` 的既有规则，**未手改 FDF**）

设备包的 `PatchedBinaries/UFSDxe.inf` 原文：

```
[Defines]
  FILE_GUID    = 0D35CD8E-97EA-4F9A-96AF-0F0D89F76567
  MODULE_TYPE  = DXE_DRIVER
[Binaries.AARCH64]
   DXE_DEPEX|UFSDxe.depex|*
   PE32|UFSDxe.patched.efi|*      ← 注：设备包实际写的是 PE32|UFSDxe.efi|*
[Depex]
  TRUE
```

⇒ 只要把 **`PatchedBinaries/UFSDxe.efi`** 这个文件名换成 dodge 二进制即可（**INF / APRIORI / FDF 一行没动**）：

```bash
D=Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries
cp $D/UFSDxe.efi /tmp/UFSDxe.e0-mu.efi          # 备份（= 00ae059f…）
cp .../UFSDxe.patched.efi $D/UFSDxe.efi         # = e76b555f…
# 重跑 §1.4 的 build（增量，~45 s）→ BUILD_RC=0
# 构建完立刻还原：cp /tmp/UFSDxe.e0-mu.efi $D/UFSDxe.efi
```

`APRIORI.inc` 里 UFSDxe 的位置（未改）：**第 76 行**，`INF $(PACKAGE_NAME)/Device/$(TARGET_DEVICE)/PatchedBinaries/UFSDxe.inf`；`SimpleFbDxe` 在**第 165 行**（UFSDxe 早于显示 89 位）。

### 3.3 逐件记录（E1）

| 件 | 大小 | sha256 |
|---|---|---|
| `SM8750_EFI.fd`（E1） | **4 194 304 B** | `bde4831b280710829894635ad48c2ad25107a376089ef13aba81a4550cd6bea5` |
| payload 原始 | **4 194 416 B** | `c5b82bef4321c557292dfd044a94b764715d89c3706a42e4baa69448d98f205b` |
| `e1-bootpayload.bin`（gzip） | 2 437 723 B | `2a40bc9e02833a7fdf085153991ff40eb41c670002721180d28c60e5d2b32616` |
| **`lenovo-y700g4-E1-v0.img`** | **2 445 312 B** | **`1ae201c2d518672dc2715e2553396c6bd1fbf13c7c4804fc0ee9ed1f74f96540`** |
| **FV 内实际落地的 UFSDxe PE32** | 155 652 B | `bc336c04a85748fc952a07b826b2f98ed9ccc9680ade3d6d3c6f28d2406f243d` |
| ↳ 其中 dodge 二进制部分（`[4:]`） | 155 648 B | **`e76b555f…3c85ef`** ← **逐字节一致** |

**「FV 里真的是 dodge 那枚」的验证（不是靠文件名）**：
```
$ python3 -c "..."
sec = 0D35CD8E-…SEC2.1.pe32          # GenFfs 生成的 PE32 section
dodge = UFSDxe.patched.efi
sec[:4] = 04 60 02 10                # EFI_SECTION_PE32 header（4 B）
sec[4:] == dodge                     # True，全长逐字节一致
sha256(sec[4:]) = e76b555f7c855784cc03303ae1044c69b24f04f214a320a8e2ea101b4f3c85ef
```
（该 PE32 section 已存档为 `E1-UFSDxe-in-FV-SEC2.pe32`。）

镜像结构自检：
```
FILE: lenovo-y700g4-E1-v0.img  (2445312 B)
  sha256 1ae201c2…96540
  [Android boot] header_version=0 ; kernel_size=2437723 ; ramdisk_size=0
  -> gzip decompressed 4194416 B ; code0=0x10000381 ; magic@56=ARMd
  UEFI FV '_FVH'@ payload 152  (PE/MZ count 27)
```

### 3.4 E0 → E1 的差异面（唯一变量确认）

```
payload 长度：两者均 4 194 416 B（shim 112 + fd 4 194 304）
payload 差异字节：2 401 454 个，范围 0x1cfd … 0x259c25
```
差异跨度大是因为 FV 内模块**重排**（UFSDxe 从 151 552 涨到 155 648 B，后续模块整体后移 + FFS 校验和变化），
**不是**「改了别的东西」—— 构建输入只改了一个文件（`PatchedBinaries/UFSDxe.efi`），BootShim 未重编（sha 同为 `054e114d…`）。

> **E1 状态：已构建。未上机。**

---

## §4 E2 · tiny DXE 拉 UFS link state —— 只做可行性，不实现

### 4.1 dodge 补丁到底改了什么（反汇编取证，**不是看 README**）

`ext-repos/mu-dodge/UFSDxe.efi`（原版 151 552 B，sha `0b32d924…`）vs `UFSDxe.patched.efi`（155 648 B，sha `e76b555f…`）：
**`.text` 只差 12 字节、`.data` 0 字节、`.reloc` 0 字节**，另新增一个 4 KiB 的 **`.extra` 节**（`RVA 0x24000`，SizeOfImage 151 552→155 648，`SizeOfHeaders` 不变）。

| # | 位置 | 原指令 | 补丁后 | 语义 |
|---|---|---|---|---|
| 1 | RVA `0x0a998` | `bl 0xafa4`（`35fffd80 cbnz` 后紧跟） | `mov w1,#1` ; `bl 0xb0d0` | **把「UFS Sleep」调用换成「UFS Wakeup」，并带一个 `=1` 参数** |
| 2 | RVA `0x1191c` | `bl 0x10284` | `b 0x24000`（跳进 `.extra`） | **gear check 之前**改道 |

`0xb0d0` 是新函数（原 `0xafa4` 的改写版），关键差异：
- 原 `0xafa4`：构造 UIC 命令 **`0x28c`(652) / `0x28b`(651)**（DME_* 读）→ 送 `0xdb00`（`UfsExecUicCmd` 之类）→ 读 `[sp,#32]` 状态位；
- 新 `0xb0d0`：多了 `lsl w9, w19, #4`（把入参 `w19` 左移 4 位作为 UIC 参数），**UIC 命令字改成 `0xd0`(208)**，随后同样送 `0xdb00`，`cmn w0,#0x3e8`（`-1000`）时走 `0xa778` 重试路径，最后 `ldrb w21,[sp,#32]` 写回 `[x8,#1184]`。

`0x25000`（`.extra` 尾部的另一段代码，由 `0x24000` 处跳转进入）：
```
25000: mov  w9, wzr
25004: strb w9, [x0, #1193]      ; 清某个 flag
25008: mov  w1, wzr
2500c: bl   0x106d0
25010: cbnz w0, 0x25020
25014: mov  x0, x19
25018: bl   0x11284
2501c: b    0x11920             ; 回到 gear check 主流程
25020: … mov w1,#0x47(71) ; b 0x11a04   ; 错误分支
```
`0x24000` 头部像**跳转表/描述符**（`0x1000/0x10`、`0x1c000/0x5c`… 与 `.reloc` 后的 RVA 序列），配合 `0x1191c` 的 `b 0x24000` 用。

⇒ **两条补丁语义与上游 issue #12 的说法完全对得上**：
- 补丁 1 = *"The UFS Sleep call has been Replaced with the UFS Wakeup Call"*（`0x0a998`）；
- 补丁 2 = *"Force UFS Link Wake Up Function to run before Gear Check"*（`0x1191c`）。

### 4.2 判断 ①：直接换 dodge 二进制是否已覆盖？

**是 ⇒ tiny DXE 不必要（在本层意义上）。**

理由：
1. dodge 二进制里**已经**含「sleep→wakeup 替换」+「gear check 前强制 link 唤醒」两处改动（§4.1 逐指令取证）。
2. 这两处改动正是上游建议的 tiny DXE 想做的事 —— 只不过 dodge 是**在 UFSDxe 内部、时序天然正确**的位置做的，而不是另起一个独立驱动。
3. 独立 tiny DXE 反而更差：`UFSDxe.depex` = `06 08`（= **`TRUE`**，无自带顺序约束），`APRIORI.inc` 第 76 行才加载 UFSDxe。tiny DXE 若想「在 UFSDxe 之前」跑，只能靠 `APRIORI` 手工插到第 75 行 —— 而 APRIORI 是**全局强制顺序**，插错会把 UFSDxe 推到更早（在 `PmicDxe`/`ClockDxe` 之前），UFS PHY 供电/时钟没起来 ⇒ 比现在更糟。
4. **风险对比**：dodge 二进制是**别人已验证跑起来过**的（`Status.md`：dodge `Internal Storage ✅` / `Linux Boot ✅`）；自写 tiny DXE 是**零验证**的新代码，而它操作的正是 UFS UIC 寄存器。

⇒ **结论：先做 E1（换 dodge 二进制），不要先写 tiny DXE。**

### 4.3 判断 ②：若确需自写，要什么、多少代码、什么风险

#### (a) 需要的 protocol / GUID

| 用途 | 接口 | 说明 |
|---|---|---|
| 拿 UFS 主机控制器 | **`gEdkiiUfsHostControllerProtocolGuid`**（`MdeModulePkg/Include/Protocol/UfsHostController.h`） | `EFI_UFS_HOST_CONTROLLER_PROTOCOL`：`SendUicCommand` / `DmmeGet` / `DmmeSet` / `Map/Unmap` / `AllocateBuffer` —— **首选路径，不碰裸 MMIO** |
| 拿控制器平台信息 | **`gEdkiiUfsHostControllerPlatformProtocolGuid`**（`UfsHostControllerPlatform.h`） | 提供 `UfsVersion` / `UfsBaseAddress` / `UfsHostControllerId` |
| 直接 MMIO（备选） | UFSHCI 寄存器基址 | 本机 DSDT `Device (UFS0)` 的 `_CRS`：**`Memory32Fixed(0x01D84000, 0x0001C000)`**、中断 `0x129`（`iasl -d` 反编译 `ACPI/DSDT.aml` 取得） |

> **注意**：`EdkiiUfsHostControllerProtocol` **由 UFSDxe 自己生产**。所以独立 tiny DXE **无法**用这个 protocol 去「先于 UFSDxe 把 link 拉起来」—— 它必须**裸 MMIO**（`0x1D84000`）。这是 §4.2 结论 3 的又一层理由。

#### (b) 裸 MMIO 的最小动作（UFSHCI 3.x）

```
1. 读 HCS (0x30) 确认 UTP 就绪；读 HCS 的 UPMCRS 字段判断当前 Unipro 电源模式
2. 若已 Active/Idle 则直接返回（幂等，避免把好状态搞坏）
3. 若为 Sleep/SleepStall：
   写 UICCMDAR (0x94) = (MIB 属性 | 目标值)
   MIB_SLEEP / MIB_POWER_MODE 的 "UniPro Power Mode" = FastAuto / Fast / SlowAuto / Slow
   轮询 UICCMDAR 的 bit31（Command Complete）直到置位，带超时（如 100 ms × N）
4. 读 IS (0x20) 的 UIC Command Completion (bit 0)，写回清中断
5. 再读 HCS.UPMCRS 确认已 Active
```

#### (c) depex 与 APRIORI 位置

| 项 | 结论 |
|---|---|
| depex | `gEfiCpuArchProtocolGuid`（只依赖 CPU 架构协议，与 `SimpleFbDxe` 同款最小 depex）。**不要**用 `TRUE` —— `TRUE` 会进 BDS 前的最后一批，可能晚于 UFSDxe |
| APRIORI 位置 | 必须 **早于第 76 行（UFSDxe）**，建议紧贴 `PmicDxe` / `ClockDxe` **之后**（UFS PHY 供电与参考时钟必须先起来）。具体行号需先确认 `PmicDxe`/`ClockDxe` 在 APRIORI 的实际位置（本轮未逐行核对，属**未证实**） |
| 文件名 | `Platforms/PakalaPkg/Device/lenovo-y700g4/PatchedBinaries/UfsLinkWakeDxe.{inf,efi}`，INF 里 `PE32|UfsLinkWakeDxe.efi|*`，与现有 PatchedBinaries 机制一致 |
| **不能做的** | 不要改 `UFSDxe.depex`（`06 08`=TRUE）去依赖新驱动 —— 会改变 UFSDxe 在 APRIORI 中的实际生效点，风险大于收益 |

#### (d) 最小代码量

约 **120–160 行 C**（`UfsLinkWakeDxe.c` + `.inf` + `.depex`）：
- `EntryPoint`：`gBS->LocateProtocol(gEdkiiUfsHostControllerPlatformProtocolGuid)` **不可用**（由 UFSDxe 生产）⇒ 硬编码 `0x1D84000` 或从 ACPI/HOB 取；
- `MmioRead32/Write32` + 一个有界轮询循环（`gBS->Stall`）；
- `DEBUG()` 打印**进入前/后的 HCS.UPMCRS 与 UIC 命令结果**（这是它唯一的验收价值）；
- 约 60% 代码是错误处理与日志。

#### (e) 风险（必须写明）

| 风险 | 说明 |
|---|---|
| **砖化（最严重）** | 直接写 UIC 命令字到 `0x1D84000` 的 UFSHCI 寄存器。若命令字编码错（MIB 属性/目标值/参数打包方式错），可能把 Unipro 链路推进**不可恢复的 SleepStall/Hibernate**。UFS 是**启动盘**：UFS 起不来 ⇒ 后续 `Fat`/`SimpleFileSystem` 全无，且**这次开机彻底没救**（只能长按重启回 ABL）。**零写盘，但会丢一次启动机会** |
| **与 dodge 补丁叠加** | 若同时装 dodge UFSDxe + 自写 tiny DXE，两者都会发 wakeup ⇒ 时序竞争。**不要叠加** |
| **PmicDxe/ClockDxe 时序** | UFS PHY 供电/时钟未起时发 UIC 命令 = 写进黑洞，读回全 `0xFF`，无法区分「成功」与「总线不存在」 |
| **无法自检** | tiny DXE 的日志只能靠 `FrameBufferSerialPortLib` 出屏（即依赖 E0/E1 的可见性先成立）。**没有可见性时，tiny DXE 是盲写** |
| **与 10-05 崩溃点的关系** | 10-05 的 `Synchronous Exception` 是 **`UFSDxe+0x13224`**：`ldr x9,[x0,#8]`，`x0` 来自 `ldrb` 拼出来的值（`bfi x0,x10,#8,#8` / `bfi x0,x8,#16,#16`）—— 这是**结构体/指针解引用**，`ESR=0x96000005`（Translation fault, L2）、`FAR=0x0` ⇒ **SMMU/页表层**，不是 link state 层。⇒ **tiny DXE 即使成功，也解释不了这个崩溃**（见 §6） |

### 4.4 E2 小结

| 问题 | 答案 |
|---|---|
| ① dodge 二进制是否已覆盖 tiny DXE 的功能？ | **是**（§4.1 逐指令证明两处补丁语义完全对应）。⇒ **tiny DXE 不必要** |
| ② 若需自写 | ~120–160 行 C；`gEfiCpuArchProtocolGuid` depex；插在 `PmicDxe`/`ClockDxe` 之后、APRIORI 第 76 行（UFSDxe）之前；**必须裸 MMIO `0x1D84000`**（UFS protocol 由 UFSDxe 自己生产，拿不到）。**风险：写错 UIC 命令可让 UFS 链路进不可恢复态 ⇒ 当次开机失败（零写盘，但丢一次启动）** |
| 推荐顺序 | **E0 → E1 →（若 E1 仍报 link/gear 错）才考虑 E2**；且 E2 必须**先有可见性**才有意义 |

---

## §5 上机配方与判据（**本轮不执行**）

### 5.1 E0（复现 10-05 基线）

```bash
# 零写盘，仅 fastboot boot
fastboot devices
fastboot --set-active=a          # 仓库规定动作；失败回落槽 a 时不至于掉到 b
fastboot boot reports/artifacts/uefi-e0e1-20261028/lenovo-y700g4-E0-v0.img
```

| 判据 | 含义 |
|---|---|
| `Booting FAILED (usb_read failed: No such device)` | **ABL 真交棒**（`PITFALLS #387`） |
| 屏上出现 EDK2 文字（`Synchronous Exception` / `UEFI Firmware (version …)` / 驱动 banner） | **早期可见性成立** = 复现 10-05 |
| 全程联想 logo、无黑屏切换 | **未复现**，UEFI 死在 GOP 之前 |
| 60 s 内 USB 全静默后 ~80 s 回 `17ef:7f3d`（stock Android） | 载荷崩溃，ABL 回落槽 a |

**取证要求**：屏上文字**字号小且会刷屏**（10-05 已踩过）。**从回车起用 60 fps 录像**，事后逐帧看异常前最后 10–15 行驱动 banner。

### 5.2 E1（E0 + dodge patched UFSDxe）

同 §5.1，把镜像换成 `lenovo-y700g4-E1-v0.img`。

| 现象 | 判定 |
|---|---|
| 与 E0 **完全相同** | dodge 补丁对本机**无效** ⇒ 推翻「link state = Sleep」为本机根因 |
| `ufs_error_log 11/3b/55` **消失**，但出 `Synchronous Exception`（`ESR 0x96…05`） | link 层修好、**卡在 SMMU 层** ⇒ 转 SMMU 方向，tiny DXE 到此为止 |
| 出现 `SimpleFileSystem` 句柄 / `map -r` 能列分区 | **E1 成功**（UFS 全通） |
| 出现**新**的崩溃点（PC 不在 `UFSDxe+0x13224`） | dodge 二进制引入 dodge 专属路径问题（PMIC/Clock 不同）⇒ 记下新 PC，回退 E0 |

### 5.3 回退

```bash
fastboot set_active b     # 失败 fastboot boot 会把槽标 unbootable；恢复
fastboot reboot
```
全程零写盘（仅 misc 槽属性）。

---

## §6 未证实项与风险

### 6.1 未证实（本轮明确没能定的）

| # | 项 | 现状 |
|---|---|---|
| 1 | **10-05 亮屏 vs 10-26 全静默的真正差异** | **未证实**。已收窄到 3 个候选：① **v3 vs v0**（10-05 用 v3 且**真跳了**；10-24/26 结论是 v3 不跳 —— **直接矛盾**）② CI 双跑（`WM_CI_BUILD=true` 同产 SB+NoSb）vs 本地单跑 ③ BootShim `dc civac` 补丁（**本轮已按 10-05 口径去掉**，E0 就是该变量） |
| 2 | **v3 到底跳不跳** | 未证实。本轮按派工单产 v0（保守），**没有**产 v3 对照件 |
| 3 | **E0/E1 是否真能亮屏** | **未上机**。构建成功 ≠ 能亮屏 |
| 4 | **本机 UFS 是否真的处于 Sleep** | 未证实。只有上游主张 + dodge 补丁的间接支持；本机 `HCS.UPMCRS` 从未读出来过（没有可见性/串口） |
| 5 | **`PmicDxe`/`ClockDxe` 在 APRIORI 的确切行号** | 未逐行核对（只确认 `UFSDxe`=76、`SimpleFbDxe`=165） |
| 6 | **dodge UFSDxe 的 PMIC/Clock 依赖是否与本机兼容** | 未证实。dodge=OnePlus 13，本机=Lenovo Y700g4；两者同 SM8750 但 `PatchedBinaries` 集合不同（dodge 有 `PhoenixDxe` 等） |
| 7 | **`DeviceTreeBlob/Linux/linux-y700g4.dtb` 是占位符** | **已证**：文件只有 **6 字节**（`dtc` 拒绝解析）。构建时 `-D FDT=y700g4.dtb` 只是传给 UEFI 的**名字**，不读内容 ⇒ 不影响本镜像，但**影响后续 Linux 引导**（10-05 已记） |

### 6.2 本轮构建环境的两个坑（已修，但会再咬人）

1. **`stuart_build` 本机不通**（`Trim` 不在 PATH ⇒ `error 7000/F002`，且真实错误被 BUILDLOG 的 504 行 `Unrecognized content` 噪音淹没）。绕过法见 §1.4。
2. **`-n 26` 触发 clang SIGSEGV**（`PxeBcDhcp6.c`，exit 139）。`-n 12` 稳定通过。**不要**在 28 线程机上用 `-n 26` 跑这个树。

### 6.3 风险

1. **`fastboot boot` 失败会标 `slot-unbootable`**（`PITFALLS #387`）⇒ 恢复需 `fastboot set_active b` + `reboot`。
2. **dodge 二进制自带警告**：`Project-Silicium/Device-Binaries/dodge/README.md` 明写 **「These Patches are Outdated & Unstable!」**。E1 是「已知不稳但方向正确」的件。
3. **E1 的差异面很大**（240 万字节，因 FV 重排）。若 E1 出现**新**崩溃点，不能立刻归因 dodge 补丁 —— 需先确认 UFSDxe 的加载地址/大小变化是否影响别的模块（`APRIORI` 未变，但 FV 内偏移变了）。
4. **10-05 的崩溃在 `UFSDxe+0x13224`**（SMMU 层），与 dodge 补丁修的 link 层**不是同一层**。⇒ **E1 即使完全成功修好 link，仍可能在同一 PC 崩**。这是本轮最需要上机验证的判据。

### 6.4 对既有结论的影响

| 既有结论 | 本轮影响 |
|---|---|
| 10-05 亮屏（`FrameBufferSerialPortLib` 直写 framebuffer） | **未推翻**，且本轮 E0 编译命令行逐字含 `-DUSE_SCREEN_FOR_SERIAL_OUTPUT=1` + 编入 `FrameBufferSerialPortLib.inf` |
| BootShim cache 补丁是 10-26 头号嫌疑 | **未推翻**；E0 已把该变量去掉（shim 112 B / 无 `d05b7e25`） |
| dodge `UFSDxe.patched.efi` 已含 sleep→wakeup + gear 前唤醒 | **已由反汇编独立证实**（§4.1），不再只是 README 主张 |
| 上游「link state = Sleep」 | 仍是**上游主张**；本轮补充：它**只能解释 link/gear 层**，解释不了 `ESR 0x96000005` |

---

## §7 产物清单

目录：`reports/artifacts/uefi-e0e1-20261028/`（`manifest.sha256` 为权威）

| 文件 | 大小 | 说明 |
|---|---|---|
| `lenovo-y700g4-E0-v0.img` | 2 441 216 | **E0 交付件**（v0 header，BootShim 无 cache 补丁，Mu 原版 UFSDxe） |
| `lenovo-y700g4-E1-v0.img` | 2 445 312 | **E1 交付件**（同上 + dodge patched UFSDxe） |
| `e0-bootpayload.bin` | 2 436 681 | E0 的 gzip payload（= img 的 kernel 段） |
| `e1-bootpayload.bin` | 2 437 723 | E1 的 gzip payload |
| `SM8750_EFI-E1.fd` | 4 194 304 | E1 的 FD（含 dodge UFSDxe） |
| `UFSDxe.patched.efi` | 155 648 | dodge 取件原件（sha 与派工单一致） |
| `E1-UFSDxe-in-FV-SEC2.pe32` | 155 652 | 从 E1 FD 里**实际解出**的 UFSDxe PE32 section（前 4 B 为 section header） |
| `empty.ramdisk` | 0 | `mkbootimg.py` 要求 `--ramdisk`，占位 |

日志：`logs/e0-build-20261028.log`（失败的 stuart 路径）、`logs/e0-direct2-20261028.log`（E0 成功）、`logs/e1-direct-20261028.log`（E1 成功）。

构建树状态（**已还原，未留副作用**）：
- `BootShim/BootShim.S` = `git checkout` 恢复 HEAD 版（742 B，无 cache 补丁）
- `PatchedBinaries/UFSDxe.efi` = 已还原为 Mu 原版 `00ae059f…`
- `git status`：`M BootShim/BootShim.S` 已消除；仅余 2 个上一轮留下的 `.orig-mu` 备份文件（未跟踪）
