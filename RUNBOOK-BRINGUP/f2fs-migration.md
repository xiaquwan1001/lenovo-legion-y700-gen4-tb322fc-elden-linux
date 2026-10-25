# RUNBOOK：ext4 → f2fs 根（路线 A：缩 ext4 + 尾部新建 f2fs + 本地复制）

> 状态：**已备好、未执行**（2026-10-25）。所有写盘步骤都要显式 `--yes`。
> 依据：`reports/f2fs-host-bench-20261025.md`（参数定案 + discard 已证实）、
> `reports/g0-fstype-zero-write-20261025.md`（`/init` fstype 探测已上机验证）、
> `reports/userland-service-consolidation-20261025.md`（入口已收敛，换 fs 不再牵动服务）。
> 编排脚本：`scripts/f2fs-migrate.sh`；GPT 手术：`scripts/gpt-surgery-tb322fc.py shrink-append`。

## 为什么是 A，不是「原地格式化」

| 维度 | A（并存：缩 ext4 + 新建 f2fs） | B（原地换） |
|---|---|---|
| 数据搬动 | **同盘本地 tar（分钟级）** | 主机 ←→ 设备两趟 30 GB |
| 实测瓶颈 | UFS 本地 | **USB NCM 仅 14.3 MB/s**（300 MB / 21.0 s）⇒ ≈1–1.5 h 纯传输 |
| 回退 | **ext4 原样保留**，`fastboot boot out/boot-elden-vk152.img` 即回 | 只有归档可回，且要先格回 ext4 |
| 空余 | 96 + 96 GiB（余 1 GiB 给 GPT 备份） | 全部 193 GiB 给 f2fs |

结论：**A**。B 的唯一优势是「整块盘给 f2fs」，等以后回收 Android 分区（Phase B）时再统一扩。

## 目标布局（4 KiB 扇区，已用当前 GPT 实测值算过）

| # | 名字 | first | last | 容量 | 文件系统 | LABEL |
|---|---|---|---|---|---|---|
| 16 | `linux17` | 73 277 435 | **98 443 258** | 96.0 GiB | ext4（缩小后保留） | `linux17` |
| 17 | `linux18` | **98 443 259** | 123 609 082 | 96.0 GiB | **f2fs** | `linux18` |
| — | 尾部余量 | 123 609 083 | 123 871 226 | 1024 MiB | 不用（备份 GPT 在上方） | — |

`last_usable` / `backup_lba` 都不变 ⇒ 备份表位置不变，只需重写 LBA0..5 与备份表（脚本已双表 CRC 自校验 + 写后读回比对）。

## 执行顺序（每步都可单独跑、可中断）

```bash
# 0. 只读核查：设备基线 + 尺寸账 + 计划（默认动作）
bash scripts/f2fs-migrate.sh

# 1.（可选但推荐）主机拉一份根归档作最终保险：14 MB/s ⇒ 30 GB ≈ 36 min，可后台
nohup bash scripts/f2fs-migrate.sh archive > /tmp/archive.log 2>&1 &

# 2. 进 RAM root（ext4 必须离线才能缩容；零写盘）
cd ~/y700-elden && fastboot boot out/boot-elden-vk162-rescue.img
#   判据：SSH 上来后 findmnt / 是 tmpfs（不是 /dev/sda17）；ramdisk 自带 mkfs.f2fs/fsck.f2fs/partprobe

# 3. 手术（写盘）：e2fsck → resize2fs 96 GiB → 写 GPT → partprobe →
#               mkfs.f2fs -l linux18 /dev/sda18 → 本地 tar 复制 → fsck.f2fs
bash scripts/f2fs-migrate.sh shrink --yes

# 4. 主机侧构建切根镜像（不写槽）
bash scripts/f2fs-migrate.sh bootimg
#   判据：cmdline 含 elden_root=LABEL=linux18；kernel_sha256 = b6a074ff…（= vk152 那份）

# 5. 写 boot_b（写槽；失败恢复 = fastboot set_active b）
bash scripts/f2fs-migrate.sh writeslot --yes

# 6. 重启进新系统，验收 + 读回校验
bash scripts/f2fs-migrate.sh verify
bash scripts/f2fs-migrate.sh readback
```

