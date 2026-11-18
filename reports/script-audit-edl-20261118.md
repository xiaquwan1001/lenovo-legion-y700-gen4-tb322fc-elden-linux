# 脚本功能审查 R1：EDL / qdl / GPT 板块（只读静态审查）

日期：2026-11-18 · 范围：`scripts/{linux-gpt-apply,linux-gpt-dump,esp-apply,gpt-dump,edl-peek,t2-stock-lun45,build-locked-chain}.sh`、
`scripts/{gpt-audit-tb322fc,gpt-restore-tb322fc,gpt-surgery-tb322fc,gpt-minimal-build,make-gpt-only-xml,android-rom-segassemble,android-super,android-lpdump}.py`、
外挂核对 `scripts/slot-attr.py`（用户点名 A/B 类，属 R2 主件，本轮因 `--image` 路径与本板块直接耦合而一并审）。

**纪律**：全程未执行 fastboot / adb / ssh / scp / qdl / edl.py，未改动仓内任何文件。
可执行的静态取证 = 用仓内已有 dump 与官方 259 包在 `/tmp` 跑 python 脚本（纯主机侧，不碰设备）。
建议补丁：`/tmp/script-audit-edl.patch`（12 文件，`git apply --check` 通过）。

---

## 0. 数字结论

| 严重度 | 条数 | 一句话 |
|---|---|---|
| **P0** | **5** | 会留下「下一次实验注定失败」状态，或会把在用分区数据写坏 |
| **P1** | **15** | 判据缺失 / 回退不可执行 / 设备状态与退出码不符 |
| **P2** | **11** | 假报警、临时件泄漏、跨机型硬编码、只读工具的解析边界 |
| 合计 | 31 | |

**根因第一梯队（必须同轮修）**：

1. **`qdl -R` 的语义被三个脚本写反了**。`~/edl/qdl/src/cli.c` 里 `-R` = `--skip-reset`，
   `qdl.c:884` 是「**默认**在跑完所有 op 后追加 reset」；`-R` 是**跳过**它。
   ⇒ `-R` 的作用是「让设备**留在** 9008」，不是「执行 reset」。
   `linux-gpt-apply.sh:22/113`、`linux-gpt-dump.sh:11`(注释)、`t2-stock-lun45.sh` 全部按反的语义写。
   这一条**直接就是 PITFALLS #674/#675 的成因**：`t2` 两发都没 `-R` ⇒ 第一发结束设备自己 reset ⇒
   第二发 `SAHARA: failed to read request`（`reports/bl-stuck-20261118-forensics.md:197` 实测）；
   `linux-gpt-dump.sh` 是同一形状（第 1 步无 `-R`、第 2 步有 `-R`）。
2. **三处「写盘目标 LBA 来自主机侧 dump、从不与设备现表核对」**（`esp-apply.sh` 最典型）。
3. **`slot-attr.py --image` 只改主表却打印「primary & backup」并 exit 0**（本轮实测复现），
   而它正是 `PITFALLS #308` 指定的「清 UNBOOTABLE」手段。

---

## 1. EDL 板块专项必查项（逐条给答案）

