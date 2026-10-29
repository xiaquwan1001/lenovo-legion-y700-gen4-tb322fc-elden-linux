# B5（M6）系列投递前 preflight — 2026-10-29

> 范围：`patches/local/b5-resoc-20261028/`（0001–0006）投递上游前的四项门 + 依赖清单。
> 纯主机任务，不碰设备。
> 判据口径：**已证**（有命令 + 原始输出）/ **未证实**（推断，无直接证据）/ **未上机**（需设备）。
> 时间盒：≤80 min。

pi 会话 id：`01a18584-776c-7292-8511-8dce264f0c63`
任务：B5（M6）系列投递前 preflight（pristine git am + 拆表项 + 显式 master 检查）

---

## 0. 状态（逐节回填，末尾 §6 汇总）

| 项 | 结果 |
|---|---|
| §1 pristine `git am` 复现 + 依赖清单 | 序列 **0/6**（逐枚仅 0002 干净）；依赖 4 文件 +822 −46 = 下游 `0f1fb1c9c`，上游无等价提交 |
| §2 SM8750 DSI cfg 独立表项 | **已独立**（行号见 §2），无需改动 |
| §3 「调用者必须是 master」显式判据 | **已存在**于 0005；草案 `proposed/0007` 补残留裸错误码 |
| §4 全量编译门 + checkpatch | 从零 `-j26` rc=0 / 286.78 s / 0E 0W；checkpatch 6/6 + 草案 0E 0W 0C |
| §5 style 门禁 | dt-check-style rc=0；yamllint **未跑**（缺工具）；commit message 6/6 合格（16 行 73–74 建议收紧） |

详细论证与原始输出见 §1–§5；判定见 **§6**。

基线事实（本轮现查，不引用旧结论）：

```
$ cd build/m3v2-7.3rc7 && git log -1 --format='%H %d %s' 24a19b953
24a19b953e2a3d0ea5a8c4951a0ab8f32720c907  (grafted, tag: v7.3-rc7) Linux 7.3-rc7
$ git merge-base --is-ancestor 24a19b953 24223e44a ; echo $?
0                       # 日常线是本轮的 7.3-rc7 后代
$ git rev-list --count 24a19b953..24223e44a
2                       # = 0f1fb1c9c(payload) + 24223e44a(phy mux)
$ git rev-parse 0f24eb699^      # 系列基线（0001 的父提交）
24223e44ad805a75048e8a30d0cbfff14cd99e24
```

---

## 1. pristine 重放（`git am` 逐枚 + 序列）

### 1.1 环境与命令（可复跑）

本轮**新建**独立 pristine worktree，不扰动既有 `~/.cache/pi-tmp/tmp.vXWJ0X2O6j`：

```sh
cd build/m3v2-7.3rc7 && git worktree add --detach /tmp/b5pf-pristine 24a19b953
cd /tmp/b5pf-pristine && git status --porcelain | wc -l     # → 0
```

逐枚判定脚本（每枚前 `reset --hard` 回 base，失败即 `am --abort`，不 `--skip`）：
`/tmp/b5pf-am-replay.sh`、冲突行定位 `/tmp/b5pf-conflict-lines.sh`；原始日志
`/tmp/b5pf-logs/am-replay.log`、`/tmp/b5pf-logs/conflict-lines.log`（关键片段已内联到下文，脚本 20 行内可重打）。

### 1.2 结果：逐枚 `git am --3way` = **1/6 可打**，序列 = **0/6**

| 补丁 | hunks / files | `git am` rc | 冲突文件 |
|---|---|---|---|
| 0001 | 5 / 1 | 128 | `dsi_manager.c` |
| 0002 | 8 / 3 | **0（干净）** | — |
| 0003 | 21 / 5 | 128 | `dsi.h`、`dsi_cfg.c`、`dsi_host.c`、`dsi_manager.c` |
| 0004 | 13 / 4 | 128 | `dsi.h`、`dsi_cfg.h`、`dsi_host.c`、`dsi_manager.c` |
| 0005 | 2 / 1 | 128 | `dsi_manager.c` |
| 0006 | 2 / 1 | 128 | `dsi_cfg.c` |
| 序列 | — | **0/6**（第 1 枚即停） | — |

