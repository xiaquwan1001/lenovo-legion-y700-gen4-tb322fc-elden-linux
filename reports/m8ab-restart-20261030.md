# M8 A/B 续测（2026-10-30）：基线臂三发正常，坏发未复现

> 续 2026-10-29 断电中断的 M8 v2 真机 A/B。主机侧构建见 `reports/m8ab-build-20261029.md`，
> 判据口径见 `patches/upstream/q28-dispcc-v2-20261029/GATES.md`。本报告只记录本轮设备证据与停手理由。

## §0 数字结论

| 项 | 值 |
|---|---|
| 刷入臂 | **基线臂** `out/boot-elden-m8ab-base.img`（签后 96 MiB，sha256 `2ba252cc…`，写后读回一致） |
| 有效采样发数 | **1 发**（用户现场另判 2 发正常，无标准采样） |
| 判据结果 | `STORM=0`、`command DMA timeout=0`、`DSI_PLL_lockfail=0`、`mdss reset 获取失败=0`、`card0-DSI-1=connected/enabled` |
| 坏发复现 | **0/3**（现场判别口径） |
| v2 疗效 | **未证实**（未刷 v2：基线臂未复现坏发 ⇒ 本机本轮无判别力） |
| 备份 | 刷前 `boot_b` sha256 `caaa171c…` 已存档；GPT 双表（sda/sde 主+备）已存档并复核尺寸 |
| 当前设备 | 仍为基线臂；恢复日常镜像**未执行**（收尾备份读回被 90 s 超时截断 32 KiB） |

## §1 本轮设备事件时间线（全部同口径）

| 时间 (CST) | boot_id | 触发 | 结果 |
|---|---|---|---|
| 10:48:05 | `27d09ef2` | `flash-b` 写臂 A 后 `sysrq-b`（暖复位） | 面板 connected/enabled，错误计数 0 |
| 10:50:21 | `1f78ddce` | 用户 POR #1 | 同上（未采样） |
| 10:51:04 | `7377535e` | 用户 POR #2 | **标准采样 GOOD**：`reports/artifacts/q28-clkdiag-r11-7377535e.txt`、`reports/trials/20261030T025103Z-q28por-r11.json` |
| 10:52:58 | `b5447e3f` | 用户 POR #3 | 同上（现场判别正常） |

`journalctl --list-boots` 另见 `-1 = b4b248e9`（epoch 未同步的启动，同为现场正常发）。

## §2 停手理由（按 2026-10-29 约定的预注册规则）

预注册规则：**臂 A 若 2–3 发全好 ⇒ Q28 在本机不再复现，A/B 无判别力，立刻停手、不刷臂 B**。
本轮臂 A 三发全好 ⇒ 规则触发，未刷 v2，未继续消耗用户物理动作。

⇒ 结论限定：**「基线臂在本机当前状态下不产生坏发」**，不能外推为「v2 无效」，也不能外推为「Q28 已根治」。
再要判别力需要换台架（历史坏发线：`vk149` / 7.2 血统 / `vk86` 复现线），见 `TASKS/README.md` §5 Q28。

## §3 备份与恢复现场

- 存档目录 `backup/HA2EXB0E-16+512/m8ab-restart-20261030/`：
  `boot_b-before.img`（sha `caaa171c…`，逐字节等于刷臂 A 前分区）、`device-info.txt`、
  `gpt-{sda,sde}-{primary,backup}.bin`（24576 / 20480 B，sha 记录在提交说明）。
- 恢复件仍在：`bootslot-b/boot_b-vk181-daily-signed-20261029.img`（sha `b72866ef…`，与 10-29 在机分区逐字节一致）。
- **中断点**：收尾时再次 `dd` 读 `boot_b` 备份在 90 s 超时内只到 100 630 528/100 663 296 B（差 32 KiB）⇒
  该文件**不是完整备份**，已丢弃，未用于任何恢复。**未执行恢复写入**，设备留在安全态（基线臂 + 好屏 + 可 SSH）。
- 恢复动作前置条件：重取完整读回并通过 sha 等于 `2ba252cc…` 的校验后，再整块 `dd` 回 `boot_b` 并读回校验。

## §4 门禁与账本副作用

- 两枚臂镜像在 `versions/vk-ledger-known-issues.tsv` 的登记键从文件名改为构建名（`m8ab-base` / `m8ab-v2`），
  否则 `check-doctor` §5d 把已审计的 `uts_dup` 例外判成 FAIL；改后 `scripts/vk-identity.py` 重生成身份表。
- `scripts/check-doctor.sh`：**FAIL=0 / WARN=3**（WARN 为账本例外汇总、无版本号的 `boot-elden.img`、四份报告待挂指针）。
