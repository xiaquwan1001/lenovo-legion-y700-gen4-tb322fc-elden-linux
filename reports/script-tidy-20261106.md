# 脚本 / 工具整理（2026-11-06 第四轮）

> 派工：本条 lane 原派 `doc-audit` 子代理（45 min 上限）；实测它 60 min 未落盘（turn 停在 03:03），
> 由 **L0 亲自做完并停掉该子代理**。因此本文件的每条数字都是 L0 自己重跑过的，不是 worker 自报。
> 上位：`.pi/plans/2026-11-06-项目整理第四轮.md`；相邻产物 = `reports/doc-audit-20261106.md`（文档）、
> `reports/out-uefi-trim-20261106.md`（`out/r21-sbstop` 裁决）。

## 0. 摘要（先数字）

| 量 | 值 | 现查命令 |
|---|---|---|
| 可执行入口总数 | **318**（`scripts/**.sh/.py` + `initramfs/` + `rootfs/` + `tools/` + `packaging/`） | `awk -F'\t' 'NR>6' versions/scripts-inventory.tsv \| wc -l` |
| **LIVE**（被入口文档或活脚本引用） | **264** | 同上 `$7=="LIVE"` |
| **HIST-ONLY**（只能从 `reports/`、`*/sessions/`、`.pi/plans/`、`archive/` 得知） | **54** | 同上 `$7=="HIST-ONLY"` |
| **UNREFERENCED**（全仓纳管文本零命中） | **0**（开工时 4 个，本轮全部裁决：2 件退役、2 件补登记） | 同上 `$7=="UNREFERENCED"` |
| 本轮工时内实际删/移的文件 | 3 个目录级：`tools/mkbootimg/`（空壳）、`wt/wt-scripts-tidy`（已合并 lane 工作树 1.2 G）、2 个脚本移 `archive/` | 见 §2 |

## 1. 本轮新增的机器账（这是「整理」能继承下来的部分）

`scripts/static-scan.py --inventory`（新增模式，~45 行）：

- 复用 doctor §6 已有的语料与 `grep -F` 引用索引（**零新增扫描成本**，整表 0.3 s）；
- 把引用分成 **live / hist** 两类：入口文档（`INDEX`/`TASKS`/`RESOURCES`/`RUNBOOK`/`DEVICE`/`PITFALLS`/`AGENTS`/`README`）
  与 `scripts|rootfs|tools|packaging|initramfs` 下的引用记 live；只在 `reports/ | */sessions/ | .pi/plans/ | archive/`
  出现的记 hist；
- `versions/scripts-inventory.tsv` = 快照（派生表，破例入 git 的理由同 `vk-kernel-identity.tsv`：兼作整理轮账本）。
  重生成：`python3 scripts/static-scan.py --inventory | sed '1d' > versions/scripts-inventory.tsv`（表头注释带全文）。

**踩到的坑（已沉淀 `PITFALLS #520`）**：清单表一旦入库就进了自己的语料 ⇒ 第二次运行把每个脚本名都算「被引用」、全表刷成 `LIVE`（318/318）。已在 `corpus()` 里排除自身输出，并把判据写成「先看三类分布」。

**为什么值得做**：`check-doctor §6` 只能抓「连历史记录都没提过」的脚本（4 个），
抓不到「写了但已经不用了」——后者正是历轮整理反复人工重查的那 55 个。现在有账可查。

## 2. 已执行的处置（3 类）

### 2.1 `tools/` 从「整目录忽略」改为「白名单纳管」

- `.gitignore`：`/tools/` → `/tools/*` + 四条 `!`（`avbtool.py`、`l2-extract/`、`gunyah-modules/`），
  并单独挡 `*.dtb`/`*.bin`/`vmmtest`/`rmtest`/`hypprobe`（构建产物）。`git add -n tools` = **20 个文本文件、0 二进制**。
- 坑与通则见 `PITFALLS #521`（`/dir/` 尾斜杠整目录忽略会让 `!/dir/xxx` 静默失效）。
- 理由（结构性，不是洁癖）：`.pi/memory/MEMORY.md` 2026-10-17 条已把「`tools/mkbootimg` 换机后全丢」归因于
  `.gitignore:15 /tools/`，但该条一直被忽略（本轮前 `git status --ignored tools` 仍是 `!! tools/`）。
- 连带：`tools/mkbootimg/` 只剩一个孤立的 `mkbootimg.cpython-314.pyc`（打包器真源早已搬到 `scripts/mkbootimg.py`）
  ⇒ **删除空壳**；`RESOURCES` §2.1「boot 打包/签名」行、`versions/layout.tsv` 的 `tools/` 职责随之改写。

### 2.2 退役 2 件 + 补登记 3 件（`UNREFERENCED` 的 4 个逐个裁决）

| 脚本 | 裁决 | 依据 |
|---|---|---|
| `rootfs/add-pkgs.sh` | **退役** → `archive/2026-11-06-retired-scripts/` | 硬编码 WSL 时代路径 `R=/TB322FC/rootfs`（换机后不存在）；现役 = `rootfs/build-rootfs.sh` |
| `rootfs/verify-image.sh` | **退役** → 同上 | 校验的是 **Ubuntu 根**；Ubuntu 线已不在主线，同职责 = `packaging/elden-userland/tools/verify.sh` |
| `rootfs/vk-probe.py` | 留 + 登记 | ctypes 直调 Vulkan loader 枚举物理设备（本机无 `vulkan-tools`），G1-8 基准现役探针 |
| `initramfs/probe-device.sh` | 留 + 登记 | initramfs 内 DT/`msm-id`/`board-id`/reserved-memory 一次性 dump，bring-up 现场用 |