## 验收判据（`verify` 会打印，人工确认）

| 判据 | 期望 |
|---|---|
| `findmnt -no FSTYPE /` | **`f2fs`** |
| `dmesg \| grep "root fstype"` | `f2fs`（`/init` 用 blkid 探测） |
| 模块 | `grep -c . /proc/modules` ≥ 37，`version magic` 错误 0 |
| 桌面 | `pgrep -c phoc` = 1，`card0-DSI-1` = connected，背光 > 0 |
| 服务 | `rc-status` 无 crashed；`qbootctl` 在 default 里 |
| 槽 | `boot_b retry` 不递减、`succ=1`、`unbootable=0` |
| fsck | 复制后 `fsck.f2fs -f` 干净；首启后 `fsck.f2fs -f` 仍干净 |

## 回退（三级，均在写槽之前就有）

1. **没写槽**：`fastboot boot out/boot-elden-vk152.img` → 仍从 ext4 起（ext4 完整未动）。
2. **写了槽**：`fastboot boot out/boot-elden-vk152.img`（零写盘回 ext4）；要恢复默认启动再 `writeslot` 写回 ext4 版镜像。
3. **槽属性异常**：`fastboot set_active b`（`PITFALLS` 记录过失败的 `fastboot boot` 会把 boot_b 标 unbootable）。
4. **f2fs 本身坏**：ext4 侧数据仍在 ⇒ 回 1；要重建 f2fs 只需 `mkfs.f2fs -l linux18 /dev/sda18` 再复制。

## 已知风险与缓解

| 风险 | 缓解 |
|---|---|
| 缩容不可逆 | 数据 <30 G，缩到 96 GiB 仍留 3× 余量；先 `e2fsck -f` 再 `resize2fs`（脚本顺序固定），失败即停 |
| GMT 双表写坏 → 分区表不可读 | 先抓当前双表到 `backup/<SN>/gpt-<date>/`；脚本写后 `cmp` 读回；必要时 EDL 写回 |
| AB 槽 retry 归零卡 fastboot | 基线 `boot_b retry=6 succ=1` 已记录；`writeslot` 前后各查一次；`fastboot set_active b` 兜底 |
| boot.img 变砖级（AVB） | 只写 boot_b（不动 vbmeta）；签名用 `bootslot-b/avb.key` + `partition_size 100663296`；写前 `dd` 备份分区到主机（本机 ABL 无 `fastboot fetch`，用 Linux 侧 `dd`） |
| f2fs 高利用率 GC 悬崖 | 台架 93% 未见悬崖，但运维口径 **<85%**；`mount -o noatime,discard,gc_merge` |
| Waydroid 镜像（`/var` 12 G）在 f2fs 上行为 | 复制后先跑一次 `waydroid container restart` + 起一个 App；`sqlite` 密集写入是本 fs 的收益面 |

## 待办（本轮未做，明确记账）

1. `writeslot` 之前的 **boot_b 分区备份**：进 Linux 后 `dd if=/dev/disk/by-partlabel/boot_b of=...`（96 MiB）存到主机 —— 属于写槽前的强制前置，脚本里留了提示但未自动化（避免在 fastboot 态误读）。
2. `verify` 之后要跑一遍**真 POR 冷起**（不只 reboot）：`scripts/q28-por-rounds.sh`，确认真 POR 下 f2fs 根也能起（`PITFALLS` 里 POR 与暖复位行为差异多次咬过人）。
3. Mobian/G2 侧：`/var` 上的 Waydroid 镜像若迁移到 Debian，需重新 `waydroid init`（镜像与新 rootfs 不通用）。