原始行（0001）：`自动合并 drivers/gpu/drm/msm/dsi/dsi_manager.c` → `冲突（内容）：合并冲突于 drivers/gpu/drm/msm/dsi/dsi_manager.c` →
`打补丁失败于 0001 … rc=128`；序列段：`seq 0001… rc=128` → `SEQUENTIAL_OK=0/6`。

### 1.3 冲突行号（`--3way` 落冲突标记后实测，worktree 行号）

| 补丁 | 文件 | 冲突块（`<<<<<<<` 行 → `>>>>>>>` 行） |
|---|---|---|
| 0001 | `dsi_manager.c` | 28→47、53→66、352→403、578→655 |
| 0003 | `dsi.h` | 54→60、77→86 |
| 0003 | `dsi_cfg.c` | 361→365 |
| 0003 | `dsi_host.c` | 2165→2555 |
| 0003 | `dsi_manager.c` | 38→56、516→547 |
| 0004 | `dsi.h` | 61→66 |
| 0004 | `dsi_cfg.h` | 44→68 |
| 0004 | `dsi_host.c` | 2165→2566 |
| 0004 | `dsi_manager.c` | 348→399、574→605 |
| 0005 | `dsi_manager.c` | 496→541、554→581 |
| 0006 | `dsi_cfg.c` | 197→236 |

（0002 无冲突块。注：0003/0004 的 `dsi_host.c` 冲突区间 390/401 行 = 整段 bonded 实现缺席，不是局部错位。）

### 1.4 依赖清单（可复跑；「是否需要」= 符号出现在该补丁的**上下文/删除行**里）

判据来源：对每枚补丁取 `^[ -]` 行（context + removed，即补丁**要求已存在**的代码）与载荷符号表求交，
脚本 `/tmp/b5pf-symneed.sh`；文件级前置量 = `git diff 24a19b953:<file> <series-base>:<file>`（下表均已实测）。

**外部依赖（系列基线 `24223e44a` 有、pristine `24a19b953` 无）**

| # | 文件 | 前置量（pristine → 系列基线） | 提供者（本地） | 上游等价提交 | 为什么需要 | 需要的补丁 |
|---|---|---|---|---|---|---|
| D1 | `drivers/gpu/drm/msm/dsi/dsi_manager.c` | **+222 −27** | `0f1fb1c9c` «elden payload v2: downstream vk64 tree state …» | **无**（pristine 树内 `dsi_mgr_bonded_cmd_xfer` 等 0 命中） | 0001 要搬的 `dsi_bonded_cmd_failed` 就长在这个载荷里；`is_sm8750`/`is_bonded_dsi`/`is_sync_needed`/`master_dsi_link_id` 字段与 `dsi_mgr_uses_bonded_cmd()`/`msm_dsi_manager_cmd_failed()`/`dsi_mgr_bonded_cmd_xfer()` 全在其中 | 0001(8 符号)、0004(6)、0003(5)、0005(2) |
| D2 | `drivers/gpu/drm/msm/dsi/dsi_host.c` | **+560 −18** | 同上 | **无** | 0003 要把 10 个直调改成 host ops，被调的 `msm_dsi_host_bonded_cmd_{arm_master,build,init_trigger,poll_slave,stage,trigger,wait_master}`、`_bonded_xfer_prepare/_xfer_restore/_wait_video`、`msm_dsi_host_cmd_xfer_config()`、`dsi_cmd_error_prepare/cleanup()` 都只在此载荷里 | 0003(13)、0004(1) |
| D3 | `drivers/gpu/drm/msm/dsi/dsi.h` | **+18 −1** | 同上 | **无** | 0003 的原型块（10 个 `msm_dsi_host_bonded_*` + `msm_dsi_manager_cmd_failed` + `msm_dsi_manager_cmd_xfer_trigger`）在 pristine 不存在；`dsi.h` 冲突块即此原型区 | 0003、0004 |
| D4 | `drivers/gpu/drm/msm/registers/display/dsi.xml` | **+22** | 同上 | **无** | 0003 使用 `DSI_CMD_DMA_CTRL_BROADCAST_MASTER`(pos30)/`WC_SEL`(pos29)/`PACKET_TYPE`(pos24)、`DSI_DMA_SCHEDULE_CTRL`。pristine `dsi.xml:189-191` **只有** `BROADCAST_EN`(31) 与 `FROM_FRAME_BUFFER`(28) ⇒ 缺位域会让 pristine 上的 0003 **编不过**（文本可落、语义不可用） | 0003 |

