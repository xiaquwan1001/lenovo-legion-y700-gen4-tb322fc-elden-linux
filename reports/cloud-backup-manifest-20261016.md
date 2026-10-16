# 云盘备份清单 — 本机独有 / 不可重下的二进制（2026-10-16）

> **用途**：git 纳管的是**文本层**（文档/脚本/补丁/小证据）；大二进制走云盘。本文件是
> 「哪些本机独有、必须上云」的**清单与理由**，由 `scripts/pack-cloud-backup.sh` 生成上传目录。
> **配套**：`RESOURCES/README.md` §3（git 边界）· `scripts/pack-cloud-backup.sh`（打包器）。

## 0. 一句话

**T1 = 本机之外没有任何副本，坏了就没了** ⇒ 无条件上云；
**T2 = 能重下但代价高 / 上游源可能失效** ⇒ 建议一并上云。

## 1. 已生成的上传目录

```
~/cloud-backup-y700-elden-20261016/
├── README.md                    # 包内说明（分层/校验/敏感提示）
├── MANIFEST.sha256              # 2999 个文件的 SHA256
├── T1-irreplaceable/
└── T2-optional-redownloadable/
```

- 逻辑体积 **6.6 G**（T1 ≈ 4.7 G + T2 ≈ 1.8 G），**实占 0**：目录内是**硬链接**（`cp -al`，link count=2），
  与仓库源文件共享数据块 ⇒ 上传读内容、不额外占盘；源均为只读 dump/归档，不会被就地改写。
- **完整性已验**：`sha256sum -c MANIFEST.sha256` → **ALL-OK（2999/2999）**。
- 刷新/重建：`scripts/pack-cloud-backup.sh [DEST]`（幂等，先 `rm -rf` 目标目录）。

## 2. T1 — 不可再生（无条件上云）

| 项 | 体积 | 为什么不可重下 |
|---|---|---|
| `backup/HA2EXB0E-16+512/unique/` | 133 M | **21 个设备独有分区**（persist/proinfo/modemst1-2/fsg/fsc/frp/keystore/ssd…）。EDL 全量包的 `rawprogram*.xml` 把这些分区**留空（不刷）** ⇒ 刷机不恢复，**只有本机这一份** |
| `backup/HA2EXB0E-16+512/pre-unlock/` | 164 K | 解锁前取证（**Widevine L1**、by-name 119 项、getprop 全量、SHA256SUMS）——解锁后**不可再采** |
| `backup/HA2EXB0E-16+512/c0-baseline/` | 256 K | Android 侧身份/DRM/传感器/分区基线（23 份文本 + SHA256SUMS） |
| `backup/HA2EXB0E-16+512/current-259/` | 68 K | 1.5.10.259 现场态快照（by-name/cmdline/getprop/df） |
| `backup/HA2EXB0E-16+512/stock/` | 229 M | U2 **降级前**原厂 b 槽分区（boot/dtbo/recovery/vbmeta×2）；该状态已被覆盖 |
| `…/boot_b-before-vk{72,94}-*.img` | 96 M ×2 | 换内核前的**现场** boot 镜像（回退锚点，已不在任何镜像里） |
| `…/gpt_{main0,backup0,new_*,post-surgery_*}.bin` | ~132 K | U2 GPT 主/备双表五个时点（手术前后），**按单元+容量档唯一** |
| `backup/gpt/` | 92 K | 234 GiB 档 GPT 快照（**禁跨容量档复用**，见 PITFALLS） |
| `backup/misc/` | 1.6 M | misc / devinfo / uefivarstore 分区 dump |
| `backup/sde-gpt-{head,tail}.bin` | 272 K | SDE 卡 GPT 头尾 |
| `backup/HA2EXB0E-16+512/sn.img`、`sn-neko-zuxos.img` | 8 K | 解锁签名 blob（⚠ **含本机序列号**，只上私有云盘） |
| `backup/avf/` | 249 M | AVF 资产（crosvm / microdroid / u-boot.bin…）由 **U1 原厂镜像离线提取**；U1 已非 stock ⇒ **删 `l2/` 后不可再取** |
| `backup/rawdump.img` | 257 M | sda14 日志型分区 dump（诊断证据，原始态唯一） |
| `backup/slot-probe/` | 6.7 M | 槽位探测原始数据 |
| `backup/doctor-scripts-wt-20261015/` | 16 K | 一次性工作树留档 |
| `backup/kernel-git-repair-2026-10-08/elden-all-refs-1820.bundle` | 265 M | **内核现役线唯一备份**（41 ref，`bundle verify` 判完整）——内核仓 **shallow 且远端不可更新**，见 `RESOURCES` §3 |
| `backup/kernel-git-repair-2026-10-10/elden-all-refs-pre-boundary.bundle` | 265 M | 同上（边界前快照） |
| `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz` | 3.3 G | 持久根 rootfs 归档（30852 项，**过环境栈里程碑成功态**）；设备 rootfs 此后已演变 ⇒ 快照不可复得 |
| `/mnt/Samsung/l2/{lp_tool.py,dump-super.sh}` | 12 K | 自研 LP v1.2 工具（dump/extract/splice），**全项目唯一副本**（大镜像部分另见 §4） |

