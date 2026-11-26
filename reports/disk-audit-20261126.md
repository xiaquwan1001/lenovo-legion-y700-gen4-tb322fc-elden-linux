# 磁盘空间审计（2026-11-26）—— 剩余 43 G 在哪里、要不要动

> 只读审计（`find` + `sha256sum`，258 个 >50 MB 文件 / 94.8 G）；**本报告不删任何东西**，只给判据与建议。
> 前置：同轮已完成「可再生/可共享缓存搬出仓库」——仓库 **123 G → 80 G**，账 = `versions/cache-ledger.tsv`，
> 门 = `scripts/cache-audit.sh --check`。本报告处理剩下的 80 G。

## 1. 一页结论

| # | 候选 | 可回收 | 可逆性 | 我的建议 |
|---|---|---|---|---|
| A | `out/` 三个 Android 镜像构建工作区（`android-slim-v3-20261119` 29 G、`android-min-20261118` 8.5 G、`android-slim-v2b-20261119` 1.1 G） | **38.6 G** | 脚本可重建（~1–2 h，需 super/原厂件）；**删除不可逆** | **✅ 已执行（2026-11-26 用户授权）**：三件已删，38.6 G 回收；账 = `reports/out-android-purge-20261126.md`，删前 sha 清单 = `reports/artifacts/out-android-purge-20261126.sha256` |
| B | 内容重复的大件（19 组，sha256 完全相同） | **9.9 G** | `cp -l` 建硬链即回收，物理数据还在（**可逆**） | 谨慎：boot/镜像件**可能被脚本原地改写** ⇒ 就地改写会同时破坏两份。建议只对 `backup/` 内两两重复做硬链，`out/`/`runs/` 的按 A 一起清 |
| C | `.pi/sessions/`（378 个 jsonl，1.0 G） | **~0.45 G** | gzip 实测最大件降到 43%；**需先确认 `sessfind`/`session-librarian` 能读 .gz** | 先做 1 个文件的工具兼容验证，再批量（本轮未动） |
| D | `reports/artifacts/`（2.0 G） | ~0.3 G | 归档（顶部 8 目录 ≈ 300 MB，结论已入 md） | 低优先：先 A，再谈这个 |
| E | `.git` 418 M / `backup/` 29 G / `bootslot-b/` 1.8 G | — | 不可再生 / 含私钥 | **不动**（`.git` 瘦身须先 bundle；`backup` 删前上云） |

⇒ **A+B 一起做可到 ~50 G（80 → 30 G）**；只做 A = 41 G。

## 2. A 项的判据（为什么可以交给脚本重建）

| 目录 | 体积 | 重建入口 | 是否持有唯一件 |
|---|---|---|---|
| `out/android-slim-v3-20261119/` | 29 G | `scripts/android-slim-v3-build.sh` + `scripts/android-rom-segassemble.py` | 否（`super_min_v3.img` 与 `rb/super_rb.img` 互为重复；成品件另有 sha 账件在 `out/min-restore-*`） |
| `out/android-min-20261118/` | 8.5 G | `scripts/android-min-build.sh` + `scripts/android-rom-segassemble.py` | 否 |
| `out/android-slim-v2b-20261119/` | 1.1 G | `scripts/android-slim-v2-plan.sh`（v3 已取代） | 否 |
| `out/min-restore-20261119/` | 2.5 G | **不可再生**（最小可恢复集，候选件有 sha 账，doctor §29 在读） | **是 ⇒ 保留** |

## 3. B 项：19 组重复（sha256 完全相同，258 件里命中）