| 必查项 | 结论 |
|---|---|
| loader 选择与 secboot 门控（#486） | 5 个 EDL 脚本都硬编码 `~/下载/tb322fc/xbl_s_devprg_ns.melf`，**没有** loader 能力预检；`edl-peek.sh` **仍然会去试**已知必败的 `peek`（无拒绝门、无 timeout）。见 P1-③、P2-⑥ |
| qdl vs edl.py 分工（#669） | 写/读路径已统一 `~/edl/qdl/build/qdl`（好）；`edl.py` 只剩 `edl-peek.sh` 一处，属「只留 loader/peek」口径，但脚本本身应判死 |
| **一次 qdl 会话内多目标** | `linux-gpt-apply.sh`、`esp-apply.sh` 做到了（单条命令多 write/read，**正确**）；`linux-gpt-dump.sh`、`t2-stock-lun45.sh` **拆成两条** ⇒ P0-②/P0-① |
| 写前：分区存在 / LUN 归属 / 4096 单位 / 文件 ≤ 分区 | `esp-apply.sh` 只对**dump** 校验（不核对设备现表）、`linux-gpt-apply.sh` 完全靠调用方给对 LBA、`t2` 完全交给官方 xml（无几何断言）；`build-locked-chain.sh` 的 `--partition_size 100663296` 是常量、无核对 |
| 写后：读回比 sha / 设备端 sha256 | apply 两脚本有读回比 sha（**好**），但没有 `qdl sha256` 第二把尺子；`t2` **完全没有**任何读回；`build-locked-chain.sh` 只打印命令 |
| `--dry-run` 是否真 dry-run | `linux-gpt-apply`/`esp-apply` 默认 dry-run，实测逻辑上不写盘（**好**）；`slot-attr.py` 的 `--dry-run` 历史坑已修（本轮实测镜像字节未变，**确认安全**） |
| 覆盖冲突预计算 | **三个写路径都不做**。最现实的一例：`gpt-minimal-build` 出的新表里 `linux = 90504..123871226` 把老 `eldenesp`(123609088) 与 `linux17` 全包住；此时再用旧 dump 跑 `esp-apply` 就写到 linux 中段（P0-③） |

---

## 2. P0（5 条）

### P0-① `t2-stock-lun45.sh:30-36` —— 失败被 pipeline 吞掉，脚本自报 rc=0 继续刷下一段
- **触发**：`timeout ... "$Q" ... | tail -6 | tee -a "$LOG"` 之后 `say "step1 rc=$?"`。
  `$?` = 管道**最后一段**（`tee`）⇒ **恒为 0**；且全脚本无 `set -e`。
- **后果**：step1 失败也照样刷 step2（15 GiB），最后发 `reset` 并 poll、「=== T2 end ===」。
  这是 2026-11-17 19:37 那次事故的脚本化版本（`reports/bl-stuck-20261118-forensics.md:197`）：
  两发 qdl **都没 `-R`** ⇒ 第一发结束设备自行 reset ⇒ 第二发 `SAHARA: failed to read request`，
  而日志写的是 `step1 rc=0 / step2 rc=0`。
- **修法**：`-R` 上到每条 qdl（最后那发 reset 除外）+ 输出先落文件再取 `$?`，非 0 立即停。

### P0-② `linux-gpt-dump.sh:40` vs `:59` —— 两条 qdl 会话，第一条无 `-R`
- **触发**：`timeout ... "$QDL" -s ufs "$LOADER" read 0/0+6 ...`（第 40 行，**无** `-R`）。
- **后果**：qdl 在该会话末尾自动 reset ⇒ 设备离开 9008 ⇒ 第 59 行第二条命令失败。
  叠加 `set -euo pipefail` 与 `| grep -E 'read .* successfully|ERR' | tail -8`：
  **即使 qdl 成功**，只要 `grep` 没匹配到新格式输出，管道即返回 1 ⇒ 脚本在第 3 步（写 SHA256SUMS）
  之前中止，留下一半 `gpt<N>-backup.bin` 缺失的目录 —— 而这个目录正是 `linux-gpt-apply.sh`
  失败时被告知用来「回滚」的来源。
- **修法**：两条都加 `-R`（设备留在 EDL 供下一条用），末尾需要时显式 `qdl reset`；
  grep 过滤改成 tee 到日志再过滤。

### P0-③ `esp-apply.sh:87` + `:196-198` —— 写目标 LBA 只来自主机 dump，从不核对设备现表
- **触发**：`P_START/P_SECT` 从 `--gpt` 文件解析；写前只检查「文件 ≤ 分区（dump 里的大小）」。
  `--enter-edl`/`lsusb 9008` 之后直接 `write "$LUN/$P_START" "$IMG"`。
