# pc1「干净世代」UEFI + R72 启动菜单修复 + GRUB 双层菜单定案（2026-11-10 晚）

> 用户指令（2026-11-10 晚）：「编一版去掉 debug 的 UEFI 启动，以及装载 grub 进行测试」；
> 「GRUB 界面可用，但逻辑有 bug：8 s 不倒计时、按键后仍到点启动（疑似进了 vk185）」；
> 「**不需要物理 POR 验收** —— 之前已查明 POR 与 `reboot bootloader` 的差异主要是脚本行为没对齐，可规避」。
> 本轮全程 **暖复位**（`reboot bootloader` / `fastboot boot`），零写盘（只动 ESP 上的 FAT 文件）。

---

## 0. 结论（先数字）

| 项 | 结果 |
|---|---|
| **干净世代构建** | `pc1` = p69 配方 **−R64/R66/R67/R68/R69/R70**（纯诊断/停留）**+ R71**（屏上静默）。产出 `out/r21-sbstop-pc1/uefi-preamblec1-r1.img`，67 186 688 B，sha256 `40d43397…` |
| **屏上静默的效果** | UEFI 阶段**不再刷任何 `[K]/[L]/[E]` 标记**（R71 在 `SerialPortWrite`/`SerialPortWriteCritical` 单一收敛点早退，标记仍进 `SbLogPut` 环形日志）。顺带去掉 R2 的**每字符 40 000 次忙等**（量级 ~1–3 ms/字符，是本轮之前最大的一笔人为开销） |
| **实测启动**（`fastboot boot pc1`，暖复位，菜单 8 s 用满） | **+39 s** 到 SSH（其中 fastboot 传输+ABL「Booting OKAY」11.7 s、loader 菜单 8 s）⇒ UEFI+内核 ≈ **19 s**；`/proc/cmdline` 有 `elden_bootloader=esp`，内核 `vk184-00002`（ESP 侧 `\boot\boot.img`） |
| **对照** | p69（含 R70 三个 25 s 停留）：128.7 s；本轮 39 s ⇒ **R70 的 74 s 停留 + 慢速屏显已被去掉**。注意：与「p67 = 54.5 s」的口径可能不同（那一条是旧测法），同法复测后才能给严格差值 |
| **GRUB 双层菜单** | GRUB 菜单可用（用户已确认）；**GRUB 侧看不到倒计时**是**结构性**的：GRUB 的倒计时文字走 `ConOut` 打印，而本平台 `ConOut` 被 R7 补丁设成 no-op（屏上是 GOP 绘制的菜单本体）⇒ 交互件改 `timeout=-1`（永不自动启动） |
| **真正的 bug 在我们自己的 loader 菜单** | 用户看到的「8 s 到点仍进入下一阶段 / 进了非预期条目」= **`Loader.efi` 的 `LMenuSelect()`**：倒计时只画一次（数字不走）+ `Start` 不因按键重置 + 结尾 `if (mLMenuTimeout == 0) Sel = 0;` 会强拉回第 0 项 ⇒ 已修（R72） |
| **R72 loader**（已被 R73 取代，见 §4） | `out/espboot-20261110/Loader-r72.efi`（184 832 B，`566cb12d…`）：标题每秒重画剩余秒数、**任何按键即取消自动启动**（`[L] menu autoboot off`）、删掉强拉回第 0 项的老逻辑 |

---

## 1. 本轮做了什么

### 1.1 构建「干净世代」pc1（主机侧）

* 配方 `patches/uefi/pc1-recipe.txt`（80 条 patch，= p69 的 79 条 − R64/R66/R67/R68/R69/R70 + R71）。
* 新增补丁 `patches/uefi/20261110R71-quiet/0001-fb-serial-quiet-default.patch`：
  `FrameBufferSerialPortLib.c` 里加 `#define ELDEN_FB_QUIET 1`，`SerialPortWrite`/`SerialPortWriteCritical`
  在 `m_Initialized` 守卫后**只 `SbLogPut()`、不画帧缓冲、不做忙等**。
* 世代入口已绑进脚本：`scripts/uefi-r21-p7-ladder.sh --gen pc1 --mkimg-only --rebuild`。
* 构建判据：`build.log` 里 **114 次 patch 应用全部成功**，最后一次正是 `FrameBufferSerialPortLib.c`（= R71）；
  `--rebuild` 不逐字节可复现属预期（`PITFALLS #510`）。
