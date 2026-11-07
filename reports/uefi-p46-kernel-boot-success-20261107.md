# UEFI p46：BDS → `LinuxLoader` 走到跳内核；**「内核真起来」= 误判，已撤回（2026-11-07 夜；2026-11-07 深夜更正）**

> ## ⛔ 更正（2026-11-07 深夜，第六轮整理 + 用户质疑）
>
> **本文 §0/§3 的「UEFI 间接引导打通 / 内核真起来」结论撤回，降级为「未证实」。**
>
> 判据错误（两条，均可复现）：
> 1. **「内核起来」的证据不可归属**：当时唯一的旁证是主机 USB 事件（`1d6b:0104`，product
>    `TB322FC mainline`）。但同型号机的 gadget iSerialNumber 是**硬编码常量 `HA2CB1KY`**
>    （`rootfs/usb-gadget:37`）⇒ 这条证据对「哪台机/是不是 U2」**零信息量**；
>    `ssh root@192.168.7.1` 同样不区分机器。认设备只认 `fastboot getvar serialno` 或
>    内核 `androidboot.serialno`（`PITFALLS #549`）。
> 2. **只有易失 DDR 环作证**：环里 `…pph-ok → JUMP-BANNER eb=Success` 只证明「跑过一条走到跳转的
>    UEFI 链」，**不能排除**「跳转后内核早崩 → 复位 → ABL 自己引导 `boot_b`」——同一个 `uname -r`、
>    同一个根分区、同样 `efi: UEFI not found.`；而环是环形缓冲、跨启动残留，同一次 32 KiB 里就混着
>    别的世代的**乱码**记录（`dulp` / `pr%Db lEn=802t` / ``dl`gs db=1``）。
>
> 后续实证（2026-11-07 19:1x，p47/p48 两发）：`flags fb=0` + `LIA st=Success` + `pre-BL` + `BL-in`
> 证明 UEFI 确实进了 `BootLinux()`，但两发**都死在 preeb 之后**（设备黑屏、USB 全无），
> 即「正常路径交棒内核」至今**未成功过**；p46 的成功走的是我手动触发的 `fastboot continue` 路径，
> 且其结果证据如上不可靠。
>
> 已登记的排他判据（`patches/uefi/20261107R43-bootpath-proof/`）：UEFI 把 ` elden_bootpath=uefi`
> 追加进 cmdline（内核侧 `/proc/cmdline` 可见，ABL 引导不会出现），并在跳转前写
> `SBLOG01 tag=jump` 到 logfs（持久）。**下一发以此二判据为准**；坑见 `PITFALLS #549`。


> 线：G1-29（UEFI 间接引导）。承接 `reports/uefi-p45-ebscreen-prebuilt-20261107.md`（p45 备料）
> 与 `reports/uefi-p39-p43-continue-20261107.md`（`fastboot continue` 纪律）。
> 本轮 = **2 发零写盘上机**（p45 定位崩点 → p46 打通），无任何分区/槽/固件写入。

---

## 0. 一句话结论（**已撤回，见文首更正**）

~~**UEFI 间接引导链路打通**~~：`fastboot boot` 起 Mu UEFI → 本树写死的 fastboot → 宿主发
`fastboot continue` → `LinuxLoader`（`QcomModulePkg`，AVB 解锁态走 `ALLOW_VERIFICATION_ERROR`）
→ `BootLinux()` → `CheckAndSetVmData` → `ExitBootServices()`（**成功**）→ `PreparePlatformHardware()`
→ `LinuxKernel()`，**内核 7.3.1 真起来**（DSI connected / WiFi 关联 / `root=/dev/sda17`）。
启的就是 ABL 启动的**同一份 `boot_b`**，新增字节 0。

途中定案一条结构性结论：**`ExitBootServices()` 之后不能再用缓存的 `BlkIo` 写盘**
（`BlkIo->WriteBlocks` 读出 0 ⇒ `blr 0` ⇒ `pc=0`），p37 起的「EB 后立刻死」全部是这一条
造成的**自家探针自杀**。

