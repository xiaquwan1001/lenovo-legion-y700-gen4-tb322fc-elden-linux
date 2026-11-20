# y700-elden 工作区瘦身·只读盘点（2026-11-20）

> 性质：**只读审计**。本报告不含任何删除动作，所有建议需主会话人工确认后执行。
> 测量命令均可直接复跑（cwd = /home/xuqianhui/y700-elden）。总盘 122G。
> 状态：**完成（2026-11-20 06:4x）**

## 0. 快照（du -sh 顶层，sort -rh）

| 目录 | 体量 | git 态 | 判定 |
|---|---|---|---|
| out/ | 87G | 忽略（/out/*，manifest 入库） | 主要瘦身对象 |
| backup/ | 29G | 忽略 | 部分可归档 |
| reports/ | 2.0G | 部分 | 内藏 4.3G `full-image.bin`，见 §1/§5 |
| bootslot-b/ | 1.7G | 忽略（README 入库） | 镜像历史，见 §3 |
| external/ | 884M | 忽略 | 上游克隆/sysroot |
| dl-cam/ | 639M | — | 相机调研素材 |
| 其余（Y700-elden-linux 28M、patches 13M、build 3.5M、scripts 2.6M 等） | 合计 <50M | 在库 | 不动 |

## 1. 大文件（>200M，find 实测，≥500M 共 17 个）

| 路径 | 体积 | 判定依据 | 建议动作 | 可再生产？ |
|---|---|---|---|---|
| out/android-min-avb-20261118/parts/system_a.img | 12.3G | 与 backup/official-rom-15.10.259/super_4.img **同大小 12.3G**（未哈希，疑似官方拆出）；parts/ = 中间拆分区 | 归档后删：官方 super 原件在 backup/ | ✅ 从 backup super 重拆 |
| backup/official-rom-15.10.259/super_4.img | 12.3G | 官方 ROM 原始备份 | **保留**（不可再生，唯一原件） | ❌ |
| out/android-slim-v2b-20261119/new/super_min_v3.img | 9.2G | v2b = 中间方案 | 待 v3 首启验证后随整树归档 | ✅ v3 流程可重造 |
| out/android-slim-v3-20261119/rb/v1_super_rb.img | 8.9G | `rb/v1_` = 旧版重建回滚件；与 out/android-min-20261118/pkg/super_min.img 同大小 | 删 v1（生成物；v3 final 在 new/） | ✅ |
| out/android-min-20261118/pkg/super_min.img | 8.9G | min 首版造件，被 v2b→v3 线取代；**reports/ 下未找到同名报告**（见 §7） | 归档 | ✅ 可重造 |
| out/android-slim-v3-20261119/rb/super_rb.img = new/super_min_v3.img = new/super_dbg.img | 7.5G×3 | rb/ = 已写入设备后的读回件，报告称「读回逐字节一致」已验证完毕 | 删 rb/（验证已完成）；new/ final 保留；dbg 视报告标注 | ✅ rb 已验证完 |
| out/p2-minbase-20261118/rootfs-minbase-20261118.ext4.img = out/min-restore-20261119/rootfs-minbase-gadget-20261119.ext4.img | 6.4G×2 | **同大小成对**：min-restore 是 p2 造件加 gadget 标签的副本 | 删 min-restore 副本，p2 保留 | ✅ 重造链在 scripts |
| out/android-slim-v2b-20261119/{new,verify}/system_a.img | 5.8G×2 | verify/ = 校验副本 | 删 verify/ | ✅ |
| out/android-slim-v3-20261119/{new,verify}/system_a.img | 4.1G×2 | 同上 | 删 verify/（校验已过） | ✅ |
| reports/artifacts/slotattr-20261119/full-image.bin | 4.3G | 整盘取证件（reports/ 总 2.0G 之外的统计口径内大头） | **归档到 backup/**（取证结论已落报告） | ⚠️ 不可再生（设备盘快照） |
| out/android-min-avb-20261118/{vendor,product,system_ext} | ~2.6G | AVB 中间拆分区 | 归档后删 | ✅ 从 super 重拆 |
| backup/git-slim-20261113/main-all-20261113.bundle | 0.5G | git 历史瘦身前全量 bundle | 保留 1 份（防历史不可回溯） | ❌ 历史快照 |
| backup/git-history-rewrite-20261112/pre-rewrite-main*.bundle | 0.4G×2 | 同上 | 保留或合并归档 | ❌ |

## 2. 顶层遗留/临时目录

| 路径 | 体积 | 判定 | 动作 |
|---|---|---|---|
| out/corrupt-20261102 | 106M | 名字即「corrupt」，18 天前 | 可删（作废件） |
| out/bootmark-a-test.img | 97M | 试验件 | 可删 |
| out/diag-20261119、slim-v3/diag、slim-v3/work | 合计 <300M | 诊断记录 | 保留（小，作证据） |
| dl-cam/vendor-cam-l1d.img | 256M | 相机 vendor 取证件 | 归档（结论已落 notes-camera-waydroid.md） |
| external/lc-cross + ext-repos + alpine-sysroot | ~750M | 工具链/上游克隆 | 保留（可再生但重下成本高） |

## 3. 重复副本汇总（同大小配对，未做逐字节哈希）

- `super` 级 4 组：min-avb parts ↔ backup 官件；slim-v3 rb/v1 ↔ min pkg；slim-v3 rb ↔ new；rootfs p2 ↔ min-restore。
- `system_a` verify/ 副本 3 组（v2b 5.8G、v3 4.1G）。
- bootslot-b/ 1.7G = 20+ 历史 boot_b 镜像（82–97M/个）：有 vk 版本账（vk-ledger-audit 技能管辖），**不动**；仅 `boot_b-device-20261111.img` 与 `boot_b-device-backup-20261101.img` 两个设备快照可合并归档。

## 4. 未跟踪垃圾 / git 状态

- 未提交（git status 实测）：`reports/audit-20261119/`（11 文件）、`PITFALLS/sessions/326-*.md`、本轮 `.pi/reports/cleanup-audit-20261120/` → 主会话 `git add` 提交（断电即丢）。
- `__pycache__/*.pyc` 2 个（tools/、rootfs/debian/ime/）→ 可删（可再生）。
- 其余无未跟踪大垃圾；.gitignore 对 out/backup/external/bootslot-b 覆盖良好（`/out/*` + `!manifest` 模式健康）。

## 5. 不该进仓的产物

- `reports/artifacts/slotattr-20261119/full-image.bin`（4.3G）：整盘 bin 不应放 reports/，应移 backup/（移动动作留主会话）。
- 其余在库体量健康（patches 13M、assets 319M 有豁免记录）。

## 6. 合计可安全回收 MB 估算

| 档 | 内容 | 体积 |
|---|---|---|
| **A：立即可回收（校验完的副本/中间件/可再生缓存）** | slim-v3 rb/ 7.5G + rb/v1 8.9G + v3 verify/ 4.1G + v2b verify/ 5.8G + min-restore rootfs 6.4G + bootmark-a 97M + corrupt 106M + .pyc ~1M | ≈ **33,000 MB** |
| B：v3 首启验证通过后 | v2b 整树 11G + min 14G + min-avb 15G 主体 + new/super_min_v3+dbg 收尾件 | ≈ 42,000 MB |
| C：归档（非删除，省 reports/ 在库体量） | full-image.bin 迁移 + vendor-cam-l1d 归档 | ≈ 4,500 MB（迁移） |

**数字结论：可安全回收 ≈ 33,000 MB（A 档）；总潜力 ≈ 75,000 MB（A+B）。**

## 7. 需主会话人工确认的高风险项

1. 同大小判定均未逐字节哈希（12G 级 md5 本机费时且 06:20 实测 `cargo --version` SIGSEGV，硬件不稳期不做大 IO）——删前对关键对（rootfs p2↔min-restore）抽 1 次哈希或比对 manifest。
2. out/android-min-20261118 无同名报告文件（reports/ 下 grep 无 android-min-20261118.md）——删前先定位其结论落在哪篇报告并补指针。
3. out/android-slim-v3 报告头：「设备未重新枚举 ⇒ 首启判据未取得」——v3 的 new/ 造件（~22G）**首启验证前一律保留**，只可删 rb/、verify/。
4. reports/artifacts/full-image.bin：不可再生设备取证件，只归档不删。
