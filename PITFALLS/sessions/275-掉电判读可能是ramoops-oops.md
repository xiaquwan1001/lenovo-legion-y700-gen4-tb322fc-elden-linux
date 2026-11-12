# #620 「UEFI 后 ~60–70 s 硬件掉电」这个判读**可能是错的** —— 三臂日志全是一模一样的 ramoops oops

> 索引行见 `PITFALLS/README.md` 第 275 行。首次取证：2026-11-11 22:00（用户现场贴三臂屏上日志 + 我复核）。
> 涉及 `#617`（GRUB→EFI-stub 掉电判读）与 `reports/grub-project-scan-20261111.md` 的前提。

## 一、结论（先看这 6 行）

| 项 | 结论 |
|---|---|
| **真的是「硬件级掉电」吗？** | **不是（至少这三发不是）**。三臂全部 `Kernel panic - not syncing: Oops: Fatal exception` |
| **崩溃栈（三臂逐字相同）** | `asm_cpu_toq+0x44` ← `persistent_ram_write` ← `ramoops_pstore_write` ← `pstore_console_write` ← `console_flush_one_record` ← `console_unlock` ← `vprintk_emit` ← `_printk` ← `free_reserved_area` ← `free_initmem` ← `do_populate_rootfs` |
| **触发时刻** | A=72 s、B=15.6 s、C=16 s（**随 printk 速度变**，不是固定 60–70 s） |
| **触发点** | `populate_rootfs()` 里 `free_reserved_area()` 打 `Freeing initrd memory` → console 刷 pstore → ramoops 写坏地址 |
| **为什么以前判成「掉电」** | panic 后 `panic=15` 重启/停住 + **pstore 因 oops 发生在 pstore 自身路径里而写不进去** ⇒ 看起来「pstore 空 + 整机没了」= 掉电。`#617` 的判据链在这里自相矛盾 |
| **`efi=noruntime` / `noefi` 有没有被真正测到？** | **没有**。见 §三：三发跑的都不是我写的 grub.cfg |

## 二、三臂日志的关键片段（用户提供，逐字）

```
A（基线）:
[   71.863295] initramfs unpacking failed: broken padding
[   72.008950] Internal error: Oops: 0000000096000005 [#1] SMP
[   72.009012] pc : asm_cpu_toq+0x44/0xc8 [P]
[   72.009017] lr : persistent_ram_write+0x8c/0x118
[   72.009430] Kernel panic - not syncing: Oops: Fatal exception

B（efi=noruntime）:
[   15.493141] Initramfs unpacking failed: broken padding
[   15.626427] Unable to handle kernel paging request at virtual address ffff80014daccd8
[   15.630899] Kernel panic - not syncing: Oops: Fatal exception

C（noefi）: 同样 16 s panic，之后整屏变白才「掉电」
```

**三臂同栈 ⇒ cmdline token 完全不是变量。** 这一发**没有**回答「EBS 后掉电是否与 EFI runtime 有关」。

## 三、为什么三发都没测到我写的配置（两层错误）

- **GRUB 的 prefix 是 `/boot/grub/grub.cfg`（在 `linux17` 上），不是 ESP 的 `/EFI/grub/grub.cfg`。**
   `strings BOOTAA64.EFI` 里有 `boot/grub/grub.cfg`。我第一次把 cfg 写到 ESP `/EFI/grub/`，GRUB 根本不读。
- **即使读到了，11-08 那份旧 cfg 是单条目 `chainloader Loader.efi`** ⇒ 起的是 **`Loader.efi` 的菜单**
   （`/menu.cfg`：`Elden vk184 (ESP boot.img)` / `Elden vk185 (boot2.img)`），
   默认项 `\boot\boot.img`，而**实际跑的内核是 `boot2.img` 那个**。

判据：崩溃日志的内核串是 `7.3.1-debug-fdlqg-00083-gcc74c4795a43`，而：