**系列内依赖（前一/前几枚提供，pristine 天然没有）**

| # | 提供者 | 需要的补丁 | 证据 |
|---|---|---|---|
| S1 | 0002 的 `struct msm_dsi_bonded_cfg` + `sm8750_dsi_cfg` + `sm8750_dsi_bonded_cfg` | 0006 | 0006 冲突块 `dsi_cfg.c:197→236` 覆盖整段 `sm8750_dsi_bonded_cfg`；0006 的 context/removed 行对**载荷**符号命中 = 0（`/tmp/b5pf-symneed.sh` 输出空） |
| S2 | 0002 (+0003) 的 `msm_dsi_config.compatible/bonded` 字段 | 0003/0004/0005 | 0002 的 `dsi_cfg.c`/`dsi_cfg.h` 前像 blob = `da3fe6824`/`ccf066796` **与 pristine 逐字节相同** ⇒ 这两文件的改动是纯追加，故 0002 是唯一能单打在 pristine 上的一枚 |

**为什么 0002 能单打（已证）**：`git diff <pristine blob> <patch 前像 blob>` 对 `dsi_cfg.c`/`dsi_cfg.h` = **空**，
只有 `dsi_host.c` 有 +560 前置；而 0002 在 `dsi_host.c` 只改 1 行（`msm_dsi_cfg_get(dev, major, minor)`），
落在 `dsi_get_config()` 里，`apply` 按偏移命中 ⇒ 干净 rc=0。

### 1.5 结论口径

- **已证**：系列对 pristine `24a19b953`（v7.3-rc7）**序列 0/6、逐枚 1/6**；前置依赖 = **4 个文件 / +822 −46**
  （`dsi_manager.c` +222−27、`dsi_host.c` +560−18、`dsi.h` +18−1、`dsi.xml` +22），全部来自**一个**下游压缩提交 `0f1fb1c9c`。
- **已证**：上游 7.3-rc7 里这些符号 **0 命中** ⇒ 依赖清单的「上游提交 sha」一栏**没有可填的值**：
  前置不是「缺 cherry-pick」，而是**缺一整组尚不存在的上游提交**。
- **未证实（明确留白）**：把 `0f1fb1c9c` 的 bonded 核心拆成几枚、每枚能否过 checkpatch/评审——本轮只给出**切分边界建议**（见 §6 R1），未做拆分实验。

---

## 2. 拆表项核查：SM8750 DSI cfg **已经是独立表项**（已证，无需再改）

派工单前提「现在表挂在 `sm8650_dsi_cfg` 上」**已过时**：0002 已把 bonded 数据拆到独立表项（`reports/b5-step5-upstream-20261028.md` §1 即此做法），
故**不产出最小改动 diff**（无改动可做）。以下为行号证据（树 `build/b5-resoc` @ `481225269`，`drivers/gpu/drm/msm/dsi/dsi_cfg.c`）：

