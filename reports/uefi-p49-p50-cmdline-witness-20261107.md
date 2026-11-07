# UEFI p49 → p50：R43 令牌确认已写进 UEFI 的 cmdline，但**内核侧仍拿不到** ⇒ 交棒仍未成立

> 线：G1-29。承接 `reports/uefi-p47-p49-fb0-and-cmdline-tag-20261107.md`。
> 本轮 = **2 发零写盘**（p49 一发、p50 一发，均为 `fastboot boot`；无分区/槽/固件写入）。
> 设备 = U2 `HA2EXB0E`（内核自报 `androidboot.serialno`），全程 `boot_b` 与槽位未动。

---

## ⛔ 2026-11-07 20:20 更正（本页 §0/§3 的「内核连 printk 都没跑到」**已作废**）

用户当场看屏：**`JUMP-BANNER` 之后屏幕全亮、开始进 Linux** ⇒ 跳转是成功的。
复查发现 `/sys/fs/pstore` 空**根本不说明任何事** —— `systemd-pstore.service` 在每次 boot 时会把
`/sys/fs/pstore/*` **搬到 `/var/lib/systemd/pstore/`** 并清空源目录。真正的记录在那里：

```
/var/lib/systemd/pstore/console-ramoops-0   (64 858 B)
  [    0.000000][    T0] Booting Linux on physical CPU 0x0000000000 [0x514f0014]
  [    0.000000][    T0] Machine model: Lenovo Legion Y700 Gen4
  …  Kernel command line: … elden_nocamera=1 elden_bootpath=uefi
  [    0.000000][    T0] Unknown kernel command line parameters "elden_root=LABEL=linux17
                          elden_nocamera=1 elden_bootpath=uefi", …
  …（1 s 内的 mmc/pcie/ufs 逐条）
  [    4.051881][   T92] mmc0: SDHCI controller on 8804000.mmc using ADMA 64-bit
  [    4.122504][    C0] mmc0: ADMA error: 0x02000000      ← 日志到此为止（64 KiB 环未回绕）
  [    4.122698][    C0] mmc0: sdhci: Host ctl2: 0x00000000
```

⇒ **两条硬结论改写**：

1. **UEFI 交棒成立**（R43 的令牌出现在那个内核自己的 `Kernel command line:` 里，排他）；本页
   §0.2–§0.4 与 §3 的「交棒没成/内核没跑到 printk」**作废**。
2. 新的卡点 = **那个内核在 4.1225 s 的 `mmc0: ADMA error` 之后停住**：ramoops 环 64 KiB **没有回绕**
   （文件头仍是 boot banner）⇒ 内核此后**没有再打印任何东西** ⇒ 卡死/复位在 sdhci 出错处理里。
   同一台机器由 **ABL** 引导同一内核时，mmc0 在 3.983 s 正常认出 `SDXC card 58.6 GiB`、无 ADMA 错误。

新的持久通道（本轮最大收获）：**失败那次的内核 console 会留在 `ramoops` 里，下一次 boot 由
`systemd-pstore` 归档到 `/var/lib/systemd/pstore/console-ramoops-0`** ⇒ 每次 `fastboot boot`
失败后都能拿到那个内核的**完整早期日志**（不再依赖看屏）。证据：
`reports/artifacts/uefi-p51-uefi-kernel-console/console-ramoops-0.bin`。

---

## 0. 一句话结论

1. **R43（cmdline 令牌）确定生效**：p50 新增的 R44 见证行在持久 logfs 里读到
   `[K] cmdline len=293 tag=1 tail=no=51318dc0 androidboot.baseband=apq elden_bootpath=uefi.`
   ⇒ `UpdateCmdLine()` 产出的 `FinalCmdLine` **确实以 ` elden_bootpath=uefi` 结尾**，
   而下一句 `LoadAddrAndDTUpdate()` 正是把它交给 `UpdateDeviceTree()` 写进 DTB（`BootLinux.c:766`）。
2. **但起来的内核 `/proc/cmdline` 没有该令牌**（p49/p50 两次都是）⇒ 我们说话的那个内核
   **不是 UEFI 交棒的那个**（`boot_b` 被 ABL 自己引导）。