```
ESP boot.img  → 7.3.1-debug-vk184-00002-g4da9a8b69fc8
ESP boot2.img → 7.3.1-debug-vk184-00003-gec74c4795a43   ← 匹配（gcc74c4795a43）
linux17 /boot/Image → 7.3.1-debug-vk184-00002-g4da9a8b69fc8
```

⇒ **起的是 `boot2.img`**，即 ESP Loader 菜单的第二项，不是我 grub.cfg 里的 `/boot/Image`。
（`-fdlqg` 是构建期 `LOCALVERSION` 被污染，不是另一棵树；本机所有 `build/*/vmlinux` 均无此串。）

## 四、真正的 bug 候选：ramoops 在 `no-map` 区域被 `iomap` 且地址错

DT（`sm8750-lenovo-elden.dtb`）：
```
ramoops@c2000000 {
    compatible = "ramoops";
    reg = <0x00 0xc2000000 0x00 0x400000>;   /* 4 MiB @ 0xc2000000 */
    console-size = <0x200000>;                /* 2 MiB */
    pmsg-size = <0x200000>;                   /* 2 MiB */
    no-map;
};
```

注意：**没有 `record-size`**，而 `console-size + pmsg-size = 4 MiB = mem_size` ⇒
`dump_mem_sz = 0`。代码路径（`fs/pstore/ram.c`）：

```c
dump_mem_sz = cxt->size - cxt->console_size - cxt->ftrace_size - cxt->pmsg_size;  /* = 0 */
ramoops_init_przs("dmesg", dev, cxt, &cxt->dprzs, &paddr, dump_mem_sz, cxt->record_size, ...);
```

`no-map` 区域 → `pfn_valid()` 为假 → `persistent_ram_iomap()` → `ioremap_wc()`。
崩溃地址 `ffff80014daccd8` **不是合法的 ioremap 返回**（太短，像被截断的物理地址 `0x14daccd8`）。

⇒ **候选 1**：`dump_mem_sz = 0` 时 `ramoops_init_przs` 的行为（0 长度 zone）导致后续 `persistent_ram_write` 写到坏指针。
⇒ **候选 2**：`record-size` 缺失 + `console-size==pmsg-size==mem_size/2` 的组合在 7.3.1 上有回归。

**必须先分清**：这是**我们 DT 的配置问题**，还是**上游 ramoops 的 bug**。

## 五、下一发怎么做（已备好）

- **修 GRUB 的 cfg 位置**（已做）：写到 `linux17:/boot/grub/grub.cfg`，备份 `grub.cfg.bak-20261111-2158`。
   新 cfg 有 4 臂：A 基线 / B `efi=noruntime` / C `noefi` / D 走 ESP Loader（对照）。
   判据 = **`/proc/cmdline` 里出现 `elden_bootmenu=grub-expA/B/C`**，否则说明又没走我的 cfg。
- **单独验 ramoops**：给 DT 加 `record-size = <0x100000>` 并把 `console-size/pmsg-size` 降到
   `0x100000`/`0x80000`，让 `dump_mem_sz > 0`。这是**最可能直接消掉 oops** 的一发。
- **判据纪律（新增）**：任何「掉电/重启」结论，必须先在屏上或串口找到 **`Kernel panic` / `Oops` / `end trace`**
   字样；**没有这三样之一，不得写「硬件掉电」**。pstore 为空**不能**作为「没 panic」的证据
   （oops 发生在 pstore 路径里时它必然写不进去）。

## 六、被这条推翻/收紧的旧口径

- **`#617`「EBS 之后 60–70 s 硬件掉电」** → 至少这三发是 **ramoops oops + panic**，不是掉电。
  `#617` 的「pstore 空 + 无 watchdog + uptime 归零」三条判据**全部可由 panic 解释**，不构成「硬件掉电」的证明。
- **`reports/grub-project-scan-20261111.md` §3.1 的推论**「kernel proper 在 EBS 后不碰固件 ⇒ 掉电更像固件计时器」
  → 前提（「掉电」）未被证实，该推论**暂缓**。