| 行 | 内容 | 说明 |
|---|---|---|
| `:224` | `static const struct msm_dsi_bonded_cfg sm8750_dsi_bonded_cfg = {` | bonded 数据本体（独立符号） |
| `:235-245` | `static const struct msm_dsi_config sm8650_dsi_cfg = {…}` | **无** `.compatible`、**无** `.bonded`（`grep -n '\.bonded' 只有 :261`） |
| `:251-262` | `static const struct msm_dsi_config sm8750_dsi_cfg = {` … `.compatible = "qcom,sm8750-dsi-ctrl"` (`:260`)、`.bonded = &sm8750_dsi_bonded_cfg` (`:261`) | 独立表项 |
| `:415-416` | `{…V2_9_0, &sm8650_dsi_cfg, &msm_dsi_6g_v2_9_host_ops}` | 通用回退项（不命名 SoC） |
| `:417-418` | `{…V2_9_0, &sm8750_dsi_cfg, &msm_dsi_6g_v2_9_bonded_host_ops}` | SoC 专用项，排在通用项**之后** |
| `:435-447` | `for (i = ARRAY_SIZE(dsi_cfg_handlers) - 1; i >= 0; i--)` + `of_device_is_compatible()` 闸门 | 倒序扫 ⇒ 专用项先命中；未命名 SoC 的项照旧通用 |
| `dsi_cfg.h:56-79` | `struct msm_dsi_bonded_cfg` + `msm_dsi_config.{compatible,bonded}` | 字段落在 per-SoC 表（不是 `cfg_handler`） |

**DTS / binding 侧（同轮现查，已证）**：

- `arch/arm64/boot/dts/qcom/sm8750.dtsi:3439/3548`、`eliza.dtsi:2617/2725` 都带 compatible `"qcom,sm8750-dsi-ctrl"` ⇒ `of_device_is_compatible()` 能命中（多串只取任一命中，`eliza-dsi-ctrl` 在前不影响）。
- binding `dsi-controller-main.yaml:48/62/390` 在 **pristine 已列** `qcom,sm8750-dsi-ctrl`（`/tmp/b5pf-pristine` 同样行号）⇒ **无需新增 binding**（系列里也没有；与 `0002` 的 3 文件清单一致）。

**评审风险（未证实，仅登记）**：同一 `(major,minor)` 出现两条表项，维护者可能问「为何不用 `io_start` 区分」。
现有依据 = 两 SoC 的 `io_start` **相同**（都 `{0xae94000, 0xae96000}`）⇒ 只能是 compatible 闸门；这点 0002 正文与 `dsi_cfg.c:246-250` 注释已写明，本报告仅确认行号对得上。

---

## 3. 「调用者必须是 master」显式检查

### 3.1 核查结论：0005 **已经是显式判据**（派工单前提过时）

派工单写「0005 现在是靠 -22 返回」——本轮现查：`patches/local/b5-resoc-20261028/0005-*.patch` 的 diff **已经**包含
显式校验 + `dev_err`（= 上一轮 `reports/b5-step5-upstream-20261028.md` §2 的产物）。证据：

- 补丁侧：`0005` 的 `+` 行含 `if (id != master_id) {` / `dev_err(&dsi_mgr_get_dsi(id)->pdev->dev,` /
  `"bonded command on link %d, but link %d is the master\n"` / `return -EINVAL;`，且函数签名从 `(msg)` 改为 `(id, msg)`。
- 树侧（`build/b5-resoc` @ `481225269`，`drivers/gpu/drm/msm/dsi/dsi_manager.c`）：

| 行 | 内容 |
|---|---|
| `:633` | `static int dsi_mgr_bonded_cmd_xfer(int id, const struct mipi_dsi_msg *msg)` |
| `:637` | `int master_id = dsi_mgr_bonded_master_link_id(id);`（按**发起 link** 取 master，与 0004 的 `master_link_id` 事实对齐） |
| `:639-640` | `if (master_id < 0 \|\| master_id >= DSI_MAX) return -EINVAL;` ← **残留的裸 -EINVAL**（见 3.2） |
| `:642-654` | 注释 + `if (id != master_id) { dev_err(... "link %d is the master"); return -EINVAL; }` ← **显式判据已存在** |
| `:656-659` | `if (!master_dsi \|\| !slave_dsi \|\| !master_dsi->host \|\| !slave_dsi->host) return -ENODEV;` ← **无日志** |
| `:661-666` | `ops->bonded_cmd_xfer(...)` 真正调用 |