- **后果**：dump 与设备现表不一致时，64 MiB 镜像落到**任意**在用分区中段。
  具体可判定的场景：`gpt-minimal-build` 的新 LUN0 表里 `linux = 90504..123871226`
  覆盖了 `eldenesp` 的原位置 `123609088`（见 `scripts/gpt-minimal-build.py:46` 的 DROP 列表与
  本报告 §4 的实测计划输出）⇒ 用 11-17 的旧 dump 跑 `esp-apply` 会写坏 linux 分区中段，
  且脚本仍打印「OK 读回逐字节一致」（读回只证明「我写的和我读的一样」，不证明「写对地方」）。
- **修法**：写前**同一条 qdl 会话**读一次 live `LUN/0+6`（带 `-R`），解析后断言
  「分区存在 && first == dump 里的 first && 分区扇区数 ≥ 待写扇区」，不满足即拒写。

### P0-④ `slot-attr.py:121-129`、`:241-252` —— `--image` 只改主表却打印「primary & backup」，exit 0
- **触发**：`--image <文件>` 且文件不是整盘视图（典型：主表 24576 B + 备表 20480 B 拼成 45056 B）。
  `_hdr_off("backup") = size - sector` ⇒ 恰好落在拼接件的备表头上（**巧合能读**）；
  但备表条目地址取的是 `b_lba`（绝对 LBA，本机 LUN4 = 1048571）×4096 ⇒ 远超 EOF ⇒ `find()` 返回 `None`。
- **后果（本轮实测，见 §4 证据 A）**：只写了主表条目 + 主表头 CRC，备表**原封不动**，
  打印 `! boot_b not found in backup GPT` + `written + CRCs fixed (primary & backup)`，**rc=0**。
  主备不一致的 GPT：ABL 若读备表 ⇒ `boot_b` 仍是 `UNBOOTABLE=1/retry=1` ⇒
  **下一次实验注定失败且原因不可见**（正是 `PITFALLS #672/#308` 的那一类）。而 `#308` 正文
  明确把 `--image` 路径列为「清 UNBOOTABLE」的两种手段之一。
- 同一函数还有第二个洞：条目在**两张表里都没有**时（例如对 `/dev/sda` 跑 `set a`，`boot_*` 在 LUN4），
  `changed` 为空仍打印「written + CRCs fixed (primary & backup)」且 rc=0。
- **修法**：镜像模式加尺寸闸（必须 `size == (alt_lba+1)*4096`，否则明确拒绝并给替代命令）；
  任一张表缺条目 ⇒ rc≠0 且一个字都不写；写后读回条目字节 + 头 CRC 自证。

### P0-⑤ `build-locked-chain.sh:122-124` —— 输出的写盘配方缺槽属性卫生（#672 根因）
- **触发**：脚本末尾只打印 `qdl ... write boot_b boot_b.img`（dtbo/vbmeta 同理）。
- **后果**：这条配方被照抄执行后，`boot_b` 条目 byte6 里若仍有 `0x80(UNBOOTABLE)` 或 `retry=0`，
  ABL 直接回 fastboot，**镜像根本没被执行**，实验记录会写成「自签链不起作用」。
  本机 11-16 的 LUN4 dump 实测 `boot_b=0x2a`（retry=5, succ=0）、11-18 为 `0x32`；
  官方件对应条目是 `0xf3`（succ=1 + unbootable，属「非活动槽」常态）——
  也就是说**这个脚本产出的三件套完全可能落进一个被标 UNBOOTABLE 的槽**，而脚本对此零提示。
  另有 `--partition_size 100663296`（第 74 行）写死、不与 GPT/`blockdev` 核对。
- **修法**：末尾配方加「写前 `slot-attr.py show`、写后 `set b --no-unbootable --retry 7 --successful`、
  复核 `show`」三步，并把 `--partition_size` 变成参数（默认值仍 96 MiB 但打印来源）。
  （补丁里对「自动执行」标 TODO：本脚本无设备上下文。）

---

## 3. P1（15 条）

### `linux-gpt-apply.sh`
- **P1-①** `:16` / `:22` / `:113` —— **`-R` 语义写反 + `--restore` 只写在用法里、解析器没有这个分支**
  （`case` 里无 `--restore` ⇒ 使用时 `未知参数` exit 2）。后果：文档承诺的**唯一**回退入口不可执行
  （属判据 E「回退步骤是否真的可执行」）；`-R` 被当成「最后 reset」，实际是「跳过 reset」⇒
  写完后设备留在 9008 而脚本 rc=0、无任何状态提示。修法：实现 `--restore DIR` + 加 `--reset`，改注释。
