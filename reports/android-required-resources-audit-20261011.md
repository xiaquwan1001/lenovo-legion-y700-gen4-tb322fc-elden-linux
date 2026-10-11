# 安卓侧「必须提取资源」审计（U2 · 2026-10-11）

> 背景：用户口径 = **原安卓系统以云盘全量线刷包为准**（`RESOURCES.md §2.5`，2026-10-02 确认）；
> `a` 槽安卓可能被回收。本审计回答：**在安卓被去掉之前，哪些是「云包不一定能给、必须从本机提取」的东西**。
> 本轮为**只读检查**，未做任何提取/写设备。

## 0. 结论（三句话）

1. **系统镜像本身可依赖云全量包**（super / boot / dtbo / vendor_boot / recovery / 各固件分区）——但**本地 `~/下载/tb322fc` 不完整**（无 super/dtbo/vendor_boot/recovery），云包 = 唯一全系统副本，**须先核对版本 = 1.5.10.259 与含 dtbo/recovery/vbmeta**。
2. **设备独有分区不在云包里**：EDL 包的 `rawprogram_save_persist_unsparse0.xml` / `rawprogram5.xml` 明确把这些分区**留空（不刷、保留）**⇒ 全量刷机**不会**恢复它们 ⇒ **必须现在从本机 dump**。
3. 本项目自研/设备定制资产（`linux17` GPT、`l2` 全系统本地副本、`backup/fw` 驱动固件、`backup/avf` AVF）**已提取**，不依赖云包。

## 1. 设备独有分区（云包「保留不刷」⇒ 必须本机 dump）

判定依据：`~/下载/tb322fc/rawprogram_save_persist_unsparse0.xml` 与 `rawprogram5.xml` 中这些 label 的 `filename=""`（= 不动该分区）。

| 分区 | 设备路径 | 大小 | 用途 | 已 dump？ |
|---|---|---|---|---|
| `persist` | `sda6` | 32 M | **传感器/WiFi/BT 校准** | ❌ |
| `proinfo` | `sda1` | 3 M | 产品信息 | ❌ |
| `lenovolock` | `sda2` | 512 K | Lenovo 锁状态 | ❌ |
| `lenovocust` | `sda3` | 300 M | Lenovo 定制 | ❌ |
| `lenovoraw` | `sda4` | 16 M | Lenovo raw | ❌ |
| `ssd` | `sda5` | 8 K | 安全存储 | ❌ |
| `misc` | `sda7` | 1 M | BCB/启动控制 | ✅ `backup/misc/`、`backup/slot-probe/` |
| `keystore` | `sda8` | 512 K | keystore | ❌ |
| `frp` | `sda9` | 512 K | 工厂复位保护 | ❌ |
| `modemst1` | `sdf2` | 4 M | **modem NV** | ❌ |
| `modemst2` | `sdf3` | 4 M | modem NV | ❌ |
| `fsg` | `sdf4` | 4 M | modem FS | ❌ |
| `fsc` | `sdf5` | 128 K | modem FS cache | ❌ |
| `devinfo` | `sde66` | 4 K | 解锁/设备信息 | ✅ `backup/misc/devinfo_from-android-a.bin`、`backup/slot-probe/devinfo_from-linux-b.bin` |
| `uefivarstore` | `sde70` | 512 K | UEFI 变量（含启动项） | ✅ `backup/misc/`、`backup/slot-probe/` |
| `secdata` | `sde71` | 28 K | 安全数据 | ❌ |
| `mdcompress` | `sde72` | 20 M | modem 压缩数据 | ❌ |
| `connsec` | `sde73` | 128 K | 连接安全 | ❌ |
| `tzsc` | `sde74` | 128 K | TZ 安全配置 | ❌ |
| `spunvm` | `sde75` | 32 M | SPU NVM | ❌ |
| `xbl_sc_test_mode` | `sde76` | 64 K | XBL 测试模式 | ❌ |
| `xbl_sc_logs` | `sde77` | 128 K | XBL 日志 | ❌ |
| `dpm` | `sde78` | 8 K | DPM | ❌ |
| `qmcs` | `sde23` | 30 M | QMCS | ❌ |
| `rawdump` | `sda14` | 256 M | 崩溃日志（非关键） | ❌（低价值） |
| `pstoredump` | `sda15` | 128 M | pstore dump（非关键） | ❌（低价值） |

**建议提取集合**（去掉 rawdump/pstoredump 这类日志）：`persist proinfo lenovolock lenovocust lenovoraw ssd keystore frp modemst1 modemst2 fsg fsc secdata mdcompress connsec tzsc spunvm xbl_sc_test_mode dpm qmcs`，合计约 **420 MB**。
**必提最小集**（真正设备唯一、丢了不可复得）：`persist`、`modemst1/2`、`fsg`、`fsc`、`proinfo`、`keystore`、`frp`、`lenovolock`、`ssd` —— 约 **46 MB**。

## 2. 安卓系统资源（可由云包恢复，但须先核对云包）