判据位置也正确：`msm_dsi_manager_cmd_xfer()` 以 `id` 原样透传（`0005` 同时改了这一行调用），而该检查位于
`dsi_bonded_xfer_prepare()`（`pm_runtime_resume_and_get` + 时钟）与 `bonded_cmd_failed` 闩锁**之前** ⇒ 被拒调用无副作用（已证：代码顺序）。

### 3.2 仍存在的裸错误码（两处，本轮出 diff 草案）

`:639-640` 的 `-EINVAL` 与 `:656-659` 的 `-ENODEV` 仍然**无任何日志**——正是 0005 想消灭的形态，只是在上一条分支。
尤其 `master_id < 0` 会在「SoC 无 bonded 表且 `master_dsi_link_id` 尚为 -1（`msm_dsim_glb` 初值）」时静默返回。

草案：`patches/local/b5-resoc-20261028/proposed/0007-drm-msm-dsi-log-the-bonded-command-link-checks.patch`
（挂在 0006 上，**不覆盖原 6 枚**；错误码不变，只加两行 `dev_err` 点名 link id）。

门禁（本轮现跑）：

```
$ cd build/b5-resoc && perl scripts/checkpatch.pl --strict --no-signoff \
    < /home/xuqianhui/y700-elden/patches/local/b5-resoc-20261028/proposed/0007-*.patch
total: 0 errors, 0 warnings, 0 checks, 26 lines checked      # 与 --no-tree 文件模式同结果
$ git apply --check -v <proposed/0007>        # 在 481225269 树上
正在检查补丁 drivers/gpu/drm/msm/dsi/dsi_manager.c...   → APPLY_OK
$ make -j26 W=1 drivers/gpu/drm/msm/dsi/dsi_manager.o     # /tmp/b5pf-proposed（已打草案）
  CC      drivers/gpu/drm/msm/dsi/dsi_manager.o    rc=0  warn=0
```

**未上机**：该草案只改错误路径日志，不改判定结果（`-EINVAL`/`-ENODEV` 不变）⇒ 行为中性仅由代码阅读支持，**无设备侧证据**。

---

## 4. 全量编译门（`make -j26 Image.gz dtbs`）

**为何在 `/tmp/b5pf-proposed` 而不是 `build/b5-resoc` 跑全量**：`build/b5-resoc` 已是增量树（`make` 只做 12 步、29 s，
`vmlinux` 早已存在），拿它当"全量门"没有意义；而 `make clean` 会拆掉别的 lane 可能在用的产物、也违背「不破坏当前可用系统」。
故本轮在**自己的一次性 worktree**里从零编译。两树同源：`/tmp/b5pf-proposed` = `481225269` = `build/b5-resoc` HEAD，工作区 `git status --porcelain` = 0 行（草案 0007 已 stash）。

```sh
cd build/m3v2-7.3rc7 && git worktree add --detach /tmp/b5pf-proposed 481225269
cd /tmp/b5pf-proposed && cp /home/xuqianhui/y700-elden/build/b5-resoc/.config .config   # 同一 .config
export ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-"
/usr/bin/time -f "WALL=%es" make -j26 Image.gz dtbs
```

结果（`/tmp/b5pf-logs/fullbuild.log` + `.rc`）：

```
rc=0                                     # 从零（无旧 .o）全量
WALL=286.78s                             # 4 min 47 s，-j26
CC 目标数=4570   warning:=0   error:=0
  OBJCOPY arch/arm64/boot/Image
  GZIP    arch/arm64/boot/Image.gz
vmlinux      637548480 B   Image.gz 19763145 B   dtb 文件数=410
```

