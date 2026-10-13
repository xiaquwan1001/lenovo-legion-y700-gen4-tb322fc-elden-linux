# 会话记录 — 2026-10-13 晚（M1 重基 + 上游化多片备料 + 新树首次上机）

> 证据层。状态权威 = `TASKS.md §7`（含「M1-7.3 首次上机 bringup」段）；规则 = `reports/upstream-policy-20261013.md`。
> 本轮**无任何上游发信**（投递冻结；唯一例外 = 用户批准的 M3-1，见 `patches/upstream/m3-2026-10-13/README.md` §投递记录）。

## 1. 编排者主线（parent 自己做的）

1. **M1 基线重基到 7.3-rc7（用户批准后执行）**
   - 关键纠正：lane 报的「12 提交可重放 91.7%」只覆盖容易的一半——**payload 基座在浅边界 `ba28ec16f0` 之下**（用 `ba28` 树含 `aw88461.c`/`wl2868c`/panel elden 增量证实）。真实重基 = v7.2 tag(`237a1c39e8df`) → `ba28` 的 **173 文件 / +16120 / −672** payload 差量打到 7.3-rc7。
   - `git apply --3way` **原子失败且静默**（7.3 已把 `fs/crypto/inline_crypt.c` 并入 `block.c`）⇒ 改用 `git rebase --onto 24a19b953e upstream-v7.2`，得 **16 文件 / 41 冲突块**，逐条按「上游为基 + 只贴回 elden 增量」解决。
   - **编排者复核并补修**：lane 局部编译漏掉 vendor `dm-default-key` 的**调用方**（`fs/f2fs/data.c`、`include/linux/blk_types.h`）⇒ 全量构建失败；补修提交 `ed6f232d10` 后 `make Image.gz dtbs` **rc=0 / 0 error / 0 warning**。新树 = `build/m1-upstream/clean-tree-73` @ `m1/clean-tree-7.3rc7`，相对 7.3-rc7 = **147 文件 / +15361 / −687**。
2. **上层机器可查性**：`patches/upstream/README.md`（提交前门 checklist：三问门 + 7 道机械门 + Q3 违例扫描 + 系列索引）· `versions/vk-kernel-identity.tsv` 刷新（登记 m1-73 镜像族 7 行）· `PITFALLS #108`（复发记录）、**新 #247**（跨版本改 config 两坑）· 技能 `upstream-mail-ustc`（补 2 条实测坑）· **`check-doctor` FAIL=0 / WARN=8**。

## 2. 派发的 lane（全部 `deepseek/deepseek-flash`；编排者逐条独立重跑判据）