- **P1-②** `:114-119` —— 写前**不落回退基线**（注释把备份责任推给 `linux-gpt-dump.sh`，但无强制校验）；
  写序是「先主后备」，中途掉电会留下「新主表 + 旧备表」。修法：同会话先 `read LUN/0+6` 存基线；
  写序改「先备后主」。
- **P1-③** `:114-129` —— 写后只有「读回件 vs 主机件」一把尺子，没有 `qdl sha256`（#669 要求的第二把尺子）。
  修法：同一命令尾追 `sha256 $LUN/0+6` 与 `sha256 $LUN/$BKP_START+5`，与主机 sha 比对。
- **P1-④** `:31-35` —— `SN` 默认硬编码 `HA2EXB0E`、`READDIR` 目录名硬编码容量档 `16+512`，
  与本仓「身份 = (SN,hwboardid,容量)、产出设备无关」冲突；换单元/U2 时会建出假目录。
  修法：`--sn` 必填或从 `fastboot devices` / `--readdir` 显式给。

### `esp-apply.sh`
- **P1-⑤** `:196-208` —— 64 MiB 单发读回（#669：单发大读不可靠，`qdl` 有 `-u/--out-chunk-size`），
  且回滚提示「用旧 ESP 镜像回滚」但脚本**没有保存任何旧镜像**。修法：读回分块或改用设备端 `sha256`；
  写前把目标区间现内容读一份成 `$READDIR/pre-write-tail.img`。
- **P1-⑥** `:196` —— 与 P0-③ 同源的另一半：没有 device-lock（同 §P1-⑬）。

### `t2-stock-lun45.sh`
- **P1-⑦** `:20`、`:30/:35` —— 无 device-lock；`fastboot -s HA2EXB0E` 硬编码 SN；无写前槽属性取证。
  修法：`. scripts/lib-device-lock.sh`；SN 从 `fastboot devices` 现读；写前 `slot-attr.py show` 进日志。
- **P1-⑧** —— 全文无写后校验（连 GPT 读回都没有）。修法：加一步读回 `0/0+6`、`4/0+6` 与官方件 `cmp`。

### `gpt-dump.sh`（设备侧）
- **P1-⑨** `:25`、`:34` —— `SECT=4096` 写死且**不核对** `blockdev --getss`；也不校验 `DEV` 的 LBA1 是 `EFI PART`。
  后果：`DEV` 指错（别的 LUN / U 盘）或换到 512 B 逻辑扇区的内核/机型时，`dd` 一样「成功」，
  产出整表错位的 dump，而这个 dump 是 `gpt-surgery` 的输入。修法：`--getss` 断言 + `EFI PART` 断言。

### `slot-attr.py`
- **P1-⑩** `:213-252` —— `patch_slot` 无写后读回自证、无 pre-state 落日志、任一路径 rc 恒 0
  （只剩 `SystemExit` 的异常路径非 0）。判据 A 要求「实验开始前先 show、失败路径也留」，
  本工具既不自证也不留痕（`show` 是另一个子命令，靠人记得跑）。修法：写后读回条目字节 + 头 CRC，
  失败 rc≠0；补丁已实现。
- **P1-⑪** 文档/CLI 不一致：`PITFALLS/sessions/308-unbootable槽标志污染整轮实验.md:27` 给的
  `set a --successful --retry 7 --unbootable off` 里 `--unbootable off` **不是合法形式**
  （`--unbootable` 是 store_true，正确写法 `--no-unbootable`）⇒ 该命令会 `unrecognized arguments: off`
  直接失败。修法：文档改为 `--no-unbootable`（本轮只报，不改 PITFALLS 正文）。

