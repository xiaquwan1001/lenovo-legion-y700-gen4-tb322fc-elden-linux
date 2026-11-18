# R2 — fastboot / A/B 槽位 / GPT 槽属性 板块静态审查（2026-11-18）

- 性质：**只读静态审查**。全程未执行任何 `fastboot`/`adb`/`ssh`/`scp`/`qdl`/`edl.py`/9008 命令，
  未改仓内既有文件；唯一新增 = 本报告 + `/tmp/script-audit-fastboot.patch`。
- 范围（任务书主件；`scripts/cycle.sh` **已不存在**，以 `kexec-bs-cycle.sh` + `iterate.sh` 顶替审查）：
  `to-fastboot.sh` `lib-fastboot.sh` `lib-device-lock.sh` `device-lock.sh` `slot-switch.sh` `slot-attr.py`
  `fix-ab-mark-successful.sh` `uefi-a-slot-prepare.sh` `flash-b.sh` `flash-recovery.sh` `sign-boot-b.sh`
  `slotboot-run.sh` `trial.sh` `eldroid-bootctl` `uefi-flashed-trial.sh` `uefi-boot-trial.sh` `kexec-boot.sh`
  ＋相邻的 `kexec-bs-cycle.sh` `iterate.sh` `f2fs-migrate.sh`（writeslot）`linux-gpt-apply.sh`
- 交叉核对过的既有结论：`PITFALLS/sessions/{286,294,305,190}`、`.pi/skills/qbootctl-slot-management/`、
  `reports/bl-history-and-playbook.md`、`reports/bl-stuck-20261117-device-window.md`、
  `reports/bl-stuck-20261118-forensics.md`、`TASKS/sessions/2026-11-18-安卓最小线刷包-*.md`、
  `reports/android-min-avb-facts-20261118.md`、`.pi/plans/2026-10-07-造轮子审计.md`（引用处）。

## 0. 结论（先数字）

| 等级 | 条数 | 一句话 |
|---|---|---|
| **P0**（写完即留下「下一次注定失败」状态 / GPT 没核对就写 / 静默成功） | **7** | 全部集中在「槽属性生命周期无人负责」与「a 槽线零门禁」两处 |
| **P1**（能致挂死、假恢复、假判读、无回退） | **14** | 裸 fastboot / 管道 / 无 -k / 无尺寸核对 / 备份不全 |
| **P2**（文档漂移、口径错误、边界粗糙） | **11** | 含一条**任务书与脚本都在引用的错号**（#569 应为 #371） |

**最重的三条（回答「上一轮 3 发实验全废」）**：

1. **没有任何脚本对 `boot_a` 的失败标志负责**。写 `boot_a` 的入口只有一个
   （`uefi-flashed-trial.sh`），它 `set_active a`（`uefi-flashed-trial.sh:224-225`）后**不回读**
   `slot-unbootable:a`，落地成功后**不 `mark-successful a`**（同文件 233-269 全程无一次 succ 写入）；
   `trial.sh` 的健康门**只读 `boot_b`**（`trial.sh:65`）。⇒ 每发实验 ABL 扣 1 retry，
   永不置 succ ⇒ 7 发内必然 `UNBOOTABLE`。设备现态 `boot_a byte6=0xf7`（bit7+succ+retry6）
   就是这条链的产物（`INDEX.md` §0 2026-11-18 条目、`TASKS/sessions/2026-11-18-…md`）。
2. **恢复工具本身也清不掉 UNBOOTABLE**：`eldroid-bootctl:190-193` 的 `slot set-active` 只写
   `--active --retry 7`，**不带 `--no-unbootable`**；而 `fastboot --set-active` 走 ABL 自己的实现、
   **会**清 bit7（`reports/bl-stuck-20261117-device-window.md:35` 实测 `unbootable=yes/retry=0 →
   --set-active=b 后 no/7`）。⇒ 「切一下槽」在两个工具里语义不同，本地工具那条是**假恢复**。
3. **`slot-attr.py` 会静默成功**：主备两表都找不到 `boot_<slot>` 时（LUN 选错、分区表不是这块、
   名字拼错），`patch_slot` 打印 `written + CRCs fixed` 并 **rc=0**（`slot-attr.py:212-228`）。
   恢复脚本链里「命令成功但一个字节没改」正是最贵的一类失败。

## 1. A 类（失败标志全链路）——谁写、谁置、谁补、谁清、谁回读