3. **没有任何一次 UEFI 交棒的内核进过用户态**：`journalctl --list-boots` 在 p48/p49/p50
   三次尝试中每次只多出 **一条** boot 记录（= ABL 引导的那次）；`/sys/fs/pstore/` 全空，
   而同一次引导里 `ramoops` 控制台**已注册**（`dmesg: ramoops: using 0x400000@0xc2000000`、
   `printk: legacy console [ramoops-1] enabled`）⇒ **内核连 printk 都没跑到**。
4. 故障窗口因此收窄到 **`JUMP-BANNER` → `LinuxKernel()` 调用点 / 内核最早几条指令**
   （即 `PreparePlatformHardware()` 之后的 MMU/cache 交接），而不是 `BootLinux` 前段、也不是 EB。
5. 判据纪律修正：`scripts/uefi-boot-trial.sh` 原先把「fastboot 无应答 / USB gadget 消失」记成
   `HANDOFF` —— 那只是 ABL 的 gadget 被销毁（跳转后复位同样如此，`PITFALLS #549`）。
   本轮已改为**必须看内核 cmdline 令牌**才给 `HANDOFF_TAGGED`，否则 `ABLBOOT_NOTAG`。

---

## 1. 两发的账（全部 `fastboot boot`，零写盘）

| 发 | 件 | 关键改动 | 结果 |
|---|---|---|---|
| p49 | `out/r21-sbstop-p49/uefi-preamble49-r1.img`（`15d0b778…`） | R43 v2 = 只留 cmdline 令牌 | logfs 链到 `preeb` 转储（与 p47 同型）；内核回来**无令牌** |
| p50 | `out/r21-sbstop-p50/uefi-preamble50-r1.img`（`9a7e22c1…`） | + **R44** = `UpdateCmdLine()` 之后把 `len/tag/tail` 写环+上屏 | `tag=1`（令牌已进 cmdline），内核仍**无令牌** |

- 两发上机方式：`reboot bootloader`（`eldroid-bootctl`）→ `fastboot boot <img>` → **不发 `continue`**。
- 两发均为**自恢复**：失败后约 45–54 s 内设备自己回到 ABL → `boot_b` → Linux（本轮**没有**需要长按断电）。

## 2. p50 的决定性证据（logfs，持久）

```
[K] cmdline len=293 tag=1 tail=no=51318dc0 androidboot.baseband=apq elden_bootpath=uefi.
[K] dtb=B405D000 m=EDFE0DD0 sz=AA590200 k=A8080000.
[K] gbs=D4C0B010 ap=D4BF81F4 eb=D4BF3B80 fp=D4BF85B0.
[K] preeb-go.
[K] dump-in preeb.
[K] dump-ring-ok preeb.
```

（`dump-ring-ok` 之后的 `dump-write`/`preeb-ok` 本来就看不到：logfs 的这份内容是**那一次转储写盘时**
的环快照，见 p48 屏上 dump 的同一位置。）

读回方式：`scripts/uefi-boot-trial.sh` 的 logfs 提取（`UEFILOG1.TXT`），文件
`reports/artifacts/uefi-boot-20261107-195415/logfs.img`。

## 3. 三条独立证据说「交棒没成」

| # | 证据 | 观测 | 判读 |
|---|---|---|---|
| 1 | 内核 `/proc/cmdline` | 无 `elden_bootpath=uefi`（p49/p50 两次） | 这个内核不是 UEFI 起的 |
| 2 | 设备 `journalctl --list-boots` | 每次尝试只多 1 条 boot 记录（p48 之后 19:14 / p49 19:54 / p50 20:00） | 没有第二个「UEFI 内核」进过用户态 |
| 3 | `ramoops` 控制台 | `/sys/fs/pstore/` 全空，而本 boot 已 `legacy console [ramoops-1] enabled` | 那个内核连 printk 都没跑到（<0.03 s） |

