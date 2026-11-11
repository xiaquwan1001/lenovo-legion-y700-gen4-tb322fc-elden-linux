# 阶段性总结：G1-29 EFI-stub 掉电这条线（2026-11-11 夜）

> 本轮从「phoc 版本门 / IME 候选窗」一路做到「UEFI 掉电定性」，中途连翻三次判读。
> 本文件只做**阶段收口**：说清哪些结论站得住、哪些已作废、下一步怎么走。
> 详细证据见各节指针。

---

## §0 一页结论

| 项 | 状态 | 一句话 |
|---|---|---|
| **「UEFI 后 60–70 s 硬件掉电」** | ⛔ **判读作废** | 三臂日志全是 `Kernel panic`，栈逐字相同（ramoops oops）；「掉电」是 panic 的下游症状 |
| **真正观测到的现象** | ✅ **已定性** | **只有背光、无任何屏显，约 20 s 后重启**（用户 2026-11-11 深夜现场） |
| **ramoops oops 的真因** | 🟡 **有强候选、已修、未验** | DT 缺 `record-size` 且 `console-size+pmsg-size == mem_size` ⇒ `dump_mem_sz=0`；项目里 10-22 就写好的补丁从未应用，本轮已应用并重打包 |
| **A/B/C 三臂实验** | ⚠️ **三发全部无效** | 两次都是「没走到我的配置」（第一次 cfg 写错位置，第二次 GRUB 没内嵌显示模块 ⇒ 菜单不显 ⇒ 超时/默认路径） |
| **GRUB 菜单** | 🔧 **已修（未验）** | v2 件内嵌显示模块 + `gfxmode` + 30 s 超时；sha `4f91a8fd…` |
| **T18 充电** | ✅ **根因已定 + 已修 + 上机验证** | `charge-watch` 9.0 s 启动 vs battmgr 12.84 s 节点 ⇒ 最长 ~20 s 无人顶回 ICL |

---

## §1 站得住的结论

### 1.1 「掉电」不是掉电（`PITFALLS #620`）

用户现场贴出的 A/B/C 三臂屏上日志，**全部**是：

```
Kernel panic - not syncing: Oops: Fatal exception
栈（三臂逐字相同）:
  memcpy_toio / asm_cpu_toq
  ← persistent_ram_write
  ← ramoops_pstore_write
  ← pstore_console_write
  ← console_flush_one_record / console_flush_on_panic
  ← console_unlock ← vprintk_emit ← _printk
  ← free_reserved_area ← free_initmem
  ← do_populate_rootfs
```

触发点 = `populate_rootfs()` 打 `Freeing initrd memory` 时 console 刷 pstore。

**⇒ 判据纪律（新增，已写进 `#620`）**：
**没有 `Kernel panic` / `Oops` / `end trace` 字样，不得写「硬件掉电」；pstore 为空不能当「没 panic」的证据**（oops 发生在 pstore 自身路径里，必然写不进去）。

这一条同时**收紧**了 `#617` 与 `reports/grub-project-scan-20261111.md` §3.1 的推论（那条推论以「掉电」为前提）。

### 1.2 ramoops 的 DT 缺陷（强候选，已修未验）

```dts
/* 修复前（build/daily 一直在用）*/
ramoops@c2000000 {
    reg = <0 0xc2000000 0 0x400000>;   /* 4 MiB */
    console-size = <0x200000>;          /* 2 MiB */
    pmsg-size = <0x200000>;             /* 2 MiB */
    no-map;                             /* 无 record-size */
};
/* ⇒ dump_mem_sz = 4M - 2M - 2M = 0 */

/* 修复后（本轮应用 patches/dt/0001）*/
    reg = <0 0xc2000000 0 0x800000>;   /* 8 MiB */
    record-size = <0x200000>;
    console-size = <0x200000>;
    pmsg-size = <0x400000>;
```

**这个补丁 2026-10-22 就写好了**（注释里的推理与本次完全一致：「a real `echo c > /proc/sysrq-trigger` left /sys/fs/pstore completely empty」），
**但从未 `git apply` 到 `build/daily`**。本轮已应用、重建 DTB、重打包镜像
`build/exp-cmdline/boot-elden-vk187b-ramoopsfix.img`（kernel/ramdisk 逐字节不变）。

### 1.3 T18 充电时序（已修并验证）

见 `reports/t18-charging-timing-20261111.md`。要点：
`charge-watch` 在 boot 后 **9.0 s** 启动，而 `qcom-battmgr-usb` 节点 **12.84 s** 才出现 ⇒ 首轮空转；
脚本注释自证「ADSP defaults it to 100 mA」⇒ 插电后最长 ~20 s 净放电。
已加 `wait_for_usb()` + 轮询 2 s + udev 事件兜底，上机判据全绿。

---

## §2 作废/收紧的旧结论（本夜累计 5 条）