| lane | 产物 | 编排者复核结果 |
|---|---|---|
| `m1-rebase-eval` | `reports/m1-rebase-7.3rc7-feasibility-20261013.md` | 13 提交/浅根/板 DTS 不在 7.3 等主张复现 ✓；**更正其「`--is-ancestor` 不可信」的误记**（实测正常，报告已插更正块） |
| `m1-rebase-exec` | 重基工作树 + `reports/m1-rebase-7.3rc7-execution-20261013.md`（§7 = 编排者复核） | 16 冲突处置合规；**补修其漏改的 dm-default-key 调用方** |
| `m3-2-boardsplit` | `reports/m3-2-board-basics-split-20261013.md` | 58 `&label`+root=59 ✓、`dtbs` rc=0 ✓、`dt-validate` 0 诊断 ✓；揭出**基座漂移**（M1 树 7.2.0 vs pristine 7.3-rc7） |
| `m3-3-audio` | `patches/upstream/m3-3-2026-10-13/`（2 枚）+ 报告 | checkpatch 2/2 0E/0W ✓、`dt-doc-validate` rc=0 ✓、干净 `git am` rc=0 ✓、编译 rc=0 ✓、Q2 依据（payload 已 include aw88395_device.h）✓ |
| `m3-4-panel` | `patches/upstream/m3-4-2026-10-13/`（4 枚）+ 报告 | checkpatch 4/4 0E/0W ✓、`am` rc=0、**终态残差 = H1**、编译 rc=0 ✓；lane 主动剔除 H1（`to_primary_dsi` 无条件改 `dsi[0]` = 板级事实覆盖全树唯一 desc） |
| `m3-6-wireless` | `patches/upstream/m3-6-2026-10-13/`（2 枚）+ 报告 | checkpatch 2/2 0E/0W ✓、`dt-doc-validate` rc=0 ✓、`drivers/power/sequencing/` 编译 rc=0 ✓ |
| `m4-camss` | `patches/upstream/m4-camss-2026-10-13/`（3 枚）+ 报告 | checkpatch 3/3 0E/0W ✓、3 个新 binding `dt-doc-validate` rc=0 ✓、干净 `am` rc=0 ✓、media 增量 18 文件/+3354/−62 ✓；**更正其 D 类核验命令的原始输出**（命中 5 处 `pm_runtime_force_*` 属内核 API，非测试钩子；结论不变） |
| `m5-dmdefaultkey` | `reports/m5-dm-default-key-20261013.md` + `patches/out-of-tree-dm-default-key/` | 存在性/祖先关系/config 死代码/上游 `dm-inlinecrypt` 620 行全部复核 ✓ |
| `b5-dsi-resoc` | `reports/b5-dsi-resoc-20261013.md` + 分支 `b5/dsi-compat-cleanup` | 56 hunk ✓、必删项不在树内 ✓、散落 compat 7+1 ✓；**更正我方 496/218 的错口径**（权威 = numstat +552/−18、+222/−27） |
| `m1-73-onboard-img` | `out/boot-elden-m1-73.img` + 报告 | 镜像 format/cmdline 与现役同构 ✓；36 模块 vermagic **36/36 逐字匹配** ✓；DTB sha 与树内一致 ✓ |
| `m1-73-boot-forensic` | `reports/m1-73-boot-failure-20261013.md` | 两 DTB 逐节点差异（唯一可疑 = `simple-framebuffer`）✓、往返编译可复现 ✓、`73d`（去 fb）造好 ✓ |
| `m1-73-dts-fixes` | 提交 `b3815fb150` + `out/boot-elden-m1-73f.img` + 报告 | 板 DTS 功能差异仅 3 处 ✓、`73e→73f` 恰为这 3 处（12 行）✓、**`&usb` 两树逐行相同** ✓ |
| `m1-73-daily-config` | `out/m1-73-cfg/Image.gz` + 报告 | 复核并**采纳其更正**：7.3 把 `PROC_SYSCTL` 改名 `SYSCTL`，用 `extract-ikconfig` 抽成品内核实测 `CONFIG_SYSCTL=y` ⇒ **我方「缺 /proc/sys」判断作废**；两 config 实际只差 `IPV6_MULTIPLE_TABLES` |

## 3. 上机（零写盘 `fastboot boot`，全部主机侧记录）

逐步变量与结果、两处设备侧修复（`&i2c0`=PITFALLS #108、`splash_region`=PITFALLS #11）、以及当前卡点（USB gadget 不枚举 / 无声音 / 无马达）见 `TASKS.md §7`「M1-7.3 首次上机 bringup」表。
本轮新增取证工具：**磁盘日志黑匣子**（ramdisk 层让 `/init` 把 `dmesg` 快照写进持久根 `/root/m1-73-dmesg.txt`，带 `sync`）——USB 不通也能拿内核原始日志。

## 4. 未决 / 下一步

1. **73h 复测取日志**（当前唯一卡点的取证路径）；仍 0 字节则改直接写裸分区 `persist`/`logfs`。
2. 拿到日志后按序查：USB（dwc3/role-switch/gadget）、音频（sndcard/wcd939x probe）、马达（aw86927 probe）。
3. M3-2 板基础片（6 枚补丁草案已在台账里）· M3-5 camss DTS/binding 面 · M4 深化 · M5 out-of-tree patchset 落地 —— 均**备料封存**，等收盘统一投递。
