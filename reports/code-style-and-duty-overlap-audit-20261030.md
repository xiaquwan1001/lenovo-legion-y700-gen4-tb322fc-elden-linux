# 代码风格 / 上游规范 / 职责重复 / 需求对齐 审计（L5）

- 日期：2026-10-31
- 性质：**只读审计**（未改动任何代码/文档/配置；未 git add/commit；未触碰设备写路径）
- 范围：`patches/upstream/**`（A1）、日常线内核增量（A2）、职责重复（B1–B7）、需求↔实现↔文档对齐（C/D）
- 证据标签：`已证`（有原文/命令输出）/`未证实`（推断）/`未上机`（有产物无实测）

## #0 一页结论

> 状态：审计完成（A1 / A2 / B1–B7 / C / D 全部落地；未覆盖项见 §E）。

### 0.1 计数

| 类别 | P0 | P1 | P2 | 合计 |
|---|---|---|---|---|
| A 上游规范不合规（A1 `patches/upstream/**` + A2 日常线增量） | **4** | 9 | 9 | **22** |
| B 职责重复/冲突 | **2** | 5 | 8 | **15** |
| C 需求与实现对不上 | **3** | 3 | 3 | **9** |
| D 缺失 | **1** | 4 | 3 | **8** |
| **合计** | **10** | **21** | **23** | **54** |

- A1 机械门实测总账：**108 个 `*.patch` → 81 个 0/0/0，合计 1 E / 35 W / 10 C**（其中 24 W 是 4 类已知假阳性）⇒ **实质待修 = 1 E + 11 W + 10 C**。
- 22 个有自检记录的系列里，**18 个 checkpatch 自报与实测完全一致**；不一致的集中在 `m1-2026-10-14`（Fixes 指向错 commit + 原因描述错）与 `phoc-im-keyboard-grab`（唯一带 ERROR 且从无门禁记录）。
- 设备实测（只读）推出的最重要一条：**在机镜像的 DTB 缺 `qcom,non-secure-domain`**（源码里有、但只是 `build/vk151` 未提交的工作区改动）⇒ `/dev/fastrpc-adsp` 不存在 ⇒ `hexagonrpcd` failed ⇒ `HasAccelerometer/AmbientLight/Proximity` **三全 false**，而 `TASKS/README.md` G1-34 仍写 ✅ 三真。

### 0.2 Top 10 必须先修

| # | 编号 | 一行 |
|---|---|---|
| 1 | **A1-11** | `patches/upstream/**` 的**门禁命令本身**在仓库根下会静默降级：同一枚 patch 从仓库根跑得 `3 errors/63 lines`（把补丁当源码，patch 级检查全跳过），从 `/tmp` 跑得真实 `1 error/8 warnings/16 lines` ⇒ 历史上任何「仓库根跑出 0E/0W/0C」都不足为凭。门禁命令改成 `cd /tmp`。 |
| 2 | **C-08 / D-01** | `build/vk151` 是 **11 文件 / +546 −32 的脏工作区**（含 `qcom,non-secure-domain`、Q28 闩锁、MDSS reset、b5 魔数改名、M9 的 +249 行、kexec 诊断）⇒ 日常线镜像不可复现，且在机镜像因此**没有** `qcom,non-secure-domain`。先落提交，再重编重刷（需用户在场）。 |
| 3 | **C-01 / C-02** | 传感器链在**当前这一发**是死的（三属性全 false、`hexagonrpcd` failed、`qrtr-lookup` 无 svc 400），而 `TASKS` G1-34 写 ✅。修完 #2 后按 D-01 的四条判据复验，再回填文档。 |
| 4 | **A2-01** | `dsi_phy_7nm.c:437,459` 有 `of_machine_is_compatible("lenovo,elden")` 板名判定 —— 项目自己 §2 Q3 红线的正命中，而 `m1-2026-10-14/0001` 改的就是这个文件 ⇒ 投出去必被拒。改成 DT 属性或 per-SoC 表字段。 |
| 5 | **A1-01 / A1-02** | `m1-2026-10-14/0001` 的 `Fixes: 44784327815b ("drm/msm/dsi: phy: rework PLL bias enable/disable")` —— 该 hash 实际是 `Revert "drm/msm: dsi: fix PLL init in bonded mode"`（Dmitry, 2026-07-12）；且 README 把这条告警写成「Unknown commit id / partial clone 良性」，与实测不符。 |
| 6 | **B7-01 / B7-02** | `scripts/check-abi-config.sh` 默认目标是已退役的 `build/m1-73/.config`（不是 `patches/current-tree` 指的 vk151）⇒ 裸跑必过；而 `build/m4-base/.config` 实测 **FAIL 3 项**（`CONFIG_SUSPEND`/`PM_SLEEP`/`PM_SLEEP_SMP=y`），`MODVERSIONS=n` 拦不住 ⇒ 相机模块热推会静默 ABI 错位。 |
| 7 | **B3** | `ucsi.c:1860-1867` 把 `-EPROBE_DEFER` 消费掉（置 NULL + `goto out_put`），而 PPM 层 `:2244-2259` 本就有 10 s 重试环 ⇒ 两层对「等 role switch」不对称，connector 注册永不重试。让 defer 上抛即可，别再加第三处重试。 |
| 8 | **B4** | Q28 看门狗「四套机制」实况：硬件 WDT `permanently disabled`、无 `/dev/watchdog`、`WatchdogSec` 零使用；唯一活体 `q28-boot-watchdog` 被 cmdline `elden_q28_nowd` 关掉（`count=0`）；同一脚本在仓内有 **2 份同 sha 副本 + 1 份 heredoc + 1 条 MANIFEST**，「设备侧唯一源」不成立。 |
| 9 | **B5** | 生成链（`services.tsv`+`render.py`）只管到 `/usr/lib`，**19/19 生成单元在设备上逐字节一致、未被改**；真正的覆盖全在 `/etc/…/service.d/` 的 3 个 drop-in（2 个由 `rootfs/debian/stage.sh` heredoc 写死、1 个手写），greetd 叠 **4 层、3 层改 `ExecStart`**，净效果与生成值逐字相同 ⇒ 改 `services.tsv` 时会被 drop-in 静默盖回。 |
| 10 | **A1-07 / A1-08 / D-02 / D-06** | `patches/upstream/` 缺隔离区：`m3v5-20261030`/`m3v5-fix-20261030` **无 README**；`m4-camss-series-20261027/0007-NOT-FOR-UPSTREAM-*` 与可投补丁同级；`q28-dispcc-2026-10-22`（形状已被否）、`aw86927-20261027`（已被 v2 取代）、`m4-camss-2026-10-13/*.patch`（SOB = `Elden Mainline Agent <elden-mainline@localhost>`）都还在 glob 可达处。 |

### 0.3 三条「已核实为无问题」的正面结论（避免重复审计）

1. **b5 的 bonded 表已不挂 `sm8650_dsi_cfg`**：`build/b5-resoc/dsi_cfg.c:224-262` 有独立 `sm8750_dsi_bonded_cfg` + 独立 `sm8750_dsi_cfg`（`.compatible`）+ 独立表项；任务书怀疑点的旧形状只在已废弃的 `m6-b5-p4-20261026/`。
2. **Q34 的 A2 固件门禁真的存在且真的会 FAIL**：`rootfs/debian/elden-firmware/build.sh:222-270`；设备 `/lib/firmware/qca/` 已含 `tmel_peach_20.elf`。该脚本还显式记录了「用 `-d` 判 `.git` 会让门禁永远通过」的坑（本仓唯一处理了「门禁静默跳过」的地方）。
3. **G1-34 的 udev 门禁真的存在**：`files/etc/udev/rules.d/81-libssc-elden.rules` + `MANIFEST.tsv:20 kind=udev-rule` + `tools/verify.sh:157-167` §E 红线。它没生效是因为更上游的 D-01 断点。

---

## §A 风格与上游规范

### A1 `patches/upstream/**` 全量机械门（最高优先）

#### A1.0 方法与总账

- 内核树 checkpatch：`build/vk151/scripts/checkpatch.pl`（**Version 0.32**，与 7.3 树同源；`build/m3v2-7.3rc7/scripts/checkpatch.pl` 结果一致）。
- 命令（**注意工作目录**，见 A1-11）：
  ```sh
  cd /tmp   # 不能在 y700-elden 仓库内！
  for p in $(find /home/xuqianhui/y700-elden/patches/upstream -name '*.patch' | sort); do
    perl /home/xuqianhui/y700-elden/build/vk151/scripts/checkpatch.pl --strict --no-tree "$p"
  done
  ```
- **实测总账（108 个 `*.patch` 文件，含 cover letter 与本 lane 未预期的子目录）**：

  | 项 | 值 |
  |---|---|
  | 文件数 | 108 |
  | 0/0/0 干净 | 81 |
  | ERROR 合计 | **1** |
  | WARNING 合计 | **35** |
  | CHECK 合计 | **10** |

  折算「真实补丁级缺陷」= **1 E / 35 W / 10 C**；其中 **24 W 属于 4 类已知假阳性/环境噪声**（下表逐条标注），**实质待修 = 1 E + 11 W + 10 C**。
- 复核说明：早先以仓库根为工作目录跑出的「全 0」是**假阴性**（见 A1-11），本报告全部数字来自 `/tmp` 工作目录的复跑。

#### A1.1 非零条目逐项清单

> 假阳性判据：`--no-tree` 下 checkpatch 无法读 `MAINTAINERS`，故「added, moved or deleted file(s), does MAINTAINERS need updating?」在 `--no-tree` 下**恒为假阳性**；`create mode …` 行超过 75 列触发的 `Prefer a maximum 75 chars` 同理（diffstat 行不受 75 列规则约束）。