| # | 旧结论 | 现口径 |
|---|---|---|
| 1 | `#617`「UEFI 后 60–70 s **硬件掉电**」 | **panic 的下游症状**，判读作废（`#620`） |
| 2 | `grub-project-scan-20261111.md` §3.1「内核 EBS 后不碰固件 ⇒ 像固件计时器」 | 前提未证实，推论**暂缓** |
| 3 | `grub-direct-vs-secondstage-20261110.md` §1「主根因 = EFI 内存契约 ~469 MiB」 | 与本次日志不符（崩溃点与内存契约无关），**需重估** |
| 4 | 我一度说「ADSP 起来后 `charger_pd` 变 DOWN ⇒ 关掉充电」 | **读反**：`0x1FFFFFFF` = `SERVREG_SERVICE_STATE_UP`（`pdr.h:13-19`） |
| 5 | 「C 臂会屏幕变白才掉电」（我引用过的旧口径） | **已过期**（用户明确） |

---

## §3 三臂实验为什么一直没跑成（两次不同的错，都记下）

| 轮次 | 我做的 | 错在哪 | 现象 |
|---|---|---|---|
| 第 1 轮 | 把 cfg 写到 **ESP `/EFI/grub/grub.cfg`** | GRUB 的 prefix 是 `/boot/grub`；且当时 `BOOTAA64.EFI` 是 11-08 的单条目 `chainloader Loader.efi` ⇒ 走的是 **Loader.efi 的菜单** | 看到 `Elden vk184/vk185/Mu fastboot` 菜单；三臂实际都起 `boot2.img`（内核串 `...00003-gec74c4795a43` 对上） |
| 第 2 轮 | 把菜单**内嵌**进 GRUB（`--cfg`）并 `--activate` | **模块列表里没有任何显示模块**（`MODULES` 默认只有 `normal linux fdt ext2 fat ...`，无 `all_video`/`gfxterm`/`video`/`font`/`efi_gop`）⇒ 菜单**不显示**，超时走默认 | **A/B/C 均只有背光、无屏显、~20 s 后重启** |

**第 2 轮还有一个附加效果**：因为 `set timeout=20` + 无显示，实际是「盲等 20 s → 起 A 臂（默认）→ panic」。
用户看到的「约 20 s 以后关机重启」= **`timeout=20` + panic 的组合**，不是固件计时器。

> 这条也说明：**「只有背光无屏显」本身不能证明「没走到 GRUB」**——没有显示模块的 GRUB 就是这样。

---

## §4 已做的修复（本轮）

1. **GRUB v2 件**：`build/grub-arm64/grubaa64.efi`
   - 模块补齐：`all_video gfxterm video font efi_gop gfxmenu terminal png`
   - 配置加 `insmod all_video/gfxterm/gfxmenu` + `set gfxmode=1024x768,1280x720,auto` + `terminal_output gfxterm`
   - `set timeout=30`（留足观察时间）
   - sha256 `4f91a8fdba0bb96af70763fb5d507ae63a4bdf5a55e1d0cfec564a1e0058c36d`，**已 `--activate` 到 ESP**（读回一致）
2. **ramoops DT 修复** 已应用 + 重打包 `build/exp-cmdline/boot-elden-vk187b-ramoopsfix.img`
3. **`charge-watch` 三处修复**（见 §1.3）

---

## §5 下一步（需要用户操作）

### 5.1 先验证「GRUB 菜单能看见」

```bash
ssh elden-root 'reboot bootloader'
fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img
```

**唯一判据 = 屏上是否出现 5 项菜单**（A/B/C/D/E）。
- 出现 ⇒ 第 2 轮那个坑已修好，可以继续做实验
- 仍只有背光 ⇒ 说明**不是模块问题**，而是 GOP/字体/控制台在 Mu UEFI 下不可用，需要换思路（下一步见 §5.3）

### 5.2 若菜单可见，跑实验的顺序

1. **A 臂**（基线）— 确认还能复现 panic，并**记下栈是否与 §1.1 相同**
2. 换 **ramoops 修复镜像** 再跑 A — 判据：**panic 消失**，或**栈变了**，或**pstore 里终于有东西**
3. **B**（`efi=noruntime`）/ **C**（`noefi`）— 只有 1、2 有了干净基线才有意义

### 5.3 若菜单仍不可见（备选方案）

- **D 臂（chainload `Loader.efi`）** 是纯文本菜单，能验证「UEFI 的 ConOut 到底能不能画东西」
- 若 D 能显、GRUB 不能 ⇒ 是 GRUB 的 `gfxterm` 在本机 GOP 上不可用 ⇒ 改用 `terminal_output console`（纯文本模式）
- 若 D 也不能显 ⇒ 回到 `#558` 的结论域：Mu UEFI 的 ConOut 在这块屏上就是不可用（此前 `R7 noop ConOut` 补丁就是为这个加的）

---

## §6 未完成 / 明确未做

- **未验证 ramoops 修复是否真的消掉 oops**（要上机）
- **未做 B/C 的实质对比**（三发都无效）
- **未做 Limine 直启**（`reports/bootloader-alternatives-20261111.md` §2 判定它判别价值最高，但本轮没到那一步）
- **未做固件侧 watchdog 审计**（`#620` 之后这条优先级下降：既然不是掉电，就不必先查 watchdog）
- **`grub-direct-vs-secondstage-20261110.md` §1 的「EFI 内存契约」根因需重估**（本轮未做）

---

## §7 一句话给下一个会话

**这条线现在的正确姿势是：先把「屏上能不能看到 GRUB 菜单」这件事单独确认掉**（它是一切实验的前提），
**然后再谈 `efi=noruntime` / `noefi` 的对比**。在此之前不要再假设「掉电 = 固件问题」。