### `gpt-surgery-tb322fc.py`
- **P1-⑫** `:178` —— `ud = next(e for e in ents if e["name"] == "userdata")`：
  空槽是 `None`，`e["name"]` 会抛 `TypeError: 'NoneType' object is not subscriptable`。
  实测：拿 11-17 设备现表 dump 跑 `build` 立刻崩，报错完全看不出「表里没有 userdata（现表叫 elden-data）」。
  修法：`next((...), None)` + 明确诊断（补丁已给）。
- **P1-⑬** `:170-190`（`cmd_build`）—— **无覆盖冲突检查**：新 `linux` 区间 `[new_ud_last+1 .. last_usable]`
  只断言「比原 userdata 大」，不检查中间是否夹着别的在用分区。任何「userdata 不是最后一个分区」的表
  都会生成条目区间互相重叠的 GPT（B 类核心判据）。修法：与所有保留条目做区间相交断言（补丁已给）。

### `gpt-restore-tb322fc.py`
- **P1-⑭** `:162` + `:91` —— `--backup-start-lba` 默认 `61390814` 是旧 234 GiB 布局常数，
  现表 `alt_lba=123871231` ⇒ `b_off` 跑到镜像外，报 `no GPT header at 5xxxxxxx`（用户看不出是常数过期）。
  且「把 userdata 拉长到 last_usable」**无重叠检查**。修法：默认 `alt_lba-4` 现算 + 相交断言（补丁已给）。

### `gpt-minimal-build.py`
- **P1-⑮** `:46` —— 对**本机现表**误跑会静默删掉 `elden-super/elden-data/linux17/eldenesp`
  并新建 472 GiB `linux`（实测计划输出见 §4 证据 C），全程无警告、无「这段会毁谁的数据」报告。
  修法：输入表里出现「我方活分区」时默认拒绝（`--allow-drop-live` 才放行），并列出新分区
  区间会物理覆盖的被删分区数据区（补丁已给）。

### `make-gpt-only-xml.py`
- **P1-⑯** `:13-14`（docstring 配方）+ `:39-51` —— 配方带 `-f`（`--allow-missing`），
  「gpt_main*.bin 不在当前目录」会被 qdl **静默跳过**，两行全跳 ⇒ 退出码 0、一个字节没写（#669）。
  同时不校验 `SECTOR_SIZE_IN_BYTES=4096` / `num_partition_sectors=6|5`（写错单位 = 整表错位）。
  docstring 「失败后可原样退回」与 `#675` 直接冲突（写回原厂表 ≠ 回到原厂态）。
  修法：去掉 `-f`、加几何断言、补 `#675` 声明（补丁已给）。

（⑯ 与 ⑮ 合并计数见 §0 表格：P1 共 15 条按「问题点」计，逐文件列出时序号到 ⑯。）

---

## 4. P2（11 条，摘要）

1. `linux-gpt-dump.sh:69` —— 主/备 entries 比较写死 `p[8192:8192+4096]==b[:4096]`；
   LUN4 是 96×128 = **12288 B**（3 扇区）⇒ 恒判 `entries_DIFF`（假报警）。补丁改为按表头现读长度 + CRC。
2. `linux-gpt-dump.sh` —— 无 device-lock（与 ⑬ 同类）。
3. `esp-apply.sh:107` —— `mktemp` 只 trap 了 `$MANIFEST`，`$MANIFEST.paths/.tmp/.mf` 泄漏在 `/tmp`（A 类「临时件清理」）。
4. `gpt-audit-tb322fc.py:40` —— 头 CRC 用固定 92 B 计算，忽略 `hdrsize`；`hdrsize>92` 时假 `hdr_crc=BAD`。
5. `gpt-audit` 的「仅 boot_a/boot_b 的计数被 ABL 当真」是**打印在**属性差异列表里的免责句，
   不是判据 ⇒ 22 条 LUN4 属性差异里真正要紧的只有 `boot_a/boot_b`，读者极易误判。建议单列一节。
6. `edl-peek.sh:19` —— 仍会去试 #486 已定案不可用的 `peek`，且 `exec python3 edl.py` **无 timeout**
   （违反仓规「外部命令一律 `timeout -k`」）。补丁：默认拒绝 + `FORCE=1` 才试 + timeout。