| 编号 | 严重度 | 位置 | 实测（E/W/C） | 证据（原文） | 规范依据 | 建议修法 | 阻塞投递 |
|---|---|---|---|---|---|---|---|
| A1-01 | **P0** | `patches/upstream/m1-2026-10-14/0001-drm-msm-dsi-phy-program-PLL_SYSTEM_MUXES-on-the-firs.patch:17` | 0/1/0 | `Fixes: 44784327815b ("drm/msm/dsi: phy: rework PLL bias enable/disable")`；checkpatch：`WARNING: Please use correct Fixes: style 'Fixes: <12+ chars of sha1> ("<title line>")' - ie: 'Fixes: 44784327815b ("Revert "drm/msm: dsi: fix PLL init in bonded mode"")'`；`git -C build/m3v2-7.3rc7 log -1 44784327815b` → `Revert "drm/msm: dsi: fix PLL init in bonded mode"` / `Dmitry Baryshkov` / `2026-07-12` | checkpatch `FIXES_TAG`/`BAD_FIXES_TAG` 规则；上游惯例 = hash 与被引 commit 的 subject 必须逐字一致 | 把 `Fixes:` 改指**真正引入 `pll->pll_enable_cnt = 1` 预置**的那个 commit（不是那枚 Revert），或其 Revert 的原文 subject；若定不到 hash 就删掉 `Fixes:` 改正文叙述 | **是** |
| A1-02 | P0（**文档/实测不一致**） | 同上系列 `README.md:36`、`README.md:49` | — | README 称「唯一 W = `Unknown commit id '44784327815b'`（partial clone 无该对象，**已知良性**）」；实测该对象**在本地树存在**（`git -C build/m3v2-7.3rc7 cat-file -t 44784327815b` → `commit`），告警文案也不是 `Unknown commit id` 而是 `Please use correct Fixes: style` | 本 lane 任务书 §A1「声称 vs 实测不一致 ⇒ P0」 | 修 README 的门禁行，并连同 A1-01 一起改 | **是** |
| A1-03 | P1 | `patches/upstream/phoc-im-keyboard-grab-2026-10-18/0001-…-d.patch` | **1/8/2** | `ERROR: Please use git commit description style 'commit <12+ chars of sha1> ("<title line>")' - ie: 'commit 0123456789ab ("input-method-v2: Destroy keyboard grab before input method")'`；`WARNING: Unknown commit id '06275103'`（**8 hex，不足 12**）；正文另见 3×`no spaces at the start of a line`、2×`suspect code indent`、`Block comments use a trailing */ on a separate line` | checkpatch `COMMIT_LOG_USE_LINK`/`GIT_COMMIT_ID` 族规则；`Documentation/process/submitting-patches.rst` | 补足 12+ hex，正文改成 `commit <sha> ("<subject>")` 形式；修 3 处行首空格与缩进；**该系列是全仓唯一遗留的 1 E** | 是（若仍计划投递） |
| A1-04 | P1 | `patches/upstream/phoc-im-keyboard-grab-2026-10-18/0001-…-d.patch:…Signed-off-by` | — | `Signed-off-by: Xu Qianhui <xuqianhui1001@mail.ustc.edu.cn>`，而 `git config user.email` = `xiaqinghuan@mail.ustc.edu.cn` | 项目自身 `patches/upstream/README.md` §3「`Signed-off-by: Xu Qianhui <xiaqinghuan@mail.ustc.edu.cn>`」 | 统一身份（选 u1001 也行，但必须与 `git config user.*` 和其余 27 个系列一致） | 是 |
| A1-05 | P1 | `patches/upstream/m6-b5-p4-20261026/0001-drm-msm-dsi-bonded-broadcast-command-path-for-sm8750.patch` | 0/1/8 | `WARNING: line length of 101 exceeds 100 columns`；`CHECK: usleep_range is preferred over udelay`；`CHECK: Please don't use multiple blank lines` ×6；`CHECK: Please use a blank line after function/struct/union/enum declarations` | checkpatch `LONG_LINE`(>100 硬规则)、`USLEEP_RANGE`、`MULTIPLE_BLANK_LINES`、`LINE_SPACING` | README 已把 `udelay` 辩解为「Q28 现场语义原样保留」——上游不接受该理由（`usleep_range(10,20)` 在 500×10µs 轮询下等价且更省电）；建议改 `usleep_range` + 清理多空行；`dsi.xml.h` 101 列需改 XML 源而非生成文件 | 是（该系列要投） |
| A1-06 | P1 | `patches/upstream/aw86927-20261027-v2/0001-Input-aw86927-fix-the-7-V-boost-reference-for-AW8693.patch:14` | 0/1/0 | `Fixes: df53055c540f ("Input: aw86927 - add support for Awinic AW86938")`；checkpatch `WARNING: Unknown commit id 'df53055c540f', maybe rebased or not pulled?`；**实测该对象在全部 8 棵本地树中都缺失**（含 20264 提交的 `build/m3v2-7.3rc7`、非 shallow 的 `build/base-7.2`/`Y700-elden-linux`），不只是 shallow | checkpatch `UNKNOWN_COMMIT_ID` | 该 hash 由 `PITFALLS/sessions/112-投递前必须对linux-next核对.md:41` 记载为 lore 核过；本轮 lore 复核通道失效（见 §E），**未能独立复证**。发前用任何可达通道再核一次；核不到就改正文叙述不写 `Fixes:` | 否（弱阻塞：审稿人若发现会要求重发） |
| A1-07 | P1 | `patches/upstream/m3v5-20261030/`、`patches/upstream/m3v5-fix-20261030/` | 0/0/0 | 两个目录**既无 `README.md` 也无 cover letter**（`find … -name README.md` 无命中）；`m3v5-fix` 的 `Subject:` 是 `[PATCH 1/2]`（v1 编号）而内容是 v5 的 fix-up | `patches/upstream/README.md` §3「系列 README.md 必须写：补丁清单、每枚设计取舍、验收命令+原始输出、收件人、发送状态」 | 补 README（按 m3-v4 模板），并把 `m3v5-fix` 明确标成「v5 的 fixup，并入 v6」或直接删；否则 glob 发送会以 v1 名义发出 | 是（要发就会撞） |
| A1-08 | P1 | `patches/upstream/m4-camss-series-20261027/0007-NOT-FOR-UPSTREAM-csid-vfe-pairing.patch` | 0/0/0 | 文件名自述 `NOT-FOR-UPSTREAM`，却与 6 枚可投补丁同目录 | `patches/upstream/README.md` §1 的发送命令用 `$SER/*.patch` glob | 移到 `patches/local/` 或改名加 `.skip` 后缀；否则 `git send-email $SER/*.patch` 会把它一起发出去 | 是 |
| A1-09 | P2 | `patches/upstream/m4-camss-2026-10-13/0001-gt9764.patch`、`0002-wl2868c.patch`、`0003-s5kjns.patch` | 0/0/0 | 三枚的 `Signed-off-by: Elden Mainline Agent <elden-mainline@localhost>`（机器身份、`@localhost` 域） | `Documentation/process/submitting-patches.rst` §Sign your work；checkpatch `NO_AUTHOR_SIGN_OFF` 不报只是因为 `From:` 也是同一机器身份 | 这三枚已被 `m4-camss-2026-10-13/sent-20261027/` 取代（后者 SOB 正确）；建议把 `m4-camss-2026-10-13/*.patch` 全部下沉到 `superseded/` 子目录 | 否（现状是归档污染 + glob 风险） |
| A1-10 | P2 | 12 个 cover letter（`m3-*`/`m4-*`/`wl2868c-*`） | — | `grep -c '^Signed-off-by:'` = 0；`sep---count=0`（无独立 `---` 分隔行） | 上游 cover letter 惯例（`git format-patch --cover-letter` 生成物默认带 SOB；多数 maintainer 会顺手 require 一致签名链） | 用 `git format-patch --cover-letter -N` 重新生成 cover，或手工补 SOB | 否 |
| A1-11 | **P0（方法论/门禁命令本身有缺陷）** | `patches/upstream/README.md:16`（门禁命令） | — | 同一枚 patch 换工作目录得到**完全不同的结果**：<br>仓库根：`total: 3 errors, 0 warnings, 0 checks, 63 lines checked`（3 条 ERROR 全是 diff 上下文的尾随空格，**patch 级检查全部被跳过**）<br>`/tmp`：`total: 1 errors, 8 warnings, 2 checks, 16 lines checked`（真实结果）<br>根因：`build/vk151/scripts/checkpatch.pl:1338` `git_is_single_file()` → `git ls-files -- $filename 
` 命中仓库内被跟踪的 `*.patch` ⇒ `$file = 1`，checkpatch 把补丁当**源码文件**扫 | checkpatch 源码 `sub git_is_single_file`；`$is_patch` 在 `$in_commit_log` 分支里永远不被置位 ⇒ 末尾 `if (!$chk_patch && !$is_patch) { exit(0) }` 之前就已走完「源码文件」路径 | 门禁命令改成 `cd /tmp && perl <tree>/scripts/checkpatch.pl --strict --no-tree <abs-path>`，或在 README §1 加一行硬提醒；并把「lines checked」当自检指纹（源码模式 = 整个文件行数，补丁模式 = 新增行数） | **是**（历史上任何用仓库根跑出的「0E/0W/0C」都不足为凭） |
| A1-12 | P2 | `patches/upstream/q28-dispcc-v2-20261029/` | 0/0/0 | 目录内只有 `0001..0003`，**无 `0000-cover-letter.patch`**；但 `SENT.md:16` 声称「v2 0/3 cover」Message-ID = `20261029123238.29877-1-…` | 本 lane 任务书「`---` 之后的 diffstat 与实际一致 / cover letter 存在性」 | 从 `git format-patch --cover-letter` 重新导出补齐 0000，否则归档与实物不一致 | 否（已发，仅归档完整性） |
| A1-13 | P2 | `patches/upstream/m3-v4-20261026/0000-cover-letter.patch:9` | 0/1/0 | `WARNING: Prefer a maximum 75 chars per line` → 该行 **114 列**：`and it contains the driver that uses the binding it describes.  Sorry for the confusion caused by sending v3 as an` | checkpatch `LONG_LINE_COMMIT`（commit log ≤75） | 重折行（`m3-v4-20261026/README.md` 也自报「0E/0W/0C on all three patches」，没把 cover 计入） | 否 |
| A1-14 | P2 | 3 个系列 cover letter 的 diffstat 行 | 0/1/0 each | `m4-camss-series-20261028`、`-v2`、`-029-v3`、`wl2868c-*` 的 cover 里 `create mode 100644 …yaml` 行 >75 列 | 假阳性（diffstat 行不受 75 列约束） | 无需修；但 README 引用 checkpatch 数字时应显式排除 | 否 |

#### A1.2 系列「声称 vs 实测」并排（不采信自报）

> 实测 = 本 lane 在 `/tmp` 下对目录内**全部** `*.patch` 复跑 `--strict --no-tree` 的结果。

| 系列 | 文档声称（原文位置） | 实测 | 判定 |
|---|---|---|---|
| `aw86927-20261027`（v1） | 5/5 `0E/0W/0C`（`README.md:26-30`） | 5/5 = 0/0/0 | ✅ 一致 |
| `aw86927-20261027-v2` | 0001 `0E + 1W`（shallow 认不到 Fixes）；其余 4 枚 `0E/0W/0C`（`README.md:29-33`） | 完全一致（0001 = 0/1/0，其余 0/0/0） | ✅ 数字一致 / ❌ **原因描述错**（A1-02） |
| `m1-2026-10-14` | `0E/1W/0C`，W = `Unknown commit id`（`README.md:36`） | `0E/1W/0C`，W = `Please use correct Fixes: style` | ❌ **原因描述错 + Fixes 指向错 commit**（A1-01/A1-02） |
| `m1-pas-dtbfw-20261027` | `0 errors, 0 warnings, 0 checks, 30 lines`（`README.md:20`） | 0/0/0，30 lines | ✅ 一致（行数都对上了） |
| `m2-2026-10-13` | `0 errors / 0 warnings`（`README.md:11`） | 2 枚 0/0/0 | ✅ |
| `m3-2026-10-13` | 3/3 `0E/0W/0C`（`README.md:24`）、4/4 `0E/0W`（`:62`） | 0000-0003 全 0/0/0 | ✅ |
| `m3-3-2026-10-13` | 2/2 `0E/0W/0C`（`README.md:22`） | 2/2 0/0/0 | ✅ |
| `m3-4-2026-10-13` | 4/4 `0 errors, 0 warnings`（`README.md:28`） | 4/4 0/0/0 | ✅ |
| `m3-6-2026-10-13` | 0001/0002 `0E/0W/0C`（`README.md:15`） | 2/2 0/0/0 | ✅ |
| `m3-v2-2026-10-17` | 2 枚 `0E/0W/0C`（`README.md:27`） | 0001/0002 0/0/0；**0000 cover 0/1/0** | ⚠️ 补丁一致；cover 未计入 |
| `m3-v3-2026-10-19` | 0001 `0E/0W/0C`(129 行)/0002 `0E/0W/0C`(58 行)（`README.md:31`） | 0001/0002 0/0/0；0000 cover 0/0/0 | ✅ |
| `m3-v4-20261026` | 「`checkpatch --strict`: 0 errors, 0 warnings, 0 checks on all three patches」（cover letter `:146`） | 0001-0003 0/0/0；**0000 cover 0/1/0** | ⚠️ 补丁一致；「all three」措辞回避了 cover |
| `m3v5-20261030` / `m3v5-fix-20261030` | **无 README** | 各 2 枚 0/0/0 | ❌ **无声称可核**（A1-07） |
| `m4-camss-2026-10-13` | 0001/0002/0003 `0E/0W/0C`（83/79/132 行）（`README.md:23-25`） | 三枚 0/0/0（**但 SOB 是机器身份**，A1-09） | ⚠️ 数字一致、身份不合格 |
| `m4-camss-2026-10-13/sent-20261027` | 未单列 | 0000 cover 0/1/0（长行），0001/0002 0/0/0 | ⚠️ |
| `m4-camss-fixes-20261029` | `GATES.md` 记录 | 0000 cover 0/0/0，0001-0003 0/0/0 | ✅ |
| `m4-camss-series-20261027` | 「0 errors；3 条 WARNING 全是同一假阳性（0003/0005/0006）」（`README.md:47`） | 7 枚：0003/0005/0006 各 1 W（`MAINTAINERS need updating?`），其余 0/0/0 | ✅ **完全一致** |
| `m4-camss-series-20261028` | 「0 errors / 0 checks；3 条 WARNING 假阳性（1/4/8）」（`README.md:46`） | 9 枚：0001/0004/0008 各 1 W；**另 0000 cover 1 W** | ✅ 补丁级一致 / ⚠️ cover 未计入 |
| `m4-camss-series-20261028-v2` | 同上模板 | 0001/0004/0008 各 1 W；0000 cover 1 W | ✅/⚠️ |
| `m4-camss-series-20261029-v3` | 「9/9：0 errors / 0 checks；3 条 WARNING 全为同一假阳性（patch 1/4/8）」（`README.md:28`） | 0001/0004/0008 各 1 W；0000 cover 1 W（`- csid 980: …` 长行） | ✅ 补丁级一致 / ⚠️ cover 未计入 |
| `m6-b5-p4-20261026` | 「0 errors / 1 warning / 8 checks」（1119 行）（`README.md:75`） | `0 errors, 1 warnings, 8 checks, 1119 lines` | ✅ **逐字一致** |
| `m-gic-its-claim-20261024` | `0 errors, 0 warnings, 0 checks`（73 行）（`README.md` §3） | 0/0/0，73 lines | ✅ |
| `phoc-im-keyboard-grab-2026-10-18` | 无 README 门禁表 | **1/8/2** | ❌ 唯一带 ERROR 的系列且无自检记录 |
| `q28-dispcc-v2-20261029` | `GATES.md` §2：0001/0002/0003 = `0 errors, 0 warnings, 0 checks`（22/31/10 行） | 三枚全 0/0/0（行数一致） | ✅ 逐字一致；但目录缺 cover（A1-12） |
| `wl2868c-driver-20261028` / `-v2-20261029` / `-v2b-20261030` | 未见门禁数字 | 0000 cover 各 1 W（`create mode` 长行，假阳性）；v2b 0003 另有 **`DT binding docs and includes should be a separate patch`** | ❌ **v2b 0003 把 binding 与 DTS 混在一枚里**（真实规范问题） |

