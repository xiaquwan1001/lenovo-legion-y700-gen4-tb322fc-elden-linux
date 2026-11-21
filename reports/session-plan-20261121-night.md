# 2026-11-21 晚 — 进度整理 / 待办 / 子代理编队（协调层文件）

> 本文件只是**这一轮会话的协调面板**；状态真源仍是 `INDEX.md` §0，任务真源 `TASKS/README.md`。
> 本文件每轮更新；收尾时把结论并回 INDEX §0 / TASKS，然后本文件可归档。
> **2026-11-21 深夜起已被取代**：待办派发入口改为 `TASKS/README.md` §4.0「维度总表」（D1–D9）；本文件只作当晚现场记录。

## 0. ★P0 已完成（2026-11-21 16:42–16:55，上机）

- 16:42 用户断电重启后 BL 恢复响应 → EDL 读 LUN4 主/备表：**几何/GUID 与 11-20 基线一致，但 b 侧类型 GUID
  仍是通用占位**（`boot_b type=abl_b type=77036CD4…`）⇒ 正是 `ValidateSlotGuids` 拒的形态。
  注意：只比 **UniquePartitionGUID（偏移 16）** 会误判「一切正常」，判据必须看 **PartitionTypeGUID（偏移 0）**。
- 新工具 `scripts/gpt-slot-swap-guids.py`：对 32 对 `X_a/X_b` 交换 type GUID（= ABL `SwapPtnGuid()`）+ 按
  `MarkPtnActive()` 写 ACTIVE 位 + 重算双表 CRC；单向/往返自检通过；产物经
  `scripts/linux-gpt-apply.sh --lun 4 --apply --reset` 写盘（写前 dump + 写后逐字节 + 设备端 sha256 全 OK）。
- 刷 `boot_b` = `boot_b-minbase-labellinux-20261119.img`（740d431b，`LABEL=linux`），**未**再调 `--set-active`。
- 结果：**两次冷起都直进 Linux**（`uname -r` = vk192 口径、`/`=`/dev/sda17`、`elden_root=LABEL=linux`）；
  `ab-mark-successful.service` 已装 enabled、`Result=success`、`qbootctl -n b` = `SLOT _b: is marked successful`；
  `deploy-desktop-shell.sh --check` = **MISS=0**（含新 §13）；`check-doctor` = **FAIL=0**。
- 回退基线：`backup/HA2EXB0E-16+512/edl-apply-readback-20261121-164957/rollback/`（写前旧表）。

## 1. 现在的位置（实测，不是文档抄写）

| 项 | 状态 | 证据 |
|---|---|---|
| 设备 | **在 BL，且 ABL 半挂**（`fastboot devices` 能看见 HA2EXB0E，`getvar` 无回包） | 本轮 16:05–16:20 多次采样 |
| 起不来的根因 | **`ValidateSlotGuids: BootableSlot _b does not have valid guids`** ⇒ `FindBootableSlot` → `LoadImageAndAuth` Device Error → `Launching fastboot` | XBL log `UEFILOG1.TXT`（`logs/restore-20261121/logfs-now.bin` 内 FAT 卷） |
| 已排除 | `boot_b` 内容（换 vk192 签名件仍同败）、`vbmeta_b`（flags3 已刷）、`vendor_boot_b`（写回原厂仍同败）、`misc` BCB（全 0）、电池（4294 mV / soc ok） | `reports/bootloader-slotguid-brick-20261121.md` §4 |
| 结论 | **`fastboot --set-active` 会搬 partition type GUID**，连续调用留下「GUID 侧 ≠ ACTIVE 位」半完成态 | `scripts/gpt-slot-flip-active.py` 头注释 + 本轮 GPT 对照（68 分区几何/GUID 与 11-20 基线相同，仅属性字节差异） |

## 2. 待办（按依赖排序）

**P0 — 把设备恢复日常 Linux（主会话独占设备）**
1. 等用户物理断电/长按电源 → BL 恢复响应。
2. **已备好一键脚本** `scripts/recover-lun4-slotguid.sh`（默认 dry-run；`--apply` 才写；`--from-dir` 可离线干跑）：
   探活 → `oem edl` → 读 LUN4 主/备表 → 与 11-20 基线比 GUID/几何/ACTIVE → 判定（写回基线对表 / 只补属性位 / noop）
   → 只经 `scripts/linux-gpt-apply.sh --apply --reset` 写盘。
3. 判据原文（源码级）：`PartitionTableUpdate.c:1568` —— **`boot_<slot>` 与 `abl_<slot>` 的 type GUID 相同 ⇒
   `EFI_DEVICE_ERROR`**；`set_active` 会**整表换 GUID 侧 + 切 UFS boot LUN**，非幂等。
3b. **GPT 修好后立刻刷 `boot_b` = `bootslot-b/boot_b-minbase-labellinux-20261119.img`（740d431b，`elden_root=LABEL=linux`）**；
   不要刷 `bootslot-b/boot_b.img`（06c081ca，`LABEL=linux17`，与本机 root label 不符）。
4. 判据：SSH 回 `uname -r`=vk192、`qbootctl -a` b 槽 Active/Successful/Bootable=1、`/`=sda17、graphical active。
5. 上机后立刻做：`fix-ab-mark-successful`（systemd unit）落盘 + `deploy-desktop-shell.sh --check` MISS=0 + T9 采样器 alive。

