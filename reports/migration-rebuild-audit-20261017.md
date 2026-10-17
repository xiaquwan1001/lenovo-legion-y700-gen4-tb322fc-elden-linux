# 换机后「可重建进度」审计（2026-10-17）

> 目的：量化 2026-10-17 换机（`xuqianhui1001` → `xuqianhui`）后**工作区实际还剩多少可支撑继续研究的资产**，
> 把「丢失」从一句描述变成**分组 + 重建代价 + 顺序**。配套：`versions/migration-gaps-2026-10-17.tsv`（缺口登记）。
> 本文只做账面与路线，不改任何既有结论口径（Q24/Q28 口径见 `TASKS/README.md` §5）。

## 0. 数字结论

| 项 | 数值 |
|---|---|
| 镜像身份表行数 | 117 行，其中**源提交仍在本地仓库 = 58**，**缺失 = 56** |
| 缺失源提交的构成 | **M1-7.3 线 27 行**（同源 `ed6f232d10e3`）+ **上游显示实验线 9 行**（p1/p2/p4）+ **vk 编号构建 13 个**（vk54/58/79/80/84/86/90/91/92/95/96/98/101）+ p1-uplink 等杂项 |
| 镜像产物 | `out/*.img` = **0 个**；`.manifest` = **153 个**（身份可查、镜像不可复跑） |
| 内核 git 仓库 | `geekidos-linux` **在**（2.3 G，shallow），**62 refs / 19 heads / 最高 tag = vk83**，HEAD = `ba28ec16f`（= gitlab `fe54fcfff` 线） |
| 可恢复 refs 快照 | `backup/kernel-git-repair-2026-10-08`（41 refs）、`-10-10`（43 refs，含 `q28/vk86`）两个 bundle **在** |
| 补丁/配置资产 | `patches/` 6.4 M **完整**（含 `upstream/m1..m4` 7 个系列、`q28-*` 22 枚、`config-vk*` 11 份、fragment 8 份、candidate-* 9 枚） |
| 报告/证据 | `reports/*.md` = **103 篇**；`backup/` 2.5 G（fw/stock/HA2EXB0E 全在） |
| 会话轨迹 | `.pi/sessions` 179 个顶层 jsonl（备份内 311 文件/391 M 已 RESTORED） |
| 自检 | `scripts/check-doctor.sh`：**FAIL=1 WARN=0**，唯一 FAIL = §5d 内核身份表过期（换机后必然） |
| 宿主工具链 | `aarch64-linux-gnu-gcc`/make/bison/flex ✅；**clang、dtc、adb、fastboot 均缺** |

一句话：**「文档 + 补丁 + 配置 + 证据」几乎无损；「历史提交 + 构建产物 + 在机镜像」才是真损失**。
即：**结论与配方在，可执行物不在**。

## 1. 现存的四类资产（可直接用）

1. **决策/证据层**：`reports/` 103 篇 + 七个角度 `README.md` + `PITFALLS/` + `archive/topics/` + `HISTORY/`。
   这批是**最贵的部分**（含被否证的假设），全部在。
2. **代码增量层**：`patches/upstream/{m1,m2,m3,m3-3,m3-4,m3-6,m4-camss}`（已发/备料的上游系列，checkpatch/dt-doc-validate 结论随附 README）；
   `patches/q28-*.patch`（22 枚，Q28 各轮实验的**唯一代码记录**）；`patches/candidate-*`（TF/BT）。
3. **构建配方层**：`patches/config-vk{20,26,27,28,38,40,50,76,89,95}` + `fragment-{modular,c1-iprule,camera-sensors,netd-ipv6-xfrm,modular-video}` + `config-daily-c1`；
   `reports/*daily-config-rebuild*`、`*.manifest`（153 份，含 `config_sha256`）⇒ **能把任一 vk 的 config 复原到 sha 级**。
4. **设备侧现状（在机上，不在主机）**：U2 的 `boot_b` = `m1-baseline-f3`（7.3-rc7 线，**主机无副本**）、持久根 `/lib/modules/7.3.0-rc7-debug-ged6f232d10e3/`（1497 `.ko`）、`/usr/local/sbin/{cam-mode.sh,...}`。
   `backup/HA2EXB0E-16+512/` 只有 `boot_b-before-vk72`/`-before-vk94` 两份 100 MiB 镜像 + stock 全套。

## 2. 真损失（分组 + 是否可再生）