## 1. 两发上机的账（全部零写盘）

| 发 | 件 | 动作 | 结果 |
|---|---|---|---|
| p45 | `uefi-preamble45-r1.img`（`fbde3a70…`） | `boot` + `continue` | 屏上 `[K] posteb-go` → `[K] FLT pc=00000000 esr=86000007`（IABT），`x03=00004000 x04=CFCFA810`（= 缓冲指针）⇒ 崩在 `WriteBlocks(This,MediaId,Lba,0x4000,Buf)` 的 `blr x9` |
| p46 | `uefi-preamble46-r1.img`（`e78b86bc…`） | `boot` + `continue` | **内核起来**（见 §3） |

p45 时间轴（宿主 `journalctl -k` + fastboot 回显）：
`09:20:49 boot → Sending 1.480s / Booting OKAY 10.107s`；`09:21:14` USB 出现 `045e:0c2f`
（Mu UEFI 侧 fastboot，`product: sun`）；`09:21:25` `continue`；**同一秒 USB 断开、此后无枚举**。
⇒ 与 p41/p43 同形态，但这一发多了 R39 的屏显标记，直接把崩点钉在 `posteb` 转储里。

## 2. 崩点归因（静态 + 寄存器双向对齐）

- 静态（`LinuxLoader.map` 定址 + `llvm-objdump`）：`SbDumpLogNoBs` = `0x4a58..0x4c2c`，
  内联了 `SbWriteLogWindowNoBs`；写盘调用在 **`0x4c14: blr x9`**，`x9` 来自
  `0x4bfc: ldr x9, [x20, #0x20]` = `EFI_BLOCK_IO_PROTOCOL.WriteBlocks`（偏移 0x20）。
  前序寄存器装载 `x0=BlkIo, w1=MediaId, x2=Base, w3=0x4000, x4=m_SbNoBsBuf`。
- 动态（p45 屏帧）：`x03=00004000`（`w3`）与 `x04=CFCFA810`（`m_SbNoBsBuf` 运行期地址，
  = 模块基址 `0xCFCC1000` + 静态偏移 `0x39810`）**逐值吻合** ⇒ 确定停在这条 `blr`。
- 结论：**`BlkIo->WriteBlocks` 读出 0**。机制 = `ExitBootServices()` 释放 boot-services 拥有的内存、
  卸载非 runtime 映像 ⇒ 缓存的协议实例（及其函数表）失效。**该通道结构性不可用**，不是补丁能修的。

## 3. p46 与成功证据

p46 = p45 + `R41-noebdump`：删掉 `SbDumpLogNoBs("posteb")` 整段（换一行 `[K] posteb-skip`），
并在 `PreparePlatformHardware()` 两侧加 `[K] pph-go` / `[K] pph-ok`。

### 3.1 DDR 共享环形日志（`0xE3F80000`，本次上电内容，逐字）

```
[K] dump-ring-ok preeb
[K] dump-write preeb len=8224
[K] dump-tag=preeb cached=Success
[K] preeb-ok
[K] eb-go
[K] EBC-call
[K] EBC-ret0
[K] eb-ret st=Success
[K] bb4
[K] EB-returned st=Success
[K] marks: reached-eb
[K] post gbs=D4C0B010 ap=0
[K] posteb-skip
[K] EB-OK st=Success
[K] pph-go
[K] pph-ok
[K] JUMP-BANNER eb=Success
```

读法：`scripts/blackbox.py` 的 `blackbox.ko`（本轮按 `wt/reb-731` 现场重编，见 §5）以
`pa=0xE3F00000 size=0x100000` 挂 debugfs 窗口，环在窗口 +`0x80000`。
阶段页 0..15 全为 0xFF（`popcount≥6` 占比 99%+）属 PrePi `MemoryPeim` 的填充（`PITFALLS #491`），
故**以环内文本为准**，不用阶段页判读。