登记点 = `RESOURCES` §2.1 新增行；退役账 = `PITFALLS §15.1` 新增一行；归档目录带 README（含「未退役同批候选」）。

### 2.3 空间：删一个已合并的 lane 工作树（唯一无争议的删除）

`wt/wt-scripts-tidy`（1.2 G，`lane/scripts-tidy` @ `75ab301`）——`git merge-base --is-ancestor 75ab301 main` 为真、
`git -C wt/wt-scripts-tidy status --porcelain` 为空 ⇒ `git worktree remove`。`wt/` 现 4 KB。

> `out/r21-sbstop` 的 4.6 G **故意没删**（活线中间件、且构建配方未脚本化）——理由与可执行配方见
> `reports/out-uefi-trim-20261106.md`。盘上可用 464 G，没有拿活线换空间的必要。

## 3. 重复 / 重叠对（只定性，未合并——合并要连着文档一起改，留给专门一轮）

| 家族 | 成员 | 现状判断 | 建议 |
|---|---|---|---|
| 串口 | `serial-log.sh`（抓 console）/ `serial-logger.sh`（跨重启重连）/ `serial-capture.sh`（等节点出现再落盘）/ `serial-fanout.sh`（systemd 常驻追加）/ `serial-run.sh`（串口执行一条命令）/ `serial-probe.sh`（独占敲一下）/ `serial-sysrq.py` | **职责确实不同**，不是重复；但 7 个入口无统一前缀文档 | 保持，补一行家族说明（`RESOURCES` §2.1 已有 `serial-run/serial-log` 提及） |
| 网络启动 | `net-up.sh`（NM）/ `net-up-manual.sh`（无 NM 回退）/ `net-egress.sh`（主机选出口）/ `net-selfheal.sh`（设备侧自愈） | 前两个是**主/备**关系（同一件事两条路），后两个不同层 | 保持；`net-up-manual.sh` 标注「fallback only」 |
| 刷写 | `flash-b.sh`（Linux 内写 b 槽）/ `flash-recovery.sh`（Linux 内写 recovery 分区）/ `sign-boot-b.sh` | 目标分区不同，非重复 | 保持 |
| boot 打包 | `build-boot.sh`（常规）/ `build-boot-slim.sh`（G1-30 最小 initramfs，**已判不作日常启动**） | slim 是**已否决路线**的产物 | 建议在脚本头加「⛔ 不作日常启动，见 TASKS G1-30」 |
| Waydroid | 12 个 `waydroid-*.sh`（camera×2、haptics×3、headless×2、mesa/proxy/ota/cmdline） | 分属 C5/C10/Q28/代理四条线，**不是同一件事** | 保持；缺一个 `waydroid-*.sh` 家族索引（可并入 `RESOURCES` §2.1） |

结论：**本轮没找到可以安全合并的脚本对**。「看起来重复」的几个家族经逐条读头注释都各有职责边界
⇒ 真正的欠账是**家族索引**，不是合并。

## 4. 卫生（抽查，不是全量）

| 项 | 结果 |
|---|---|
| `#!/bin/sh` 里的 bashism | 0（`static-scan.py --tsv`：`BASHISM -`） |
| 从未被提及的脚本 | 处理完（见 §2.2） |
| `patches/current-tree` 指向 | `build/daily` 存在（`ls -l patches/current-tree`） |
| `build/` 树名引用 | 未做全量核对（上轮 11-05 归档过 29 棵旧树，脚本里的旧树名引用未逐条查）；**待下一轮**：`git grep -n 'build/[a-z0-9-]*' -- scripts/` 与 `ls build/` 求差 |
| `patches/uefi/` 45 个目录分级 | **未做**（需逐目录读 patch + 对应报告，≥1 h）⇒ 明确留给下一轮 |

## 5. 下一轮可直接执行的清单（按收益/代价排序）

1. **`patches/uefi/` 分级**（45 目录，520 KB）：按「已推翻（对应报告已加作废头）/ 已定案（结论进 SSOT）/ 仍活（11-06 窗口用）」三类，
   把前两类移进 `archive/patches-uefi-<date>/` 并在 `TASKS` §5 留一行指针。判据：每个目录能在 `reports/` 找到唯一归属报告。
2. **`p7`/`preamble7` 打包配方脚本化**（见 `reports/out-uefi-trim-20261106.md` §3，与 UEFI 主线并行）。
3. **家族索引两行**：`serial-*`（7 个）与 `waydroid-*`（12 个）各在 `RESOURCES` §2.1 加一行「成员 + 一句话区别」。
4. **`build/` 旧树名引用清扫**：`git grep -n 'build/[a-z0-9_.-]*' -- scripts/ packaging/ | grep -v daily` 与 `ls build/` 求差。
5. **10 个 >1500 B 单元格下沉**（`reports/doc-audit-20261106.md` §2 已给逐条目标文件）。