## 3. T2 — 可重下但代价高 / 源可能失效（建议一并上云）

| 项 | 体积 | 说明 |
|---|---|---|
| `backup/stock-elden/` | 258 M | 原厂 kernel/dtbo/vendor_dlkm(139 M)/DT/dts/传感器配置——从原厂镜像解出，重取需重跑解包链 |
| `backup/stock-259/` | 443 M | 原厂 13 分区备份（1.5.10.259）；云盘全量包已覆盖，但重取繁琐 |
| `backup/fw/` | 191 M | 固件子集（vendor/modem/bluetooth/dspso/gen80000_*） |
| `backup/dtbo_a.img` | 32 M | a 槽 dtbo 原始 dump |
| `y700四代工具/` | 271 M | 厂商工具 + 解锁工具箱；**第三方源随时可能失效**；⚠ 含 sn 模板（只上私有云盘） |
| `~/下载/tb322fc/` | 599 M | EDL 全量包（救砖 programmer/loader/XBL，**版本敏感**） |

## 4. 不入包（明确可重下 / 已另有副本）

| 项 | 体积 | 理由 |
|---|---|---|
| `/mnt/Samsung/l2/{super,system_a,system_a.pristine}.img` | 47 G | 云盘**全量线刷包**已覆盖（唯一全系统副本 = 云包）；**真要删本地前另议**（工具已单列入 T1） |
| `geekidos-linux/` `stock-src/` `Y700-elden-linux/` `edk2-*` `mu_wide_platforms/` `uefi-firmware-backup/` | ~18 G | 上游 clone / 自有 fork，可重下（`RESOURCES` §1） |
| `out/` `build/` `bootslot-b*/` `logs/` `pkgs*/` `probe/` `twrp/` | ~30 G | 可由 `patches/` + `scripts/` 重建（`out/*.manifest` 已入库作指纹） |
| `backup/kernel-git-repair-2026-10-08/{corrupt-pack-*.pack,*.idx}` | 295 M | 修复过程的破损包留档，结论已入 PITFALLS；`elden` bundle 已在 T1 |

## 5. 上传与恢复

```bash
# 上传：把整个目录（或打包后的单文件）丢到云盘
# 校验（在云盘目录内）：
sha256sum -c MANIFEST.sha256

# 可选：打成单个归档再上传（省得多文件同步）
tar -C ~ -cf - cloud-backup-y700-elden-20261016 | zstd -T0 -19 -o /mnt/Samsung/y700-elden-cloud-20261016.tar.zst
```

**恢复**：解包后按相对路径放回仓库根对应位置即可（路径与 §2/§3 表一致）。

## 6. 维护

- 有新 dump/归档 → 加进 `scripts/pack-cloud-backup.sh` 的 `T1`/`T2` 数组 → 重跑 → 重传变更文件。
- `MANIFEST.sha256` 是**快照时点**的校验和；重建后需重传对应文件或整包重传。
- 与本文件配套的**文本层**备份见 `RESOURCES/README.md` §3（USTC GitLab `origin` 全分支+标签 + hermes 记忆镜像）。
