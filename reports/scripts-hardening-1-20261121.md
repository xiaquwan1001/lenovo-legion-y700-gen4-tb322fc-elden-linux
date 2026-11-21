# scripts-hardening-1-20261121.md — 脚本整改批 1（7 个 DANGEROUS）落地记录

输入：`reports/scripts-audit-20261122.md`（§3/§5 批 1）+ `out/audit/scripts-audit-20261122.tsv`（kind=DANGEROUS 共 7 行）。
原则：**最小 fail-closed 门**——拿错设备/拿错表/无备份时拒绝执行；默认 dry-run；危险动作需 `--apply`/`--force`/显式 `SN=`；风格对齐 `scripts/linux-gpt-apply.sh`（写前对账 + 写后读回）与 `scripts/lib-device-lock.sh`（SN 口径）。
**本轮未对任何设备执行脚本；全部为静态验证 + 合成 GPT 夹具 dry-run。未跑 git commit/push（改动被并行会话的提交 3e234cbb / d5f67e39 收编，见 §8）。**

## 0. 七项结论（数字先行）

| # | 文件 | 危险点（行号实测） | 门 | 静态验证 |
|---|---|---|---|---|
| 1 | `scripts/ath12k-load.sh` | :36 写设备路径进 `driver/bind`（bind 只吃设备名，`ath12k-retry.sh:50-51`）+ `2>/dev/null` 吞错 ⇒ 被调用必静默失效 | RETIRED 头 + `ATH12K_LOAD_ALLOW=1` 才能跑（rc=2）；移出 `packaging/elden-userland/MANIFEST.tsv:40` 与 `rootfs/build-rootfs.sh:73` 拷贝名单 | `bash -n` OK；直跑 rc=2 打印退役原因 |
| 2 | `scripts/dev-super-relabel.sh` | :7 硬编码 `PART=/dev/sda10`（sda 号随启动盘序不稳） | PARTLABEL=super 运行时解析 + 分区名复核；`--apply` 必须显式 `SN=` | `bash -n` OK；宿主 dry-run rc=1（找不到 super，fail-closed 生效） |
| 3 | `scripts/dev-userdata-relabel.sh` | :8 硬编码 `PART=/dev/sda16` | PARTLABEL=userdata **且**类型 GUID 1B81E7E6… 解析 + 名字复核；`--apply` 必须显式 `SN=` | 同上 rc=1 |
| 4 | `scripts/f2fs-migrate.sh` | :250,259 整盘 dd 写 GPT；写槽无写前基线 | apply 级阶段（shrink/writeslot）`need_yes` 加 `SN=?` 硬门；writeslot 写前 `fastboot fetch boot_b` 基线（shrink 原有双表 dump 保留） | `bash -n` OK；`shrink --yes` 无 SN 时 FATAL 拒跑 |
| 5 | `scripts/gpt-restore-tb322fc.py` | usage 内嵌 `dd of=/dev/block/sda`（删 linux 分区）；无表指纹校验 ⇒ 拿错表 = 抹 Linux 根 | `--expect-fingerprint '<main_sha>,<backup_sha>'` **必填**，与实算 sha256 比对，不符/缺失一律 rc≠0 且不出镜像；dd 指引补「写后读回 sha256」两行 | 合成夹具三连测：缺指纹 rc=1 / 错指纹 rc=1 / 对指纹 rc=0 出件 |
| 6 | `scripts/gpt-slot-flip-active.py` | 只改属性位；GUID 侧 ≠ ACTIVE 侧时补 ACTIVE 也救不回来，写错槽 = 引导指向错槽 | 写前 `ValidateSlotGuids` 判据（`PartitionTableUpdate.c:1568`）：`boot_<slot>` 与 `abl_<slot>` type GUID **必须不同**，相同 rc=3 并指向 `scripts/gpt-slot-swap-guids.py`；新增 `--apply`（默认 dry-run 不落盘） | 夹具：半完成表 rc=3 拒绝；合法表 dry-run 不落盘；`--apply` 出件；swap→flip 链路闭环 |
| 7 | `scripts/n5b-vk64-death-rate.sh` | :131/:167/:177 发已停用 `reboot2 bootloader`（TASKS §4 + #701）+ sysrq 逃生梯 | 新增 `REBOOT_FB()` = `sync; systemctl reboot bootloader`（`to-fastboot.sh:60` 口径）；软路径 30/90 s 未进 fastboot 即停手要求物理键；删 sysrq 梯 | `bash -n` OK；`grep -n 'reboot2\|sysrq'` 仅余注释 0 实代码 |

## 1. `ath12k-load.sh`（退役，最重的一处静默失效）