### 3.2 内核侧判据（SSH `root@192.168.7.1`）

| 项 | 值 |
|---|---|
| 内核 | `7.3.1-debug-vk184-00003-gec74c4795a43`（= `out/boot-elden-vk185-adsp.manifest` 的 `kernel_release` ⇒ 就是 `boot_b` 里那份 vk185 件） |
| root | `/dev/sda17 ext4`（`root=LABEL=linux17` 由 UEFI 侧 `UpdateCmdLine` 生效） |
| DSI | `card0-DSI-1/status=connected` |
| 网络 | `wlp1s0 UP 114.214.228.6`；`usb0 192.168.7.1/24` |
| ADSP | `/dev/fastrpc-adsp` 在；`qrtr` sensor 服务 1 条 |
| 其它 | 43.4 °C、`/sys/fs/pstore` 空（无崩溃留痕）、`lsmod` 43 |
| 时间自洽 | `continue` 09:31:11Z → 网络 09:31:3xZ 起 → `uptime` 与 `date` 对齐（内核在 `continue` 之后起） |

## 4. 纪律与边界（诚实标注）

- **全链路零写盘**：`fastboot boot` + `fastboot continue`；`boot_b` 与槽位（`retry=7 succ=1`）本轮未动，
  设备随后仍在 Linux 正常状态。
- **BDS 菜单没做**：G1-29 原始验收含「出现 GRUB/BDS 菜单」。本轮证明的是**链路可达**（不需要菜单即可
  交棒），菜单仍是独立工作项。
- **96 MiB 限制**：`G1-30/vk61` 已解决，UEFI 不构成主线依赖 —— 所以本线从「阻塞项」转为「可选能力」。
- **`sbstop=`/`sbprobe=` 前缀对 UEFI 路径无效**：UEFI 的 `LinuxLoader` 用的是 **`boot_b` 头部的 cmdline**，
  不是我们 `fastboot boot` 那份 boot.img 的命令行 ⇒ 以后走 UEFI 路径时不能靠前缀改行为（见 `PITFALLS #547`）。

## 5. 本轮补丁与产物

| 项 | 内容 |
|---|---|
| 补丁 | `patches/uefi/20261107R41-noebdump/0001-drop-posteb-dump-and-pph-marks.patch` |
| 配方 | `patches/uefi/p46-recipe.txt`（= p45 + R41，67 枚；构建 `成功应用补丁` 100 / 失败 0） |
| 镜像 | `out/r21-sbstop-p46/uefi-preamble46-r1.img`（`e78b86bc…`，67 219 456 B）+ `p46-s26-pb3.img` |
| 构建归档 | `reports/artifacts/uefi-20261107R41-p46/` |
| trial record | `reports/trials/20261107T101141Z-uefi-p46-kernel-boot.json` |
| 证据件 | `reports/artifacts/uefi-p46-boot-success/`（环 32 KiB 切片 + logfs 尾 16 KiB） |
| 模块 | `blackbox.ko` 现场重编：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -C wt/reb-731 M=<dir> modules`（**必须显式给 `ARCH`**，否则宿主 `uname -m`=x86_64 会让 Kbuild 走 `arch/x86`，报 `asm/compiler.h` 找不到 —— `PITFALLS #546`） |

## 6. 下一发候选（未做）

1. **启动菜单**：BDS 里给 `LinuxLoader` 加菜单（多 entry / 多 kernel），这是 G1-29 原始目标里唯一还没做的。
2. **摆脱 boot.img 限制的原意**：直接从 FAT/EXT4 读 kernel+initrd（现在仍走 `boot_b`）。
3. 把 UEFI 路径纳入日常候选启动（例如 A/B 槽出问题时的备用引导器），需要先量化「UEFI 启动耗时」。