**结论**：绝大多数系列的 checkpatch 自报是**可信的**（22 个系列里 18 个完全一致）。真正的问题集中在 (a) `m1-2026-10-14` 的 Fixes 指向错 + 原因描述错；(b) `phoc-im-keyboard-grab` 从未过门；(c) 两个 m3v5 目录无任何自检记录；(d) 门禁**命令本身**在仓库根下会静默降级（A1-11）。

#### A1.3 头部字段机械核对（Subject/body/SOB/Fixes/Link/Reported-by/diffstat）

| 项 | 实测结果 | 判定 |
|---|---|---|
| Subject ≤72 字符 | 仅 1 处超：`q28-dispcc-2026-10-22/0001-…` = **94 字符**（`clk: qcom: dispcc-sm8750: reset the MDSS blocks at probe when the bootloader left them running`） | P2（该枚已被 v2 取代，仅归档问题） |
| body 每行 ≤75 | 除 cover letter 的 diffstat 行（假阳性）外，checkpatch 只报了 `m3-v4` cover:9（114 列，真实）与 `phoc` 1 处 | 见 A1-13/A1-03 |
| `Signed-off-by:` 与 `git config user` 一致 | `git config user` = `Qianhui Xu / xiaqinghuan@mail.ustc.edu.cn`。**28 枚用 `Xu Qianhui`**（名序颠倒，同一邮箱）、**3 枚用 `Elden Mainline Agent <elden-mainline@localhost>`**、**1 枚用 `xuqianhui1001@`**、**12 枚 cover letter 无 SOB** | P2（名序）+ P1（A1-09/A1-04） |
| `Fixes:` 格式（12 hex + 括号 subject） | 全仓只有 2 处 `Fixes:`（A1-01、A1-06），**两处都有问题** | P0/P1 见上 |
| `Link:` / `Reported-by:` / `Closes:` | `grep -rln '^\(Link\|Reported-by\|Closes\|Suggested-by\):'` → **0 命中**（整个 `patches/upstream/` 无一条） | P2：不是硬规则，但 `m-gic-its-claim`（跨 kexec 行为变更）与 `m1-pas-dtbfw`（leak fix）类补丁缺 `Link:` 会被问「证据在哪」 |
| cover letter `---` + `Changes in vN`（v2+ 必须有） | v2+ 的 cover 共 8 个：`m3-v2`(1 块)、`m3-v4`(**0 块**)、`m4-camss-20261028`(0)、`-v2`(1)、`-029-v3`(2)、`wl2868c-driver`(0)、`-v2`(0)、`-v2b`(0) | ❌ **`m3-v4` 是 v4 却完全没有 `Changes in vN:` 块**（只有正文里一段散文「The v4 changes are the review fixes listed above」）；`m4-camss-series-20261028`（v1→v2 之间）也是 0 块。P1 |
| `---` 之后的 diffstat 与实际一致 | `m1-pas-dtbfw` 声称 30 行 = 实测 30 行；`m6-b5-p4` 1119 = 1119；`q28-dispcc-v2` 22/31/10 = 22/31/10；`m4-camss-029-v3/0001` 435 = 435 | ✅ 抽样 5 个全对，未发现 diffstat 漂移 |

---

## §B 职责重复 / 冲突

> 每条格式：**现状 → 冲突后果 → 建议唯一归属**。
> 设备侧证据全部来自 `ssh root@192.168.7.1`（只读），内核 `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`，`hostname=elden`。

### B5 生成链被手工覆盖（`services.tsv`+`render.py` ↔ `rootfs/debian/stage.sh` drop-in）

| 项 | 内容 |
|---|---|
| 编号 | B5 |
| 严重度 | **P1** |
| 位置 | `packaging/elden-userland/services.tsv`（19 行服务定义 + 表头 24 行）+ `packaging/elden-userland/tools/render.py` ↔ `rootfs/debian/stage.sh:134-141,177-186,211-260` ↔ 设备 `/etc/systemd/system/*.service.d/*` |
| 证据 | **① 生成物全部逐字节落地，未被改**（19/19）：<br>`for f in packaging/elden-userland/out/units/systemd/*.service; do ssh … sha256sum /usr/lib/systemd/system/$n; done` → 19 个 `same`，0 个 `DIFFERS`、0 个 `MISSING-ON-DEVICE`。<br>**② 设备上只有 3 个 drop-in 目录**：<br>`ls /etc/systemd/system/*.service.d` → `accounts-daemon.service.d{zz-elden.conf}`、`greetd.service.d{zz-elden.conf, zz-stop.conf}`、`hexagonrpcd.service.d{elden.conf}`。<br>**③ 3 个 drop-in 里有 2 个由 `rootfs/debian/stage.sh` 的 heredoc 写死**（文件首行 `# GENERATED by rootfs/debian/stage.sh — DO NOT EDIT`），**不是 render.py 产物**：<br>`grep -n 'zz-elden' rootfs/debian/stage.sh` → `134: mkdir -p … greetd.service.d` / `135: cat > … zz-elden.conf <<-EOF` / `140: ExecStart=/usr/sbin/greetd --config /etc/greetd/config.toml` / `177: … accounts-daemon.service.d`。<br>**④ greetd 的生效链有 4 层、3 层改 `ExecStart`**（`systemctl cat greetd`）：<br>L1 `<render.py>` `/usr/lib/systemd/system/greetd.service`：`ExecStart=/usr/sbin/greetd --config /etc/greetd/config.toml`<br>L2 `<Debian 包 greetd-phrog>` `…/greetd.service.d/phrog.conf`：`ExecStart=` + `ExecStart=greetd --config /etc/greetd/phrog.toml`<br>L3 `<stage.sh 生成>` `/etc/…/greetd.service.d/zz-elden.conf`：`ExecStart=` + `ExecStart=/usr/sbin/greetd --config /etc/greetd/config.toml`<br>L4 `<手写>` `/etc/…/greetd.service.d/zz-stop.conf`：`TimeoutStopSec=5` / `SendSIGKILL=yes` / `ExecStop=-/usr/local/libexec/elden/greetd.stop`<br>**⑤ 净效果 = 零**：`systemctl show -p ExecStart greetd` → `argv[]=/usr/sbin/greetd --config /etc/greetd/config.toml`，**与 L1 渲染值逐字相同**。也就是说 L2+L3 这两层叠加的唯一作用，是把 Debian 包的 phrog.conf 抵消回 render.py 本来就写好的值。<br>**⑥ `services.tsv` 的两行在实际设备上根本不是「自己的 unit」**：<br>`systemctl show -p Names hexagonrpcd` → `Names=hexagonrpcd.service hexagonrpcd-adsp-sensorspd.service`；`ls -l /etc/systemd/system/hexagonrpcd-adsp-sensorspd.service` → 符号链接 → `…/hexagonrpcd.service`（**包 unit + 别名**）。render.py 对 `init=package` 行不产生 unit（`ls out/units/systemd | grep hexagon` → 空），该服务真正的语义（`RestrictAddressFamilies=AF_QIPCRTR` / `PrivateNetwork=no` / `hexagonrpcd_extra=-s`）**只存在于 stage.sh 的 heredoc**，`services.tsv` 里一个字都没有。<br>**⑦ `accounts-daemon` 完全不在 `services.tsv`**（`grep accounts packaging/elden-userland/services.tsv` → 0 命中），只有 stage.sh 的 heredoc。<br>**⑧ stage.sh 自己还给这个 heredoc 写了断言**：`stage.sh:398` `grep -q "hexagonrpcd_extra=-s" "$STAGE/etc/systemd/system/hexagonrpcd.service.d/elden.conf"` —— 即「唯一真源」的校验被复制到了第二个文件里。 |
| 冲突后果 | ① **声明与现实脱节**：`services.tsv` 头注释写「服务语义唯一真源（人工维护；render.py 渲染两种 init，verify.sh 校验）」，实际有 **4 类语义**（greetd 的 ExecStart、accounts-daemon 的 After、hexagonrpcd 的 sandbox 放宽、greetd 的 stop 语义）**完全在真源之外**；`verify.sh` 校验不到它们。<br>② **静默失效面**：若将来改 `services.tsv` 里 greetd 的 `exec`/`args`，regen 只会改 L1，L3 的 `zz-elden.conf` 仍会**逐字节覆盖**回老值——且没有任何门禁会报错（`render.py --check` 只比 out/ 与 tsv）。这是「生成链被手工 drop-in 覆盖」的**可复现事故模型**，greetd 就是现成样本。<br>③ **drop-in 数量已超出注释口径**：`zz-stop.conf`（2026-10-30 新增，来源 `reports/shutdown-greetd-hang-plan-20261031.md` §3.1）既不在 stage.sh 也不在 services.tsv，属第三种落点，`systemctl cat` 才能看到。<br>④ 顺序脆弱：`zz-elden.conf` / `zz-stop.conf` 同前缀字典序 → 现在靠 `zz-e < zz-s` 保证 stop 后应用；改名就翻转。 |
| 建议唯一归属 | **把「发行版单元覆盖」提升为 `services.tsv` 的一等公民**，消灭 heredoc：<br>1. 新增 `packaging/elden-userland/dropins/` 目录，按 `<unit>.d/<file>.conf` 布局存**数据文件**（非 heredoc），`render.py` 负责 `install -D` 到 `/etc/systemd/system/`；<br>2. `services.tsv` 增列 `dropin`（相对路径或空），`init=override/package` 行必须填；<br>3. `render.py --check` 增加「设备上 `/etc/systemd/system/<unit>.service.d/` 的文件集 == dropins/ 声明集」的比对（可用 `systemctl cat` 或 `ssh` 拉取后 sha256 比）；<br>4. 删掉 `stage.sh` 的三段 heredoc 与 `stage.sh:398` 的重复断言；<br>5. **greetd 的 L2/L3 应合成一条并写进真源**：`clean ExecStart` 的语义（「清空包内 ExecStart 再重设」）必须作为数据表达（例如 `exec_clear=1`），否则任何人重排 drop-in 就会退回 phrog。<br>落点：`packaging/elden-userland/{services.tsv,dropins/,tools/render.py,README.md}`；`rootfs/debian/stage.sh` 只保留 `install -D` 调用。 |
| 阻塞上游投递 | 否（纯用户态打包层，不进内核） |

**B5 附带发现（同属生成链漂移，独立一条）**

| 编号 | 严重度 | 位置 | 证据 | 建议 |
|---|---|---|---|---|
| B5b | P2 | `packaging/elden-userland/provides.tsv`（仅 1 条数据行）vs 设备 | `provides.tsv` 只登记 `greetd → display-manager`；但设备上还存在 `hexagonrpcd-adsp-sensorspd → hexagonrpcd` 别名（`ls -l /etc/systemd/system/hexagonrpcd-adsp-sensorspd.service`），来源是 stage.sh 的 `ln -s`/包，**未登记**。`services.tsv` 里 `hexagonrpcd-adsp-sensorspd` 这个名字只有靠这条未登记别名才存在。 | 把 `hexagonrpcd-adsp-sensorspd → hexagonrpcd` 写进 `provides.tsv`，或把 `services.tsv` 的名字改成包真名 `hexagonrpcd` 并在 dropin 声明里说明。 |

### B1 显示 / MDSS 复位：几处在复位同一组 BCR？