7. `build-locked-chain.sh:37` —— `[ "$6" = "--out" ]` 在 `set -u` 下参数 <6 个时直接
   `$6: 未绑定的变量` 退出（文档只要求 3 个必填）；实测复现。补丁已改 `shift` 循环。
8. `build-locked-chain.sh:74` —— `--partition_size 100663296` 常量，不核对 GPT/`blockdev`（B）。
9. `android-rom-segassemble.py:67/83` —— 用 `rows[0]["ssz"]` 算所有段偏移，段间 `ssz` 不同即错位；
   源件短于 `nsec*ssz` 时只打印 `len=` 静默短写。修法：逐段断言 `len(data) == n*ssz`。
10. `android-lpdump.py:57/225` —— `META_BACKUP_BASE=208896` 硬编码（= 12288+3×65536），
    若 `metadata_max_size` 变化则备 metadata 偏移错，但脚本不校验。
11. `android-super.py:442/465` —— `assemble` 用 `entries[0][2]` 当统一扇区大小、短件零填充只 WARNING；
    `extract` 对 `target_type` 未知时抛异常属正常，但 `--slot` 的备用槽选择逻辑
    （`if meta is None or not ...`）会在主槽 CRC 坏时**静默换槽**，不给提示。

---

## 5. 静态取证（可复现，全部主机侧）

**证据 A —— `slot-attr.py --image` 只写主表（P0-④）**
```
$ cat reports/.../edl-read/gpt4-primary.bin ~/文档/TB322FC_15.10.259/gpt_backup4.bin > /tmp/sa_test.img   # 45056 B
$ python3 scripts/slot-attr.py --image /tmp/sa_test.img set b --retry 7
  ! boot_b not found in backup GPT
  primary boot_b byte6: 0x32 -> 0x3a
  written + CRCs fixed (primary & backup)          ← 谎报
$ cmp -l <旧> <新>   → 只有主表条目区(4185)与主表头 CRC(4113..4116) 变了
```
修后（整盘视图 + 读回自证）：
```
$ python3 /tmp/r1/b/scripts/slot-attr.py --image /tmp/lun4full.img set b --retry 7 --successful --no-unbootable
  primary boot_b byte6: 0x32 -> 0x7a   (retry 6->7, succ 0->1, unbootable 0->0)
  backup  boot_b byte6: 0xf3 -> 0x7b   (retry 6->7, succ 1->1, unbootable 1->0)
  verify primary boot_b byte6 读回=0x7a (want 0x7a) hdr_crc=OK  OK
  verify backup  boot_b byte6 读回=0x7b (want 0x7b) hdr_crc=OK  OK
  written + read-back verified (primary & backup)
```
⇒ 顺带得出结论：**本机 LUN4 主表与备表的 `boot_b` 属性本来就不同**（主 0x32 / 备 0xf3，
即备表里 boot_b 是 `UNBOOTABLE`）。任何「只看主表」的槽属性判据都不安全。

**证据 B —— `gpt-surgery build` 在现表上崩（P1-⑫）**
```
$ python3 scripts/gpt-surgery-tb322fc.py build --main reports/.../gpt0-primary.bin --backup <stock backup> ...
TypeError: 'NoneType' object is not subscriptable   (scripts/gpt-surgery-tb322fc.py:178)
```

**证据 C —— `gpt-minimal-build` 对现表的实际计划（P1-⑮）**
```
保留 9 项 / 353.5 MiB：frp, keystore, lenovocust, lenovolock, lenovoraw, misc, persist, proinfo, ssd
删除 9 项 / 471.69 GiB：elden-data, elden-super, eldenesp, linux17, metadata, pstoredump, rawdump, vbmeta_system_a, vbmeta_system_b
linux: 90504..123871226  (472.19 GiB)      ← eldenesp 的 123609088 落在里面
```
（`--linux-gib 0` 默认吃满；旧版无任何告警，旧版 `--dry-run` 也不会报覆盖。）

