# 设备台账（Device Registry）— 同型号多单元，物理等价

> 总纲：`MISSION-SCOPE.md` §2（设备等价原则）。**身份 = (SN, hwboardid, 容量)，不是"新/旧"。**
> 本文件是唯一登记处；新单元到货/刷机状态变化后**当场更新本表**，不要在别的文档里另立称谓。

---

## 1. 单元台账

| ID | 序列号 | hwboardid | 内存/UFS | 入库 | a 槽 | b 槽 | LUN0 GPT | 当前可派任务（状态决定） |
|---|---|---|---|---|---|---|---|---|
| **U1** | `HA2ABH62`（主线 gadget SN `HA2CB1KY`） | `TB322FC_SM8750P_12+256` | 12 GB / 234 GiB | 已有 | stock 259 **已 root**（SUSFS 6.6.118 + KSU + ZN/Shamiko/PIF） | **原厂已刷回**（`boot_b`/`dtbo_b`） | **已逆手术**：`linux17` 已删，`/data` 回 211 GiB | Android 侧全部（G2-S0/S2、过环境、固件对照提取）；mainline 需重做手术 |
| **U2** | 待登记 | 预期 `TB322FC_SM8750P_16+512` | 16 GB / ~476 GiB | 预计 10-03 | 原厂未动 | 原厂未动 | 原厂未动（**未 dump**） | 破坏性手术 + mainline 首次 bring-up（状态最干净） |

两台**同一目标形态**（`MISSION-SCOPE.md` §2.4），只差容量。任何一台都可承担任一任务，只要先把它切到该任务要求的状态。

---

## 2. 共用的原厂基线（对两台都成立）

| 项 | 值 / 位置 |
|---|---|
| 机型 | Lenovo Legion Tab Y700 四代 = **TB322FC** = 代号 **elden**，`elden_prc_wifi`（国行 WiFi） |
| SoC | **SM8750(P)** 骁龙 8 至尊版，8 核 max 4.09 GHz；GPU **Adreno 830** |
| 屏 | LCD 1904×3040，双 DSI bonded + CPHY + DSC，CSOT PP8807HB1-1，Novatek **NT36536**（165 Hz） |
| 原厂 build | `TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`（Android 16） |
| EDL 全量包 | `~/下载/tb322fc/`（~599 MB / 63 文件）；已抽子集 `backup/fw/`、`backup/stock-259/` |
| 原厂分区备份 | `backup/stock-259/`（abl/boot/dtbo/init_boot/recovery 双槽）+ 各单元自有 `backup/<SN>…` |
| AVB | boot 为 chained 分区，须 **AOSP testkey（sha1 `2597c218`）+ rollback 1738713600 + 3 条 prop** 才被 ABL 接受 |
| BL | 已解锁（`unlocked:yes`） |

---

## 3. 容量差异的唯一体现（GPT 参数）

| 参数 | U1（234 GiB 实测） | U2（待实测） | 取法 |
|---|---|---|---|
| 扇区 | 4096 B | 4096 B（预期同） | `fastboot getvar block-size-for-sda` / 主线 `/sys/block/sda/queue/logical_block_size` |
| 主表 | LBA0..5 | 同 | `scripts/gpt-dump.sh` |
| `backup_lba` | `61390847` | **必须现 dump**（od 读头 0x20 处 8B LE） | `scripts/gpt-dump.sh` 打印 |
| `userdata`（未手术） | 211.4 GiB | ~470 GiB | `gpt-surgery-tb322fc.py list` |
| 建议 `linux17` | 65 GiB | 128 GiB | `--linux-gib` |

> ⛔ 跨容量档复用 GPT 二进制 = 必砖（历史：`flashing-bundle/skills/…/tb322fc-bootloop-gpt-mismatch.md`）。
> ✅ 备份目录命名规范：`backup/<SN>-<容量档>/`（例 `backup/HA2ABH62-12+256/`、`backup/<U2SN>-16+512/`），**不要用 `new-tablet`**。

---

## 4. 按状态分派（当前快照）

| 前置状态 | 满足的单元 | 可做 |
|---|---|---|
| mainline（b 槽 vk40 直启 + 持久根） | 暂无（U1 已逆手术、U2 未动） | G1 全部上机项、G2-S1（Waydroid） |
| stock Android + root | **U1** | G2-S0（兼容下限）、G2-S2（`/dev/gunyah`、`vm`/crosvm）、过环境、固件对照 |
| 原厂未动（可做首次手术） | **U2** | GPT dump + 手术 + 首次 RAM 验收（零历史包袱） |
| 纯 RAM（不落盘） | 任一（刷 `bootslot-b/boot_b_vk40-ram.img`） | 采集、dump、验收，失败即回退 |

## 5. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-10-02 | 建台账；确立"设备等价 + 按状态分派"，废止"两轨分机"。U1 当前 = 逆手术后纯 Android（Linux 已归档 `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz`）。 |