- 危险点：`echo "$DEV" > "$DRV/bind"`（设备路径 vs 设备名）+ 全仓 0 调用点（`rg -n ath12k-load` 现查：仅 scripts/README.md、versions/scripts-inventory.tsv、打包副本与历史报告）。装机面：`packaging/elden-userland/MANIFEST.tsv:40`（已删）+ `rootfs/build-rootfs.sh:73`（已从 for 列表移除）。
- 改法：文件头 RETIRED 块 + fail-closed（默认 exit 2）；强行调试需 `ATH12K_LOAD_ALLOW=1`。
- 未动：`packaging/elden-userland/files/usr/local/sbin/ath12k-load.sh`（打包副本保留，MANIFEST 行已删 ⇒ verify.sh A 项只查 MANIFEST→files 方向，不会因此 FAIL；真源=ath12k-retry.sh）。`sync-from-device.sh:24` 的同步列表按审计口径未动（只影响 device→files 拉取）。
- 验证：`bash -n` OK；`sh scripts/ath12k-load.sh` → `ath12k-load: RETIRED —— bind 写设备路径必静默失效…` rc=2。
- 回退：`git revert` 对应 hunk（或恢复 MANIFEST.tsv:40 + build-rootfs.sh:73 + 删 RETIRED 块）。

## 2/3. `dev-super-relabel.sh` / `dev-userdata-relabel.sh`（设备侧）

- 危险点：硬编码 `PART=/dev/sda10`/`/dev/sda16`——设备等价原则要求运行时读实际 GPT；`--apply` 改类型码（可逆）但第 4/5 步 mkfs 不可逆。
- 改法（两文件同构）：
  - PART 缺省时从根盘运行时解析：super 按 `PARTLABEL=super`；userdata 按「PARTLABEL=userdata 且 PARTTYPE 前缀 1B81E7E6（AOSP user data）」；找不到 ⇒ FAIL rc=1。
  - 找到后仍复核分区名（`sgdisk -i` name 必须等于目标名），解析错位拒绝盲改。
  - `--apply` 前置：`SN=<序列号>` 必须显式传入，否则 FAIL rc=1；dry-run 打印解析到的 `PNUM/DISK`。
  - GPT 备份文件名由 `gpt-sda-*` 改为 `gpt-super-*`/`gpt-userdata-*`（不再写死 sda）。
- 验证（宿主，无目标分区 ⇒ 应 fail-closed）：
  ```
  $ sh scripts/dev-super-relabel.sh
  FAIL: /dev/nvme0n1 上没有 PARTLABEL=super 的分区 —— 拿错设备/已重命名，拒绝继续   (rc=1)
  $ sh scripts/dev-userdata-relabel.sh
  FAIL: /dev/nvme0n1 上没有（PARTLABEL=userdata 且 Android user data 类型 GUID）的分区 …  (rc=1)
  $ bash -n 两个文件 OK
  ```
- 回退：git revert；dry-run 默认行为未变，设备侧可随时覆盖验证。

## 4. `f2fs-migrate.sh`

- 危险点：`:250`（主表 dd seek=0）`:259`（备份表 dd）整盘写；`shrink` 原有写前双表 dump（say "0."，实测仍在，保留）；`writeslot` 写槽前无基线。
- 改法：
  - `need_yes()` 加第三门：apply 级阶段必须 `SN=<序列号>`（对齐 `linux-gpt-apply.sh` 的 `SN=${SN:-HA2EXB0E}` 显式化口径）；命中即 echo 目标 SN。
  - `writeslot` 第 2 步加写前 `fastboot fetch boot_b → $WORK/boot_b_before.bin` 基线（fetch 不可用则 WARN 继续，不阻塞既有流程）。
  - 顺带把「先 reboot2 bootloader」提示改为指向 `scripts/to-fastboot.sh`（#701）。
- 验证：`bash -n` OK；`bash scripts/f2fs-migrate.sh shrink --yes`（无 SN）→ `FATAL: shrink 是 apply 级阶段，必须显式 SN=<平板序列号> …`。
- 回退：git revert；`--yes`/SN 双门只收紧不放松，原阶段结构未动。

## 5. `gpt-restore-tb322fc.py`（本轮最高优先）

- 危险点：产物 = 设备侧 `dd … of=/dev/block/sda`（恢复 userdata、**删 linux 分区**）；build 对输入表无任何来源校验，拿错 dump = 抹 Linux 根。
- 改法：
  - 新增 `--expect-fingerprint '<main_sha256>,<backup_sha256>'`，**build 必填**：缺失 ⇒ 打印 `sha256sum <main> <backup>` 查值方法后退出；不符 ⇒ 打印实算/期望四行后退出（rc=1），不产出任何镜像。
  - 通过后才进入原 CRC/覆盖检查链（原逻辑一行未动）。
  - 头部 dd 指引补写后读回：`dd if=/dev/block/sda bs=4096 count=6 | sha256sum`（及备表对应行），对齐 linux-gpt-apply.sh 口径。
