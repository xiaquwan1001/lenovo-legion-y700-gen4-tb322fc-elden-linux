# DDR 黑匣子（P0）实施与实测：本机 DRAM 跨复位**不保真**，判据必须改成单调编码

> 2026-11-01 12:00–13:45 CST。设备 HA2EXB0E（U2，在机 `boot_b` = vk183 + `memmap/iomem=relaxed` 变体）。
> 本轮设备操作：`boot_b` 三次重打包写盘（有 `bootslot-b/boot_b-device-backup-20261101.img`，sha `aedae5f1…` 逐字节等于原在机件）、
> 五次 `fastboot boot`（零写盘）、若干次 `reboot`。全部实验件与脚本已入库。

---

## §0 结论（六条）

1. **通道打通**：`probes/blackbox/{blackbox.c,blackbox.ko}` + `scripts/blackbox.py` 可以在 Linux 侧读写一块被保留的
   DDR 窗口（1 MiB）。arm64 上 `CONFIG_STRICT_DEVMEM=y` 使 `/dev/mem` 对 System RAM 一律 EPERM（`iomem=relaxed`
   在 arm64 分支无效），本机又没开 `CONFIG_PROC_KCORE` ⇒ 必须走这条 out-of-tree 模块，已按目标 UTS 编出
   （vermagic `…-vk172`，与在机内核逐字一致）。
2. **本机 DRAM 跨复位不保真**（本轮最重要的实测）：1 MiB 写满 `0xA5`，热复位后 **26%–32% 的字节出现 1–3 个比特翻转**，
   翻转方向几乎全是 **1→0**（`0xA5` 的四个 1 位 0x01/0x04/0x20/0x80 占绝对多数，0→1 几乎为零）；
   坏点集合每次复位都不同，越晚读越多。
3. **0x00 是稳定态**：页填 0x00 的窗口复位后 **逐字节仍是 0**；页填 0xFF 的窗口复位后仍有 **81%–86% 的字节 popcount≥7**。
   ⇒ 判据不能是「结构体 + CRC」，必须是**单调编码**：整页 0xFF 表示「到过该 stage」，读侧按 popcount 占比判；
   数值（ELR/ESR/FAR）用**位平面编码**（每个位一页，1 填 0xFF、0 留 0x00）。
4. **独立旁证**：多次复位之后 `/sys/fs/pstore` 始终为空 —— 内核自己的 ramoops 记录 CRC 不过被丢弃，
   与 §0.2 的比特衰减一致（本机 ramoops `0xC2000000` 4 MiB，`ecc: 0`）。
5. **结构性障碍**：载荷复位后 ABL 一律回落到 **stock Android（a 槽）**，回落那次启动的 XBL/Android 会在我们能读之前
   覆盖/清零候选窗口。实测：`splash_region` 尾部（`0xFEF00000`）与 `dsm-partition-2`（`0x89300000`）在回落之后是
   **干净的 0**（既没看到 marker，也没有别的东西），而 `oem-vm`（`0xF7D00000`）被覆盖成 ~14% 低熵内容。
6. **尚未定论**：`splash`/`dsm` 两窗「干净 0」有两种解释 ——（a）shim 的写没执行（该地址受保护/不可写，一写就复位）或
   （b）marker 写了但回落启动把它清零了。**必须先排除回落启动这个干扰源**，否则任何 marker 结论都不可信。

---

## §1 通道实现（已入库）

| 件 | 作用 |
|---|---|
| `probes/blackbox/blackbox.c` | debugfs 窗口：`memremap(MEMREMAP_WB)` → `ioremap_cache` 回退；写路径带 `dc civac` + `dsb sy`（脏行必须落到 DRAM，不能等 cache 自然淘汰） |
| `probes/blackbox/Makefile` | **必须 `ARCH=arm64`**（否则 kbuild 按宿主 x86 找 `arch/x86/include/asm/compiler.h`，报 `asm/compiler.h: 没有那个文件`） |
| `scripts/blackbox.py` | `prep`（清零，0x00 稳定态）/ `read`（单调编码解码）/ `raw` / `selftest`；全部经 ssh 走设备 |
| `patches/uefi/20261101-ddr/0001-bootshim-ddr-stage-markers.patch` | BootShim 的 DDR stage marker（含 0001 的 cache 维护）；`scripts/uefi-build-variant.sh --shim ddrmarks` 构建 |

实测命令：
```
scripts/blackbox.py prep --pa <PA>     # 清零窗口
scripts/blackbox.py read --pa <PA>     # 解码：stage 页 + pc/esr/far 位平面
scripts/blackbox.py selftest           # 解码器自测（含 10% 单比特衰减样本）
```

`boot_b` 侧为窗口加的 cmdline（**这是必须的**，否则内核会把它当普通 RAM 分配写回）：
`memmap=1M$<PA>`，试过同时加 `iomem=relaxed`（对 arm64 无效，已撤）。

---

## §2 「DRAM 保真性」三组对照（全部实测）

