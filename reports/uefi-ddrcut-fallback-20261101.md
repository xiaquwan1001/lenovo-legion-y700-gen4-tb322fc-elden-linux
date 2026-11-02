# UEFI ① 实测：切断回落 + DDR 标记回读 —— **载荷两条路径都没被执行到第一条指令**，但「窗口被回落启动清掉」的假设被推翻

> 2026-11-01 23:1x – 11-02 02:0x CST。设备 HA2EXB0E（U2）。编排者直接执行（单设备串行）。
> 本轮设备动作：GPT 属性写 2 次（a 置/清 unbootable，LUN4 双表 + CRC 重算）、`logfs`/`misc`/GPT/`boot_b` 全量备份、
> `boot_b` 写入 1 次（UEFI 载荷）+ 恢复 1 次、`fastboot boot` 3 次（零写盘）、`fastboot --set-active=b` 2 次、`reboot` 4 次。
> 终态：**已恢复**（`boot_b` = `fb55997c…`、`current-slot=_b`、a/b 均 bootable、Linux 在机、`systemctl` 未查但 ssh 正常）。
> record：`reports/trials/20261102T020117Z-ddr-cut-fallback-p2.json`（verdict FAIL / reset cold）。

---

## §0 结论（四条，全部实测）

1. **「回落启动清掉 DDR 窗口」这个假设被推翻（本轮最有价值的负结果）**：三块候选窗口
   `0x84A00000`(dsm-1) / `0x9C300000`(video) / `0x89300000`(dsm-2) 在 Linux 里被 `blackbox.ko` **清零后**，
   经历「写 boot_b 载荷 → 正常 reboot → ABL 失败 → fastboot(3 次 boot 尝试) → `fastboot flash boot_b` → reboot → Linux」
   整圈之后，**三窗仍然逐页为 0**（`stage 0/1/2/4` 全 0%）⇒ **ABL/fastboot/Linux 启动链都不碰这三块**。
   ⇒ 之前「读回干净 0 无法判读」的顾虑不成立（那时读到的是「数据存在但非标记形态」，见 §2.1）。
2. **载荷在两条路径上都没有执行到第一条指令**（`stage1` = 0/3 窗）：
   ① `fastboot boot`：**3/3 被拒**（`Failed to load/authenticate boot image: Invalid Parameter`），与 #482 的
   「接受与否与另一槽是否 bootable 相关」一致（本轮 a 槽处于 unbootable）；② 槽位正常启动路径（`boot_b` = 载荷 + `reboot`）：
   **ABL 在数秒内直奔 fastboot**，三窗 `stage1` 仍 0 ⇒ **shim 的第一条指令没跑**。
   且这发**没有在 `logfs` 留下任何段**（10 段里 seg0=当前 b 启动、seg1–9 全是 slot `a` 的历史）⇒ ABL 没走到
   「Loading Image boot_b / Booting from slot」就被挡回 fastboot（判据缺失，§4）。
3. **`qbootctl -u a` 在本机不可用**（`gpt_disk_commit: Invalid args` / `update_slot_attribute: Failed to commit disk`）：
   当前活动槽 `b` ⇒ boot LUN 2，改 `a` 的属性需要切 boot LUN，ioctl 失败即整笔放弃。
   正解 = **`scripts/slot-attr.py set a --unbootable` 直接写 `/dev/sde`（LUN4）主/备双表 + 重算 CRC**；
   写后 ABL 立即采信（`getvar slot-unbootable:a` = `yes`）。**写 GPT 会让内核重扫 `/dev/sde`（分区节点短暂消失 ~3 s），不是故障**。
4. **恢复链全部实测可用**（都在 Linux/fastboot 内完成，未用 EDL）：
   `fastboot flash boot_b <96 MiB 备份>`（2.3 s，`Writing OKAY [0.056s]` 属 ABL 正常快写）→
   `fastboot --set-active=b`（自动清 `slot-unbootable:b`、retry 复位 7）→ `fastboot reboot` →
   **约 15 s 回 Linux**（`boot_id` `94865bce…`）→ 直接核 `boot_b` 分区 sha = `fb55997c…` 逐字节一致。

---

## §1 实验设计（为何这样切）

- 目的：把「marker 读不到」的两个原因拆开 ——（a）载荷没执行（b）执行了但回落的 Android 把窗口清掉。
- 做法（方案 a′）：让 **a 槽（stock Android）unbootable** ⇒ 载荷失败后 ABL 无处可回，只能停 fastboot；
  此时没有任何内核/Android 会跑过，再看三窗是否出现 stage 标记。
- 前置（全部完成，`reports/artifacts/uefi-ddrcut-20261101/`）：
  `lun4-gpt-primary.bin`(`84efc47d…`) / `lun4-gpt-backup.bin`(`7d4e7feb…`) / `misc.bin`(`85094313…`) /
  `logfs-base.bin`(`5459cd1a…`) / `boot_b-backup-2350.img`(`fb55997c…`, 96 MiB, 设备侧 dd 取回)。