> 原 P0 第 2/3 步（手工 EDL + 比表 + `linux-gpt-apply`）已被脚本替代，保留为 fallback。

**P1 — 主机侧，不占设备（本轮已派 7 个子代理）**

| 子代理 | 产出 | 用途 |
|---|---|---|
| scripts-audit | `reports/scripts-audit-20261122.md` + `out/audit/scripts-audit-20261122.tsv` | 脚本/工具逐个标记 KEEP/STALE/DANGEROUS/BROKEN |
| mobian-mainline-upstream | `reports/mobian-mr-plan-20261122.md`、`reports/mainline-upstream-audit-20261122.md` | Mobian 首个 MR 草案 + 主线四态总账/72h 投递顺序 |
| ime-osk-zh-research | `reports/ime-osk-zh-matrix-20261122.md` | 键盘弹出 + 中文组词（可不绑 fcitx5）+ 候选窗决策矩阵 |
| daily-linux-deploy | `reports/daily-linux-deploy-20261122.md` + unit/脚本改动 | 日常化部署清单、自动标槽成功、重启 BL runbook、资源获取 |
| pitfalls-condense | `reports/pitfalls-condense-20261122.md` + 低风险 edit | PITFALLS 降噪（不改编号） |
| best-state-recall | `reports/best-state-and-gap-20261122.md` | 历史最佳状态矩阵 + 补全清单 + 互斥项 |
| android-boot-audit | `reports/android-boot-audit-20261122.md` | 安卓起不来的证据链审计 + 3 个最小单变量实验 |

> 状态（16:40）：`best-state-recall-r2` **已完成** → `reports/best-state-and-gap-20261122.md`（182 行）。
> 早先两次 SIGSEGV（同一可执行 id `62933cde…`、RSS 766 MB）已记 `~/hw-stability/evidence/inbox/20261121-y700-elden-pi-child-segv/MANIFEST.md`；
> 处置 = 降并发，`android-boot-audit` 在 best-state 收工后重派（r2 口径）。

### ★best-state-recall 主结论（主会话已独立复核其中两条）

1. **历史最佳 = 2026-11-20 23:10 那个态**（vk192 + 190 G 根 + `deploy-desktop-shell.sh --check` MISS=0 + s2idle 4/0）。
2. **与现在的差 = 一张 GPT 表 + 一处 boot_b 内容错配**（不是能力丢失）。
3. **boot_b 内容陷阱（主会话已用 `scripts/boot-img-cmdline.py --show` 复核）**：
   - `bootslot-b/boot_b.img`（06c081ca）= `elden_root=LABEL=linux17` ← **错件**（11-19 重建根后 label 是 `linux`）；
   - `bootslot-b/boot_b-minbase-labellinux-20261119.img`（= `logs/forensics-20261120-2210/boot_b.img`，740d431b）= `elden_root=LABEL=linux` ← **正确件**（今早在机跑 vk192 的就是它）。
   ⇒ 恢复流程里**必须刷 740d431b 那件**，不能再刷 06c081ca（否则 GUID 修好后换成 root 挂载失败）。
4. 11-19 重建根把用户态层冲回 stock trixie（phoc/phosh 0.46.0）⇒ T20 电源键、phoc syncobj、IME、相机 IPA helper 等非包资产全回归
   （`PITFALLS` #689/#698/#700 同族）—— 这与 `daily-linux-deploy` 子代理的部署清单是同一件事。

> 注：文件名用了 `20261122`（派发时的下一日标签），实际产出时间 = 2026-11-21 深夜；INDEX 引用时以文件名为准。

**P2 — 依赖子代理结论后由主会话裁决**
- 脚本精简：只批准「DANGEROUS 加门」与「STALE 归档」两类，逐批 ≤10 项、每批独立回退。
- PITFALLS：先看精简方案的体积收益，再决定是否 DEMOTE 到 `.pi/memory`。
- Mobian：先确认 `droid-juicer` 目标仓库与清单格式，再决定是否本周提交。
- 输入法：先选一条路径（倾向「ibus + squeeboard」或「squeakboard 送 committed text」），再开设备窗口。

## 3. 设备使用权规则（本轮现场约定）

- **设备 = 主会话独占**；子代理一律主机侧（已写进每个子代理的硬纪律）。
- 上机窗口内的纪律：一条命令只碰一个通道（fastboot 循环里不出现 ssh，`PITFALLS #585/#638–#646`）。
- **不要用 `fastboot --set-active` 切槽**（本轮砖的直接机制）；Linux 侧用 `qbootctl -s <slot>`。
- BL 一旦「能枚举但不回包」= ABL 半挂，只能物理长按电源，不要连发命令。

## 4. 本轮新增待入账（等 PITFALLS 子代理收工后一起写）

- 新坑候选 #709：`fastboot --set-active` 连续调用会留下「GUID 侧 ≠ ACTIVE 位」，ABL 报
  `ValidateSlotGuids: BootableSlot _<x> does not have valid guids` 并直接掉 fastboot；取证口径 =
  EDL 读 LUN4 主/备表 + `logfs` 内 `UEFILOG1.TXT`（不要只读 seg0 的 strings）。
- 附：`logfs` 里的 ABL 日志在 **FAT12 卷内的 `UEFILOG1.TXT`**，用 `mdir -i logfs.bin ::/` 才能看到。
