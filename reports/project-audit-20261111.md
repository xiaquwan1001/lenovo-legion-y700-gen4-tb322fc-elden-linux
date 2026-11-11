# 项目整理审计 2026-11-11

范围：只读调查；仅本机静态分析，未联网。

> **口径声明**：本报告只读产出；未删未改任何既有文件，所有「删除/归档」均为建议，待用户裁决后按 RESOURCES §3 纪律（删前 O_DIRECT 复核 sha + bundle）执行。

## §1 文档 ↔ 实况不一致

### 1.1 TASKS/sessions「★SSOT 待并入」未并入项（2026-11-09/11-10）

11-09/11-10 共 11 个会话文件，逐条核对其「★SSOT 待并入」字段后，**仍有 2 条真正未并入**：

| 失效路径 | 引用位置 | 实况 |
|---|---|---|
| `out/boot-elden-vk61.img` | TASKS:46（G1-30 行证据列）、versions/vk-triage.tsv、archive 多处 | **全仓不存在该文件**，且不在 `backup/out-history-20261105/ARCHIVE.tsv` 归档账内（账内 114 件无 vk61/vk63/dp5/vk74/m1-baseline）；仅剩 `out/boot-elden-vk61.manifest`。建议：G1-30 行改指 manifest + `versions/vk-kernel-identity.tsv` 逐字节证据，或补一行「镜像件已删、证据以 manifest+sha 为准」 |
| `out/boot-elden-vk63.img` / `dp5.img` / `vk74-q28power.img` / `m1-baseline.img` / `cdsp-vk47clean.img` | TASKS 各行 | 同上：只剩 `.manifest`，镜像件已删 |
| `out/r21-sbstop-p{38,45,58,59,61}/uefi-preamble*-r1.img` 及 `out/r21-sbstop/` | TASKS §5 多处（p45/p58/p59/p61 各块）| 2026-11-10「发送清理」会话：9 明言已删（释放 7.39 GiB）；但 TASKS §5 各历史块仍原样引用。建议：在这些块首统一加一行「镜像件已于 2026-11-10 删除，配方/补丁在 `patches/uefi/`，sha 见会话记录」，不必逐路径改 |
| `patches/uefi/p58-kept.sh`、`scripts/envpass-provision.sh`、`scripts/sensor-send-termux.sh`、`tools/render.py`、`tools/verify.sh` | TASKS 各行 | 文件不存在（rg 全仓无引用或仅 TASKS 自引）。建议逐条改指现存等价物或删除引用 |

参考脚注：`scripts/check-progress-counts.sh` 实跑输出 **G1 35/36、G2 8/13**，与 TASKS:14/24 的口径一致（未过期）。

### 1.2 TASKS §1 产物路径失效（镜像已删，文档仍指原路径）

用正则抽 TASKS/README.md 全部带后缀的产物路径并逐个 `[ -e ]` 验证，**16 条失效**。根因是两轮清理（2026-11-05 `out/` 归档 114 件、2026-11-10 删 `r21-sbstop-p54…p61,63…65` 共 7.39 GiB）后文档未回填：

1. `TASKS/sessions/2026-11-10-pc1干净世代与GRUB双层菜单.md:26`
   - 待并入内容：「pc1 干净世代 + R72 菜单修复」应补进 `TASKS/README.md` §1 G1-29 行与 §5 收尾块。
   - 核验：`rg 'pc1|干净世代' TASKS/README.md` → **0 命中**；G1-29 行（:45）只有「BDS/GRUB 菜单交互」剩余项，未提 pc1/R72。
   - 建议改法：在 §1 G1-29 行「剩余」句尾补一句，并把该会话文件标记字段改为「已并入」。
2. `TASKS/sessions/2026-11-10-Waydroid网络定案与droidloom复评.md:31`
   - 待并入内容：§5 Q3（droidloom）行补「2026-11-10 设备实测：doctor 13 过/1 阻塞，阻塞只剩 NF_TABLES；合成器缺口 = phoc 少一行，0.59.rc1 也没有」；Q1/C3 行补「Waydroid 网络已定案，判据改 HTTP 码」。
   - 核验：`TASKS/README.md:1053`（Q3 行）最新只写到 2026-11-08 复核，无 11-10 设备实测句（11-10 的 droidloom 实测写在了 §2 C12 行:84，Q3 行未回指）。
   - 建议改法：Q3 行末尾追加 11-10 实测一句 + 指向 C12；或直接在 Q3 行标「实测见 §2 C12（2026-11-10）」。