| 项 | 内容 |
|---|---|
| 编号 | B1 |
| 严重度 | **P2（已收口，仅留一句口径硬化）** |
| 位置 | `build/vk151/drivers/gpu/drm/msm/msm_mdss.c:321-395`（`msm_mdss_reset()`）、`:438`（唯一调用点）；`build/vk151/arch/arm64/boot/dts/qcom/sm8750.dtsi:3332-3335` |
| 现状（全链实测） | **日常线里复位同一组 BCR 的地方只有 1 处。**<br>① `grep -rn MDSS_CORE_BCR --include=` 在 **C 代码里 0 命中**（只有 19 个 `include/dt-bindings/clock/qcom,*dispcc*.h` 的常量定义）。<br>② `grep -rn 'reset_control_\(assert\|deassert\|reset\)' drivers/gpu/drm/msm/` → 只有 `msm_mdss.c:339` / `:345` 两行，都在 `msm_mdss_reset()` 内。<br>③ `grep -rn msm_mdss_reset` → 定义 `:321` + **唯一调用** `:438`（`msm_mdss_init()` 第一件事）。<br>④ `grep -n reset drivers/clk/qcom/dispcc-sm8750.c` → 只有 `disp_cc_sm8750_resets[]` 表与 `.resets/.num_resets` 注册（`:1868,1891,1892`），**probe 里没有任何 assert/deassert** ⇒ 2026-10-22 那版 RFC（`patches/upstream/q28-dispcc-2026-10-22/`，dispcc probe 复位）**已不在日常线**。<br>⑤ DT 单点声明：`sm8750.dtsi:3332` `resets = <&dispcc DISP_CC_MDSS_CORE_BCR>, …` + `:3335` `reset-names = "core", "core_int2", "rscc"`；`sm8750-lenovo-elden.dts` 的 `&mdss`（`:2349`）**没有**再写 `resets`。<br>⑥ `grep -rln 'MDSS_CORE_BCR\|dispcc.*reset' scripts/ rootfs/ packaging/` → **0 命中**（没有 shell/initramfs 层复位）。<br>⑦ 复位实现用 `devm_reset_control_bulk_get_shared()`（历史 `-EBUSY` 教训见 `TASKS/README.md` §5 Q28「★上机冒烟」）。 |
| 冲突后果 | 无现存冲突。**残留风险**：`TASKS/README.md` §5 Q28 与 `reports/q28-v2-mdss-reset-20261023.md` 里同时保留了「0154 = dispcc probe 复位」与「v2 = mdss 侧复位」两套描述，且 `patches/upstream/q28-dispcc-2026-10-22/` 仍在 `patches/upstream/` 下可被 glob 发送——读者/自动化都可能把**已废弃的 v1 形状**当现状。 |
| 建议唯一归属 | 归属已正确收敛到 **display 侧 `msm_mdss_reset()` + DT `reset-names`**（与 Taniya 的架构意见一致）。只需：把 `patches/upstream/q28-dispcc-2026-10-22/` 移入 `superseded/`（或删），并在该目录 README 首行标 `SUPERSEDED BY q28-dispcc-v2-20261029`。 |
| 阻塞上游投递 | 否 |

### B2 bonded DSI 全局状态（per-SoC 表是否收口）

| 项 | 内容 |
|---|---|
| 编号 | B2 |
| 严重度 | **P2（三步已落地；第 4/5 步的实际状态需澄清）** |
| 位置 | `build/vk151/drivers/gpu/drm/msm/dsi/dsi_manager.c:41,54,275-281,388,665`；`dsi_host.c:143,383,2420,3100,3123,3155-3170`；对照 `build/b5-resoc/drivers/gpu/drm/msm/dsi/dsi_cfg.c:224-262,405-432` |
| 现状 | **日常线（`build/vk151`）仍然没有 per-SoC 表**：<br>`grep -rn 'dsi_bonded_cmd_failed\|link_configured\|0x001f0200\|0x44440400' build/vk151/drivers/gpu/drm/msm/` → `dsi_manager.c:41 static bool dsi_bonded_cmd_failed;`（**文件级全局变量，仍在**）、`:54 READ_ONCE(...)`、`:281 WRITE_ONCE(...false)`（清零点已加）、`:388/:665 WRITE_ONCE(...true)`（两处置位）；`dsi_host.c:143 bool link_configured`（**per-host 结构体成员，非全局**）、`:383/:3123/:3168` 三处无条件清、`:3100` 置 true。<br>**`b5-resoc` 树已经把三步 + 第 4 步都做了**：`dsi_cfg.c:224-234` 新增 `struct msm_dsi_bonded_cfg sm8750_dsi_bonded_cfg`（`master_link_id`/`cmd_dma_ctrl`/`err_clear_bits`/`err_cleanup_bits`/`poll_timeout_us`/`needs_link_clk_bump`/`needs_sw_reset` 全部数据化）、`:251-262` 新增独立 `sm8750_dsi_cfg`（`.compatible = "qcom,sm8750-dsi-ctrl"` + `.bonded = &sm8750_dsi_bonded_cfg`）、`:418` 独立表项 + `msm_dsi_6g_v2_9_bonded_host_ops`；`:425-431` 注释明写「lookup walks the table backwards, so the SoC-specific entry wins」。<br>⇒ **任务书怀疑的「bonded 表挂在 `sm8650_dsi_cfg` 上靠 compatible 闸门限定」已不成立**（`git -C build/b5-resoc log --oneline -6` 有 `4683b6c72e drm/msm/dsi: take the bonded master link from the SoC config`）。<br>但 **`build/vk151`（= 日常线 = 设备在跑的 `24223e44ad`）不含这些提交**。两棵树分叉。 |
| 冲突后果 | ① **上游投递件与日常线不同源**：`patches/upstream/m6-b5-p4-20261026/`（v1，1119 行）基于旧形状；`b5-resoc` 的新形状**还没有对应的 `patches/upstream/` 目录**（`ls patches/upstream | grep b5` → 只有 `m6-b5-p4-20261026`）。若现在投 b5，发出去的是已经被自己重构掉的形状。<br>② `dsi_bonded_cmd_failed` 仍是**跨实例全局**（`dsi_manager.c:41`），双 DSI 控制器（本机 2 个）共享一个失败标志——这正是 `reports/b5-per-soc-cfg-design-20261027.md` 要消灭的东西，但日常线未受益。<br>③ 新增的 `struct msm_dsi_config.compatible` 字段 + 「反向遍历表」是**上游没有的匹配机制**（`struct msm_dsi_config` 在 pristine 无该成员），必须进补丁正文解释，否则会被问「为什么不用 of_device_id」。 |
| 建议唯一归属 | **`msm_dsi_config`（数据）+ `msm_dsi_host_cfg_ops`（行为）** 是正确归属，`b5-resoc` 已经实现。下一步只有一个动作：把 `b5-resoc` 的 6 个提交 rebase 成 `patches/upstream/b5-resoc-<date>/` 的新系列，并用它**取代** `m6-b5-p4-20261026/`（后者下沉 `superseded/`）。全局标志 `dsi_bonded_cmd_failed` 应移进 `struct msm_dsi_manager`（`b5-resoc` 的 `0f24eb6998 drm/msm/dsi: move the bonded command failure flag into the manager state` 已做）。 |
| 阻塞上游投递 | **是**（要投 b5 的话，必须先出与 b5-resoc 一致的 v2 补丁目录） |

### B3 typec / UCSI：三处「重试」是否在做同一件事

| 项 | 内容 |
|---|---|
| 编号 | B3 |
| 严重度 | **P1** |
| 位置 | `build/vk151/drivers/usb/typec/ucsi/ucsi.c:1860-1867`、`:2244-2259`；`drivers/usb/roles/class.c:166-190`；`drivers/usb/typec/ucsi/ucsi_glink.c`（全文 0 处 retry） |
| 证据 | ① **PPM 层有重试**（上游原生代码，非本项目新增）：`ucsi.c:2244-2259`<br>`ret = ucsi_init(ucsi); if (ret) dev_err_probe(…); if (ret == -EPROBE_DEFER) { if (ucsi->work_count++ > UCSI_ROLE_SWITCH_WAIT_COUNT) { dev_err(…"PPM init failed, stop trying"); return; } queue_delayed_work(…, UCSI_ROLE_SWITCH_INTERVAL); }`；`ucsi.h:491-492` `INTERVAL = HZ/UCSI_ROLE_SWITCH_RETRY_PER_HZ`、`WAIT_COUNT = 10*UCSI_ROLE_SWITCH_RETRY_PER_HZ`。<br>② **connector 层没有重试**（同一件事，第二个层级）：`ucsi.c:1860` `con->usb_role_sw = fwnode_usb_role_switch_get(cap->fwnode);` → `:1861-1866` 仅判 `IS_ERR()`，`dev_err_probe()` 后 **`con->usb_role_sw = NULL; goto out_put;`** ⇒ 连接器注册直接中止，`-EPROBE_DEFER` 被消费掉、不上抛给比它更有重试能力的调用者。<br>③ `roles/class.c:182` 已是 `if (sw) {`（= `TASKS/README.md:316` 的 F1 已落地，不再是 `!IS_ERR_OR_NULL(sw)`）。<br>④ `ucsi_glink.c`：`grep -n 'retry\|EPROBE_DEFER\|msleep\|schedule_delayed'` → **0 命中** ⇒ F3 未实现，且 `TASKS/README.md:310` 明写「F3 不需要」。<br>⑤ 项目自己的结论：「三处修（`ucsi.c` 降级 / `ucsi_glink` 重试 / `ucsi_register` 返回值）实际只落地了两处，且其中一处就是上游原生重试环」。 |
| 冲突后果 | ① **不对称**：PPM init 走「defer→10 s 内重试 100 次」，connector 注册走「defer→立刻永久失败」。role switch 在 PPM init 之后才注册是**正常时序**（dwc3 的 `dwc3_drd_init` 只对 `dr_mode=otg` 跑，见 `TASKS` G1-9 根因链），所以 connector 层恰恰是最需要 defer 的地方，却把 defer 吞掉了。<br>② 因为吞掉，**上层看不到 defer**，症状从「稍后再试」退化为「connector 不存在」，与 2026-10-30 实测「两个 mux role switch 已注册但连接器未绑定」完全同型。<br>③ `ucsi_glink.c` 不重试本身没错——但如果将来又有人按旧 `TASKS` 记录去「补 F3」，就会造出**第三个**重试面，与前两个互相掩盖。 |
| 建议唯一归属 | **唯一归属 = 让 `-EPROBE_DEFER` 一路向上传播，由 `ucsi_init_work()` 那个既有重试环统一兜住**。具体：把 `ucsi.c:1861-1866` 的 `IS_ERR()` 分支拆成 `if (ret == -EPROBE_DEFER) { … goto out_put; }`（**不置 NULL**，把 `PTR_ERR` 原样 `return`）与真错误的 `NULL + abort` 两条路径；`ucsi_glink.c` **保持零改动**，并在 `TASKS/README.md` §4 把 F3 划掉（现已划，但 `patches/upstream/m3v5-*/` 无 README 记录该判定，见 A1-07）。 |
| 阻塞上游投递 | **是**（`patches/upstream/m3v5-20261030/` 0002 若含此逻辑，必须在正文写清「不新增重试环」的理由） |

### B4 看门狗 / 自愈：四套机制谁负责什么