### 1.1 全链路表（实测行号）

| 环节 | `boot_b` 线（日常 Linux） | `boot_a` 线（UEFI/flashed/安卓试装） |
|---|---|---|
| 谁写分区 | `flash-b.sh:42-48`（dd，Linux 内）、`slotboot-run.sh:16-21`、`to-fastboot.sh --flash`、`f2fs-migrate.sh:324`（fastboot flash） | `uefi-flashed-trial.sh:219`（`fbx flash boot_a`）、EDL/qdl 手工 + `linux-gpt-apply.sh` |
| 谁切槽 | `slot-switch.sh:130`（`fastboot --set-active`）、`uefi-ddr-trial.sh:44,55` | `uefi-flashed-trial.sh:225`、`uefi-a-slot-prepare.sh:112`（回滚提示） |
| 谁置 succ | `fix-ab-mark-successful.sh:36`（开机服务，**无槽位参数**）、`slot-switch.sh:139`（`qbootctl -m b`，`\|\| true`）、`trial.sh:60`（仅 `--fix`） | **无**（全仓 grep：a 槽 mark-successful 只出现在本报告建议里） |
| 谁补 retry | `slot-attr.py mark-successful`（retry=7）、`eldroid-bootctl slot set-active`（retry=7） | 仅 `fastboot --set-active` 隐式补（ABL 行为，本项目未验证 a 槽分支） |
| 谁清 UNBOOTABLE | `slot-attr.py mark-successful`（`unbootable=False`）✅ / `eldroid-bootctl slot set-active` ❌（不写该位） | **无通道**：a 槽从不会被执行 `mark-successful a` |
| 谁**写完回读** | `flash-b.sh:47-51`（只回读**内容** sha，不回读**属性**） | `uefi-flashed-trial.sh:225` 只存命令输出，无 `getvar slot-*` |
| 实验前 show 并进日志 | `trial.sh gate`（只读 b）✅；`flash-b.sh` ❌；`slotboot-run.sh` ❌ | `uefi-flashed-trial.sh:118-132` pre 快照 ✅（但**无判定**）；`trial.sh gate` ❌ 未调用 |

⇒ **「哪个脚本写完就走人」的准确答案**：`uefi-flashed-trial.sh`（写 boot_a + 切槽 + 重启，全程
不回读属性、不置 succ）、`flash-b.sh`（写 boot_b + 重启，无属性基线、无 succ）、
`slotboot-run.sh`（写 boot_b + 重启，无门无 mark）、`kexec-bs-cycle.sh`（反复 `fastboot boot`，
无属性回读）。四个都是「下一次注定失败」的制造器。

### 1.2 misc BCB / pstore / logfs 的陈旧性

- **misc BCB**：全仓**没有任何脚本**读写 `/dev/disk/by-partlabel/misc`（`grep` 结果为空）。
  现在的「BCB 清空」是 11-17 人工做的（`reports/bl-stuck-20261118-forensics.md` §2.3：
  前 7 字节 `ffbm-00` → 全 0，且该状态一直保留）。⇒ **无幂等清理/无写前读**，
  一旦走回 `misc` BCB 路径（`to-fastboot.sh:4-5` 记录过 `--fastboot` 方案），两个入口会互相打架。
- **logfs 假判读**：`uefi-flashed-trial.sh:134-147` 与 `uefi-boot-trial.sh:262` 取 logfs，
  判据只有「字节数 = 8 MiB」（#587 的短读修正）。**没有「本次是否新增 ABL 段」的判据**——
  `reports/bl-stuck-20261118-forensics.md` §2.3 已经证明 logfs 会**逐字节不变**（sha 相同）而设备
  照样失败 ⇒ 现有快照只能证明「读全了」，不能证明「是本发的记录」。
- **pstore**：`/sys/fs/pstore` 本机长期为空（PITFALLS #650 残留未解释段），脚本没有一处判「pstore 空 =
  panic 未落盘」与「pstore 空 = 没 panic」的区别。

### 1.3 「留在 9008/fastboot 却 return 0」