- **0 错误 / 0 警告**（`grep -ci 'warning:'` 与 `' error:'` 均 0；默认 `W=0`）。
- 交叉核对：`build/b5-resoc` 的增量构建产物 `vmlinux` = **637548528 B / 10:55**，与从零树 **637548480 B / 11:02** 同级别差异（48 B 来自 `UTS_VERSION`/时间戳）⇒ 两树代码一致，没有隐藏未提交改动。
- 与 6 枚补丁有关的文件**全部在本轮从零重编**：`fullbuild.log` 里 `CC … drivers/gpu/drm/msm/dsi/` 共 **11** 行，含 `dsi_manager.o`/`dsi_host.o`/`dsi_cfg.o`。

**W=1 定向门**（草案 0007 已打）：

```sh
cd /tmp/b5pf-proposed && make -j26 W=1 drivers/gpu/drm/msm/dsi/dsi_manager.o
  CC      drivers/gpu/drm/msm/dsi/dsi_manager.o    rc=0  warn=0
```

**未做（明确留白）**：`W=1` 的**全树**编译（时间盒内不值得；6 枚只碰 dsi 目录，已用定向 `W=1` 覆盖）；
`make dtbs_check` 全树（本系列零 DTS 改动，见 §5.1）。

---

## 5. 投递前 style 门禁（PITFALLS #462 三条逐条）

> 先记一条**方法学订正**（本轮实测，会影响后续所有投递）：`#462` 定式里的
> `perl scripts/checkpatch.pl --strict --no-signoff --no-tree <patch>` 在本树会把 **patch 文件本身当源码扫**
> （输出 `ERROR: trailing whitespace #30: FILE: .../0001-*.patch:30`，命中的全是 patch 里空 context 行那个前导空格），
> 6 枚全中、纯属假阳性，合计 **81 条 ERROR / 6 枚**（逐枚 `7 / 16 / 30 / 20 / 6 / 2`，见 `/tmp/b5pf-logs/checkpatch-notree-filemode.log`；
> 同批补丁用正确跑法 = **0E/0W/0C**）。**正确跑法 = 去掉 `--no-tree`、用 stdin**（`cd <tree> && perl scripts/checkpatch.pl --strict --no-signoff < patch`）。
> 注：草案 `0007` 在 `--no-tree` 文件模式下也是 0E（它同样含 4 行 ` ` 空 context），故「何种输入会退化成文件模式」**未完全查清**；
> 行得通的判据是**看输出里有没有 `FILE: …/*.patch:NN`** —— 出现即说明它在扫 patch 而非补丁内容，结果不可用。

### 5.1 ① `dt-check-style` 必须用 dtschema venv 的 python——**已跑（相关面）**

```sh
$ cd build/b5-resoc    # = 6 枚全打上的树，HEAD 481225269
$ ~/.local/opt/dtschema-venv/bin/python scripts/dtc/dt-check-style --mode=relaxed \
    Documentation/devicetree/bindings/display/msm/dsi-controller-main.yaml
rc=0
```

为什么只跑这一个 yaml：**6 枚补丁不碰任何 DTS/binding**（`grep -h '^+++ b/' 000*.patch` 只有 `dsi_manager.c`/`dsi_host.c`/`dsi_cfg.c`/`dsi_cfg.h`/`dsi.h` 五个 .c/.h）。
`dsi-controller-main.yaml` 是唯一与本系列语义相关的外部件（`qcom,sm8750-dsi-ctrl` 的 compatible 闸门依赖它），故把它当作**外围回归**跑了一遍：rc=0。

### 5.2 ② yamllint——**未跑（工具缺失，且跳过的机制在本树确实存在）**