主机侧 USB 交叉印证：每次尝试只出现 **一次** `1d6b:0104`（Linux gadget），时间在「内核启动 +8…9 s」；
p49 与 p50 都是 payload 接管后 **45–54 s** 才出现，与「UEFI 跑到某处 → 复位 → ABL 13.5 s → 内核」一致。

## 4. 判据可靠性与脚本修正（本轮顺手修的）

- **`scripts/uefi-boot-trial.sh`**：
  - 原判定 `HANDOFF = fastboot 不再应答 / USB 消失` → 改为**候选**，只有内核 cmdline 含
    `elden_bootpath=uefi` 才记 `HANDOFF_TAGGED`；内核起但无令牌记 `ABLBOOT_NOTAG`；没起来记 `NOBOOT`。
  - 修 `PRE_BOOTID`/`POST_BOOTID` 取 `head -1`（取到 `# ssh pre <时间>` 表头）的 bug ⇒ 第 2 行。
  - 上一轮 p49/p50 的 trial record 里 `verdict":"HANDOFF` 是**旧判据**写的，不代表结论；
    本轮在该两条 record 里补 `verdict_tag`/`verdict_final`/`correction` 字段（原字段保留）。
- **环的行截断（新坑，记 `PITFALLS #550`）**：UEFI 的日志环按 **200 字符/行**截断，
  `UpdateCmdLine()` 打印的 `Cmdline:` 行在长 cmdline 下**看不到末尾** ⇒ 判据令牌必须放在**行首**
  （R44 的 `[K] cmdline len=… tag=…` 就是为此设计的），否则会误判「令牌没写进去」。

## 5. 下一步（按代价排序）

1. **屏上一次判读（零成本、只有人能做）**：再发一发 p50，`Booting OKAY` 之后 10–30 s 看屏幕 ——
   - 屏上仍是 UEFI 的 `[K] JUMP-BANNER …` 静态画面 ⇒ 内核**一条指令都没执行**（跳转/MMU 交接）；
   - 屏被内核 log 顶掉（`Booting Linux on physical CPU…`）⇒ 内核起了、死在更后面 ⇒ 转 ramoops/串口取证。
2. **p51（备料，主机侧）**：`PreparePlatformHardware()` 之后再加一行屏显 `[K] call-now`，并把令牌
   **前置**到 cmdline 首（`elden_bootpath=uefi ` 放最前）⇒ 即使只看 200 字符也能判；
   同时给 `PreparePlatformHardware()` 返回值/耗时上屏（判断 MMU/cache 关闭是否真的做了）。
3. 若确认死在跳转：查 Mu 的 `PreparePlatformHardware()` 在 SM8750 上是否等价于 ABL
   （`ArmDisableMmu`/`ArmDisableDataCache`/`ArmDisableInstructionCache` 的实际寄存器和 SCM 路径）。

## 6. 产物

| 项 | 路径 |
|---|---|
| 补丁 | `patches/uefi/20261107R44-cmdline-witness/0001-cmdline-tag-witness.patch` |
| 配方 | `patches/uefi/p50-recipe.txt`（70 = p49 的 69 + R44） |
| 镜像 | `out/r21-sbstop-p49/`（`15d0b778…`）、`out/r21-sbstop-p50/`（`9a7e22c1…`） |
| 构建归档 | `reports/artifacts/uefi-20261107R43b-p49/`、`reports/artifacts/uefi-20261107R44-p50/` |
| 上机证据 | `reports/artifacts/uefi-boot-20261107-193644/`（p49）、`reports/artifacts/uefi-boot-20261107-195415/`（p50） |
| trial | `reports/trials/20261107T114040Z-uefi-p49-bootpath-tag.json`、`reports/trials/20261107T115936Z-uefi-p50-cmdline-witness.json` |
| 脚本 | `scripts/uefi-boot-trial.sh`（判据改 cmdline 令牌 + boot_id 取第 2 行） |
| 坑 | `PITFALLS #550`（环 200 字符截断 + `ramoops` 空 = 内核没起 + 每尝试一条 boot 记录） |
| 静态可复现 | p49 镜像段从归档构建目录 repack **逐字节相同**（`--mkimg-only --build-dir`，两件 sha 一致） |