| 项 | 内容 |
|---|---|
| 编号 | B4 |
| 严重度 | **P1** |
| 位置 | `scripts/q28-watchdog.sh`（主机侧管理）、`rootfs/persistent-overlay/q28-boot-watchdog.sh`、`packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh`、`packaging/elden-userland/files/usr/local/sbin/q28-watchdog.sh`、`packaging/elden-userland/services.tsv:34`（`q28-boot-watchdog` 行）、`den-powerlog` 行、`build/vk151/.config:4994` |
| 证据 | **① 内核硬件看门狗 = 实际不参与**：`.config:4994 CONFIG_QCOM_WDT=y`，但设备 `/dev/watchdog*` → `No such file or directory`；`dmesg` → `watchdog: NMI not fully supported` / `watchdog: Hard watchdog permanently disabled`；`CONFIG_SOFT_WATCHDOG is not set`、`CONFIG_WATCHDOG_NOWAYOUT is not set` ⇒ **没有任何 watchdog 字符设备**，只剩 soft lockup 检测（`/proc/sys/kernel/watchdog=1`）。<br>**② systemd `WatchdogSec` = 零使用**：`grep -rn 'WatchdogSec' packaging/elden-userland/` → 0 命中。<br>**③ `elden-powerlog` 不是看门狗**：`systemctl cat elden-powerlog` → `Type=oneshot` / `RemainAfterExit=yes` / `ExecStart=/usr/local/sbin/elden-powerlog-mark.sh` / `Before=shutdown.target`，只写「干净关机标记」，**不做任何检测或重启**。<br>**④ `q28-boot-watchdog` 是唯一的活体兜底，但当前被 cmdline 关掉**：`systemctl cat q28-boot-watchdog` → `Type=oneshot` / `After=greetd.service` / `ExecStart=/usr/local/sbin/q28-boot-watchdog.sh`；设备 `/proc/cmdline` **含 `elden_q28_nowd`**；`journalctl -u q28-boot-watchdog` → `q28-wd[1276]: disabled by cmdline`；`/var/lib/q28-watchdog/count` = `0`。<br>**⑤ 同一个脚本在仓内有 2 份逐字节相同的副本**：`sha256(rootfs/persistent-overlay/q28-boot-watchdog.sh)` = `sha256(packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh)` = `709e9eb86c65…`，均 4116 B ⇒ `scripts/q28-watchdog.sh:4` 的自述「**设备侧实现 = rootfs/persistent-overlay/q28-boot-watchdog.sh（本仓库为唯一源）**」**不成立**（仓内两份同源副本，MANIFEST.tsv:61 还钉了第三处 sha）。<br>**⑥ 它的开关有 5 个入口**：`/etc/q28-watchdog.disable` marker、cmdline `elden_q28_nowd`、env `Q28_WD_MAX=0`、systemd unit 启停（`services.tsv` `enabled=1`）、`/etc/local.d/elden-bringup.start` 的 `for h in q28-boot-watchdog` 钩子（由 `scripts/q28-watchdog.sh install` 用 `sed` 注入）。**`install` 注入 local.d 钩子 + systemd oneshot 同时存在 = 同一次启动跑两遍**（当前设备上 local.d 钩子缺席——`grep -n 'for h in' /etc/local.d/elden-bringup.start` 无命中——所以现在只跑一遍，但 `install` 一跑就变成两遍）。<br>**⑦ 第四份副本是 heredoc**：`scripts/q28-watchdog.sh` 里 `S 'cat > /usr/local/sbin/q28-watchdog.sh' <<'EOS' … EOS` 内联写出 600 B 的 `q28-watchdog.sh`，与 `packaging/elden-userland/files/usr/local/sbin/q28-watchdog.sh` 内容一致（device sha `f9cba76ed87b…` = 仓内文件 sha）。 |
| 冲突后果 | ① 「Q28 坏发 50%→75% 兜底」这条**运营结论在当前线上是假的**：cmdline 带 `elden_q28_nowd`，看门狗从不动作（`count=0`、journal 只有 `disabled by cmdline`）。而 `services.tsv:34` 的 desc 仍是「One-shot DSI/panel watchdog for Q28 (never fired on the operational line)」+ `enabled=1` ⇒ 文档口径（正常）与设备事实（被 cmdline 禁用）不一致。<br>② 同一脚本两份副本 + 一份 MANIFEST sha + 一份 heredoc：任一处改动都不会触发另一处的门禁（`verify.sh` 只能校验 MANIFEST ↔ files/，看不到 `rootfs/persistent-overlay/`）。<br>③ `install` 会**永久改写** `/etc/local.d/elden-bringup.start`（`sed -i`），把「systemd 管理」变成「local.d 也管」，两种 init 语义混用（`render.py` 头注释明令「服务定义里不允许出现跨 init 污染」）。 |
| 建议唯一归属 | **唯一归属 = `packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh`（MANIFEST 跟踪）+ `services.tsv` 的 unit**。<br>1. 删 `rootfs/persistent-overlay/q28-boot-watchdog.sh`，`scripts/q28-watchdog.sh` 的 `PAY=` 改指 MANIFEST 那份（或直接 `install` 时 `apt`/包路径）；<br>2. 删 `scripts/q28-watchdog.sh` 里的 600 B heredoc，改 `install` 只 `ln`/`install` 仓内文件；<br>3. 删 `sed -i /etc/local.d/elden-bringup.start` 那条（systemd 已有 unit），`off/on/status` 只操作 marker；<br>4. 在 `services.tsv` 加一列或在 README 记「cmdline `elden_q28_nowd` 会整体禁用它」；`DEVICE/README.md` §1.1 里把「看门狗兜底」改成「看门狗存在但当前被 cmdline 关闭」；<br>5. 若要真兜底，二选一：去掉 `elden_q28_nowd`，或改用 systemd `WatchdogSec=`（现在零使用，且 `q28-boot-watchdog` 是 oneshot 不适用——真兜底应是 longrun + `WatchdogSec`）。 |
| 阻塞上游投递 | 否（用户态） |

### B6 `scripts/` 职责重复（202 个脚本的聚类抽样）

> 方法：`ls scripts | wc -l` = **202**；按功能词聚类（`fastboot`/`slot`/`q28`/`probe`/`iterate`/`mod-loop`/`guard`/`deploy`/`watchdog`），再用「仓内被引用次数」（`grep -rl <name> --include=*.sh --include=*.md --include=*.py .`，排除 `build/` 与自身）判活。

| 编号 | 严重度 | 重复动作 | 涉及脚本 | 证据 | 三档判定 |
|---|---|---|---|---|---|
| B6-01 | **P1** | 「编一个模块目录 → 推设备 → rmmod/modprobe，不重启」的 30 s 快环 | `scripts/iterate.sh`（`mod <dir>` 档）↔ `scripts/mod-loop.sh` | `iterate.sh:4-6` 自述「统一迭代入口（日常用它）」并列出 `mod <dir>  模块快环：编该目录模块 → 推设备 → rmmod/modprobe。**不重启**（~30s）`；`mod-loop.sh:2-3` 自述「the fast iteration ring: rebuild ONE module dir, push it, reload on the device. No kernel rebuild, no boot image, no fastboot, no reboot (~30 s)」——**逐字同义**。引用数：`mod-loop.sh` 25 处、`iterate.sh` 33 处，两个都活着 | **应合并**：`iterate.sh mod` 保留为唯一入口，`mod-loop.sh` 降为 `exec iterate.sh mod`（保留文件名以免 25 处引用全改） |
| B6-02 | **P1** | Q28 冷起三态判定（NOCARD/STORM/GOOD） | `scripts/q28-devprobe.sh`（v1）↔ `scripts/q28-devprobe2.sh`（v2） | `q28-devprobe2.sh:4-8` 明确写 v1 有缺陷：「Why v2: the old q28-devprobe.sh collapsed every DPU/DSI error into one `storm_sig` count. That conflates L1 = panel/DSI bring-up actually failed … L2 = *downstream* DPU errors … which also appear transiently on healthy boots」。引用数：v1 **31** 处、v2 29 处 ⇒ **旧口径仍被 31 处文档/脚本引用** | **应删除 v1**（或加 `SUPERSEDED` 头 + 改所有引用）；`PITFALLS` §15 未登记这一对 |
| B6-03 | P2 | 打 boot 镜像 | `scripts/build-boot.sh` ↔ `scripts/build-boot-slim.sh` | 两者都被 4+ 处引用；`PITFALLS` §15.1 只登记了「根目录 `pack.sh` 委派到 `build-boot.sh`」，未说明 `-slim` 的适用范围 | **保留**（若 `-slim` 有独立用途需在头注释写清差异），否则**应合并**（`--slim` 开关） |
| B6-04 | P2 | q28 冷起/采样族 | `q28-coldboot-collect.sh`、`q28-disp-ab-sample.sh`、`q28-por-rounds.sh`、`q28-reboot-until-good.sh`、`q28-clkdiag.sh` | 引用数分别 5/5/5/**1**/9 ⇒ `q28-reboot-until-good.sh` 只有 1 处引用，疑似已废弃但**未登记**在 `PITFALLS` §15.2 | **应删除** `q28-reboot-until-good.sh`（先补 `PITFALLS` §15.2 登记），其余**保留** |
| B6-05 | P2 | 「装/推设备」 | `deploy-camera-modules.sh`、`deploy-sensors-hal.sh`、`deploy-sensord-routec.sh`、`deploy-sensord-routec-debian.sh`、`deploy-v4l2loopback.sh`、`deploy-bt-suspend-guard.sh`、`deploy-zh-ime.sh`、`mesa-deploy.sh`（8 个） | `deploy-sensord-routec.sh` ↔ `deploy-sensord-routec-debian.sh` 是同名前缀的 init 双份（与 `render.py` 的 dual-init 设计同构）；**`deploy-camera-modules.sh` 无 ABI 门禁**（`grep -n 'abi\|check-abi\|assert-kernel-sane' scripts/deploy-camera-modules.sh` → 0 命中），而 `mod-loop.sh:55` 有 ⇒ 见 B7-02 | **保留**（各有明确标的），但 `deploy-camera-modules.sh` **应加** `assert-kernel-sane.sh` 门（否则推错 ABI 的 `.ko` 会静默） |

### B7 配置漂移：ABI 敏感项在多处各说一套

| 编号 | 严重度 | 位置 | 证据 | 冲突后果 | 建议唯一归属 |
|---|---|---|---|---|---|
| B7-01 | **P0** | `scripts/check-abi-config.sh:56`（默认目标）vs `patches/current-tree`（=`build/vk151`） | 默认目标写死为 **`build/m1-73/.config`**（`CONF=${1:-$ROOT/build/m1-73/.config}`，`:56`）。实跑 `bash scripts/check-abi-config.sh`（无参）→ `[abi] 目标: …/build/m1-73/.config` / `[abi] 参考: …/patches/config-vk127-working-20261018` / `✅ 一致`。而 `patches/current-tree` 唯一有效行 = `build/vk151`。**裸跑门禁检的是已退役的 7.2 血统树**。 | 门禁默认绿灯，但检的对象不是你正在用的树 —— 「默认参数即过」的假阳性面，正是 2026-10-22 fastrpc 刷屏（`PITFALLS #367`）那类事故的复发通道。 | 默认目标改为 `$ROOT/$(sed -n 's/^\(build\/[^ ]*\).*/\1/p' patches/current-tree | head -1)/.config`（复用 `scripts/env-build.sh` 的 `KDIR` 解析），缺失就报错退出而非静默取旧树。 |
| B7-02 | **P0** | `build/m4-base/.config`（相机系列基树） | `bash scripts/check-abi-config.sh build/m4-base/.config` →<br>`[FAIL] CONFIG_SUSPEND 目标=y 参考=__NOT_SET__`<br>`[FAIL] CONFIG_PM_SLEEP 目标=y 参考=__ABSENT__`<br>`[FAIL] CONFIG_PM_SLEEP_SMP 目标=y 参考=__ABSENT__`<br>⇒ `❌ ABI 敏感项与参考 config 不一致`。同时 `build/m4-base/.config` 与日常线 `build/vk151/.config` 的 `CONFIG_MODVERSIONS` **都是 not set**。 | 用 m4-base 编出的任何 `.ko`（camss/csiphy/csid 全是模块）**与在机内核 ABI 不兼容**，而 `MODVERSIONS=n` ⇒ 加载时不做 CRC 校验 ⇒ 静默用错 `struct device.of_node` 偏移（正是 `PITFALLS #367` 的形态：`/dev/fastrpc-*` 全缺、刷屏）。`scripts/deploy-camera-modules.sh` 无 ABI 门禁（B6-05）。 | ① 把 m4-base 的 `CONFIG_SUSPEND/PM_SLEEP*` 关掉对齐 SSOT（`--ref patches/config-vk127-working-*`）；② `deploy-camera-modules.sh` 开头加 `bash scripts/assert-kernel-sane.sh`（或至少 `check-abi-config.sh <树>/.config`）；③ 长期建议开 `CONFIG_MODVERSIONS`（会强制 CRC 校验，把这类错误变成加载失败而不是内存错位）——但需同步 `Module.symvers` 流程，属独立决策。 |
| B7-03 | P2 | `patches/config-*`（34 个）/`patches/fragment-*.config`（8 个） | `CONFIG_SUSPEND` 在仓内**两种取值同时存在**：`# CONFIG_SUSPEND is not set` = `build/vk151`、`build/m3v5-daily`、`patches/config-daily-c1`、以及 32 个历史 config；`CONFIG_SUSPEND=y` = **仅** `patches/config-suspend-s2idle-20261018-173529` 与 `patches/fragment-suspend-s2idle.config`。`patches/config-*` 里只 1 份是 `=y`。 | 名义上「一处各说一套」，实际风险收敛（只有 s2idle 实验族的 config 是 `=y`，且 `check-abi-config.sh` 的 27 项会拦）。真正的隐患是 `patches/fragment-suspend-s2idle.config` **仍在**，任何 `apply-kernel-fragment.sh` 误用它就会把 ABI 翻掉。 | 给 `fragment-suspend-s2idle.config` 首行加 `# ABI-CHANGING: 只允许用于独立实验树，禁止应用到日常线（CONFIG_SUSPEND 改 struct dev_pm_info 尺寸）`；或移到 `patches/experimental/`。 |
| B7-04 | P2 | `scripts/check-abi-config.sh:27-53`（27 项） | 27 项 = `SUSPEND`/`PM_SLEEP`/`PM_SLEEP_SMP`/`PM`/`PM_GENERIC_DOMAINS`/`DEBUG_LOCK_ALLOC`/`LOCKDEP`/`PROVE_LOCKING`/`NUMA`/`HOTPLUG_CPU`/`CPUMASK_OFFSTACK`/`NR_CPUS`/`PREEMPT`/`PREEMPT_COUNT`/`PREEMPTION`/`PREEMPT_RT`/`ARM64_VA_BITS(+39/48/52)`/`ARM64_4K/16K/64K_PAGES`/`CC_OPTIMIZE_FOR_PERFORMANCE/SIZE`/`SMP`/`MODVERSIONS`。**`CONFIG_ARCH_QCOM` 不在其中**。 | 任务书怀疑「`CONFIG_ARCH_QCOM` 在多处各说一套」——实测：`ARCH_QCOM=y` 在 `build/vk151`/`m3v5-daily`/`m4-base`/`config-daily-c1`/`config-suspend-*` **全部一致**，且 `ARCH_QCOM` 不改变任何 struct 布局 ⇒ 不进 27 项是**正确取舍**，不构成缺陷。真正的风险在 `PITFALLS` §15.1 已登记的 vk81/82/83 死内核形态（`ARCH_QCOM` 被 `olddefconfig` 删掉），而那靠 `build-kernel.sh` 的**符号守卫**（`CONFIG_ARCH_QCOM` + `gcc_sm8750`）拦截，不是靠本脚本。 | 无需改 27 项；但请在 `check-abi-config.sh` 头注释补一行「`ARCH_QCOM` 类『有没有驱动』的问题由 `build-kernel.sh` 符号守卫负责，本脚本只管 struct 布局」，避免下次有人往 27 项里塞不该塞的。 |

