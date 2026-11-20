# 大文件裁决：min-avb parts/ 与 rootfs 双副本（2026-11-20）

> 只读裁决轮：本轮**未删除任何文件**、无设备写操作、无 git 提交。所有 sha 均为 O_DIRECT 口径（`scripts/odirect-sha.py`）。
> 结论先行：**A) parts/ 15.2 G 可删（7/7 已被 backup 官方 super 逐字节重拆复现）；B) 与原计划相反——min-restore 是含 /init 的在机恢复件，不能删；可删候选反而是 p2 原件（可由 scripts 重造）。**

## A) `out/android-min-avb-20261118/parts/`（15.6 GB）—— ✅ 可删（可重拆）

**一句话**：parts/ 7 个 ext4 镜像全部与「backup 官方 8 分片 → 组装 super → 重提取」结果**逐字节一致**（O_DIRECT sha 7/7 相同），目录内无任何独有内容。

- 性质澄清：parts/ 不是「super 分片」，而是 2026-11-18 从组装 super 用 lpunpack 拆出的 **ext4 逻辑分区明文**（`file` 全部报 `Linux rev 1.0 ext2 filesystem data`；`out/android-super-20261118/logs/artifacts.txt` 记录的 7 件大小与现文件一致）。slim-worktree-plan.md 里「system_a 与 super_4.img 同大小」的说法**数字上不成立**（12 273 176 576 vs 12 266 729 472 B，差 6 447 104 B），属凑巧接近；但「可从 backup 重拆」的方向是对的，本轮已实证。
- parts/ 后续跑过 `e2fsck`（`logs/e2fsck-*.log`，均为 clean 无修复），未改动内容。

判据命令与输出（本轮实测）：

```bash
python3 scripts/android-super.py assemble \
  --xml backup/official-rom-15.10.259/rawprogram_save_persist_unsparse0.xml \
  --label super --base-lba 90504 -o /tmp/super-verify/super-recheck.img
# → wrote super-recheck.img 15,607,586,816 B
python3 scripts/android-super.py extract /tmp/super-verify/super-recheck.img . --partition <各分区>
python3 scripts/odirect-sha.py <重提件> out/android-min-avb-20261118/parts/<同名件>
```

| 分区 | 字节数 | O_DIRECT sha256（重提 = 现存，7/7 MATCH） |
|---|---|---|
| system_a | 12273176576 | `4b6957f58546012420eb5e682a9d60a07502afe9a19e95baf8417130a2546556` |
| vendor_a | 1536176128 | `6751d3a5ba6863170af88890773fd721d2348eb442dfef3cbeed78252842e437` |
| product_a | 1041178624 | `fb97bd3f0c3e88744b5965d51c6575f5817412aca4eb90f213e780e0907a1b11` |
| system_ext_a | 598372352 | `ff1acb3a3cf071d32974faee8843a4899c2268885b0287f5be40d216849258de` |
| vendor_dlkm_a | 147382272 | `93ceff6d08fbca1d824bdd0b3861e4bfb6ba5895f886ddd49bf029debc6cb814` |
| system_dlkm_a | 12533760 | `140b2543d886c1d7685d92b5741e5212aba70da1ebab30fde419173ff4dced69` |
| odm_a | 1650688 | `8ee4cced31fb8b0fa6aa3bb8c724081855629f1ad601fcf832bad0d7dfddb14d` |

可回收：**15 610 470 400 B ≈ 15.6 GB**（`du -sb parts/`）。

**可删清单（A，执行前先归档本报告引用即可）**：
- `out/android-min-avb-20261118/parts/` 整目录（7 件，见上表）。
- 同目录下的 `*-cow` 快照件不在本目录（`out/android-super-20261118/roundtrip/` 现为空）；`out/android-super-20261118/` 的 logs/ 与小件建议保留作证据，不在本裁决范围。

## B) rootfs 双副本（各 6 442 450 944 B）—— ❌ 不能删 min-restore；改判删 p2（如需回收）

**一句话**：两件**不是**同内容异标签——全量 O_DIRECT sha 不同（`d22c6a00…` vs `abf96ec4…`），内容差异实为 min-restore 比 p2 **多注入了 `/init`（34 584 B elden PID 1 脚本）和 `/usr/local/sbin/usb-gadget`（3 188 B）**；min-restore 是已通过 EDL 写入设备（LBA 73277435，`reports/device-status-20261119.md:87` 记 sha `abf96ec4…` 与本轮 O_DIRECT 一致）的在机恢复镜像，**删 min-restore 会失去与设备在跑内容对应的副本**。

判据命令与输出：

```bash
python3 scripts/odirect-sha.py out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img \
  out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img
# p2            6442450944  d22c6a00d5c27c711cccd79038f5ae3d70a2e81a602d4b85544661043a5da764
# min-restore   6442450944  abf96ec47067b642677e47f33441be48bd17a6be914a3cba2fffb8ec3c9ee604

diff <(debugfs -R 'ls -l /' p2.img) <(debugfs -R 'ls -l /' gadget.img)
# 仅多一行: 12493 100755 34584 18-Nov-2026 21:15 init      ← p2 无 /init
diff <(debugfs -R 'ls -l /usr/local/sbin' …)   # 仅多: usb-gadget 3188 B
# /sbin、/etc、/etc/systemd/system、/root 目录列表逐行相同；/etc/udhcpd.conf 两件均在（inode 1466, 127 B, 相同）
```

佐证：`TASKS/sessions/2026-11-19-主线恢复最小Linux与显示定位.md:13` 明确记录 min-restore = p2 副本 + 注入 `/init`+`usb-gadget`+`udhcpd.conf`。另注意 `execute-a-tier-20261120.md` 记的 buffered sha（`b60a355d…`）与本轮 O_DIRECT 值不同——再次印证页缓存污染，删除硬门必须用 O_DIRECT 口径。

**建议动作（本轮未执行）**：
- **保留** `out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img`（在机恢复件，唯一含 /init 的成品）。
- **可删候选**：`out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img`（6.4G）——是 min-restore 的真子集，且 `rootfs-minbase-build.sh` 可重造。若按「设备稳定运行后删历史一代」口径保守执行，也可两件都留，等下一位恢复镜像落定再删 p2。
- 若坚持回收 6.4G，删除前以本报告 O_DIRECT sha 作硬门校验。

## 汇总

| 问题 | 结论 | 可回收 |
|---|---|---|
| A parts/ | ✅ 可删（可从 backup super 逐字节重拆，7/7 sha 复现） | 15.6 GB |
| B rootfs 双副本 | ❌ 原计划「删 min-restore」**否决**；min-restore = 在机恢复件需保留；p2 为其真子集且可重造，是真正可删候选 | 6.4 GB（删 p2 而非 min-restore） |

需人项：无（两件裁决均只读完成；删除动作留主会话审批）。

■ 结束