| 7.45 G | 2 | `out/android-slim-v3-20261119/new/super_min_v3.img`；`out/android-slim-v3-20261119/rb/super_rb.img` | out（造件） |
| 0.37 G | 2 | `backup/fw/tb322fc-edl/NON-HLOS.bin`；`backup/official-rom-15.10.259/NON-HLOS.bin` | backup（不可再生证据） |
| 0.27 G | 3 | `runs/laneBootAnalyze/edl/pstoredump.img`；`runs/laneDeviceV3/pstore/pstoredump.img`；`out/android-min-20261118/diag/pstore.bin` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.20 G | 3 | `runs/laneBootAnalyze/edl/boot_b.img`；`logs/forensics-20261120-2210/boot_b.img`；`bootslot-b/boot_b-minbase-labellinux-20261119.img` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.20 G | 3 | `runs/laneDeviceV3/pstore/boot_a-device.img`；`logs/uefi-flashed-20261121/boot_a-pre.img`；`backup/official-rom-15.10.259/boot.img` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.20 G | 3 | `bootslot-b/boot_b-vk185.img`；`bootslot-b/boot_b-device-20261111.img`；`backup/boot_b-live-vk184-20261110.img` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.20 G | 3 | `backup/fw/tb322fc-edl/boot.img`；`backup/stock-259/boot_a.img`；`backup/.triage-trash-20261118-171303/boot_a-pre-uefi-20261108.img` | backup（不可再生证据） |
| 0.10 G | 2 | `backup/stock-259/recovery_a.img`；`backup/stock-259/recovery_b.img` | backup（不可再生证据） |
| 0.10 G | 2 | `bootslot-b/boot_b-vk192-linux17label-20261119.img`；`bootslot-b/boot_b.bak-20261123-740d431b.img` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.10 G | 2 | `bootslot-b/boot_b-device-backup-20261101.img`；`backup/HA2EXB0E-16+512/m8ab-restart-20261030/boot_b-readback-20261031.img` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.10 G | 2 | `backup/pre-esp-flash-20261124/vendor_boot_b-before.img`；`backup/official-rom-15.10.259/vendor_boot.img` | backup（不可再生证据） |
| 0.09 G | 2 | `out/android-slim-v3-20261119/work/system_v3/system/apex/com.android.virt.apex`；`backup/avf/com.android.virt.apex` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.09 G | 2 | `out/boot-elden-vk192.img`；`out/min-restore-20261119/exp-manifests/boot-elden-test-ctrl.img` | out（造件） |
| 0.09 G | 2 | `backup/out-history-20261105/boot-elden-vk142-q28disp73dt.img`；`backup/out-history-20261105/boot-elden-vk141-q28disp73.img` | backup（不可再生证据） |
| 0.08 G | 2 | `out/boot-elden-m3v5-daily.img`；`backup/corrupt-20261103/boot-elden-m3v5-daily.img` | 混合（backup/out/runs/logs/bootslot-b） |
| 0.08 G | 2 | `out/boot-elden-m3v5-onboard.img`；`out/m3v5-onboard/boot-elden-m3v5-onboard.img` | out（造件） |
| 0.07 G | 2 | `backup/fw/tb322fc-edl/dspso.bin`；`backup/official-rom-15.10.259/dspso.bin` | backup（不可再生证据） |
| 0.06 G | 2 | `out/vk133-ramdisk.cpio.gz`；`out/rootfs-vk127.cpio.gz` | out（造件） |
| 0.06 G | 2 | `out/ramdisk-vk181-working.cpio.gz`；`out/vk188-bootfiles/initrd.img` | out（造件） |

**为什么不一刀切硬链**：`scripts/bootimg-replace-kernel.py`、`scripts/avb-sign*`、`mke2fs` 这类工具会**原地改写**目标文件；
两份是同一 inode 时，改一份 = 两份一起变 ⇒ 会绕过「读回 sha 校验」的假设。**只对「明确只读的历史证据」做硬链**（`backup/` 内部两两重复、`logs/` 里的一次性取证副本），
`bootslot-b/` 与 `out/` 的镜像不做。

## 4. 还有一个「看不见的」占用

`out/` 45 G 里 39 G 是 A 项三个工作区；剩余 6 G = 候选启动件 + 取证件（doctor §23/§25/§29 在核），
`scripts/out-archive.py` dry-run（2026-11-26）= 8 件 / 572 MiB 可 mv 到 `backup/out-history-20261126/`，**同文件系统 rename ⇒ 净释放 0**（只是分目录），要真回收得上 tar.zst 或删。

## 5. 复跑方式

```bash
find . -path ./.git -prune -o -type f -size +50M -print0 | xargs -0 sha256sum > /tmp/bigsha.txt   # ~2 min
# 分组见 §3；A 项体积 du -sh out/*
bash scripts/cache-audit.sh --check        # 缓存台账（搬家后的软链/台账对账）
```