---

## §C 需求与实现对不上

> 只审「开放项 + 声称已完成的上游化项」。需求源：`AGENTS.md` G1–G3、`TASKS/README.md` §1/§4/§5/§7、`DEVICE/README.md` 驱动矩阵。
> 设备事实全部来自**当前这一发**：`uname -a` = `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172 #2 SMP PREEMPT Fri Oct 30 13:06:36 CST 2026`，`boot_id` = `7e56f31b-e443-41cd-b843-73392c19e640`，`uptime` = 1453 s。

| 编号 | 严重度 | 文档条目 | 声称 | 实测 | 差值 | 是否阻塞 |
|---|---|---|---|---|---|---|
| **C-01** | **P0** | `TASKS/README.md:55` G1-34 加速度计/传感器 | ✅「**两棵根都可用（2026-10-27 定案）**：… **均 `HasAccelerometer/HasAmbientLight/HasProximity` = true**（设备实测 `busctl get-property` 三真 + `AccelerometerTilt`=`face-up`）」 | **三全 false**：<br>`busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer HasAmbientLight HasProximity` →<br>`b false` / `b false` / `b false` | **声称=全绿，实测=全灭**。`iio-sensor-proxy` 虽 `active`，但 SSC 入口死（见 C-02），三属性必然 false。 | **阻塞 G1/G2**（G2 的容器传感器 `/init` 判据依赖它） |
| **C-02** | **P0** | 同上 + `DEVICE/README.md:54`「`qrtr-lookup` 见 **400 = Snapdragon Sensor Core service**」 | svc 400 已注册（旧「未注册」结论作废） | ① `qrtr-lookup` 输出 **没有 400**（列出 `64 / 15 / 66 / 43` 四条，无 `Snapdragon Sensor Core`）。<br>② `systemctl is-active hexagonrpcd` → **failed**；`journalctl -u hexagonrpcd` 连续 3 次启动全同：`Could not open FastRPC node (/dev/fastrpc-adsp): No such file or directory` → `status=4/NOPERMISSION`。<br>③ `/proc/misc` 只有 `fastrpc-adsp-secure`(263) / `fastrpc-cdsp`(262) / `fastrpc-cdsp-secure`(261)，**无 `fastrpc-adsp`**。<br>④ **根因已定位（已证）**：`drivers/misc/fastrpc.c:2599` `secure_dsp = !(of_property_read_bool(rdev->of_node, "qcom,non-secure-domain"))`；在机 live DT 的 `soc@0/remoteproc@6800000/glink-edge/fastrpc/` 目录列表**没有 `qcom,non-secure-domain`**（有：`compatible`、`compute-cb@3..8`、`label`、`memory-region`、`name`、`qcom,glink-channels`、`qcom:vmids`）⇒ `secure_dsp=true` ⇒ 只建 `-secure` 节点。<br>⑤ **而源码里有这一行**：`build/vk151/arch/arm64/boot/dts/qcom/sm8750.dtsi:2288 qcom,non-secure-domain;` —— 但它是**未提交的工作区改动**（`git -C build/vk151 diff arch/arm64/boot/dts/qcom/sm8750.dtsi` → `+ qcom,non-secure-domain;`）⇒ **在机镜像的 DTB 早于这行**。 | **源码有 / 镜像无**。这不是「回归」，是「修复只存在于未刷写的工作区」。`DEVICE/README.md:30` 已如实记「`hexagonrpcd` 失败…非回归」，但 §1.1:54 仍写 svc 400 可见、G1-34 仍写 ✅ ⇒ 三处口径互相矛盾。 | **阻塞 G1**（传感器） |
| **C-03** | **P1** | `TASKS/README.md:580` M9 vs `patches/upstream/m-gic-its-claim-20261024/README.md` | TASKS：🔴 **方案被否（2026-10-26，Marc Zyngier：nothing works at all；EFI/bootloader 配表 + DT memreserve 才是正解）⇒ 撤回或改…待用户裁决**<br>系列 README 首行：🟢 **已投递（2026-10-24，用户批准）** `<20261024075856.835932-…>`，`/lkml/` + `/linux-arm-kernel/` 均已归档 | ① 系列 README **全文 0 处**提到「被否 / 撤回 / Marc Zyngier」（`grep -n '被否\|撤回\|Zyngier' patches/upstream/m-gic-its-claim-20261024/README.md` → 无命中）⇒ **「已投递待 review」的口径仍在**。<br>② 外部归档状态（patchwork 独立复核）：`q=Claim%20LPI` → `2026-10-24 | irqchip/gic-v3-its: Claim LPI tables inherited across kexec on DT | new`（**仍是 new，没有 withdrawn/superseded 标记**）。<br>③ `reports/kexec-target-boots-20261024.md:290` 也只写「**已投递**」。<br>④ 该补丁**仍留在日常线工作区**：`git -C build/vk151 diff --stat drivers/irqchip/irq-gic-v3-its.c` → **+249 行未提交**。 | 方案已被 maintainer 否决，但 (a) 归档口径未更新、(b) 代码仍在日常线未提交区、(c) 外部归档里也没有撤回声明 ⇒ 下一个人会按「已投递待 review」继续等。 | 否（不阻塞编译/上机），但**阻塞任何「M9 收口」表述** |
| **C-04** | **P1** | `TASKS/README.md:…` b5 第 4 步「master 改由表决定，**须上机**」+ `reports/b5-per-soc-cfg-design-20261027.md` §4 | 第 1–3 步已落地（`b5-resoc`），第 4 步须上机、第 5 步未做 | ① `b5-resoc` 树**第 4 步已实现**：`dsi_cfg.c:418` 独立表项 + `msm_dsi_6g_v2_9_bonded_host_ops`、commit `4683b6c72e drm/msm/dsi: take the bonded master link from the SoC config`。<br>② **但没有任何上机记录**：设备内核 = `24223e44ad`（vk151/vk172 线），`b5-resoc` 的 6 个提交**一个都不在**在机镜像里；`patches/upstream/` 里也**没有** b5 的新形状目录（只有旧的 `m6-b5-p4-20261026/`）。<br>③ `versions/vk-kernel-identity.tsv` 里 `vk179-b5step4a` / `vk180-b5step4b` 两个镜像存在（`24223e44ad80-dirty`），说明第 4 步**曾经备过上机件**，但无对应上机报告（`ls reports | grep -i b5` → `b5-per-soc-cfg-design`、`b5-preflight`、`b5-resoc`、`b5-step4-master-from-cfg`、`b5-step5-*`、`b5-u2-atomic-timeline`，**无 `b5-onboard`/`b5-step4-onboard`**）。 | **第 4 步「已实现但未上机」** —— 任务书怀疑点成立：`b5-step4-master-from-cfg-20261027.md` 是主机侧报告，不是上机报告。 | 阻塞 b5 上游化（要投就必须上机，因为第 4 步改变 master 选择） |
| **C-05** | P2 | `TASKS/README.md:363` Q34「根治 = `elden-firmware` 加 `local-extras.tsv` + 新门禁 A2」 | 门禁已实现、负向测试已验证 | ✅ **成立**（正面结论）：<br>① `rootfs/debian/elden-firmware/local-extras.tsv` 存在；<br>② `rootfs/debian/elden-firmware/build.sh:222-270` 有完整 A2 实现（`driver_required()` 用 `git grep -o 'MODULE_FIRMWARE("[^"]*")' -- drivers/` 过滤 `qca/|qcom/|ath12k/|awinic/|novatek` 前缀；`check_driver_fw()` 逐条 `MISS` 计数）；<br>③ **该门禁自己记录了更狠的坑**：`build.sh:237-240`「⚠ 用 `-e` 而不是 `-d`：`build/vk151` 是 git worktree，`.git` 是文件 ⇒ 用 `-d` 会静默 `return 0`，A2 永远『通过』」——这是本仓里**唯一**显式处理了「门禁静默跳过」的脚本；<br>④ 设备侧已落地：`ls /lib/firmware/qca/` → 5 个文件**含 `tmel_peach_20.elf`**。 | 无 | 否 |
| **C-06** | P2 | `TASKS/README.md:55` G1-34「规则进 `packaging/…/files/etc/udev/rules.d/`，`MANIFEST.tsv` 新 kind `udev-rule`，`verify.sh` §E 新增红线（负向测试：移走文件 → `FAIL=2`）」 | 三件都已加 | ✅ **成立**：<br>① `packaging/elden-userland/files/etc/udev/rules.d/81-libssc-elden.rules` 存在（1247 B）；<br>② `MANIFEST.tsv:20` kind = `udev-rule`，sha `8d3429f8ff46…`；<br>③ `packaging/elden-userland/tools/verify.sh:157-167` 有 §E 段，注释写明「`drv-ssc-accel.c` 的 discover 是 `drv_check_udev_sensor_type(device,"ssc-accel")` ⇒ 缺属性 = 永远无 accel」，并 `fail` 分支给出「`HasAccelerometer` 会恒 false」。 | 无（门禁在位；失效是因为 C-02 的更上游断点） | 否 |
| **C-07** | P2 | `DEVICE/README.md:27` 「`boot_id` = `b4d2846d-…`（冷起 POR 后）」 | 唯一权威 boot_id | `cat /proc/sys/kernel/random/boot_id` → `7e56f31b-e443-41cd-b843-73392c19e640`（`uptime` 1453 s ⇒ 文档写成后又重启过） | boot_id 已过期；`uname -v`（`#2 … Oct 30 13:06:36`）与文档**一致** ⇒ 镜像身份仍成立，只是「这一发」的标识过期 | 否 |
| **C-08** | **P0** | `TASKS/README.md:…`「日常线内核树 = `build/vk151` @ `24223e4`」+ `patches/current-tree` | 日常线源 = `build/vk151`，身份可追溯（`versions/vk-kernel-identity.tsv`） | **`build/vk151` 是一个 11 文件 / +546 −32 的脏工作区**：<br>`git -C build/vk151 status --porcelain` →<br>`M Documentation/devicetree/bindings/display/msm/mdss-common.yaml`<br>`M arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts`<br>`M arch/arm64/boot/dts/qcom/sm8750.dtsi`（含 C-02 的 `qcom,non-secure-domain`）<br>`M drivers/gpu/drm/msm/dsi/dsi_host.c`（+57）<br>`M drivers/gpu/drm/msm/dsi/dsi_manager.c`（+24，Q28 闩锁清零）<br>`M drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c`<br>`M drivers/gpu/drm/msm/msm_mdss.c`（+90，MDSS reset）<br>`M drivers/irqchip/irq-gic-v3-its.c`（+249，**M9 已被否的方案**）<br>`M include/linux/kexec.h` / `M kernel/kexec_core.c`（+86）/ `M kernel/reboot.c`（kexec diag 旋钮）<br>而 `patches/current-tree` 唯一有效行 = `build/vk151`，`scripts/iterate.sh`/`build-kernel.sh` 默认用它构建。 | **身份链断裂**：从这棵树编出的镜像既不对应任何 git 提交，也无法从 `versions/vk-kernel-identity.tsv` 复现；`vk-kernel-identity.tsv` 已经给 `m3v5-f2` 打过 `tree_head_diff` 标记（说明台账知道这一类问题），但**日常线树本身仍是脏的**。这是 C-02 的直接成因，也是「声称与树脱节」的根。 | **是**（任何「日常线 = 24223e44ad」的陈述都不准确；改树前必须先落一次提交或建分支） |
| **C-09** | P1 | `TASKS/README.md:316` M3-1 缺口② | 「**补丁基线是 daily(`24223e44ad`) 而非 pristine**，0002 含『v2→v4 形状』重写内容，**投递前必须在 pristine 上重放**」 | `patches/upstream/m3v5-20261030/` 与 `m3v5-fix-20261030/` 两个目录**都没有 README**，无法判断该缺口是否已闭合；`reports/m3v5-pristine-replay-20261030.md` 存在（说明重放做过），但补丁目录里没有任何验收数字 | 「已重放」只有报告、没有补丁目录内的门禁记录 ⇒ 按项目自身 `patches/upstream/README.md` §3 属**未完成** | 是 |