| 组 | 写入 | 热复位后 | 结论 |
|---|---|---|---|
| G1 | 1 MiB 全 `0xA5`（0xE3F00000 / 0xB7F00000 / 0xBFF00000 三处各一次） | 26.3% / 27.5% / 31.8% 字节 != 0xA5；1 比特错占 82%，2 比特 16% | 内容「大部分在、逐位衰减」 |
| G2 | 页0/1 全 0x00，页2/3 全 0xFF | 页0/1：`distinct=1`，4096/4096 全 0；页2/3：popcount≥7 的字节占 **85.9% / 80.8%** | 0 稳定、1 只会掉 ⇒ 单调编码可用 |
| G3 | 同一窗口连续两次复位 | 坏点集合不同（交叠 263k/275k，新增 12k） | 每次衰减独立 ⇒ 位平面编码要留阈值余量 |

`XOR` 掩码统计（G1）：`0x01/0x04/0x20/0x80` 四者合计 21.3 万次，`0x02/0x08/0x10/0x40`（0→1 方向）几乎不进前列。

---

## §3 上机实验（5 发，全部 `HANDOFF`）

| # | 载荷 shim 写入位置 | 结果 | 读回 |
|---|---|---|---|
| r1 | `0xE3F00000`（普通 System RAM + memmap 保留） | HANDOFF，回落 Android | 噪声（被 Android 覆盖） |
| r2 | 同上 | HANDOFF | 噪声 |
| r3 | `0xF7D00000`(oem-vm) + `0xC2300000`(ramoops 尾) | HANDOFF | ramoops 窗被内核日志写成 73%–80%（假阳性）；oem-vm 噪声 |
| r4 | `0xF7D00000` + `0xFEF00000`(splash 尾) + `0x89300000`(dsm-2) | HANDOFF | splash/dsm **干净 0**；oem-vm 噪声 |
| r5 | `0xFEF00000` + `0x89300000`（先 splash） | HANDOFF | 两窗仍 **干净 0**，stage1 未见 |

- 全部 trial record：`reports/trials/20261101T*uefi-ddr-*.json`；现场目录 `reports/artifacts/uefi-boot-20261101-1{305,328,339,34x,35x}*`。
- **判读**：`oem-vm` 一写就复位（r3/r4/r5 里它始终是被覆盖状态，且写它排在最前时后续窗口连 stage1 都没有）
  ⇒ 该 carveout 很可能受 Gunyah/保护域管辖，**不能再作为写入目标**。

---

## §4 下一步（按顺序，均需设备在场）

1. **先把回落路径切到我们自己**（否则 §0.6 的歧义永远解不开）：
   - 目标：载荷复位后 ABL 回落到 **b 槽 Linux**（我们的 `boot_b` 已带 `memmap` 保留窗口），而不是 stock Android。
   - 手段候选：① 把 `boot_a` 的 GPT 属性标成 unbootable（`qbootctl`/GPT 属性写，**先备份 GPT 双表**）；
     ② 或用 `misc` 的 BCB 指定下一次启动；③ 最保守：payload 上机时**人手按住电源键断电**再手动回 Linux（但 DDR 会掉，等于放弃）。
   - 判据：一次 payload 失败后 `ssh` 在 ~40 s 内回到 Linux（而不是先落 Android）。
2. 回落可控后，用 **干净窗口** 重打一发 `--shim ddrmarks`：
   - 判据 A：`stage1` 出现 ⇒ shim 第一条指令执行（此前从未有过硬证据）；
   - 判据 B：`stage4` 出现而 `prepi:entry` 不出现 ⇒ 死在「跳进 FD 之后、PrePi 之前」；
   - 判据 C：`stage1` 仍不出现 ⇒ 写地址不可用/被保护（换 `splash` 头 0xFC800000+0x1000 等再试），或 ABL 从未真正跳到载荷。
3. 通道稳定后再加 **fault 记录**（`VBAR_EL2` 覆盖页 + 位平面 ESR/FAR/ELR）⇒ 直接区分「异常」vs「看门狗超时」。
4. 并行：`logfs` 10 段环形日志逐启动重建（纯主机），把每次复位前后的 ABL 行为对齐（`scripts/abl-log.sh` 目前只读第 1 段）。

---

## §5 反面清单（本轮学到、别再踩）

- **不要**指望「写结构体 + CRC + 复位后读」：本机 DRAM 会逐位衰减，CRC 必然不过（`/sys/fs/pstore` 长期为空就是实证）。
- **不要**用 `iomem=relaxed` 解开 arm64 的 `/dev/mem`：arm64 的 `devmem_is_allowed()` 不认这个开关。
- **不要**用 `oem-vm` / 受保护 carveout 做 marker 目标：写它疑似直接触发复位。
- **不要**用 ramoops 区（`0xC2000000`）做 marker：内核日志会把 `popcount` 统计顶到阈值以上，出现假阳性。
- **不要**只读 `logfs` 第一段：它是 10 段 64 KiB 环形（见 `reports/uefi-observability-pivot-20261101.md` §1.1）。
