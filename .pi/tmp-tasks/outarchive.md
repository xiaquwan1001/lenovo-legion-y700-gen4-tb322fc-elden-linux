# lane O：`out/` 历史镜像归档 + vk 账目同批改造（**只备料，不执行**）

## 语境
项目根 /home/xuqianhui/y700-elden。用户已批准本轮把 `out/` 历史镜像（129 个 `*.img` / 9.43 G）做归档瘦身，
但**必须与 `versions/vk-kernel-identity.tsv`（下称 ledger）同批处理**，否则 `check-doctor §5d` 会把「文件消失」判成
身份不可核对。历史上还有一条硬纪律：**禁止重跑 `scripts/vk-identity.py`**（镜像缺失会清空/污染整表，见 `.pi/memory/MEMORY.md` 2026-10-17 条）。

## 你的角色 = 备料 + dry-run，**不执行任何 mv/rm/写 ledger**
父进程会照你的清单执行。所以你要交付的是「可粘贴的命令 + 预期 diff + 回滚 + 判据」。

## 必做（按顺序）
1. **读懂账目与门禁的耦合**：
   - `head -3 versions/vk-kernel-identity.tsv`（列名）、随机抽 3 行看 path 写法（是 `out/xxx.img` 还是裸名）。
   - `rg -n "vk-kernel-identity|5d|5e" scripts/check-doctor.sh | head -30`，读那段：它如何定位镜像文件、缺文件是 FAIL 还是 WARN、是否比对 `sha256`、`kernel-unreadable` 标记怎么处理。
   - `versions/vk-ledger-known-issues.tsv` 里对 `uts_dup*/num_ne_tag` 的豁免机制（别踩）。
   - `out/*.manifest` 与镜像的关系：manifest 里 `image=` 是绝对路径、`image_sha256=` 是身份；`scripts/build-manifest.sh` 如何生成。
2. **定「保留集」并给判据**（每条给命令+输出）：
   - 在机对应的镜像：`DEVICE/README.md` §1.1 首条的 `boot_b` sha（vk172 线）与 `out/` 里哪个文件逐字节一致（用 manifest 的 `image_sha256` 或直接 sha256）。
   - 当前两条在用线：`m3v5-onboard` 系（含 `-b`）、`vk172`/`vk183-fastrpc` 等最新线、`reports/upstream-*` 最近条目引用的件。
   - 取证类必须留：`out/corrupt-20261102/`、`boot-elden-m3v5-daily.img`（11-03 静默损坏件，已修复但保留）、UEFI 本轮 `uefi-2026110*.img`（若 TASKS §5 11-04 块引用）。
   - 被 **reports/TASKS/DEVICE 里的「当前时态」句**引用的件（历史叙事引用不算）。
3. **给归档方案**：目标目录 `backup/out-history-20261106/`（同盘 mv，不压缩；另附「是否值得 tar.zst」评估与体积预估）。
   注意：`backup/` 是 never-delete 区、且被 `.gitignore` 忽略 ⇒ 移过去不影响 git。
4. **给 ledger 改造 patch（逐行）**：移动的每一件在 ledger 里怎么改（改 path 列 → `backup/out-history-20261106/<name>`，还是保持 `out/<name>` 并把「已归档」记在 known-issues？）。
   **选一种口径并说明为什么**，给出需要改动的行号清单 + 一个可直接 `python3 - <<'PY'` 的改写脚本（幂等、带 dry-run 开关、改前备份 ledger 到 `backup/`）。
5. **dry-run 证据**：把上面脚本以 `--dry-run` 跑一遍（不写盘），贴输出摘要（将改 N 行 / 将移动 M 件 / 释放 X 字节）。
6. **判据与回滚**：执行后必须满足
   - `bash scripts/check-doctor.sh 2>&1 | tail -1` → **FAIL=0**，且 §5d/§5e 的 WARN 数量不增加；
   - `awk -F'\t' 'NR>3{print $1"  out/"$3}' versions/out-images-sha256-20261105.tsv | sha256sum -c --quiet`（基线表要能继续校验——若路径变了，说明基线表也要同批改，给出改法）；
   - `git status` 只应有「ledger + 基线表 + 必要的 docs 指针」三类改动；
   - 回滚 = 记录 mv 的反向命令 + ledger 备份文件路径。

## 硬约束
- **不执行** mv/rm、不写 ledger、不改仓库任何既有文件、不 git commit、不上机。
- 只允许新建：`reports/out-archive-plan-20261106.md`（或 20261105-2）+ 一个 `scripts/` 之外的临时脚本放 `/tmp`。
- 每条结论带可复现命令；未证写「未证」。中文。时间盒 ≤35 分钟。

## 交付
`/home/xuqianhui/y700-elden/reports/out-archive-plan-20261105.md`：
§0 一句话结论（保留 N 件 / 归档 M 件 / 释放 X G / ledger 改 K 行 / 门禁风险）
§1 账目-门禁耦合事实（带 file:line）
§2 保留集（逐件 + 理由 + 引用来源）
§3 归档清单（逐件 + 体积 + ledger 行号）
§4 可粘贴执行序列（mv 命令 + ledger 改写脚本 + dry-run 输出）
§5 判据与回滚
§6 未证/待裁决
回执 ≤25 行。
