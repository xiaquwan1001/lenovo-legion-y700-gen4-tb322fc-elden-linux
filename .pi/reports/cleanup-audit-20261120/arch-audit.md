# arch-audit — y700-elden 工程架构审计（2026-11-20，只读）

> 状态：**完成（2026-11-20 06:4x）**
> 范围：分层/体量/依赖/构建门禁/测试覆盖；只读，不改代码。

## 0. 一句话定位

「研究型仓库 + 构建农场混合体」：代码（内核补丁/scripts）很小（<50M），但 87G out/ 造件、29G backup 与 240 个运维脚本把仓库变成了数据农场；架构风险主要在**脚本层无模块化、审计证据与造件无索引化账本**，而非代码复杂度。

## 1. 分层与体量

| 层 | 内容 | 体量 |
|---|---|---|
| 代码层 | Y700-elden-linux/（内核树 28M）、patches/ 13M、initramfs/ 2M、tools/ 1.6M | ~45M |
| 脚本/编排层 | scripts/ 2.6M（240 个 .sh + ~60 个 .py） | 2.6M |
| 证据层 | reports/ 2.0G（564 篇 + artifacts/）、PITFALLS/ 1.7M、TASKS/ 2.4M | ~2G |
| 数据层 | out/ 87G、backup/ 29G、bootslot-b/ 1.7G、external/ 884M、dl-cam/ 639M | ~119G |
| 元层 | INDEX.md（SSOT）、AGENTS.md、.pi/（memory + skills + reports） | ~2M（skills 独立） |

