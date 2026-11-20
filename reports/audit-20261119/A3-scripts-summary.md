# A3 — scripts/ 全量审计（只读）

审计代理: A3-scripts-auditor / 生成时间: 2026-11-19 / 只读
配套明细: `reports/audit-20261119/A3-scripts-audit.tsv`（344 行数据，sha256 前 16 位 `0a49af1c2d61f9b1`）

## 结论（数字先行）

1. **总量与任务口径修正**：`find scripts -type f` = **401** 项，非任务描述的 314。构成：
   - 340 个常规文件 + **4 个符号链接**（指向 `~/hw-stability/scripts/`，`find -type f` 不计 symlink：`scripts/{detect-memory-corruption.py,host-mem-build-stress.sh,kbuild-sanity.sh,verify-tree-integrity.py}`，均 KEEP，文档引用 3–14 次）；
   - **57 个 .pyc**（`scripts/__pycache__/`）+ 4 个 .pyc（`scripts/doctor/__pycache__/`）= 61 个编译缓存 = **脏数据**，可安全删除（可再生，git 未跟踪与否未逐个核实）。
   - 344 项（不含 `__pycache__`）全部进了 TSV。
2. **分类分布**（TSV 第 6 列，`cut -f6 | sort | uniq -c`）：
   | 分类 | 数量 | 判据 |
   |---|---|---|
   | KEEP | 332 | 活集闭包 93 + versions/*.tsv 账目引用 210 + 近期（≥2026-11-18）进行中工作文档引用约 29 |
   | KEEP-ARCHIVE | 9 | 仅文档/reports 引用、≥30 天未改，可移 `archive/scripts/` |
   | DELETE-CANDIDATE | 3 | 零引用 + 2026-10-17 未改 |
   | （脏数据） | 61 .pyc | 编译缓存 |
3. **零引用删除候选仅 3 个**，全是 `scripts/wd-audio-test/` 下的 Java 测试源（`TestAudio.java`/`TestCodec.java`/`TestRecord.java`，mtime 2026-10-17）；但同目录 `build.sh` 与 `ListCodecs.java` 有引用，且这是 Waydroid 音频取证的编译输入 → 建议**随目录整体移 archive** 而非单独删。预计释放 <10 KB，删除收益可忽略。
4. **无成对 MERGE（重复）候选**：按规范化 stem 聚类 + 逐个看头部注释，未发现功能重叠对。近似对均已核实为不同职责：
   - `audio-tplg/build.sh`（构建 AudioReach topology .bin）vs `wd-audio-test/build.sh`（构建 Waydroid 容器音频测试 dex）——仅同名不同物（TSV 有 generic-name 计数虚高警告）。
   - `host-net-proxy.sh`（手工 socat 中继）vs `systemd/host-net-proxy.service`（其 systemd 化替代，unit 头注释自述「取代手工 scripts/host-net-proxy.sh」，`systemd/host-net-proxy.service:3`）→ **这是唯一一处真正的替代关系**：`.sh` 仍被文档引用 5 次，建议归档 `.sh` 并改文档指针（KEEP-ARCHIVE 语义，未列入上表因它有引用）。
   - `android-slim-v2-plan.sh` vs `android-slim-v3-build.sh`：v3 头注释（`android-slim-v3-build.sh:3-6`）明确 v3=v2-B+三件 v1 缺失动作，是迭代不是重复；两者均被文档引用，保留。
5. **KEEP 体量大的主因**：`versions/*.tsv`（vk-registry、vk-kernel-identity、scripts-inventory、layout 等，`ls versions/*.tsv`）以 basename 记账 210 个脚本 —— 符合 AGENTS.md「vk 版本账」机制，这些是工件生成器/取证脚本，**必须保留**。

## 活集清单（闭包）

种子 = 门禁三件 `scripts/check-doctor.sh`、`scripts/zero-to-desktop-check.sh`、`scripts/deploy-desktop-shell.sh`；闭包 = 种子 + 其文本中引用的全部 `scripts/` 内 basename/路径，传递展开（含 `scripts/doctor/` 全部 22 段）。**共 93 项**，逐项清单在 TSV 分类=KEEP 且被 `check-doctor.sh`/`doctor/*` 闭包覆盖者；中间产物存 `/tmp/a3active.json`（会话临时件，未落 reports）。
另：`versions/*.tsv` 引用 210 项为第二保留层（`KEEP-versioned`）。

## KEEP-ARCHIVE 候选（9 项，建议移 archive/scripts/，先改文档指针）

均仅被 reports/文档引用、mtime ≤2026-10-30（明细 TSV 第 1/6 列）：

- `scripts/audio-tplg/SM8750-Lenovo-Y700-Gen4.m4`、`scripts/audio-tplg/out/Lenovo-Y700-Gen4-tplg.bin`、`scripts/audio-tplg/out/Lenovo-Y700-Gen4.conf`（tplg 源与产物；**注意** audio 主线若重启 tplg 工作需回取）
- `scripts/elden-hapticd.c`（Waydroid vibrator 桥，C 源；若 G2 振动线还活着则降级为 KEEP）
- `scripts/eldroid-sensord.c`（C4 传感器宿主 daemon，同上）
- `scripts/elden-powerlog.initd`（Q24 熄屏掉电判别 OpenRC 单元）
- `scripts/ffrumble.c`（aw86927 宿主侧振动阳性对照工具，取证价值，归档不删）
- `scripts/systemd/host-net-proxy.service`（当前可能仍在设备上运行，归档前需确认设备侧状态——**未取证**）
- `scripts/wd-audio-test/ListCodecs.java`

风险/前置：均为「证据型」资产，移动会破坏 reports 里的相对指针；执行前需 `rg -l <basename>` 改指向 archive 路径（本轮只读未改）。

## 删除候选（3 项）

`scripts/wd-audio-test/Test{Audio,Codec,Record}.java`：零引用（docs=0, scripts=0，`/tmp/a3scan2.py` 口径）、mtime 2026-10-17（>30 天）。建议动作实际为「随 wd-audio-test 目录归档」。预计释放约 8 KB（`du -b` 未逐文件核实，未取证）。

## 脏数据

- `scripts/__pycache__/`（57 个 .pyc）与 `scripts/doctor/__pycache__/`（4 个 .pyc）：Python 编译缓存，可再生。建议加 `.gitignore` 条目并删除（本轮未删）。证据：`find scripts -name '*.pyc' | wc -l` = 61。

## 脚本-文档不一致（逐条）

1. **任务描述计数过时**：314 vs 实测 401（`find scripts -type f | wc -l`）；`versions/scripts-inventory.tsv` 若为脚本清单真源，其计数需复核（本轮未比对行数，未取证）。
2. `scripts/host-net-proxy.sh` 被 systemd unit 头注释声明取代（`systemd/host-net-proxy.service:3`），但文档仍引用 `.sh` 配方 5 次（scan2 docs 计数）→ 文档漂移，配方应指向 unit。
3. `wd-audio-test/build.sh:5` 自述路径为 `tools/wd-audio-test/build.sh`，实际在 `scripts/wd-audio-test/` → 注释路径过时。
4. 4 个 hw-stability 符号链接（2026-11-16 建，`ls -la scripts/`）使「scripts/ 自包含」假设失效：审计/归档脚本若按 find -type f 统计会漏掉它们；且指向仓库外路径，跨机不可复现。建议在 INDEX 或 doctor 中登记（本轮未改）。
5. `scripts/check-doctor.sh` 头注释与 `--help` 行为一致（只读自检），未发现不一致（抽查通过）。

## 方法与可核查性

- 引用扫描：`/tmp/a3scan.py`（basename 全文匹配）+ `/tmp/a3scan2.py`（修正口径：语料剔除 `scripts/doctor/*` 与 `__pycache__` 防清单型脚本污染计数；新增 docs_path/scripts_path = `scripts/<basename>` 路径限定匹配）。语料 = INDEX.md、TASKS、PITFALLS、DEVICE、RESOURCES、RUNBOOK-BRINGUP、HISTORY、README、PROGRESS、reports/、.pi/（md/tsv/txt）+ versions/*.tsv 单独判 in_versions。
- 局限（诚实声明）：① basename 全文匹配对通用名（`build.sh`、`README.md`）计数虚高，已在 TSV 用 docs_path 列校正判类；② `.pi/sessions` 只按文件名匹配，未逐篇语义阅读；③ 头部注释逐个自动抽取 + 15 个代表脚本人工 `head -6` 核对（check-doctor.sh、zero-to-desktop-check.sh、deploy-desktop-shell.sh、android-slim-v3-build.sh、eldroid-sensord.c、elden-hapticd.c、audio-tplg/{SM8750-...m4,build.sh}、elden-powerlog.initd、systemd/host-net-proxy.service、wd-audio-test/{TestAudio.java,build.sh}、ffrumble.c、host-net-proxy.sh、t2-stock-lun45.sh），其余 329 项用途来自头注释自动摘要，存在个别摘要质量风险。
- 本轮零写操作（仅 reports/audit-20261119/ 下两个产出文件 + /tmp 临时脚本）、零 git 写、零安装、零设备操作。