- 顺序：备份 → 三窗 `blackbox.py prep` 清零（读回全 0 确认）→ `slot-attr.py set a --unbootable` →
  `boot_b` ← 载荷（`flash-b.sh`，签后 sha `98b19671…`，读回一致）→ `sysrq-b` → 观察 → 恢复。

## §2 观测记录

### 2.1 清零前（基线，说明「干净 0」不是唯一形态）
`blackbox.py read` 在 prep 之前对 `0x84A00000` / `0x89300000` 报 **stage 0..6 全部 99%+「REACHED」**（大段高 popcount 数据），
`0x9C300000` 报 page0 90%、stage1/4 ≈10–12%。⇒ 这三块里**本来就有非零内容**（不是标记布局）；
prep 后逐页全 0（`dd if=/dev/zero` 经模块写入成功）⇒ **模块对三窗可读可写**。

### 2.2 循环之后（判据）
三窗 `read` 结果一致：`stage 0..15` 全 0%、位平面全 0 ⇒ **stage1 未出现**。

### 2.3 `fastboot boot` 三发
```
Sending 'boot.img' (2384 KB)   OKAY [ 0.055s]
Booting    FAILED (remote: 'Failed to load/authenticate boot image: Invalid Parameter')
```
3/3 同形（之间间隔 5 s，fastboot 始终应答）。

### 2.4 槽位路径后的 `logfs`（10 段全扫）
seg0 = 当前这次 b 槽 Linux 启动（`Booting from slot (_b)`、`Loading Image boot_b Done: 0 ms, Image size : 4096 Bytes`）；
seg1–9 = 全部 `Booting from slot (_a)`（历史 Android 启动）。**没有任何一段记录本轮的载荷启动尝试或 fastboot 会话**。

## §3 窗口存活表（本轮实测）

| 窗口 | PA | prep 后 | 全循环后 | 判读 |
|---|---|---|---|---|
| dsm-partition-1 | `0x84A00000` | 全 0 | 全 0 | 无人触碰 |
| video | `0x9C300000` | 全 0 | 全 0 | 无人触碰 |
| dsm-partition-2 | `0x89300000` | 全 0 | 全 0 | 无人触碰 |

⇒ **0x00 是稳定态**（与 `reports/uefi-ddr-blackbox-20261101.md` §2 G2 一致），且这三块**在整个启动链里不被写**。

## §4 未证 / 下一步

1. **未证**：ABL 为何连 `logfs` 都不写就进 fastboot —— 两种可能（本轮不可区分）：
   ① 载荷镜像在 ABL 的**加载/校验层**就被拒（header/payload 形态不符 Linux `Image` 约束），
   ② ABL 确实加载并跳了，但 shim 首条指令就异常（写 carveout 时被保护域挡），且异常前未写 logfs。
   **判别实验（下轮，成本低）**：把 `boot_b` 换成一个**纯 Linux 内核 + 我们自己的 cmdline**（无 UEFI 载荷）跑一遍，
   确认「槽位路径本身是通的」；再把载荷的 kernel 段换成**真 Linux `Image` 头**的壳（内嵌 FD）重启一次 ——
   若 ABL 日志出现 `Loading Image boot_b` 且尺寸 ≈ 载荷大小、仍无 stage1，则 ①被否、②成立。
2. **未证**：`fastboot boot` 的拒绝是否**完全**由「另一槽 unbootable」决定（#482 只给了相关，未给充分条件）；
   下轮可做「a bootable × 同一镜像」对照一发。
3. **未做**：fault 记录（`VBAR_EL2` 覆盖页 + 位平面 ESR/FAR/ELR）—— 只有在 stage1 出现后才有意义。

## §5 产物 / 复现

- 证据：`reports/artifacts/uefi-ddrcut-20261101/`（`lun4-gpt-{primary,backup}.bin`、`misc.bin`、`logfs-{base,after}.bin`、
  `boot_b-backup-2350.img`、`logfs-after.bin`）
- 载荷：`reports/artifacts/uefi-ddr-20261101/dsm/uefi-v0.img`（sha `ee3d2b13…`，`shim=ddrmarks`，干净 v0 header）
- 复现（主机侧，逐条）：
```bash
scripts/blackbox.py prep --pa 0x84A00000        # 三窗各一次
scp scripts/slot-attr.py root@192.168.7.1:/tmp/ && ssh root@192.168.7.1 'python3 /tmp/slot-attr.py set a --unbootable'
scripts/flash-b.sh reports/artifacts/uefi-ddr-20261101/dsm/uefi-v0.img
ssh root@192.168.7.1 'sync; echo b > /proc/sysrq-trigger'   # → 数秒进 fastboot
fastboot -s HA2EXB0E flash boot_b reports/artifacts/uefi-ddrcut-20261101/boot_b-backup-2350.img
fastboot -s HA2EXB0E --set-active=b && fastboot -s HA2EXB0E reboot
scripts/blackbox.py read --pa 0x84A00000        # 三窗各一次
ssh root@192.168.7.1 'python3 /tmp/slot-attr.py set a --no-unbootable'
```