| 资源 | 本地状态 | 云包 |
|---|---|---|
| `super`（system/product/vendor/odm 动态分区） | ✅ `l2/super.img.raw`（23.6 G，本地唯一全系统副本） | 应有 `super_1..8.img` |
| `system_a` / `system_a.pristine` / `vendor_a` | ✅ `l2/`（12.3 G / 12.3 G / 1.5 G） | super 内 |
| `boot_a` / `init_boot_a` / `vbmeta_a` / `vbmeta_system_a` | ✅ `backup/stock-259/`（b 槽同款） | rawprogram4（a 槽） |
| `dtbo_a` | ✅ `backup/dtbo_a.img`（32 M，md5 `9181cdd1…`） | rawprogram4 `dtbo_a -> dtbo.img` |
| `recovery_a` / `vendor_boot_a` | ✅ `backup/stock-259/recovery_a.img` | rawprogram4 |
| 驱动固件（ADSP/CDSP/peach/BT/GPU/触屏/触觉/ACF/tplg） | ✅ `backup/fw/`、`backup/stock-elden/vendor-firmware` | `dspso.bin`/`NON-HLOS.bin` 等 |
| AVF/crosvm（`com.android.virt`） | ✅ `backup/avf/`（apex + 8 bin + etc-fs） | super（`system/apex`） |
| GPT（含 `linux17` 手术） | ✅ `backup/HA2EXB0E-16+512/gpt_*`、`backup/gpt/`、`backup/slot-probe/gpt-*` | ❌ **云包不含我们的 `linux17` 定制** ⇒ GPT dump 是唯一副本 |

## 3. 云全量包核对清单（待做；本机无 `reccli-ts`/凭据）

口径：`RESOURCES.md §2.5` P2 闸门 —— **删 `backup/stock-259/` 与 `l2/` 前必须先确认**。
1. 云包版本 = `TB322FC_CN_OPEN_USER_Q00041.1_W_ZUXOS_1.5.10.259_ST_260611`（与 a 槽一致）。
2. 含 `super_1..8.img`（= 完整 super）、`dtbo.img`、`recovery.img`、`vendor_boot.img`、`abl.elf`、`vbmeta*.img`、`NON-HLOS.bin`、`dspso.bin`。
3. 记录云包路径 + 文件清单 + 各文件 sha256 到 `backup/`（避免以后又只剩口头）。
- 访问方式：技能 `ustc-cloud-drive`（本机未装 `reccli-ts`、无 `~/.reccli-ts`）⇒ **需你 `reccli-ts webdav-login -d` 或给云包直链**，我可驱动 rclone/curl 核对。

## 4. 提取命令（只读、可从 Linux b 槽执行）

> **✅ 已于 2026-10-11 执行**：21 个分区 → `backup/HA2EXB0E-16+512/unique/`（133 MB；`MANIFEST.txt` + `SHA256SUMS`；
> 设备侧 md5 == 主机侧 md5，21/21 一致）。来源 Linux b 槽 `7.2.0-debug-vk64-gd02658e63cf6`，本 boot 健康（card0 在、storm=0）。
> 未提：`lenovoraw`/`lenovocust`（EDL 包内**有 filename**，云包含）、`rawdump`/`pstoredump`（日志）。
> **内容特征**：21 个中**只有 8 个有真实数据** —— `persist`（21.4 MB，传感器/WiFi/BT 校准，唯一大头）、`secdata`(3.8K)、
> `uefivarstore`(914B)、`spunvm`(205B)、`devinfo`(175B)、`qmcs`(133B)、`frp`(45B)、`misc`(34B)；
> 其余 13 个（`fsg`/`modemst1`/`modemst2`/`keystore`/`lenovolock`/`proinfo`/`mdcompress`/`connsec`/`tzsc`/`dpm`/`ssd`/`fsc`/`xbl_sc_test_mode`）**全零**（本机 WiFi-only、无 SIM 的预期）。

```sh
# 设备侧（Linux b 槽 root）：dump 到 /tmp，再 scp 回 backup/<SN>-<容量档>/unique/
for p in persist proinfo lenovolock lenovocust lenovoraw ssd keystore frp \
         modemst1 modemst2 fsg fsc secdata mdcompress connsec tzsc spunvm xbl_sc_test_mode dpm qmcs; do
  d=$(readlink -f /dev/disk/by-partlabel/$p) || continue
  dd if="$d" of="/tmp/part-$p.bin" bs=4M conv=fsync status=none && echo "$p ok"
done
# 主机侧取回
scp root@192.168.7.1:'/tmp/part-*.bin' backup/HA2EXB0E-16+512/unique/
# 校验
cd backup/HA2EXB0E-16+512/unique && sha256sum part-*.bin > SHA256SUMS
```
- 只读、不写分区；`dd` 期间设备需在 Linux（b 槽）。**当前该 boot 的 Q28 稳定性未定性**（见用户提醒），提取前应先确认 boot 为 GOOD，避免读取被风暴打断。
- `rawdump`/`pstoredump` 暂不提（日志，低价值）。

## 5. 状态回写

- `RESOURCES.md §2.5` P2/P3 闸门状态见本报告 §3（未变：仍需先核对云包）。
- 本审计结论已并入 `RESOURCES.md §2.3/§2.5` 的引用（见收尾回写）。