---

## §D 缺失清单

| 编号 | 严重度 | 缺口 | 证据 | 补法 | 阻塞 G1/G2/G3 |
|---|---|---|---|---|---|
| **D-01** | **P0** | **在机镜像的 DTB 缺 `qcom,non-secure-domain`（adsp fastrpc）** ⇒ `/dev/fastrpc-adsp` 不存在 ⇒ `hexagonrpcd` 失败 ⇒ SSC 传感器链死 | 见 C-02 ④⑤。live DT 目录列表无该属性；源码里该行只在 `build/vk151` 未提交工作区 | ① 先把 `build/vk151` 的 DT 改动落成提交（解 C-08）；② 用它重编 m3v5/vk181 系列 boot.img 并刷写（**需用户在场**，`scripts/flash-b.sh`）；③ 判据：`/proc/misc` 出现 `fastrpc-adsp`、`systemctl is-active hexagonrpcd` = `active`、`qrtr-lookup` 出现 `400`、`busctl get-property … HasAccelerometer` = `true`；④ 回退件 = `bootslot-b/boot_b-vk181-daily-signed-20261029.img`（`DEVICE/README.md:29`） | **G1（传感器）、G2（容器传感器 HAL）** |
| **D-02** | P1 | `patches/upstream/m3v5-20261030/`、`patches/upstream/m3v5-fix-20261030/` **无 README**（补丁清单/取舍/验收命令/收件人/发送状态全缺） | `find patches/upstream -maxdepth 2 -name README.md` 无这两个目录；项目硬规 = `patches/upstream/README.md` §3 | 按 `m3-v4-20261026/README.md` 模板补齐；`m3v5-fix` 明确注明是 v5 的 fixup | 阻塞 M3 上游化 |
| **D-03** | P1 | **b5 新形状（`b5-resoc`）没有对应的 `patches/upstream/` 目录**；`m6-b5-p4-20261026/` 是已被自己重构掉的旧形状 | `ls patches/upstream | grep b5` → 只有 `m6-b5-p4-20261026`；`build/b5-resoc` 有 6 个提交（`0f24eb6998`…`4812252692`） | 从 `b5-resoc` 重出 `patches/upstream/b5-resoc-<date>/`（6 枚），旧目录下沉 `superseded/`；见 B2 | 阻塞 M6 上游化 |
| **D-04** | P1 | **`q28-reboot-until-good.sh` 疑似废弃但未登记** | `grep -rl q28-reboot-until-good.sh --include=*.sh --include=*.md --include=*.py .` → **仅 1 处**（自身或单条历史引用），而同类 `q28-por-rounds.sh` 5 处、`q28-clkdiag.sh` 9 处；`PITFALLS` §15.2 未登记 | 先在 `PITFALLS/sessions/15-过时废弃功能缺陷登记.md` §15.2 登记，再移 `archive/2026-10-31-retired-scripts/` | 否 |
| **D-05** | P1 | **`patches/upstream/` 下缺 `Link:`/`Reported-by:` 惯例（全 0 命中）** | `grep -rln '^\(Link\|Reported-by\|Closes\|Suggested-by\):' patches/upstream/` → 空 | 对「行为变更 / 泄漏修复 / 跨子系统」类补丁（`m-gic-its-claim`、`m1-pas-dtbfw`、`m4-camss-fixes`）补 `Link:` 指向设计/取证报告 | 否（审稿体验） |
| **D-06** | P2 | **`patches/upstream/` 缺「已废弃系列」隔离区**：`q28-dispcc-2026-10-22`（v1，形状已被否）、`m4-camss-2026-10-13/*.patch`（机器身份 SOB）、`m4-camss-series-20261027/0007-NOT-FOR-UPSTREAM-*`、`aw86927-20261027`（v1，已被 v2 取代）全部与可投补丁同级 | 见 A1-08/A1-09/B1 | 新建 `patches/upstream/superseded/`（或每系列 `superseded/` 子目录），把上述移入；`grep '*.patch'` 的发送脚本加 `! -name 'NOT-FOR-UPSTREAM*'` 过滤 | 否（但直接决定 glob 发送的正确性） |
| **D-07** | P2 | **`hexagonrpcd-adsp-sensorspd → hexagonrpcd` 别名未登记进 `provides.tsv`** | `provides.tsv` 只有 `greetd → display-manager` 一行；设备 `ls -l /etc/systemd/system/hexagonrpcd-adsp-sensorspd.service` → 指向 `hexagonrpcd.service` | 见 B5b | 否 |
| **D-08** | P2 | **`scripts/deploy-camera-modules.sh` 无 ABI 门禁** | `grep -n 'abi\|check-abi\|assert-kernel-sane' scripts/deploy-camera-modules.sh` → 0 命中（对比 `scripts/mod-loop.sh:55` 有） | 开头加 `bash scripts/assert-kernel-sane.sh` 或 `check-abi-config.sh <树>/.config`；见 B7-02 | 否（但 G1 相机模块热推时会踩 ABI） |

---

## §A（续）A2 日常线内核增量的风格

> 树 = **`build/vk151`**（`patches/current-tree` 指向它）；`git log -1` = `24223e44ad 2026-10-14 drm/msm/dsi/phy: program PLL_SYSTEM_MUXES on the first PHY enable`；
> 基线 = `24a19b953`（Linux 7.3-rc7，**是 HEAD 的祖先**，`git merge-base --is-ancestor` 通过）；
> 相对 pristine 只有 **2 个提交**（`0f1fb1c9c1 elden payload v2: …` + `24223e44ad …`，148 文件 / **+15522 −700**）+ **11 个未提交文件**（见 C-08）。
> ⇒ 本节只审「本地增量」= `git diff 24a19b953 HEAD` **加** `git diff`（工作区），不把上游演进算进来。

| 编号 | 严重度 | 位置 | 证据 | 规范依据 | 建议修法 | 阻塞上游投递 |
|---|---|---|---|---|---|---|
| **A2-01** | **P0** | `build/vk151/drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c:437`、`:459`（**工作区未提交**） | `if (of_machine_is_compatible("lenovo,elden")) data &= ~DSI_7nm_PHY_CMN_CTRL_0_DIGTOP_PWRDN_B;`<br>`if (of_machine_is_compatible("lenovo,elden")) data \|= DSI_7nm_PHY_CMN_CTRL_0_DIGTOP_PWRDN_B;`<br>`git diff drivers/gpu/drm/msm/dsi/phy/dsi_phy_7nm.c \| grep -n of_machine_is_compatible` → `9:+` `18:+`（两行都是本次未提交新增） | **项目自己的红线**：`patches/upstream/README.md` §2 Q3 违例扫描列明「`of_device_is_compatible("qcom,...")` 散落判定」命中即拦；`reports/upstream-policy-20261013.md` §9 同款 | 板名不进驱动。两条路：① **硬件事实** ⇒ 做成 DT 属性（如 `qcom,pll-keep-digtop-pwrdn`，配 binding）或 per-compatible 数据表（`dsi_phy_cfg`/`pll_cfg` 已有 per-SoC 分层，把「首次 enable 是否清 DIGTOP_PWRDN_B」做成 `dsi_pll_7nm_cfg` 字段）；② 若只是本机面板时序需求 ⇒ 进 panel 驱动或 DT。**当前形状绝不能进 `m1-2026-10-14` 系列**（那枚补丁改的就是这个文件） | **是** |
| **A2-02** | **P1** | `build/vk151/drivers/irqchip/irq-gic-v3-its.c`（工作区未提交，**+249 行**） | 7 处调试插桩：`pr_info("[KD] gic-reserve: fdt_add_mem_rsv(@%pa,%lu) = %d …")`、`pr_info("[KD] its-quiesce: no ITS node\n")`、`pr_info("[KD] its-quiesce: @%pa CTLR=%08x CREADR=%u CWRITER=%u\n")`、`pr_info("[KD] rd-lpi: CPU%d CTLR %08x -> %08x\n")`、`pr_info("[KD] its-report: wrote /var/tmp/its-kexec-report.txt (%d B)\n")`、`pr_info("[KD] its-probe: @%pa CTLR=… cbaser=%llx\n")` | checkpatch `PREFER_DEV_LEVEL`/`printk` 与 `Documentation/process/submitting-patches.rst`「no debug cruft」；项目红线「调试插桩 ⇒ 不得进树」（`patches/upstream/README.md` §2） | ① 该文件里 249 行是 **M9（已被 Marc Zyngier 否掉）** 的实现 + kexec 诊断；② 诊断部分应改为 `dyndbg`（`pr_debug`）或移到独立 debug 模块；③ 生产镜像不该带 `[KD]` 前缀的 `pr_info` | 是（若随任何补丁发出） |
| **A2-03** | **P1** | `build/vk151/drivers/gpu/drm/msm/dsi/dsi_host.c`（`pr_err` 44 / `dev_err` 25）、`dsi_manager.c`（`pr_*` 14 / `dev_err` 3） | `grep -c 'pr_err\|pr_info\|printk(' dsi_host.c` = 44；`grep -c dev_err` = 25。**其中新增行用 `pr_*` 的有 1 处**：`git diff 24a19b953 HEAD` 内 `+  dev_info(&msm_host->pdev->dev,`（正确）+ 其余新增 13 处 `dev_err`（正确）。历史 `pr_err` 主要是 upstream 既有 DSI 代码 | checkpatch `PREFER_DEV_LEVEL`；上游 dsi 子系统近年正把 `pr_err` 换 `dev_err` | 不改历史行（会制造噪声）；**新增行一律 `dev_*`**，并在 `patches/upstream/m6-b5-p4` 的正文里说明不顺手改历史 `pr_err` 的理由 | 否 |
| **A2-04** | **P1（**但这在本树上已被修，只是没提交**）** | `build/vk151/drivers/gpu/drm/msm/dsi/dsi_host.c:2353/2367/2369`（HEAD）vs `:2358-2362/2380/2398/2400`（工作区） | HEAD 里是魔数：`val \|= 0x001f0200;` / `dsi_write(…, val \| 0x44440400);` / `val &= ~0x001f0200;`（`git grep -n '0x001f0200\|0x44440400' HEAD -- drivers/` → 3 行）。**工作区已替换成命名宏**：`#define DSI_ERR_INT_MASK0_FIFO_ERRORS …` / `#define DSI_FIFO_STATUS_FIFO_ERRORS …`（`grep -n` → 定义在 `:2358,:2362`，用在 `:2380,:2398,:2400`）。同时 `dsi.xml` 补了 22 行寄存器定义（`git diff … -- drivers/gpu/drm/msm/registers/display/dsi.xml`） | 项目红线「魔数命名」（任务书点名 `0x001f0200`/`0x44440400`）；`reports/b5-per-soc-cfg-design-20261027.md` 第 5 步要求「两处魔数永久隔离」 | **动作 = 提交**（不是改代码）：工作区已满足 b5 第 5 步，但因为未提交（C-08），HEAD/镜像仍是魔数。把它随 `dsi.xml` 一起落一个提交。 | 是（未提交就等于没做） |
| A2-05 | P2 | 新增驱动 7 个（`git diff --name-status 24a19b953 HEAD -- drivers/ \| grep '^A'`）：`drivers/input/touchscreen/novatek-nvt36xxx-spi.c`、`drivers/media/i2c/{gc08a8,gt9764,s5kjns}.c`、`drivers/media/platform/qcom/camss/{camss-csid-980,camss-vfe-gen4}.c`、`drivers/regulator/wl2868c-regulator.c` | 抽查 `sound/soc/codecs/aw88461.c`：`MODULE_DESCRIPTION("Awinic AW88461 I2S amplifier driver")` + `MODULE_LICENSE("GPL")` + `{ .compatible = "awinic,aw88461" }` 齐全（90 处 aw88461 引用）。7 个新增驱动在 `patches/upstream/m4-camss-*`/`wl2868c-*` 里已有 0E/0W/0C 记录 | checkpatch `MODULE_LICENSE`/`MODULE_DESCRIPTION` 必需 | 无（但 `aw88461` 的 binding 只在 `patches/upstream/m3-3-2026-10-13/` 里，且该系列「备料封存」——见 C 类） | 否 |
| A2-06 | P2 | DT `compatible = "lenovo,elden"` vs `"lenovo,tb322fc"` | `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts:24 compatible = "lenovo,elden", "qcom,sm8750";`；`Documentation/devicetree/bindings/arm/qcom.yaml:1171 - lenovo,elden`（**payload 新增**：`git show 24a19b953:…/qcom.yaml \| grep -c lenovo,elden` = **0**）。两者一致（不是 tb322fc 拼写问题）。 | `Documentation/devicetree/bindings/arm/qcom.yaml`；DT 命名惯例 = `<vendor>,<model>` 全小写、不与 SoC 名重复 | 保持不变（`elden` 与项目代号一致，且 qcom.yaml 同批改）。**但注意**：pristine 7.3-rc7 **没有** `sm8750-lenovo-elden.dts`（`git ls-tree -r … \| grep sm8750-lenovo` → 空），而 TASKS 记录 Pengyu Luo 正在上游评审**同名 1170 行**版本 ⇒ **文件名撞车**，合并时会 modify/delete 冲突。建议在 `DEVICE/README.md`/`TASKS` 里把「我们的 3187 行版本 vs 上游 1170 行版本」的 delta 策略写死（TASKS 已写「必须以其为基做 delta」，此处仅确认该风险仍在） | 否（但不做 delta 就直接投会被拒） |
| A2-07 | P2 | `status = "okay"` 节点 × **38** + 树内驱动核对 | 对 elden DTS 的 17 个自定义 compatible 逐个查驱动：**16 个都有**（`awinic,aw86937`→`input/misc/aw86927.c`、`awinic,aw88461`→`sound/soc/codecs/aw88461.c`、`awinic,aw99706`→`video/backlight/aw99706.c`、`csot,pp8807hb1-1`→`panel-novatek-nt36536.c`、`galaxycore,gc08a8`/`giantec,gt9764`/`samsung,s5kjns`→`media/i2c/*`、`novatek,nt36536-ts`→`novatek-nvt36xxx-spi.c`、`willsemi,wl2868c`→`regulator/wl2868c-regulator.c`、`qcom,wcn7861-{bt,pmu}`→`hci_qca.c`/`pwrseq-qcom-wcn.c`、`fcs,fsa4480`、`nxp,ptn3222`、`st,st21nfca-i2c`、`pci17cb,110e`、`sdw20217010e00`）⇒ **无「status=okay 但无驱动」的节点** | DT 一致性 | 无需修 | 否 |
| A2-08 | P2 | `static` / 跨模块全局 / `MODULE_DEVICE_TABLE` | 未做全量逐文件扫描（见 §E）。抽检 7 个新增驱动 + `dsi_host.c`/`dsi_manager.c`/`msm_mdss.c` 的 `of_device_id` 与 `MODULE_DEVICE_TABLE`：新增驱动均在 `patches/upstream/` 系列里经过 checkpatch 0/0/0（含 `MODULE_DEVICE_TABLE` 检查项） | checkpatch `STATIC_CONST_CHAR_ARRAY`/`MISSING_DEVICE_TABLE` | 见 §E「未覆盖」 | 未核实 |

