# 三十九、能力靠实测不靠 `--help`：`fastboot fetch` 不存在，以及同类的四类「记错」

> 2026-10-17 复核。起因：用户提示「fastboot 不存在 fetch 功能」，并要求**把所有同类记错的地方一起查掉**。
> 本节收录 **#290–#292**。

## #290 本机 ABL 不支持 `fastboot fetch`（写死结论，别再抄 help）

- **实测**（2026-10-17，fastboot 37.0.1，U2 `HA2EXB0E` bootloader 态）：
  ```
  $ fastboot fetch boot_b /tmp/x.img
  fastboot: error: Unable to get max-fetch-size. Device does not support fetch command.
  ```
  同一请求在 2026-10-06、2026-10-08 已两次证实（用户原话：**「带有 fetch 的一律是幻觉」**），本次是第三次。
- **为什么会记错**：`fastboot --help` 里**有** `fetch` 子命令，容易让人以为「客户端有 = 能力有」。
  真实约束在**设备端 bootloader**：必须实现 `getvar:max-fetch-size` 与 `fetch:` 命令。ABL 不实现。
- **正确备份手段（三选一，都不是 fetch）**：
  1. **官方线刷包解出**（最省事，`TB322FU_ZUXOS_*` 包内 boot/vbmeta 与 a/b 槽同源）；
  2. **设备侧 `dd if=/dev/disk/by-partlabel/<part> of=/tmp/x.img`**（booted Linux 或 rooted Android）后 `scp`/tar 取回；
  3. **EDL(9008) 读回**（唯一能给「已刷过且起不来」的槽做备份的手段）。
- **已清理的受害者**（全部改成上述三选一）：`INDEX.md` §4、`RUNBOOK-BRINGUP/README.md` §2.1、`PITFALLS` §0、
  `.pi/AGENT-OPS.md`（2 处）、`TASKS/README.md` 风险表、`scripts/build-locked-chain.sh` 注释。
- **判据**：文档里出现 `fastboot fetch` 即视为错误（`grep -rn "fastboot fetch" --include=*.md --include=*.sh .` 应为 0，历史会话档案除外）。

## #291 「客户端有子命令」≠「设备支持」：判断顺序要反过来

- 2026-10-17 还试图用 `fastboot reboot fastboot`（进 fastbootd）绕过 #290 ——**结果不可判定**：命令返回后设备仍报
  `is-userspace: no`（回到 bootloader 态），既不能证明支持、也不能证明不支持，**且执行到一半被中断时设备如何落地不可预期**。
- **纪律**：涉及引导态切换/写入的命令，先问「失败会落到哪个状态、还能不能回来」，再问「怎么写」。
  对**不可判定**的结果，只能记为「未证实」，**不得**在文档里写成能力存在。
- 反面教材：本次差点把 `fastboot fetch` 写进 P0 抢救方案（会产出 0 字节文件让人误以为已备份 —— 2026-10-15 已踩过一次，见
  `TASKS/sessions/2026-10-15-晚-p0模块树-相机栈-Q24四轮实测.md`）。

## #292 文档指向「已归档/已删除」的脚本：26 处悬空指针

- 机检：`*.md` 引用的 `scripts/*.{sh,py}` 共 **109** 条，其中 **26 条在本机不存在**。
- 实测根因**不是换机丢失**：它们在 `6265d32`（"清理+Q28方案A备料：归档 32 个一次性 Q24/Q28 脚本"）里**被有意归档**，
  `git log --all -- scripts/q24-kill.sh` 能看到归档前的历史。⇒ **是文档没跟着改**，不是资产丢了。
- 清单（26）：`q24-{kill,rebuild-arms,cseries-run,dev-trace-on,instrument-check,mech-run,pmic-cycle,pmic-dump,s123-run,build-h1-dtarm}.sh`、
  `q28-{ab-delay,boot-cycle,build-arm-lv64,build-daily-id,build-oldrep-pin,cold-run,cold-sample-loop,layout-ab,layout-experiment,layout-one,race-hunt,verdict,warm-vk117-loop}.sh`、
  `apply-out-of-tree.sh`、`envpass-provision.sh`、`sensor-send-termux.sh`。
- **处置纪律**：这些指针只出现在**历史会话档案**里时可以保留（它们是过程记录）；出现在**当前可执行配方**
  （`RUNBOOK`/`INDEX`/`TASKS` 的"下一步"）里则必须改成现存脚本或写明"已归档，需按报告重写"。
  本次只做清点，不做批量改写（避免把历史档案改成失真文本）。

## 一句话

**凡「命令/工具能做什么」的结论，必须有一条本机实测输出；`--help` 与记忆都不算证据。**