* 件：`out/r21-sbstop-pc1/uefi-preamblec1-r1.img`，并附 `pc1-m3-stop*` 阶梯件（同 p69 用法）。

### 1.2 上机（暖复位，零写盘）

```
ssh elden-root 'reboot bootloader'              # 12 s 进 fastboot
fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img
#   Sending 1.504 s / Booting OKAY 10.138 s / Finished 11.694 s
#   → SSH up at +39 s
```

* `/proc/cmdline`：`elden_root=LABEL=linux17`、`androidboot.slot_suffix=_b`、`elden_nocamera=1`、`elden_bootloader=esp`
* `/efi/loader.log`：`[L] entry r59-menu … [L] menu ui 4 → [L] menu timeout → [L] menu boot \boot\boot.img`
  （无按键 ⇒ 走默认项，**未进入 vk185**）
* ESP `BOOTAA64.EFI` 与 `/EFI/elden/Loader.efi` 均已换成 R72（`566cb12d…`），写后读回一致、`fsck.vfat -n` 干净。

### 1.3 R72：loader 菜单的两个 bug

| 现象（用户反馈） | 根因（`LinuxLoader.c: LMenuSelect`） | 修法 |
|---|---|---|
| 8 s 不倒计时，看不出还剩多少 | 标题只在 `LMenuDrawScreen()` 里画一次，值恒为 `mLMenuTimeout` | 每秒重画：`Boot menu (Vol +/- move, Power = OK, <n> s to autoboot)` |
| 按键后仍 8 s 到点启动 | `Start` 不因按键重置，`while (mLMenuTimeout > 0)` 照旧比时长 | **任何按键即 `Timeout = 0`**（只等 Power 确认），标题改 `autoboot cancelled`，日志 `[L] menu autoboot off` |
| 按过键却启动到别的条目 | `if (mLMenuTimeout == 0) Sel = 0;` 把选择强拉回第 0 项 | 改为 `if (!Keyed && mLMenuTimeout == 0)` |

* 补丁：`patches/uefi/20261110R72-loader-menu/0001-loadermenu-countdown-and-pause.patch`
* 构建：快照 4 件回填 → `stuart_build -c Platforms/PakalaPkg/PlatformBuildNoSb.py TARGET=RELEASE TARGET_DEVICE=lenovo-y700g4`
  → 21 s → `Build/PakalaPkg/RELEASE_CLANGPDB/AARCH64/LinuxLoader.efi` → `out/espboot-20261110/Loader-r72.efi`
* 关键字串自检：`[L] menu autoboot off`、`… %lu s to autoboot`、`… autoboot cancelled` 均在件内。

### 1.4 GRUB：双层菜单定案（含为什么「倒计时」修不了）

* **结构事实**：GRUB 只能自己加载内核才能选内核，而 arm64 GRUB 的 `linux` 命令=**EFI-stub 交接**，
  在本平台 `ExitBootServices` 后必死（`PITFALLS #558`：四条取证通道同时静默）。
  ⇒ 想要「GRUB 选内核」就得先修内存图/EFI-stub 墙；**当前唯一可用路径仍是我们的 `LinuxLoader`**。
  因此菜单**必然两层**：GRUB 选「去哪个 loader / 重启 / 关机」，loader 选「哪个内核」。
* **GRUB 倒计时不可见**：GRUB 用 `ConOut` 打印 "… executed automatically in Ns"，本平台 `ConOut` 是 no-op
  （R7 补丁）⇒ 交互件改 `set timeout=-1`（等按键，不自动跳），另备 `timeout=1` 的无人值守件。
* 件（已放到 ESP `/EFI/grub/`，**未替换** `BOOTAA64.EFI`）：

| 件 | sha256 | 用途 |
|---|---|---|
| `out/grub-20261110/grub-menu.efi` | `4cc428ca…` | 4 条目（chainload loader / 直连 EFI-stub 墙复测 / reboot / halt），`timeout=-1` |
| `out/grub-20261110/grub-chain.efi` | `84d3bbede…` | 单条目无人值守（`timeout=1` → chainload `/EFI/elden/Loader.efi`） |
| `out/grub-20261110/{menu.cfg,chain.cfg}` | — | 源 cfg（`grub-arm64-standalone.sh --cfg`） |

---

## 2. 待做的两个上机动作（都需人手按键）

### T1 —— R72 菜单行为验证（约 1 分钟）