| 脚本 | 行 | 出口状态 | rc |
|---|---|---|---|
| `uefi-flashed-trial.sh` | 227-231 | `--no-reboot`：设备停 fastboot，`active=a`，boot_a 已换件 | **0** |
| `uefi-a-slot-prepare.sh` | 104-105 | dtbo_a 已改；`STATUS=READY` 后设备在 Linux（OK）；`VERIFY_FAIL` 出口 | 9 ✅ |
| `uefi-ddr-trial.sh` | 41-59 | HANDOFF 后回 Linux；但**开始时把 slot a 标 unbootable 的前置从不复位** | 0 |
| `slotboot-run.sh` | 30-47 | 采样 150 s 后无论设备在哪都结束 | 0 |
| `to-fastboot.sh --flash` | 54-66 | 主动停在 fastboot（设计如此），但**不打印槽属性** | 0 |

## 2. B 类（GPT 分区核对）

| 检查项 | `slot-attr.py` | `flash-b.sh` | `uefi-flashed-trial.sh` | `slotboot-run.sh` | `flash-recovery.sh` | `linux-gpt-apply.sh` |
|---|---|---|---|---|---|---|
| 分区存在 | 靠 `find()`，**找不到不报错**（P0-6） | 靠 dd 失败 | ❌ | 靠 dd 失败 | ✅ 读 `blockdev` | ✅ 文件尺寸硬校验 |
| LUN 归属 | 默认 `/dev/sde`，**不校验是 LUN4** | by-partlabel ✅ | by-partlabel ✅ | by-partlabel ✅ | by-partlabel ✅ | `--lun` 显式 ✅ |
| 4096 vs 512 | `SECTOR_DEFAULT=4096` ✅（头注释已警告） | n/a（按名） | n/a | n/a | n/a | ✅ 硬编码 4096 |
| 尺寸 ≥ 文件 | n/a | **❌ 无** | **❌ 无** | ❌ 无 | ✅ 但要求**严格相等**（过严） | n/a |
| 主表+备表都写 | ✅（但**先主后备**，断电窗口不利） | n/a | n/a | n/a | n/a | ✅ 单会话写两段 |
| CRC 重算 | ✅ | n/a | n/a | n/a | n/a | ✅（输入表先验 CRC+互指） |
| 写后读回 | **❌（本次审查前）** | 内容 sha ✅ | ❌ | 内容 sha ✅ | 内容 sha（截断取整，见 P1-14） | ✅ 逐字节 |
| 覆盖冲突 | 只改属性字节，不碰 LBA ✅ | 只写 boot_b ✅ | 只写 `$PART` ✅ | boot_b ✅ | recovery_* ✅ | 全表覆盖（有 dry-run ✅） |

补充事实：`slot-attr.py` 头注释（第 20-22 行）说 `boot_a/boot_b` 在 `/dev/sde`(LUN4)，与
`reports/bl-stuck-20261118-forensics.md` §2.1（LUN4 = 78 分区、22 个属性字节偏离 stock）一致；
但**没有任何脚本验证「用户给的 --device 就是 LUN4」**，而 LUN0 上也有一份 GPT（18 分区）。
`slot-attr.py` 若被指向 LUN0 的整表 dump，只会得到「not found」→ 旧代码静默 rc=0（P0-6）。

## 3. C/D/E/F

- **C 写后校验**：`flash-b.sh:47-51` / `slotboot-run.sh:20-27` / `flash-recovery.sh:45-51` 都是
  「主机侧再 hash 读回」，属单工具结论；`PITFALLS #669` 要求**设备端摘要**（`qdl sha256`）当第二把尺子，
  板内 dd 回读只算同一把尺子（同一 UFS 栈、同一内核）。三处都**只看退出码之外还看了 sha**（好），
  但都缺第二工具。`uefi-flashed-trial.sh:219-222` 完全**没有内容读回**（只认 `rc=0`）。
- **D 超时/串行**：
  - `lib-fastboot.sh` 是全仓唯一合规实现（`fbx` = `timeout -k 2`+落文件+禁管道），但**只有 2 个脚本用**
    （`uefi-a-slot-prepare.sh:39`、`uefi-flashed-trial.sh:60`）。
  - 不合规：`trial.sh:213`（无 `-k`、进管道）、`uefi-ddr-trial.sh:37`（无 `-k`、进管道）、
    `kexec-bs-cycle.sh:19`（无 `-k`、无 `-s`）、`slot-switch.sh:41`/`uefi-boot-trial.sh:66`（`timeout` 无 `-k`）。
  - **持锁率 8/15**（任务书主件逐个 grep `device_lock_acquire`）：有锁 = `to-fastboot.sh`
    `flash-b.sh` `kexec-boot.sh` `trial.sh`（仅 `run`）`uefi-a-slot-prepare.sh` `uefi-flashed-trial.sh`
    `uefi-boot-trial.sh` `slot-switch.sh`；**无锁** = `flash-recovery.sh`（写 recovery 分区）
    `slotboot-run.sh`（写 boot_b）`uefi-ddr-trial.sh`（反复 fastboot boot）`kexec-bs-cycle.sh`（同上）
    ＋相邻的 `f2fs-migrate.sh writeslot`（fastboot flash boot_b）⇒ 这五处可与别的 agent 交错写同一分区。
  - ssh+fastboot 同命令：`uefi-ddr-trial.sh:35`（先 ssh 再 sleep 再单独 fastboot，合规）;
    `kexec-bs-cycle.sh:15-19` 同一脚本内交替但不同命令（合规）。**未发现同一命令混用**（#584 主因已消除）。