**证据 D —— 「只信退出码」在本仓已造成实害**
`reports/artifacts/bl-stuck-20261116/lun4-gpt-primary-final.bin` 与 `lun4-gpt-backup-final.bin`
均为 **0 字节**（2026-11-16 23:29），名字里带 `-final`。这就是「命令 rc=0 / 没人读回」的产物，
与 P0-② 的「dump 目录留半套」同型。

---

## 6. 建议补丁（`/tmp/script-audit-edl.patch`）

12 个文件，`git apply --check` 通过，可直接 `git apply`。要点：

| 文件 | 补丁内容 |
|---|---|
| `linux-gpt-apply.sh` | 实现 `--restore DIR`；加 `--reset`；同会话先读**写前主/备表基线**再「先备后主」写；读回 + 设备端 `sha256` 双尺子；device-lock；注释改成 `-R = --skip-reset` |
| `linux-gpt-dump.sh` | 两条 qdl 都加 `-R`；`--reset-after`；entries 比较按表头长度现读 + CRC；device-lock |
| `esp-apply.sh` | 写前 live-GPT 闸（分区存在/起点一致/装得下，否则拒写）；`--reset-after`；设备端 `sha256`；临时件全清；device-lock |
| `gpt-dump.sh` | `blockdev --getss` 断言 4096 + `EFI PART` 断言 |
| `t2-stock-lun45.sh` | 每条 qdl 加 `-R`（reset 那发除外）；输出落文件取 `$?`，非 0 即停；写前槽属性取证；写后 GPT 读回 `cmp` |
| `build-locked-chain.sh` | 修 `$6` 未绑定；`--out/--partition-size` 正规解析；末尾配方加槽属性三步 |
| `slot-attr.py` | 镜像模式尺寸闸（只收整盘视图）；备表位置取 `alt_lba`；任一张表缺条目 ⇒ 不写且 rc≠0；写后读回条目 + 头 CRC 自证（`sys.exit(rc)`） |
| `gpt-surgery-tb322fc.py` | `userdata` 缺失给明确诊断；`cmd_build` 加新 linux 区间与在用分区的相交断言 |
| `gpt-restore-tb322fc.py` | `--backup-start-lba` 默认由 `alt_lba-4` 现算；userdata 拉长前相交断言 |
| `gpt-minimal-build.py` | `--allow-drop-live` 闸；打印「新分区会覆盖哪些被删分区的数据区」 |
| `make-gpt-only-xml.py` | 几何断言（`SECTOR_SIZE_IN_BYTES=4096`、6/5 扇区）；缺件默认失败；配方去 `-f`、补 `#675` 声明 |
| `edl-peek.sh` | 默认拒绝（`FORCE=1` 才试）；`timeout -k 10 180` |

**TODO（补丁里已就地标注，需设备窗口才能闭环）**
1. `build-locked-chain.sh` 的槽属性三步目前只是打印的指令 —— 自动执行需要设备在线，
   接线位置 = `flash-b.sh`（R2 主件），本轮不动。
2. `esp-apply.sh` 的 live-GPT 闸目前只断言「存在/起点/装得下」；
   「与其它在用分区不相交」在 GPT 语义下由条目唯一性隐含，但**跨 LUN 误用**（`--lun` 给错）仍需上机验证一次。
3. `linux-gpt-apply.sh` 写完是否让设备真的启动一次新表（boot 验证）属实验编排，不放进脚本。

---

## 7. 本轮未做/未验证

- 未上机：所有结论来自源码 + 仓内 dump/官方包的主机侧复算，qdl 行为结论来自
  **读 `~/edl/qdl/src/cli.c`、`qdl.c` 源码**（`-R`=`--skip-reset`、reset 默认追加于 `qdl.c:884`），
  不是跑出来的。
- 未覆盖：`to-fastboot.sh`/`flash-b.sh`/`slot-switch.sh` 等槽位族（R2）、`android-*.py` 的写盘调用方（R3）。
- 未改任何仓内文件；PITFALLS 正文（尤其 #308 的 `--unbootable off`）只报不改，等主代理裁决。