```bash
cd ~/y700-elden
ssh elden-root 'reboot bootloader'                      # 或设备已在 fastboot 则跳过
fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img
```

看三件事：
1. 菜单标题里的 **秒数逐秒递减**（`8 s to autoboot` → `7 s` → …）；
2. 按一次**音量键**后，标题变 **`autoboot cancelled`**，并且**长时间停住不再自动启动**；
3. 按**电源键**确认 → 正常起 Linux。
   （事后 `cat /efi/loader.log` 应见 `[L] menu autoboot off`，且**紧跟没有** `[L] menu timeout`。）

### T2 —— GRUB 双层菜单（约 2 分钟，可选）

```bash
# 装 GRUB 当 ESP 引导层（先备份现行 loader）
ssh elden-root 'mount /dev/sda18 /mnt/esp && cp /mnt/esp/EFI/BOOT/BOOTAA64.EFI /mnt/esp/EFI/BOOT/BOOTAA64.EFI.loader-r72.bak \
  && cp /mnt/esp/EFI/grub/grub-menu.efi /mnt/esp/EFI/BOOT/BOOTAA64.EFI && sync && umount /mnt/esp'
ssh elden-root 'reboot bootloader'; fastboot boot out/r21-sbstop-pc1/uefi-preamblec1-r1.img
#  GRUB 菜单出现（4 项，不会自动启动）：
#    1) chainload Loader.efi → 进内层菜单（内核选择）
#    2) 直连 EFI-stub（预期：#558 墙，静默死）
#    3) reboot  4) halt
# 回退：把 BOOTAA64.EFI.loader-r72.bak 拷回去
```

---

## 3. 判据与残项

* **pc1 可用性**：`elden_bootloader=esp` + SSH 可达 + `boot_b` 未动（本轮未写任何分区）⇒ 已成立。
* **「屏上静默」是否影响取证**：不影响主线 —— 标记仍进 `SbLogPut`（固定物理地址环形日志，`logfs` 落盘那条路还在），
  ESP 侧 `loader.log`/`espboot.log` 照写，cmdline 令牌 `elden_bootloader=esp` 照旧；需要屏上判据时用 `p69` 件或删掉 `#define ELDEN_FB_QUIET` 重编。
* **残项（非阻塞）**：① 与「p67 = 54.5 s」同法复测以给严格差值；② R47/R48/R49（看门狗，已证无效但无害）仍在栈里，
  下一步「去无用调用」一轮再删；③ GRUB 直连内核要等 EFI-stub/内存图问题解决（`#558`），当前不做。
---

## 4. R72 上机第一发的结果与 R73 修正（2026-11-10 晚，用户实测）

| 用户反馈 | 判读 |
|---|---|
| ①「倒计时」成功 | 标题秒数逐秒递减成立 ⇒ R72 的每秒重画有效 |
| ②「按下音量键出现了 auto cancel 但**一下就进入系统**」 | **R72 自身的 bug**：把「取消自动启动」实现成 `Timeout = 0`，而主循环是 `while (Timeout > 0)` ⇒ 置 0 让循环**立刻退出**，随后照常「应用当前选择」⇒ 立刻启动；标题在退出前已被重画成 `autoboot cancelled`，所以看着像取消了 |
| T2 GRUB 四条目正常 | GRUB 交互件（`timeout=-1`）与 chainload 条目可用 |

**R73 修正**（`patches/uefi/20261110R73-loader-menu-wait/0001-loadermenu-wait-for-confirm.patch`）：
主循环改 `while (TRUE)`，超时判定只在「从未按键」时生效；按键后**唯一**启动路径 = Power（`SCAN_SUSPEND`，
落日志 `[L] menu confirm`）；`#timeout` 缺省时仍保持零等待旧行为。件 = `out/espboot-20261110/Loader-r73.efi`
（184 832 B，`6e51fc60…`），已写入 ESP 的 `BOOTAA64.EFI` 与 `/EFI/elden/Loader.efi`（读回一致、`fsck.vfat` 干净）。

**待验判据**：按音量键 → 标题 `autoboot cancelled` → 画面**长时间停住** → 按 Power 才起；
`\loader.log` = `autoboot off` →（可选 `menu sel N`）→ `menu confirm` → `menu boot …`，**且无** `menu timeout`。


---

## 5. 「GRUB 条目 2（EFI-stub）能否起系统」——取证设计与已完成部分（2026-11-10 晚）

### 5.1 为什么不能凭「进系统了」判定