| 组 | 内容 | 可再生性 | 判定 |
|---|---|---|---|
| **L-A 内核提交史** | `vk87–vk126`、`m1/*`（7.3-rc7 线，含 `m1-73/baseline` tip `c7da05b1d8`）、`m3/*`、`q28/*` 分支对象 | **部分可再生**：`patches/upstream/*` 覆盖 M1–M4 的**补丁内容**；`patches/q28-*` 覆盖 Q28 实验补丁；但**分支结构/逐提交顺序/提交信息**不可再生 | 主要损失是「可二分性」，不是「代码」 |
| **L-B 构建产物** | `out/*.img` 41 个（vk42–vk126 + 台架臂） | **需重编**：config 可复原到 sha 级，但**镜像哈希不可能一致**（时间戳/编译器） | 台架 A/B **必须重新采样**，不能引用旧镜像 sha |
| **L-C 在机镜像** | `m1-baseline-f3`（boot_b）、1497 `.ko` 模块树 | **只在设备上**：只要 U2 的 b 槽不被覆盖，就可用 `fastboot fetch boot_b` 与 `ssh`+tar 取回 | 本审计的**最高优先级动作**（见 §4 P0） |
| **L-D 日志/工具** | `logs/`（bench/ui 原始日志）、`tools/wd-audio-test/` | 日志不可再生（报告里已引用的数字仍在）；工具可按报告重写 | 影响 = 少量证据指针悬空，不阻塞 |

## 3. 可重建等级（按「重建后能做什么」划分）

- **R0（当前已成立，0 成本）**：`clean/base`=`d02658e63`（=vk64 源）+ `baseline/feature-only`=`6c1376907` 都在，
  `vk64/vk89/vk94` tag 在 ⇒ **功能基线口径（`reports/BOUNDARY-2026-10-10-clean-base.md`）完全可用**。
  能做的事：任何「以 7.2 clean/base 为基线」的实验（Q28 round/delay 类、模块化、C1 config 片段）。
- **R1（小时级，需网络）**：`git fetch` 上游 7.3-rc7（`24a19b953e` 当前**不在**本地）→ 按
  `reports/m1-rebase-7.3rc7-execution-20261013.md` + `patches/upstream/m1-2026-10-14/` 重放 M1 线。
  **不能**得到 `ed6f232d10e3` 同一提交，但能得到**等价 DTB/驱动集**（M1 线本质 = 7.3-rc7 + 12 枚补丁）。
- **R2（半天级）**：重编 `vk126-c1`/`vk124-merged` 等「日常镜像」口径（config 来自 `patches/config-daily-c1` + `fragment-c1-iprule{,6}`），
  用 `vk-identity.py` 重新分配新号（**不要复用旧 vk 号**，旧号语义已绑定丢失的二进制）。
- **R3（不可达）**：恢复 `vk87–vk126` 的**逐提交历史**、恢复旧镜像 sha、恢复 `logs/`。

## 4. 重建顺序（含需人手/物理动作的项）

| 优先级 | 动作 | 依赖 | 产出 |
|---|---|---|---|
| **P0** | **抢救设备侧活资产**：接 U2 → `fastboot fetch boot_b`（= `m1-baseline-f3`）、`adb`/ssh tar 走 `/lib/modules/7.3.0-rc7-…`、`/usr/local/sbin/*`、`/root/q24bak/` | **用户插线**；本机需先装 `platform-tools`（adb/fastboot 缺） | 把 L-C 从「只在机上」变成「有两副本」；补齐 vk126/m1 线唯一现存镜像 |
| **P1** | 修 `check-doctor` §5d：重生成 `versions/vk-kernel-identity.tsv`（`scripts/vk-identity.py`） | 无 | 自检回绿；表内需标注「旧镜像已失、行保留为历史账」 |
| **P2** | 装构建依赖 `clang` + `dtc`（`apt install clang device-tree-compiler`） | 网络/镜像 | 恢复 `dtbs_check`/`dt-doc-validate`/内核编译能力 |
| **P3** | R1：重放 M1-7.3 线（7.3-rc7 + `patches/upstream/m1-2026-10-14`） | P2 | 重新得到 7.3 基线树与 DTB；Q24 N5b/N6 的「血统二分」实验重新可跑 |
| **P4** | R2：重建 1 个日常镜像（`vk-new`，config = daily-c1） | P2/P3 | 台架重新可测；先只做**冷起 3 发**确认 GOOD/坏发比例，再谈 Q28/Q24 |

## 5. 对缺口登记表的增量（已写入 `versions/migration-gaps-2026-10-17.tsv`）

- 新增：`boot_b(m1-baseline-f3)` = **DEVICE-ONLY**（主机无副本，唯一抢救窗口 = 设备未被覆盖前）。
- 修正：`geekidos-linux refs vk87..vk126` 的**可恢复部分** = bundle 到 `q28/vk86`（10-10，43 refs）+ `patches/` 全量补丁；
  ⇒ 原「全部不可再生」应细化为「**M1/M3 系列补丁可再生，提交史不可再生**」。

## 6. 验收（本文的检查项）

1. `scripts/check-doctor.sh` 从 FAIL=1 → FAIL=0（P1 完成后）。
2. `git cat-file -e ed6f232d10e3` 从 MISSING → PRESENT（P3 完成后，或明确记录「用新提交替代、旧号封存」）。
3. `ls out/*.img | wc -l` ≥ 1 且 manifest 与镜像 UTS 一致（P4 完成后）。
4. P0 完成后：`backup/` 内出现 `boot_b-m1-baseline-f3-*.img` 与 `modules-7.3.0-rc7-*.tar.zst`。