- **E 回退**：`uefi-a-slot-prepare.sh:59-69` 备份 dtbo_a 并 sha 复核 ✅，但回滚命令用通配
  `backup/dtbo_a-pre-uefi-*.img`（`:110`，多件时选错）；`uefi-flashed-trial.sh:272` 回滚提示缺 `-s $SER`；
  `eldroid-bootctl` 的「写前备份」只 dump 前 34 扇区（P1-9）⇒ 回滚只恢复主表。
  **没有任何脚本备份 misc/logfs/pstore**。
- **F 幂等/重入**：`slot-attr.py` 幂等（重复 mark-successful 结果相同）✅；`uefi-a-slot-prepare.sh` 幂等
  （`--check`+sha 比较）✅；`trial.sh record` 每次新文件 ✅。**不幂等**：`uefi-flashed-trial.sh` 每跑一次
  就扣一次 retry（A 类根因）；`flash-b.sh --reboot` 同理；`fix-ab-mark-successful.sh:28` 覆盖
  `/etc/init.d/qbootctl`（已先 `cp -a` 备份 ✅）。

## 4. 逐条缺陷

### P0（7）

| # | file:line | 触发条件 | 后果 | 修法（一句） |
|---|---|---|---|---|
| P0-1 | `scripts/trial.sh:65`（`device_gate`） | 任何 `--a-slot` 实验 | 门只读 `boot_b`；a 槽 UNBOOTABLE/retry 见底时门仍 `GATE=OK`，实验照样开跑，本发注定无判据 | 给 gate 加 `--slot a\|b`，`run --a-slot` 自动传 a（补丁已含） |
| P0-2 | `scripts/trial.sh:209,213` | `--deploy fastboot-boot` | 裸 `fastboot devices \| grep -q` + `fastboot boot … \| tail -3`：①多发到总线上别的设备（#371 事故形态）②SIGPIPE 打断 bulk 通道（#584，之后只能物理 POR） | 改走 `lib-fastboot.sh`：显式 SER + `fborphans` + `fbprobe` + `fbx`（补丁已含） |
| P0-3 | `scripts/uefi-flashed-trial.sh:224-225` | 每次 a 槽实验 | `set_active a` 后不 `getvar slot-unbootable:a / slot-retry-count:a`；ABL 若没清 bit7，本发必然「ABL 拒绝尝试」却被记成镜像判据 | 写后 `getvar` 回读并落 `setactive.txt`，`unbootable: yes` 直接 FATAL（补丁已含） |
| P0-4 | `scripts/uefi-flashed-trial.sh:233-269` | 落地成功后 | 从不 `mark-successful a` ⇒ 每发 −1 retry，7 发内 `UNBOOTABLE`（本轮 3 发全废的直接机制） | 落地即 `slot-attr.py mark-successful a`（可 `MARK_OK=0` 关）+ 落 post 属性（补丁已含） |
| P0-5 | `scripts/eldroid-bootctl:190-193` | 设备停 fastboot、用本地工具「切槽恢复」 | `set-active` 不写 `--no-unbootable` ⇒ 属性显示 active/retry 已改，bit7 仍在，ABL 继续拒绝；与 `fastboot --set-active` 语义相反 | 加 `--no-unbootable`，写后回读，`unbootable=1` 返回非 0（补丁已含） |
| P0-6 | `scripts/slot-attr.py:212-228` | `--device` 指向 LUN0/错表，或分区名不在该表 | 两表都 not found 时仍打印 `written + CRCs fixed`、rc=0 ⇒ 恢复流程「成功」但一字节没改 | 两表皆无 → `SystemExit`；只剩一表 → 也拒绝（补丁已含） |
| P0-7 | `scripts/uefi-ddr-trial.sh:8-10,15-19,58` | 每次跑 DDR 循环（前置=把 slot a 标 unbootable） | 脚本收尾不复位 a 槽的 UNBOOTABLE；且全程裸 `fastboot`（无 SER/无锁）⇒ 下一轮「起 Android」的实验被这一位挡住，且可能发到别的设备 | 收尾 `mark-successful b` + 打印两槽属性；SER 必填 + 设备锁 + `fbx`（补丁已含） |