其余 9 个会话（11-09 离线收口、11-10 的 UEFI 系 5 个、发送清理、C3 收口、树合并、UEFI 收尾）字段均为「已并入」或「无」，抽样回查 TASKS §0/§1/§4/§5 均能找到对应内容（如 G1-29 行:45 的 dtbo_a 根因、:134 N1 收口、G1-37 行:53 的 zram 收口），断言成立。

### 1.3 INDEX.md §3 现状快照过期（落后 11-10 深夜收口）

- `INDEX.md:189-193`（§3「已定不做」块内的 G1-29 条）仍写「**未解决的只剩一条**：把路线 B 变成默认启动 —— 卡在 flashed 形态……**下一步 = p67**」，并指「当前口径只在 §5『2026-11-09（晚，p63→p66）』块」。
  实况：p67 已上机（`out/r21-sbstop-p67/` 存在），且 11-10 深夜 `dtbo_a` 真根因已定案、flashed 形态 37.0 s 打通（`DEVICE/README.md §1.1` 2026-11-10 20:15 块、`TASKS §5`「dtbo_a 真根因」块均已是新口径）。
  **建议**：该 bullet 改为「flashed 已通（11-10 深夜，dtbo_a 根因）；剩 BDS/GRUB 菜单取证 + 冷启动 POR 回归，口径只读 TASKS §5 最新块」。INDEX §3 其余是纯指针设计（「本节只回答还没解决什么」），其余 bullet 抽查未过期；`reports/upstream-status-20261105.md` 等被指路径存在。
- `DEVICE/README.md §1.1`：**新鲜**（2026-11-10 20:15 pc1 干净世代块，引用件 `out/r21-sbstop-pc1/uefi-preamblec1-r1.img` 实测存在），无需改。
- `RESOURCES/README.md §3`：数字基本带「2026-11-05/11-06 实测」时间戳，属快照式登记；仅一处隐性过期：其 §3 邻域（`:180`）写「本机现盘最大项 = `build/` 185 G」——实测现值 **24 G**（11-05/11-10 两轮清理后）。该行本身标注了 2026-11-03 状态，属历史快照非错误，可不改；若改，补一行现值即可。
- `scripts/check-doctor.sh` 实跑：**FAIL=0 WARN=6**（16 项检查全过，含 §13 文档资产路径 448 条、§16 TASKS §0 计数对账）。注意：check-doc-assets 报「路径齐全」与我 §1.2 找到的 16 条失效并存，说明其覆盖集与我的全量抽取口径不同（可能有 allowlist/只查部分角度文档）；两处结论不矛盾但口径需知悉。
- `scripts/check-progress-counts.sh`：G1 35/36、G2 8/13，与 TASKS §0 手写一致。

## §2 可删/可归档清单

判断「是否还有引用」均用 rg 实搜（排除 .git/build/backup 自身后，再单独核实归档层引用）。体积 `du -sh` 实测。

### 2.1 根目录临时脚本 / 目录

| 路径 | 体积 | 引用实况 | 判断 | 理由与建议 |
|---|---|---|---|---|
| `wt/reb-731`（内核 worktree） | **13 G** | **有引用**：vk184/vk185/vk187 系 manifest 的 kernel/dtb 源路径、PITFALLS #22 补记、vk-registry.tsv「reb-731」树名 | **保留** | 当前在机 vk184 模块树与落盘内核的可复现源；INDEX/layout 已登记为 ignore 工作区。若要瘦身只能清 `wt/reb-731` 内未跟踪构建产物（`make clean` 级） |
| `dl-cam/` | **2.7 G** | 有引用：`scripts/waydroid-camera-bake.sh`、`PROGRESS.md:80`、`scripts/doctor/s07-08-docs.py`（在保留白名单） | **部分可归档** | C5/U7 已上机收口（vendor.img 已固化 2026-10-29），构建目录里大头是可再生输入：`ndk/` 1.7 G、`sysroot/` 228 M、`aosp/` 118 M、`stage/` 108 M、`vendor-orig.img`/`vendor-cam-l1d.img` 各 256 M（设备/vendor 侧已有固化件与回退件）。建议：整目录打 tar 归档（~可省 2.5 G），保留 README 级指针；或至少归档 ndk/sysroot/vendor-orig |
| `env-pass/` | **3.3 G** | 目录被 INDEX/layout 登记，但 99% 体积 = `backup-20261002/linux17-rootfs-20261002.tar.gz`（3.3 G，2026-10-02 的旧 rootfs 快照，已是 Debian rootfs 时代） | **建议删除或归档** | 旧 Alpine rootfs 快照已被 2026-10-26 Debian/Mobian 迁移取代；`env-pass/scripts`、`env-pass/tools`（~44 K）保留。归档可省 3.3 G |
| `logs/` | 38 M | INDEX:141 登记（ignore，串口/构建/agent 日志） | **保留或按月滚动清理** | 最大单件 8.4 M（memstress 取证）；均为历史构建/取证日志，可按「PITFALLS 报告已引用的保留、其余删」原则清一遍 |
| `restore-259/` | 20 K | 引用：RUNBOOK-BRINGUP、bootslot-b/README、INDEX、layout.tsv | **保留** | 259 官方恢复流程指针件，体积可忽略 |
| `net/waydroid-proxy/` | 160 K | 引用：RESOURCES §3、archive PROXY-WAYDROID-2026-10-02；Waydroid 网络已于 2026-11-10 定案（判据改 HTTP 码） | **可归档** | 截图证据 2 张 + blank_screen.rc；proxy 线已定案，建议移 `archive/topics/` 配套证据位 |
| `probes/` | 2.4 M | 有 README，且 `scripts/static-scan.py --inventory` 的登记口径覆盖；q28 系列已结案但探针属「仅取证」工具 | **保留** | 体积小、性质是可复用取证工具 |
| `cycle.sh`、`elden-net.sh` | 8 K | 引用：RUNBOOK、scripts/iterate.sh、scripts/q28-por-rounds.sh、INDEX、versions/layout.tsv | **保留** | bring-up 迭代环与 USB-NCM 配网是日常脚本，有活引用 |