`/boot/Image`（ext4 上）与 ESP 的 `\boot\boot.img` 内嵌内核**都是 `vk184-00002`**，
而且两条路径的桌面完全一样 ⇒ 「进系统」**不区分来源**。唯一判据 = 在 GRUB 的 `linux` 行里埋令牌
（`elden_boot=grub_stub`）后看 `/proc/cmdline`；辅证 = `/efi/loader.log` 的 mtime/sha **不变**（说明我们的 loader 没跑过）。

### 5.2 已完成的一发（无人值守 stub 件）结果

`out/grub-20261110/grub-stub.efi`（单条目、`timeout=1`、直连 EFI-stub、cmdline 带 `elden_boot=grub_stub`）
装成 `BOOTAA64.EFI` → `fastboot boot pc1` ⇒ **设备掉电后重启/停在关机态**（用户现场：「这会掉电然后重启」），
主机侧随后 `ping`/`fastboot`/`usb` 全空（总线上只剩无关设备：vivo X200 Ultra、Huawei ELS-AN00 ⇒ `PITFALLS #569` 同族，
**adb 看到的 `10AF5J0FHQ0039G` 不是我们的板子**）。⇒ 该发与 `PITFALLS #558` 的签名一致（EB 之后整机复位、四通道静默）。

### 5.3 待做的干净 A/B（设备需先手动开机）

| 臂 | 件 | cmdline | 判据 |
|---|---|---|---|
| A（基线） | `grub-chain.efi`（chainload loader） | loader 自己的 cmdline | `/proc/cmdline` 含 `elden_bootloader=esp` + `loader.log` 新写 |
| B | `grub-stub.efi` | **与 A 逐字对齐**（含 `elden_root`/`console=ttyGS0`/`ignore_loglevel`/`panic=15`）+ `elden_boot=grub_stub` | 起来 ⇒ `cmdline` 有 `grub_stub` 且 `loader.log` **未变**（⇒ EFI-stub 成立，#558 需改写） |
| C | `grub-stub.efi`（旧精简 cmdline） | 无 `elden_root` 等 | 用于解释第 5.2 节的掉电复活是否只是 cmdline 缺失 |

### 5.4 顺带修的：GRUB 菜单字太小

根因：Debian 的 `grub-efi-arm64-bin` **不带** `unicode.pf2`（在 `grub-common` 里）⇒ `gfxterm` 退化成 EFI 文本模式，
就是用户看到的「Linux 通用 GRUB 小字」。`scripts/grub-arm64-standalone.sh` 已补：缺字体时从宿主
`/usr/share/grub/unicode.pf2` 复制进 memdisk；三份 cfg 都加了 `insmod gfxterm` + `set gfxmode=1024x768x32,800x600x32,auto`
+ `terminal_output gfxterm`。新件（7 024 640 B，字体已嵌入）：
`grub-menu.efi` `e0a91f84…`、`grub-stub.efi` `ccc1c9a0…`、`grub-chain.efi` `51ae8d92…`。

---

## 6. 2026-11-10 晚（第二、三发）：EFI-stub 判定 + 菜单字体

### 6.1 变量已排除：DTB 不是差异项（主机侧已证）

`out/boot-elden-vk184.img` 里解出的 DTB（`scripts/grub-bootfiles.sh` ⇒ `elden.dtb`，153 089 B）
sha256 = `df00cb19…`，与设备上 `/boot/elden.dtb` 的来源件 `out/fbdiag-20261108/elden.dtb` **逐字节相同**；
ESP `\boot\boot.img` 与 `out/boot-elden-vk184.img` 同为 **85 594 112 B**。
⇒ GRUB 条目 2 传给内核的 DTB 与可用路径（loader 读 `boot.img`）**同一份** ⇒ **DTB 不是死因**。

### 6.2 cmdline 也已对齐（第二发）后仍然掉电

第二发把 stub 的 cmdline 与可用启动**逐字对齐**（`console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel
printk.devkmsg=on panic=15 clk_ignore_unused pd_ignore_unused arm-smmu.disable_bypass=0 elden_root=LABEL=linux17`
+ 令牌 `elden_boot=grub_stub`），内核/initrd/DTB 与可用路径同源 ⇒ 结果**依旧掉电重启**
（用户现场：「这一版 grub 是全屏了，但依然掉电」）。
⇒ **`PITFALLS #558` 维持**：本平台「GRUB/EFI-stub 交接」在 `ExitBootServices` 之后整机复位；
与 cmdline、DTB、内核来源都无关，属 Mu 侧内存图/无控制台那一层。
⇒ 用户此前「条目 2 能进系统」**大概率是默认项（条目 1 chainload loader）**：两条路径桌面完全一样，
只有 `elden_boot=grub_stub` 令牌与 `loader.log` 的 sha 能分辨（本轮把令牌加进 cfg 就是为了这个）。