### P1（14）

| # | file:line | 触发条件 | 后果 | 修法（一句） |
|---|---|---|---|---|
| P1-1 | `scripts/to-fastboot.sh:63-64` | `iterate.sh --boot` / `iterate.sh ram`（日常入口） | 裸 `fastboot boot`；且 #650 的缓解（进 fastboot 先 `reboot-bootloader`）**只写在注释**，代码没做 ⇒ 暖复位后直接灌 RAM 镜像，黑屏/崩坏可复发 | 显式 SER + `fbprobe` + `fbx reboot-bootloader` 后再 `fbx boot`（补丁已含） |
| P1-2 | 全仓（`lib-fastboot.sh` 仅 2 处引用） | 任何写盘/启动 | #658 的通道门（孤儿 fastboot + 5 s `getvar`）只存在于只读审计 `linux-state-audit.sh:112`，写路径一个都没有 | 在 `lib-fastboot.sh` 提供 `fborphans`/`fbprobe`，所有写路径首行调用（补丁已加原语 + 4 处接入） |
| P1-3 | `scripts/flash-b.sh:41-52,54-60` | 写 boot_b / `--reboot` | ①不核 `blockdev --getsize64 boot_b`（dd 短写 rc=0）②重启前不置 succ、不读属性 ⇒ 写+重启就扣 retry | 加尺寸核对 + 写前 show + 重启前 `mark-successful b`（补丁已含） |
| P1-4 | `scripts/slotboot-run.sh:14-30` | 任何一次槽位启动实验 | 写 boot_b 后直接 reboot：无门、无 show、无 mark、无设备锁 | 同 P1-3（未进补丁，建议整体并入 `trial.sh`） |
| P1-5 | `scripts/kexec-bs-cycle.sh:17-19` | kexec 二分（反复 `fastboot boot`） | 裸 fastboot、无 `-s`、无 `-k`、无锁、无槽属性回读；失败发会被 ABL 标 `unbootable`（BL-03） | 换 `fbx`（SER+lock+`-k`），每轮前后 `getvar slot-*` 落日志 |
| P1-6 | `scripts/kexec-boot.sh:22,99` | `kexec -e` 后 | `$SSH` 无 `timeout`/`ServerAlive*`；`kexec -e` 后旧 TCP 半开 ⇒ 卡到 `tcp_retries2`（~15 min，正是 #584/#628 的形态） | SSH 加 `ServerAliveInterval=5 CountMax=2`，`kexec -e` 单发套 `timeout -k 2 30`（补丁已含） |
| P1-7 | `scripts/slot-switch.sh:130-134,139,41` | 切槽/切回 b | ①`--set-active` 后只**打印**属性，不判 `unbootable/succ` ②`qbootctl -m b \|\| true` 无读回、失败静默 ③`fb()` 的 `timeout` 无 `-k` | 属性断言（unbootable=yes → 失败退出）+ `mark-successful` 后回读 + `-k` |
| P1-8 | `scripts/slot-attr.py:112-114,184-189,225-226` | 写属性时断电/短写 | 先主后备（断电后只剩主表新、备表旧）；`os.write` 无短写循环；写后无读回 | 先备后主 + `_pwrite` 循环 + `_verify` 读回（补丁已含） |
| P1-9 | `scripts/eldroid-bootctl:171-177` | `slot set-active/mark-successful/set-retry` | 「写前备份 GPT」只 dump LBA0..33（主表区），**备表未备份** ⇒ 回滚后主备不一致（内核报 GPT mismatch 并退回备表解释） | 同时 dump 末 34 扇区（补丁已含） |
| P1-10 | `scripts/fix-ab-mark-successful.sh:36`（及 `:50`） | 开机自动 mark（`--fix` 同源） | `/usr/bin/qbootctl -m` **不带槽位**；cmdline 无 `androidboot.slot_suffix` 时 qbootctl 回退 slot a（技能 + `build-boot.sh:65-69` 明载）⇒ 给错的槽置成功，真槽继续扣 | 从 `/proc/cmdline` 解析 `slot_suffix`，缺省 `b`，显式传槽（补丁已含） |
| P1-11 | `scripts/uefi-a-slot-prepare.sh:93-105,110` | 写 dtbo_a 后设备起不来 | 读回校验依赖「重启进 Linux」；起不来就停在「dtbo_a 已改、无自动回滚、无 STATUS」；回滚命令用通配符可能选错件 | 进 fastboot 前先 `fastboot flash` 前备份到主机（已有）+ 失败路径打印**唯一**备份路径 + 加 `--rollback` 子命令 |
| P1-12 | `scripts/uefi-flashed-trial.sh:217-222` | `--part vbmeta_a` 等任意 a 槽分区 | flash 前不核分区存在/尺寸；分区名写错时 `fastboot flash` 的失败信息不足以定因，且会浪费一发 | 进 fastboot 前在 Linux 侧 `blockdev --getsize64 $PART` 存档并与 `$IMGSZ` 比较（补丁已含） |
| P1-13 | `scripts/uefi-flashed-trial.sh:227-231` | `--no-reboot` | `VERDICT=FLASHED_ONLY` 且 **exit 0**，设备留在 fastboot、`active=a`、boot_a 是新件 ⇒ 下一个人一键 `reboot` 就是一次注定失败的尝试 | 出口打印「设备停 fastboot、active=a、boot_a 已替换、恢复=…」并 `exit 0` 仅限显式确认（补丁已加提示） |
| P1-14 | `scripts/flash-recovery.sh:31-33,37,46` | 刷非 MiB 对齐镜像 | ①要求 `PSIZE == SIZE` 精确相等（小件被拒，本可 pad）②`scp` 无 timeout ③回读 `count=$((SIZE/1048576))` 向下取整 ⇒ 非对齐件必报**假 MISMATCH**；④无设备锁 | 允许 `SIZE <= PSIZE` 并 pad；`scp` 套 `timeout -k`；回读用 `count=$SIZE bs=1` 或 `head -c $SIZE`；取锁 |