---

## §E 方法与边界

### E.1 跑过的命令（可复现）

```sh
# --- A1: 全量 checkpatch（★必须在仓库外跑，见 A1-11）
cd /tmp
for p in $(find /home/xuqianhui/y700-elden/patches/upstream -name '*.patch' | sort); do
  perl /home/xuqianhui/y700-elden/build/vk151/scripts/checkpatch.pl --strict --no-tree "$p"
done                      # → 108 文件 / 81 干净 / 1E 35W 10C

# --- A1: 头部字段
for p in $(find patches/upstream -name '*.patch'|sort); do
  grep -m1 '^Subject:' "$p" | sed 's/^Subject: \[[^]]*\] //' | wc -c      # ≤72
  grep -c '^Signed-off-by:' "$p"; grep '^Signed-off-by:' "$p"
  grep -n '^Fixes:' "$p"
done
git config user.name; git config user.email     # Qianhui Xu / xiaqinghuan@mail.ustc.edu.cn
grep -rln '^\(Link\|Reported-by\|Closes\|Suggested-by\):' patches/upstream/   # 0 命中

# --- A1: Fixes 目标核验
git -C build/m3v2-7.3rc7 cat-file -t 44784327815b     # commit
git -C build/m3v2-7.3rc7 log -1 --format='%H%n%s%n%an' 44784327815b
for t in build/*/ linux/ Y700-elden-linux/; do git -C $t cat-file -t df53055c540f; done  # 全 MISSING

# --- A1: 外部归档独立复核（patchwork，因 lore 反爬）
curl -s --noproxy '*' 'https://patchwork.kernel.org/api/1.2/patches/?q=MDSS%20block%20resets&per_page=40'
curl -s --noproxy '*' 'https://patchwork.kernel.org/api/1.2/patches/?q=Claim%20LPI&per_page=40'

# --- A2: 日常线增量
git -C build/vk151 log --oneline -3
git -C build/vk151 merge-base --is-ancestor 24a19b953 HEAD
git -C build/vk151 status --porcelain
git -C build/vk151 diff --stat
git diff 24a19b953 HEAD -- drivers/… | grep -cE '^\+.*\bpr_(err|info|warn|debug)\('
grep -rn 'of_machine_is_compatible' drivers/gpu/drm/msm/

# --- B: 设备（只读）
ssh root@192.168.7.1 'uname -a; cat /proc/cmdline; cat /proc/misc | grep -i fastrpc'
ssh root@192.168.7.1 'systemctl cat greetd hexagonrpcd accounts-daemon'
ssh root@192.168.7.1 'for d in /etc/systemd/system/*.service.d; do ls -1 "$d"; done'
ssh root@192.168.7.1 'ls /sys/firmware/devicetree/base/soc@0/remoteproc@6800000/glink-edge/fastrpc/'
ssh root@192.168.7.1 'busctl get-property net.hadess.SensorProxy /net/hadess/SensorProxy net.hadess.SensorProxy HasAccelerometer HasAmbientLight HasProximity'
ssh root@192.168.7.1 'journalctl -u hexagonrpcd -n 20 --no-pager'
# 生成物一致性：19 个 unit 逐个 sha256 对比 out/units/systemd 与 /usr/lib/systemd/system
for f in packaging/elden-userland/out/units/systemd/*.service; do … done   # → 19× same
sha256sum rootfs/persistent-overlay/q28-boot-watchdog.sh \
          packaging/elden-userland/files/usr/local/sbin/q28-boot-watchdog.sh  # 同 sha

# --- B7: config ABI
bash scripts/check-abi-config.sh                       # 默认 → build/m1-73（错树）
bash scripts/check-abi-config.sh build/vk151/.config   # ✅ 27 项一致
bash scripts/check-abi-config.sh build/m4-base/.config # ❌ SUSPEND/PM_SLEEP/PM_SLEEP_SMP 三项 FAIL
```

### E.2 用的树与 commit

| 用途 | 树 | 身份 |
|---|---|---|
| checkpatch 本体 | `build/vk151/scripts/checkpatch.pl` | Version 0.32（与 `build/m3v2-7.3rc7` 同源，结果一致） |
| 日常线审计对象（A2/B1/B2/B3/B7） | `build/vk151` | `24223e44ad`（2026-10-14）+ 11 文件脏工作区；基线 `24a19b953` = Linux 7.3-rc7 |
| b5 新形状 | `build/b5-resoc` | `4812252692`，6 个提交 |
| Fixes 目标核验 | `build/m3v2-7.3rc7`（20264 提交，shallow）、`build/base-7.2`、`Y700-elden-linux`（非 shallow） | — |
| 设备 | `ssh root@192.168.7.1` | `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172 #2 SMP PREEMPT Fri Oct 30 13:06:36 CST 2026`，`boot_id 7e56f31b-…`，`uptime 1453 s` |

### E.3 未覆盖 + 原因

| 未覆盖项 | 原因 |
|---|---|
| **`dtbs_check` 全量 / `dt-validate` 全量** | 单 elden 板 dtbs_check 在本机需 ~20 min 以上（且本 lane 有 3–10 min/块的落盘纪律）；`dt-doc-validate` 依赖 `ruamel.yaml`（`patches/upstream/q28-dispcc-v2-20261029/GATES.md` §4 已记录本机缺件 `ModuleNotFoundError: No module named 'ruamel'`）。**只做了人工核对**：17 个自定义 compatible 逐个查驱动/文档（A2-07，16/16 有驱动 + 6 个有 yaml）、`lenovo,elden` 与 `bindings/arm/qcom.yaml:1171` 一致。**未做**：属性级 schema 校验、`regulator-*` 一致性、`status` 与 supply 一致性全量比对。 |
| **`static` 缺失 / 跨模块全局变量全量扫描** | 需逐文件语义判断（`sparse`/`smatch` 不在盘或未跑）。只做了 `CONFIG`/`MODULE_*` 与 `of_match`/`MODULE_DEVICE_TABLE` 的抽检（§A2-05/A2-08 标「未核实」）。建议补：`make ARCH=arm64 C=2 drivers/…` + `sparse`。 |
| **lore 归档独立复核** | lore 现被 Anubis 反爬拦截：`curl` 直连 → `HTTP 200` 但正文是 `Making sure you're not a bot!`；`?q=` 与 `/raw` → `403`；本仓工具 `~/.local/bin/lore-query.py` 的 PoW 解法对 `v1.26.2` 失效（`== !! pass-challenge HTTP 404`）。**替代通道 = patchwork API**（开源无认证），用它复核了 aw86927-v2 / wl2868c / MDSS resets / dwc3 / m-gic-its-claim / camss 的投递状态（见 §C-03、§C-04）。A1-06 的 `df53055c540f` **未能独立复证**（所有本地树均缺该对象，patchwork 不索引 commit hash）⇒ 该条按「未证实」处理。 |
| **`git am` 干净应用门逐系列复跑** | 只有 `q28-dispcc-v2-20261029/GATES.md` §1 提供了可复跑的 pristine 基线（`24a19b953`）并已自证 3/3；本 lane 未对 22 个系列逐个重建 pristine worktree（每个都要 ~1–2 min × 22 + 冲突排查）。**注意陷阱**：`build/m3v5-pristine` 的名字有误导——它的 HEAD 是 `34865c8915 usb: dwc3: fix the two-connector shared HS bus role handling`，**已是打过该系列的状态**，不是 pristine。 |
| **`scripts/` 202 个脚本逐个读** | 按任务书要求只做聚类 + 引用计数抽样（`grep -rl` 计数），审了 6 个簇（B6-01…B6-05 + D-04）。未审的簇：`wd-*`（`wd.sh`/`wd-ctl.sh`/`wd-net-baseline.dev.sh`/`wd-c1-*`）、`waydroid-*`（十余个）、`deploy-sensord-routec{,-debian}.sh` 双份的具体差异。 |
| **`build/vk151` 之外的其它 23 棵构建树** | 只核了 `m3v5-pristine`/`m4-base`/`b5-resoc`/`m3v2-7.3rc7`/`base-7.2`/`Y700-elden-linux` 的身份与 ABI 相关 config；`m1-73`/`q28-*`/`m8*`/`wl-v2`/`aw-series` 等未逐一核。 |
| **W=1 编译复跑** | 未重跑（本 lane 禁止改动树，且全量 `make W=1 drivers/…` 会写 `build/*` 的中间产物 = 破坏「只读」）。采用各系列已有 W=1 记录 + 本轮不采信自报的部分用「代码可见性」判（如 A2-01/A2-02 是纯 grep 可见的红线，不依赖编译）。 |
| **设备写操作 / 刷写 / A/B** | 按纪律禁止。D-01 的修法需要重编重刷 ⇒ 标「需用户在场」。所有设备命令均为 `cat`/`ls`/`grep`/`systemctl cat|show|is-active|list-unit-files`/`journalctl`/`busctl get-property`/`find`（读）。**未做**：`dd` 读 `boot_b`（虽然只读，但不在允许清单内）。 |

### E.4 本 lane 的产物边界

- 只新增 1 个文件：`reports/code-style-and-duty-overlap-audit-20261031.md`。
- **未**修改任何代码/文档/配置；**未** `git add`/`commit`；**未**触碰 `patches/`、`scripts/`、`packaging/`、`rootfs/`、`build/`、设备。
- 唯一副作用：`/tmp` 下的临时输出（`/tmp/l5-cp2.txt`、`/tmp/pw-*.json`、`/tmp/q.json` 等）与 `build/vk151` 里原本就存在的 `.o` 文件（未新增）。
- 所有 P0/P1 的修法均写成「命令 + 判据 + 预期输出 + 失败回退」，由父会话裁决后另派实施 lane。

DONE: reports/code-style-and-duty-overlap-audit-20261031.md 80359