依赖方向：INDEX.md → TASKS/README（开放待办）→ reports/*（证据）→ scripts/*（复现命令）→ out/*（产物）；PITFALLS 与 .pi/memory 为旁路经验层。方向基本单向，无环；主要问题是「证据→数据」引用无自动校验（报告引用的 out/ 文件可被静默删除）。

## 2. 入口文件

- 文档入口：`INDEX.md`（SSOT，§0 状态摘要）→ `TASKS/README.md`（§7 = M 系列上游化）。
- 构建入口：`scripts/build-kernel.sh`（唯一合法内核构建入口，防宿主 x86 重写 .config）；安卓侧为外部 AOSP 树（out/android-* 造件）。
- 门禁入口：`scripts/check-doctor.sh`（总门禁）+ 9 个专项 check-*（abi-config/doc-assets/init/layout/modular-config/progress-counts/project-memory/series-selfcontained/sessions）。
- 收尾口径：`.pi/AGENT-OPS.md` §5（FAIL=0 + 工作区 clean）。

## 3. 脚本依赖图（抽样）

scripts/ 已有 lib-* 分层（lib-fastboot.sh、lib-device-lock.sh 等 sourced 库），约 240 个入口中相当部分仍直接调底层命令。shellcheck -S error 实测 313 个入口仅 4 文件命中（见 deadcode.md）：说明脚本层总体卫生，但无统一 dispatch/CLI（每个任务一个一次性脚本，命名即接口）。`check-doctor.sh` 充当聚合校验器是事实上的「架构测试」。

## 4. 门禁/自检覆盖

- 覆盖好：文档资产存在性（check-doc-assets）、session 索引（check-sessions）、进度计数（check-progress-counts --selftest）、报告孤儿检测（check-doctor §13）。
- 缺口：① out/ 造件与 manifest 的对应关系无门禁（版本账靠 vk-identity.py 人工账本，且禁重跑）；② 240 脚本无入口清单/用途索引（A3 审计是一次性 tsv，非持续门禁）；③ 报告→镜像文件的引用无存在性校验（本轮就发现 android-min-20261118 无报告）。
- 测试覆盖：无单测框架（合理——脚本型项目）；「测试」= check-* 门禁 + check-progress-counts --selftest + QEMU 冒烟（scripts/qemu-full-chain-smoke.sh ~35s），覆盖编译链但覆盖不了设备侧行为。

## 5. 建议（P0/P1/P2）

| # | 级别 | 问题 | 判据路径 | 建议动作 | 收益 | 风险 |
|---|---|---|---|---|---|---|
| 1 | **P0** | 审计结论未入库（git status 未跟踪 reports/audit-20261119/ 等），断电即丢——06:21 crash 已示范一次 | `git status --short` | 主会话本轮就 `git add` 提交 | 消除单点丢失 | 无 |
| 2 | **P0** | out/ 造件无「报告↔镜像」账本门禁，删错 v3 final 会毁掉唯一可用造件 | `reports/android-slim-v3-20261119.md` 头部「首启判据未取得」 | 给 out/ 增加轻量 manifest 门禁（check-doctor 加一节：每个 out/<name>/ 必须有对应 reports/<name>.md 或归档标注），删除动作前强制查账 | 防误删 22G 级关键件；本报告 §7.2 的 min-20261118 缺报告即实例 | 门禁实现 1–2h，需防误报 |
| 3 | P1 | 240 个一次性脚本无索引，重复造轮子（A3 审计 20261119 是一次性 tsv 会过期） | `ls scripts/*.sh \| wc -l`、`reports/audit-20261119/A3-scripts-audit.tsv` | 生成 scripts/README.md 索引（名称/用途/依赖 lib），A3 升级为可重跑脚本 | 降低维护与派发成本 | 无 |
| 4 | P1 | shellcheck 疑似真逻辑错误 2 处（SC1073 解析中断、SC2081 恒假分支）未修 | `deadcode.md` 命中表；scripts/rebuild-vk64-image.sh、scripts/uefi-build-variant.sh | 修 2 处文案转义/glob 比较并重跑 shellcheck -S error | 消除门禁盲区 | 低（改前人工读行） |
| 5 | P1 | 证据→数据引用无存在性校验：报告引用的 out/ 镜像可被静默删除 | 本轮 §6 A 档多项删除建议本身依赖此风险 | 同 #2 的 manifest 门禁覆盖 | 证据链完整 | 同 #2 |
| 6 | P1 | out/ 87G 无生命周期状态标注（active/superseded/verified），每次瘦身都要全量考古 | slim-worktree-plan.md §0–§3 | 在 out/<name>/放一个 STATUS 文件（或统一 out-manifest.tsv），造件时即写状态 | 瘦身从考古变查表 | 无 |
| 7 | P2 | verify/、rb/ 等校验副本默认落盘不清理，是 33GB 可回收的主因 | slim-worktree-plan.md §6 A 档 | 造件脚本统一「校验通过即删副本」开关（默认删，--keep-verify 保留） | 一劳永逸省 10G+/轮 | 需改造件脚本流程 |
| 8 | P2 | DEVICE/README.md 等靠「叠写」实现时间序（cleanup-proposals (a) 表） | cleanup-proposals.md (a) | 按其批二计划做归档移动（等放行） | 新读者阅读成本降 | 引用改动面广 |
| 9 | P2 | .pi/reports/（agent 工作区）与 reports/（在库证据）双轨，命名易混 | `.pi/reports/cleanup-audit-20261120/` vs `reports/` | 在 INDEX.md 文档地图给两轨各一行明确定位 | 消歧 | 无 |
| 10 | P2 | pyflakes/vulture 未装，~60 个 scripts/*.py 无静态扫描 | deadcode.md「未跑的检查」 | 有网窗口 `pip install vulture` 补跑一轮 | 补盲区 | 低 |

## 附录 A 复现命令

```sh
cd /home/xuqianhui/y700-elden
du -sh * .pi 2>/dev/null | sort -rh | head -20            # §1 体量
find . -path ./.git -prune -o -type f -size +200M -printf '%s %p\n' | sort -rn   # 大文件
ls scripts/*.sh | wc -l                                    # 240 脚本
ls scripts/check-*.sh                                      # 门禁清单
git status --short                                         # 未跟踪证据
timeout -k 3 120 bash scripts/check-doctor.sh              # FAIL=0 WARN=6（todos 报告实测）
```