### 6.3 GRUB 菜单字体（小 → 大）

* 第一版：Debian `grub-efi-arm64-bin` 不带 `unicode.pf2` ⇒ gfxterm 退化文本模式（小字、通用样式）。
* 第二版：补上宿主 `unicode.pf2` + `insmod gfxterm` + `set gfxmode=1024x768x32,…` ⇒ **全屏**但 16px 字仍太小（用户实测）。
* 第三版（已备好，待上机看）：`GRUB_FONT_SIZE=40 grub-mkfont` 现造 `elden-big.pf2`（287 596 B）显式塞进 memdisk
  `boot/grub/fonts/elden-big.pf2`，cfg 里 `loadfont (memdisk)/boot/grub/fonts/elden-big.pf2` 后再 `terminal_output gfxterm`。
  件（7 311 360 B）：`grub-menu.efi` `a43b91f5…`、`grub-stub.efi` `75308e94…`、`grub-chain.efi` `4f2c5e40…`。
  脚本开关：`GRUB_FONT_SIZE=<px>`（可选 `GRUB_FONT_TTF=`）。

---

## 7. pc2（内存图实验）首测：EFI-stub 仍未通过，但症状变了

* `pc2` = `pc1` + **R74**（内存图：把 `0xD65C0000`–`0xFC800000` 这 612 MiB 无主 DDR 标成 `Conv`）。
  件 `out/r21-sbstop-pc2/uefi-preamblec2-r1.img`（`271117f1…`）。
* 判据件 = `grub-stub.efi`（单条目、`timeout=1`、`/boot/Image` + 令牌 `elden_boot=grub_stub`）装成 `BOOTAA64.EFI`。
* **结果（用户现场）**：**屏幕先只剩背光 → 一段时间后掉电**。⇒ 仍不通，但**现象与 11-08「四通道全静默」不同**：
  「只剩背光」说明**面板/背光那一段被碰过**（内核比之前走得更远，或 GRUB 退出后 ABL 状态变化），
  随后掉电 ⇒ 复位源仍未定（watchdog / SError / 内存踩踏皆可能）。
* 本轮**没有**拿到 pstore：`fastboot boot` 命令被中断（`Command aborted`），随后设备离线；
  下轮开机第一件事读 `/var/log/pstore/`（`pstore-catch` 会把 ramoops 归档）与 `journalctl -b -1`。
* **顺带暴露的无关缺陷**：这次关机 `session-c1.scope/stop` 卡满 **90 s** 才被 SIGKILL ⇒
  `reboot bootloader` 实测 **+93 s**。该问题 2026-10-30 已定根因（greetd 上游死锁：
  `check_children()` 持锁 await 与 SIGTERM 处理抢同一把写锁，见 `reports/shutdown-greetd-hang-plan-20261030.md`），
  修法现成：drop-in `TimeoutStopSec=10` + `ExecStop` 先杀 session-worker（90 s → ≤2 s）。**每轮测试都被它拖掉 1.5 min，应先修。**

### 7.1 下一步（顺序）

1. **修关机**：写 `/etc/systemd/system/greetd.service.d/zz-elden-faststop.conf`（`TimeoutStopSec=10` + `ExecStop=/bin/kill -TERM $MAINPID` 前先杀 session-worker），
   同源推进 `packaging/elden-userland/services.tsv` 的 `stop` 语义（长期）。
2. **EFI-stub 诊断**：把 `out/fbdiag-20261108/Image.fbdiag`（`CONFIG_SYSFB_SIMPLEFB=y`，UTS `7.3.1-debug-fbdiag-00003`）
   放到 linux17 的 `/boot/Image.fbdiag`，GRUB entry 2 改指它 ⇒ 若 EFI 路径能取到 GOP 帧缓冲，**屏上就能看到内核自己的日志**，
   直接看死在哪一步；同时读 `/var/log/pstore/`。
3. 若 2 仍盲：接受 `#558` 为平台墙，**菜单保持两层**（GRUB 只做 loader/重启/关机入口），不再投 EFI-stub。