### 2.2 一次性产物 / 冗余备份

| 路径 | 体积 | 理由 | 建议 |
|---|---|---|---|
| `out/` 内已被 `out/SUPERSEDED.md` 判作废的件（uefi-20261104* 旧 shim 系列） | 未单列（`out/` 共 7.9 G） | SUPERSEDED.md 首段明确「已作废（勿再上机）」 | 已列「作废名单」但文件仍在的，删除并保留 SUPERSEDED.md 即账 |
| `dl-cam/vendor-orig.img`（256 M） | 256 M | 原版 vendor.img 可从设备/waydroid-ota 重取 | 删除（留 sha 于 README） |
| `backup/f2fs-migrate-20261025-205{702,914}…` 等多份同日重复迁移备份 | （`backup/` 共 30 G） | 同一迁移当晚 5 份快照（205702/205914/210049/210242/210451） | 只留最后一份，其余删 |
| `backup/git-history-rewrite-20261026` + `-20261103`、`git-repair-20261105`、`kernel-git-repair-2026-10-10` + `-2026-10-23` | 未单列 | 同一性质（git 修复/重写备份）多代并存，最新的都已验证 | 归档进 `backup/build-bundles` 同级的单一「git-repair-history」目录或删旧代 |
| `patches/config-before-fragment-*.bak`（13 份） | <1 M | fragment 应用前自动备份，对应 fragment 均已合入现役 config | 留最近 1 份，其余删 |
| `bootslot-b/`、`backup/boot_a-pre-uefi-20261108.img`、`dtbo_a-pre-uefi-20261110.img`、`vbmeta_a-orig-20261110.img` | — | 回滚件，G1-29/UEFI 线尚未做冷启动 POR 回归 | **保留**（回滚依赖），POR 回归做完再议 |

### 2.3 已合入的补丁稿（patches/ ↔ patches/upstream/）

rg 对比两目录：**无同名目录重复**（除 README）。`patches/upstream/` 是 M 系投递版（SSOT 在 TASKS §7），`patches/` 根下的 candidate-*/q28-*/m1-73-* 是历史试验稿。发现：

- `patches/upstream/aw86927-20261027` 与 `-v2`、`m4-camss-series-20261028` 与 `-v2`、`m3v5-20261030` 与 `m3v5-fix-20261030` 等同系列多版本：**保留**（投递版本史即 vk 账的 patches 侧，删了丢「哪个版本发过」证据；与 11-10「树合并收口」会话的分支裁决同理）。
- `patches/q28-sham-noop.patch`、`q28-sham2-noop.patch`（名字即「空操作试验」）+ q28-* 散件共 ~20 个：Q28 已结案（2026-10-23 根因指名、G1-33 随之结项），散件可归档进 `patches/q28-v2-20261023/` 或 `archive/`；体积小，优先级低。
- `patches/elden-working-tree-ba28ec16f-2026-10-03.patch`（全树大 diff）：该树状态已被 vk 系 replay 取代，建议归档。

（本节合计可释放估算：dl-cam 归档 ~2.5 G + env-pass 旧快照 3.3 G + f2fs 重复备份 + out 作废件 ≈ **6–8 G**，不动任何 SSOT/回滚件。）

## §3 可精简重复（同事实多处写 / 同资产多份存）