```sh
$ cd build/b5-resoc && command -v yamllint            # → 空（NOT FOUND）
$ ~/.local/opt/dtschema-venv/bin/python -m yamllint     # → No module named yamllint
$ sed -n '6,7p' Documentation/devicetree/bindings/Makefile
DT_SCHEMA_LINT = $(shell which yamllint || \
  echo "warning: python package 'yamllint' not installed, skipping" >&2)
```

⇒ `make dt_binding_check` 的 yamllint 步骤在本机会**静默退化**（rc=0 ≠ yaml 风格过关），与 `#462` ② 描述一致。
口径：**未证实**（工具不在，不是通过）。缓解：本系列零 yaml 改动 ⇒ 本轮不阻塞投递；
若后续动 binding，先 `~/.local/opt/dtschema-venv/bin/pip install yamllint` 再单跑 `-f parsable -c .yamllint`。

### 5.3 ③ commit message 自检（checkpatch 覆盖不到的部分）——**已跑（6/6）**

判据：`^---$` 恰 1 个、diffstat 恰 1 行 `N file(s) changed`、`Signed-off-by:` 恰 1 个、正文行长、SoB 与 `---` 之间不允许出现无空行的自制 stat。

| 补丁 | `^---$` | diffstat 行 | SoB | 正文 >72 字符的行 | 结论 |
|---|---|---|---|---|---|
| 0001 | 1 | 1 (`1 file changed, 8 insertions(+), 4 deletions(-)`) | 1 | 0 | OK |
| 0002 | 1 | 1 (`3 files changed, 86 insertions(+), 8 deletions(-)`) | 1 | **6**（73/73/73/73/73/74） | 可用，建议收紧到 72 |
| 0003 | 1 | 1 | 1 | **2** | 可用，建议收紧到 72 |
| 0004 | 1 | 1 | 1 | **2** | 可用，建议收紧到 72 |
| 0005 | 1 | 1 | 1 | **1** | 可用，建议收紧到 72 |
| 0006 | 1 | 1 | 1 | **5**（74/73/73/74/74） | 可用，建议收紧到 72 |

- 三处 `#462` ③ 的坑**均未复现**：没有「手写 stat 紧跟 SoB 无空行」，stat 都在 `---` 之后、`diff --git` 之前，且**只有一份**。
- 超 72 字符的 16 行全部 ≤74，checkpatch `--strict` 不报（人类评审会念）⇒ 属**可选收紧**，不阻塞；改法 = 只重排正文，不重生成 diff。
- 全部 6 枚 `From: Qianhui Xu <xiaqinghuan@mail.ustc.edu.cn>`、日期连续（10-27/10-28）、`[PATCH n/6]` 编号连续、无 cover letter。

### 5.4 checkpatch（`--strict`，stdin 跑法，6/6 + 草案 1 枚）

```
0001  0 errors, 0 warnings, 0 checks,  43 lines checked
0002  0 errors, 0 warnings, 0 checks, 151 lines checked
0003  0 errors, 0 warnings, 0 checks, 380 lines checked
0004  0 errors, 0 warnings, 0 checks, 150 lines checked
0005  0 errors, 0 warnings, 0 checks,  39 lines checked
0006  0 errors, 0 warnings, 0 checks,  37 lines checked
proposed/0007  0 errors, 0 warnings, 0 checks,  26 lines checked
```

---

## 6. 汇总与判定

### 6.1 状态表（回填 §0）

| 项 | 结果 |
|---|---|
| §1 pristine `git am` 0/6 复现 + 依赖清单 | **已证**：序列 0/6、逐枚仅 0002 可打；依赖 = 4 文件 / +822 −46，全来自下游 `0f1fb1c9c`，**上游无等价提交** |
| §2 SM8750 DSI cfg 独立表项 | **已证已是独立表项**（`dsi_cfg.c:224/251-262/415-418/435-447`），**无需改动**，故无 diff 草案 |
| §3 「调用者必须是 master」显式判据 | **已证已存在**（`dsi_manager.c:642-654`，`0005` 已含）；**交付加固草案 `proposed/0007`**（补掉残留的裸 `-EINVAL`/无日志 `-ENODEV`） |
| §4 全量编译门 + checkpatch | **已证**：从零 `-j26` rc=0 / 286.78 s / 0E 0W / `Image.gz` 19,763,145 B / dtb 410；checkpatch 6/6 + 草案 = 0E 0W 0C |
| §5 style 门禁 | ① `dt-check-style` 相关面 **rc=0**；② yamllint **未跑（工具缺失，静默跳过机制已确认）**；③ commit message **6/6 结构合格**，16 行 73–74 字符建议收紧 |