### P2（11）

| # | file:line | 问题 | 修法 |
|---|---|---|---|
| P2-1 | `to-fastboot.sh:4-5,65`、`flash-b.sh:5`、`lib-wait.sh:6` | 引用**已不存在**的 `scripts/cycle.sh`（含「用 `cycle.sh --wait` 跟进」这样的操作指引） | 改成 `iterate.sh` / `slot-switch.sh status` |
| P2-2 | 任务书 & `uefi-flashed-trial.sh:22`、`uefi-boot-trial.sh:20` 注释 | 把「多设备总线必须显式 SER」记成 **#569**；PITFALLS 里 #569 是 ESP `Fat` 空指针崩（`PITFALLS/sessions/190`），多设备是 **#371**（`slot-switch.sh:29` 引用正确） | 统一改引 #371（#569 保留给 UEFI Fat 那条） |
| P2-3 | `uefi-flashed-trial.sh:272-273` | 回滚提示 `fastboot flash boot_a …` 缺 `-s $SER`，与全文纪律自相矛盾 | 补 `-s $SER` |
| P2-4 | `uefi-flashed-trial.sh:140-146`、`uefi-boot-trial.sh:262` | logfs 快照只验 8 MiB 长度，无「新增段」判据 ⇒ 陈旧 logfs 可造出假判读 | 记录 pre/post 的 `sha256` 与「段数」，post 未变即标 `logfs:no-new-record` |
| P2-5 | `eldroid-bootctl:238-240` | 无 `active=1` 的槽时静默回落 `b`（并无提示地写盘） | 无 active 时报错要求显式槽位 |
| P2-6 | `sign-boot-b.sh:16-19` | 先 `cp -f` 覆盖 `$OUT` 再跑 avbtool；输入 >96 MiB 时 avbtool 失败但 `$OUT` 已被覆盖成半件 | 先 `avbtool` 到临时件，成功后再 `mv` |
| P2-7 | `uefi-ddr-trial.sh:27` | `wait_fb` 用 `case "$d" in *fastboot*)` 匹配「设备列」而不是 SN ⇒ 多设备时把别人的设备当自己的 | 用 `fbdevices "$SER"`（补丁已改） |
| P2-8 | `slot-attr.py:198-206` | `show` 只遍历主表，不报主备是否一致、不报 header CRC 现状 ⇒ 「show 正常」不等于「两表都对」 | `show` 增加主备 `byte6` 对比与 `crc ok` 标记 |
| P2-9 | `trial.sh:219` | 等 SSH 写死 30×5 s，忽略 `--max-wait` 与慢启动机 ⇒ 冷起/RAM 变体常被判 `NOROUTE` | 用 `let MAXWAIT` 同源预算 |
| P2-10 | `trial.sh:220-224` | `NOROUTE` 分支只写 `README.txt`，不留槽属性/`getvar` 现场 ⇒ 判读缺一半 | 该分支也落 `slot-attr.py show` + fastboot `getvar all` |
| P2-11 | `flash-recovery.sh:37,45` | 远端固定 `/tmp/recovery.img`（并发/残留覆盖），失败路径不清理 | 用 `mktemp` + `trap` 清理 |