- 验证（合成 GPT 夹具 /tmp/gptfix，4 KiB 扇区、userdata+linux 两分区、双表 CRC 自洽）：
  ```
  == gate1: 缺 --expect-fingerprint ==
  FAIL: 缺 --expect-fingerprint。先算指纹再跑：…    rc=1
  == gate2: 错指纹 ==
  FAIL: 表指纹不符 —— 拿错表/表已变，拒绝生成恢复镜像   rc=1
  == gate3: 对指纹 ==
  [fingerprint] main=213c70d2ae981993… backup=ada75da7b4118a9c… 与 --expect-fingerprint 一致
  wrote …_main0.bin (12288 B), …_backup0.bin (20480 B); self-check OK   rc=0
  $ python3 -m py_compile scripts/gpt-restore-tb322fc.py   OK
  ```
- 回退：git revert；`--expect-fingerprint` 不传时旧行为=拒绝（fail-closed 方向，无回退风险）。

## 6. `gpt-slot-flip-active.py`（含 swap-guids 链路）

- 危险点：只动属性字节 6；若「GUID 侧 ≠ ACTIVE 侧」（2026-11-20 实测半完成态），补 ACTIVE 救不回且引导指向错槽。
- 改法：
  - 写前新增 `validate_slot_guids()`：读主表 entries 的 type GUID，`boot_<slot>` 与 `abl_<slot>` **相同**（= ABL `ValidateSlotGuids`，`PartitionTableUpdate.c:1568` 必拒）⇒ `sys.exit(3)`，stderr 指向 `scripts/gpt-slot-swap-guids.py --to <slot>`。
  - 新增 `--apply`：默认 dry-run（照常打印 byte6 改动 + CRC 自检，不落盘）；`--apply` 才写 `<out-prefix>_main.bin/_backup.bin`；文案统一指向 `linux-gpt-apply.sh` 做写盘+读回。
- 验证（合成 lun4 夹具：主表头@4096/entries@8192、备表 entries@0/头@16384、96 项）：
  ```
  == 半完成表（boot_b == abl_b == 77036cd4 占位）==
  拒绝：boot_b 与 abl_b 的 type GUID 相同（77036cd4-03d5…）… 正确工具：scripts/gpt-slot-swap-guids.py …  rc=3
  == 合法表 dry-run ==  打印 4 处 byte6 改动 + CRC ok；不产生输出文件（fail-closed ok）
  == 合法表 --apply ==  wrote flipg_main.bin (24576 B) / flipg_backup.bin (20480 B)  rc=0
  == 链路闭环 ==  swap-guids --to b（after: boot_b=20117f86 abl_b=bd6928a1，相同=False）→ 对其产物再跑 flip：guid-check 通过，--apply 出件  rc=0
  $ python3 -m py_compile OK；--help 显示 --apply
  ```
- 回退：git revert；`validate_slot_guids` 只在两 GUID 相同（必然被 ABL 拒）时拦截，不拦合法路径。

## 7. `n5b-vk64-death-rate.sh`

- 危险点：`:131/:167/:177` 三处 `SSH 'reboot2 bootloader'`（TASKS §4 停用令；#701 实测 Linux→fastboot 软路径全灭，命中只会普通重启或粘坏态）；`force_reboot_vk64` 的 SysRq-b 逃生梯在软路径已死的前提下是盲梯。
- 改法：新增 `REBOOT_FB()` = `sync; systemctl reboot bootloader`（`scripts/to-fastboot.sh:60` 同款）；三处全部替换；`force_reboot_vk64` 删 sysrq 梯——软路径 30 s 未进 fastboot 即 return 1 停手、提示人工物理键；`boot_vk64` 同口径（90 s 窗口保留）。#368 uptime≥60 s 门保留。
- 验证：`bash -n` OK；`grep -n 'reboot2\|sysrq' scripts/n5b-vk64-death-rate.sh` 仅 3 处**注释**（#60/#62/#163），实代码 0 命中（判据达成）。
- 回退：git revert；软路径失败原逻辑也 return 1，行为只更保守。

## 8. 边界与账目

- **未改的 DANGEROUS：0 个**（TSV 的 7 个 DANGEROUS 全部在本批处理）。批 2 = BROKEN 组（`arm-console-run.sh`、`arm-window-hunt.sh` 等，本批未动）；批 3 = STALE 头注/归档（本批未动）。
- **git 账目异常披露**：本轮**未执行**任何 git commit/push，但工作树改动在 17:42 前后被并行会话的提交收编——`3e234cbb`（含 ath12k-load/MANIFEST/build-rootfs）与 `d5f67e39`（含 f2fs-migrate/n5b/gpt-slot-flip）。已逐一核对 `git show HEAD:<file>`：7/7 个文件的本批改动全部在 HEAD，MANIFEST 行已删、build-rootfs 列表已改，无丢失。两个 commit message 与本批无关（IME 主题），如需账目干净可由提交者拆分或补一条 chore 说明。
- 夹具残留：`/tmp/gptfix/`（合成 GPT，仅本机 /tmp，不进仓）。
- 本轮零设备接触：未跑 adb/fastboot/ssh/qdl；`ath12k-load` 直跑与 `f2fs-migrate shrink --yes` 的 FATAL 均为门本身拒绝，无设备副作用。