---

# ★ 2026-11-02 上午续作：判别「ABL 没跳」vs「跳了没写进去」——最后一条判据指向「载荷被执行了，但缺 ramdisk/cmdline 时被静默丢弃」

> 承接 §4「下一发判据」。四条臂，全部走同一路径（a 槽 unbootable 切断回落 + `boot_b` ← 载荷 + `sysrq-b`），
> 每臂后 `fastboot flash boot_b 备份` → `--set-active=b` → `reboot` → Linux 读窗口。设备当前**待物理断电**（见 §6-B）。

## §6-A 四臂结果

| 臂 | shim 变化 | 载荷 | 结果 | 判读 |
|---|---|---|---|---|
| A0（11-01 夜） | 三 carveout 标记 | `dsm/uefi-v0.img` | 数秒 → fastboot，**三窗 stage1=0** | 未执行 或 写了没落 DRAM |
| A1 | **+ `dc civac`/`dsb sy` 回写标记页**（`patches/uefi/20261102-ddr-clean/0001-*`，`--shim ddrmarksclean`） | `out/uefi-ddrmarks-clean-20261102`（`623acee6…`） | 数秒 → fastboot，**stage1=0** | 排除「只落 cache」 |
| A2 | 标记改写到 **普通 System RAM** 保留窗 `0xE3F00000` / `0xC2500000`（+ 保留一个 carveout 对照）（`0002-*`，`--shim ddrmarkssys`） | `out/uefi-ddrmarks-sysram-20261102`（`3de803af…`） | 数秒 → fastboot，**三窗 stage1=0** | 排除「carveout 被保护写不进」⇒ 指向**根本没跳** |
| **A3（关键）** | 同 A2，但 **v0 image 补 `--ramdisk`（92 B 空 cpio.gz）+ `--cmdline "console=tty0"`** | `out/uefi-ddrmarks-sysram-rd.img`（签后 `f26e79c5…`） | **终态改变**：设备**彻底失联**（无 fastboot、无 EDL、无 ssh），USB 只剩 `17ef:7f3d` Lenovo vendor 模式（class 255 / sub 66 / proto 1，serial `HA2EXB0E`） | **首次出现「载荷被执行」的强证据** |

**对照组（本轮必做，已通过）**：`a` 槽 unbootable + `boot_b` = 日常 Linux（`fb55997c…`）⇒ `sysrq-b` 后 **3 s 回 Linux**
（`boot_id 3ad45c5f…`）⇒ **「切断回落」本身不阻塞槽位启动**，A0–A2 的失败只能归给载荷本身。

## §6-B 当前状态与恢复（待物理动作）

- 设备现在**没有任何可用 USB 模式**（`18d1:d00d`/`05c6:9008` 都不在），`lsusb` 仅 `17ef:7f3d`；`edl-ng ramdump --vid 0x17ef --pid 0x7f3d` 读超时 ⇒ **不是 Sahara/crashdump**。
- `boot_b` 里仍是 A3 载荷（`f26e79c5…`）、`a` 槽仍 unbootable ⇒ **恢复前不要让它正常启动**（会再次进入该状态）。
- 恢复（用户物理 + 我这边执行）：① 长按电源 15–20 s 强制关机；② **按住音量上 + 插 USB 长边口** 进 EDL（`lsusb` 应见 `05c6:9008`）；
  ③ 我写入备份件回 `boot_b`（EDL 直写 LUN4，不依赖 fastboot）：
  `edl-ng write-part boot_b reports/artifacts/uefi-ddrcut-20261101/boot_b-backup-2350.img -u 4 -l ~/下载/tb322fc/xbl_s_devprg_ns.melf --memory Ufs`
  ④ `slot-attr.py set a --no-unbootable`（EDL 起来后设备在 Linux 则直接跑；否则 EDL 写 GPT 回滚件 `lun4-gpt-primary.bin`/`-backup.bin`）。
- 恢复后**先读三窗**（`0xE3F00000` / `0xC2500000` / `0x84A00000`）——若出现 stage1/2/4 ⇒ 「载荷执行 + 标记落 DRAM」一次坐实，
  `PITFALLS #481` 的「载荷从未执行」结论将被推翻/限定。

## §6-C 机制假设（待验证）

Android boot image v0 的 `ramdisk_size=0` 可能让 ABL 走「非 AndroidOS」分支而**不下载内核**（静默丢弃 → 直接回落/进 fastboot）；
补上 ramdisk 后走正常分支 → 下载并跳转 → 我们的 shim 开始执行（终态因此改变）。
⇒ 若 A3 的 DDR 标记能读回，则**上一代所有「载荷未执行」的实验都可以归因到这个 header 字段**（不是载荷代码问题）。