- **`reports/grub-direct-vs-secondstage-20261110.md` §1 主根因「EFI 内存契约 ~469 MiB」**
  → 与本次日志不符：本次 `Mem abort` 前内存表正常（`Total pages` 未见 469 MiB 级限制的报错），
  且崩溃点与内存契约无关。**该根因需重估**。

## 七、复现命令

```bash
# 1) 确认 GRUB 真正读哪份 cfg
ssh root@192.168.7.1 'strings /mnt/esp/EFI/BOOT/BOOTAA64.EFI | grep -m2 "grub.cfg"'
#    → boot/grub/grub.cfg    ⇒ 配置在 linux17:/boot/grub/grub.cfg

# 2) 确认 ESP 上两份 boot.img 各是哪个内核
#    （见 §三 的对照；boot2.img = ...00003-gec74c4795a43 = 崩溃日志里那个）

# 3) 看 ramoops DT
dtc -I dtb -O dts build/daily/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb | grep -A8 ramoops
#    → 无 record-size，console-size+pmsg-size == mem_size ⇒ dump_mem_sz = 0
```


---

## 八、2026-11-11 深夜补充（用户实测更正）

### 8.1 我在这里又判错两次

| # | 我写的 | 实际 |
|---|---|---|
| 1 | 「第 2 轮 GRUB 缺显示模块 ⇒ 菜单不显」 | **错**：上一版和这一版 **GRUB 菜单都能显**（用户实测） |
| 2 | 「约 20 s 后重启 = `timeout=20` + panic」 | **错**：菜单既然显示了，超时早被选择动作取代；20 s 是 **panic 的时序** |

### 8.2 「GRUB 选了之后没屏显」的真机制

**「菜单能显」≠「内核能显」**：

| 阶段 | 谁画 | 依赖 | 本机 |
|---|---|---|---|
| GRUB 菜单 | UEFI `ConOut` → GOP | GRUB `all_video`/`gfxterm`/`efi_gop` | ✅ |
| 内核日志 / panic | 内核 fbcon | `SYSFB_SIMPLEFB` 注册 `simple-framebuffer` | ❌ |

判据（`drivers/firmware/sysfb.c:19` 注释原文）：
```
 * If CONFIG_SYSFB_SIMPLEFB is not selected, never register "simple-framebuffer"
```

本机 `.config`：
```
CONFIG_SYSFB=y
# CONFIG_SYSFB_SIMPLEFB is not set     ← 根因
CONFIG_FB_EFI=y
CONFIG_DRM_SIMPLEDRM=y
CONFIG_FRAMEBUFFER_CONSOLE=y
```

`FB_EFI` 虽 `select SYSFB`，但 **`SYSFB_SIMPLEFB` 是独立 bool**（`depends on X86 || EFI`），
没它就不注册 simple-framebuffer ⇒ fbcon 无后端 ⇒ 内核从 `start_kernel` 到 panic **一个字都不出**。

这条 `#558` 原文就写着（「面板无输出：`CONFIG_SYSFB_SIMPLEFB` 未开」），
**本夜我一直没把它接上**，反而去查固件计时器与显示模块 —— 这是本夜最大的弯路。

### 8.3 「先强光一下 → 黑屏」

`msm` DRM probe 接管显示控制器 + 初始化 DSI 面板时会短时拉高背光，随后因无 fbcon（或已进 panic）再黑。
⇒ **不是掉电特征**。

### 8.4 结论不变，但取证前提变了

`#620` 的主结论（三臂日志是 ramoops oops，不是硬件掉电）**仍然成立**——那三份日志是**用户屏上抓拍**到的，
恰好是仅有的几条能看到内核字的通道。但**要继续排查，必须先让 fbcon 有后端**：

**下一发 = 开 `CONFIG_SYSFB_SIMPLEFB` 重编内核**（1 行 config）。在此之前不要靠 SSH 判断 panic（panic 后 SSH 必断）。

### 8.5 字体太小（未修）

GRUB 菜单字太小：ESP 上**没有任何 `.pf2` 字体**（`find /mnt/esp -name "*.pf2"` 为空），
要 `loadfont` 一个更大的 unicode.pf2 才有得调。