## 5. 建议补丁

- 路径：`/tmp/script-audit-fastboot.patch`（git diff 格式，`-p1`；已在仓内 `git apply --check` 通过）。
- 覆盖 10 个文件、+229/−39：`lib-fastboot.sh`（新增 `fborphans`/`fbprobe`）、`to-fastboot.sh`、
  `trial.sh`（gate 按槽 + fastboot 路径改走 fbx）、`uefi-flashed-trial.sh`（gate + 尺寸核对 + 属性回读
  + mark-successful + post 属性）、`eldroid-bootctl`（set-active 清 bit7 + 写后回读 + 主备表都备份）、
  `slot-attr.py`（not-found 失败 + 先备后主 + 短写循环 + 读回校验）、`fix-ab-mark-successful.sh`
  （显式槽位）、`flash-b.sh`（尺寸核对 + 属性基线 + 重启前置 succ）、`uefi-ddr-trial.sh`
  （SER/锁/fbx/收尾复位）、`kexec-boot.sh`（ssh 超时）。
- 应用与验证（**不要在有实验价值的设备状态下直接跑**）：

```bash
cd /home/xuqianhui/y700-elden
git apply --check /tmp/script-audit-fastboot.patch && git apply /tmp/script-audit-fastboot.patch
bash -n scripts/{to-fastboot,trial,flash-b,uefi-flashed-trial,uefi-ddr-trial,kexec-boot,lib-fastboot,fix-ab-mark-successful}.sh
python3 -m py_compile scripts/slot-attr.py scripts/eldroid-bootctl
```

- 离线自测（审查中已做，**未碰设备**）：用 64 MiB 合成 GPT（主表 LBA0..5 + 备表末 34 LBA，
  `boot_a=0xf7 / boot_b=0x32`）跑 `slot-attr.py`：

| 命令 | 结果 |
|---|---|
| `show` | `boot_a byte6=0xf7 retry=6 active=1 succ=1 unbootable=1`（与设备现态同形） |
| `mark-successful a` | `0xf7 → 0x7f` + `read-back verified (primary & backup)` |
| `set b --retry 0 --unbootable` | `0x32 → 0x82`，读回校验通过 |
| 抹掉两表的 `boot_a` 后 `set a --retry 7` | `rc=1`，`boot_a: 主备两表都没有该条目 —— 拒绝静默成功`（旧代码此处 rc=0） |

## 6. 本次审查未能覆盖 / 需上机才能定的

1. ABL 的 `fastboot --set-active <slot>` 是否**总会**清 bit7 并把 retry 补回 7 —— 现有证据是单次实测
   （`reports/bl-stuck-20261117-device-window.md:35`），没有对 a 槽的对照。
2. `qbootctl -m <slot>` 与 `slot-attr.py mark-successful` 在「内核分区重扫窗口」内的可见性差异
   （技能里记了瞬时报 `No slots found`），脚本目前一律 `sleep 1` 后读，未验证。
3. `misc` BCB 在 `fastboot reboot-bootloader` / `oem edl` 路径上是否会被重写（无读回工具脚本）。
4. 本报告全部结论来自静态阅读 + 离线合成镜像；**设备现处 fastboot + `boot_a` UNBOOTABLE**，
   按任务纪律一次未触。

收尾: R2 静态审查完成 —— P0 7 / P1 14 / P2 11，报告 + `/tmp/script-audit-fastboot.patch`（可 apply）落盘，设备零触碰。