### 6.2 能否投递（一句话结论）

**不能按现状直接投上游**：6 枚依赖一整套尚未上游的 bonded 核心（D1 `dsi_manager.c`、D2 `dsi_host.c`、D3 `dsi.h`、D4 `registers/display/dsi.xml`），
pristine 7.3-rc7 上序列 0/6、且缺 D4 的位域即使文本落地也编不过。

### 6.3 建议的可行路线（登记，非本轮执行）

| # | 路线 | 代价 | 风险 |
|---|---|---|---|
| R1 | **先上游 bonded 核心**：把 `0f1fb1c9c` 的 `dsi_manager.c` + `dsi_host.c` + `dsi.h` + `dsi.xml` 部分拆成「能力层」若干枚（建议切点：①`dsi.xml` 位域；②host 侧 bonded ops + 原型；③manager 侧转发/闩锁），再把 B5 6 枚叠上去 | 大（要新写 3–4 枚提交并接受评审） | 中：核心含 SM8750 细节，上游可能要求先有 generic bonded 框架 |
| R2 | **只发 0002**（唯一 pristine 可打） | 小 | 高：单发一个"没人用"的 cfg 表项会被质疑无用户（其 `bonded` 字段无人读） |
| R3 | **不投上游，转内部树**：B5 作为 elden 分支补丁集维护，等主线出现同类 bonded 框架再 rebase | 0 | 低，但 G1「上游化」进度归零 |

推荐 **R1**，并把 `proposed/0007` 合并进 R1 之后的收尾枚（它与 0005 同主题，天然是那组的最后一条校验完善）。

### 6.4 不阻塞但值得做的三件小事

1. commit 正文 16 行收到 ≤72 字符（纯重排，不动 diff）；顺手补 cover letter（6 枚现在无 `[PATCH 0/6]`）。
2. 若要现在跑 yaml 门：`~/.local/opt/dtschema-venv/bin/pip install yamllint` 后单跑 `-f parsable -c Documentation/devicetree/bindings/.yamllint`。
3. `#462` 定式的 checkpatch 跑法要订正为 **stdin + 有树**（`--no-tree <file>` 会把 patch 当源码扫，见 §5 开头）。

### 6.5 证据与复跑

| 件 | 位置 | 是否长期 |
|---|---|---|
| pristine 树 | `/tmp/b5pf-pristine`（`git worktree add --detach /tmp/b5pf-pristine 24a19b953`，base = **24a19b953e2a3d0ea5a8c4951a0ab8f32720c907 = v7.3-rc7**） | 临时，收尾已移除 |
| 从零全量树（与 `build/b5-resoc` 同提交） | `/tmp/b5pf-proposed`（`git worktree add --detach /tmp/b5pf-proposed 481225269`） | 临时，收尾已移除 |
| 日志 | `/tmp/b5pf-logs/{am-replay,conflict-lines,fullbuild,draft-smoke,checkpatch-notree-filemode}.log` | 临时（`/tmp` 为 tmpfs，重启即失；关键数字已内联本报告） |
| 脚本 | `/tmp/b5pf-{am-replay,conflict-lines,deps,symneed}.sh` | 临时（逻辑已在 §1 描述，20 行内可重打） |
| 草案 | `patches/local/b5-resoc-20261028/proposed/0007-*.patch` | **长期（入库）** |