| 重复对 | 理由 | 建议 |
|---|---|---|
| `backup/official-rom-15.10.259/`（16 G，含 super_1..8.img）vs `backup/stock-259/`（443 M，单分区提取件）vs `backup/fw/`（790 M EDL 包）vs `backup/stock-elden/`（271 M）vs 仓外 `y700四代工具/`（271 M，未逐一比对） | 同一官方 259 固件的不同抽取层次；16 G 原包不可再生 | 保留 16 G 原包 + stock-259 提取件；比对 `y700四代工具/` 与 `backup/stock-elden` 去重；其余不动 |
| `backup/kernel-git-repair-2026-10-10`（265 M）/`-10-23`（290 M）/`git-repair-20261105`（882 M）/`git-history-rewrite-20261026`/`-20261103`（280 M） | 五代 git 修复备份同性质并存，最新一代已验证，重建路径有登记 | 归并为 `backup/git-repair-history/` 或删最早两代，可省约 0.5 G |
| `backup/f2fs-migrate-20261025-205702…210451` 5 份同夜快照 | 同一迁移的中间快照 | 只留最后一份（§2.2 已列） |
| 项目根 `README.md` vs `INDEX.md` §1 | 抽查：README 是使命/机型卡（无数字），未发现数字级复写 | 不动 |
| `TASKS/README.md` §5 UEFI 历史块 vs `sessions/2026-11-10-G1-29沿革.md` | 沿革文件声明「原文逐字下沉」，但 TASKS §5 原块未删 ⇒ 双份全文 | 低优先：§5 属历史账；按 ≤1500 B 口径把旧块改一行指针即可 |
| `build/` 大目录（只报大小，不删）：`uefi-woa-prep` 8.2 G、`daily` 8.2 G、`m3v2-7.3rc7` 4.9 G（daily 与 m3v2 同仓不同 worktree，11-10 树合并已判 40 分支无冗余、基线不同，**不动**）、`base-7.2` 2.3 G；合计 24 G（11-05 曾 190.7 G→17 G，之后又长回，主因是 11-07 起的 reb-731/daily 重基线） | 可再生构建区 | `base-7.2`/`uefi-woa-prep` 若近期不用可按 RESOURCES §3 纪律（bundle+导 diff）归档；daily/m3v2 等用户裁决 |
| `linux`（软链→`geekidos-linux` 3.6 G）、`build/base-7.2`、`Y700-elden-linux` 三棵内核树 | 不同基线/谱系，11-10 树合并已清冗余分支 | 保留，不属可精简 |

## §4 总结（可执行动作，10 条内）

1. **并入 2 条未并入 SSOT**：①「pc1 干净世代 + R72」→ TASKS §1 G1-29 行；②「droidloom 11-10 设备实测 + Waydroid 网络定案」→ TASKS §5 Q3/Q1/C3 行（§1.1）。
2. **回填 11-10 镜像清理到文档**：TASKS §5 各 UEFI 历史块首加一行「镜像件已删 2026-11-10，配方/补丁/sha 见会话记录」（§1.2）。
3. **修正 G1-30 行证据指针**：`out/boot-elden-vk61.img` 等 5 个只剩 manifest 的镜像，改指 manifest + vk-kernel-identity.tsv；同时核查这 5 件为何不在 out-archive-20261105 归档账内（可能 11-05 前已删，需补登记）。
4. **刷新 INDEX.md §3 的 G1-29 bullet**：从「卡 flashed、下一步 p67」改为「flashed 已通（dtbo_a 根因），剩菜单取证 + POR 回归」（§1.3）。
5. **释放 ≈6 G**：归档 `dl-cam/` 可再生输入（2.5 G）、删 `env-pass/backup-20261002/linux17-rootfs-20261002.tar.gz`（3.3 G）、f2fs-migrate 5 份只留最后一份。
6. **归并 git 修复备份五代**（kernel-git-repair ×2 / git-history-rewrite ×2 / git-repair-20261105）为单目录，省约 0.5 G。
7. **清 out/ 已列 SUPERSEDED 作废件**（SUPERSEDED.md 已是账，文件可删）。
8. **归档 net/waydroid-proxy 证据**到 archive/topics 配套位；q28 散件补丁归入 `patches/q28-v2-20261023/`。
9. **删 patches/config-before-fragment-*.bak 只留最近 1 份**（13→1）。
10. **build/ 瘦身候选**：`base-7.2`（2.3 G）/`uefi-woa-prep`（8.2 G）按 RESOURCES §3 纪律（bundle + 导 diff）归档；`daily`/`m3v2` 已由 11-10 树合并会话裁定不动。

**交叉验证基线**：check-doctor FAIL=0 WARN=6；check-progress-counts G1 35/36、G2 8/13 与手写一致。
