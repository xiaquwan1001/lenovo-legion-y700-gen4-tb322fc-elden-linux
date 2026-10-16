---
name: "vk-ledger-audit"
description: "审查 elden 项目 vk 版本账目：vk 号 ↔ 内核源 ↔ 镜像 ↔ 设备证据四列对齐。触发词：vk 版本号审查/对账、registry 与镜像不一致、boot.img 里到底是哪个内核、manifest 与镜像矛盾、版本号不可复现。"
version: 5
created: "2026-10-06"
updated: "2026-10-12"
---
## When to Use
周期性版本账盘点、合并 lane 后核对、怀疑「打包用了陈旧 Image.gz」或 registry/manifest/文档互相矛盾时。不用于单次构建排错。

## Procedure
1. 先取 ground truth：直接从镜像抽 UTS（不要信文件名/manifest 字段）—— python3 找首个 b'\x1f\x8b\x08' 后 zlib.decompress(wbits=16+MAX_WBITS)，再 re.search(rb'Linux version (\S+)', k)；搜索窗口必须是整段解压数据（UTS 串实测可落在解压后 27 MB 处，截到 4 MB 会误判「无载荷」），且只取一个 token。
2. 顺带算内核身份 sha256（解压载荷字节的 sha256 前 12 位）——唯一可靠判据；UTS 串和文件名都会骗人。
3. 四列对齐：versions/vk-registry.tsv（号↔lane↔日期） × out/boot-elden-vk<号>.manifest（树自称 kernel_release vs 镜像内 kernel_uts） × 内核仓 git tag/commit × versions/vk-kernel-identity.tsv。比 git sha（g[0-9a-f]{12,}）而非整串以忽略 LOCALVERSION 差异；dirty 位不同单独分级 WARN。
4. 四类失真分别定量：① 镜像内 LOCALVERSION 的 vkNN ↔ 源提交 vk tag（uname 会说谎）；② 同 UTS 串 → 多二进制（串不可辨识）；③ 同号↔多二进制 / 同二进制↔跨号；④ UTS 里根本没有 git sha（永久不可回溯，如 sd-*）。
5. 覆盖面自查：把 out/ 下**所有** .img（含 boot_b-*、dtbo-* 等非构建载具）逐个抽载荷，与身份表行集合做差，抓「整类跳过」造成的账外资产。
6. 扫不可复现号：无 commit/tag、无镜像、无 manifest 三者任缺即登记（项目惯例：诚实留白 + 写进 patches/kernel-history/README.md，不伪造 tag）。
7. 核对领域层口径：kernel_history/README.md、RESOURCES.md 的「内核版本时间线与『实机验证边界』」小节（其编号是 `### 3.`，与顶级 `## 3. 文件与资产台账` 同号，引用须写小节全名）、archive/topics/ITERATION-AUDIT-2026-10-04.md §5、bootslot-b/README.md 资产表、INDEX §U2 的 boot_b 现状。
8. 落地更正：registry 只增不改（更正以 # 注释块追加，alloc 取 max+1 不受影响）；已知历史问题进 versions/vk-ledger-known-issues.tsv 白名单；新校验进 scripts/check-doctor.sh §5/§5d 与 scripts/vk-identity.py；教训进 PITFALLS.md（取最新编号续条，并核对条目顺序）。
9. 在途产物一律不碰：需要豁免时写 versions/vk-identity-inflight.txt（支持有界通配），并在注记里列出「收口必补项」（缺的 registry 行、同号多内核须分列）。
10. 负向验证 + 全量门禁 + 只 add 显式路径提交（详见 Verification）。
## Pitfalls
- **多臂实验会话收尾漏登记**：一晚出 7–9 个单变量臂时，容易只写 `versions/vk-registry.tsv` 行，忘补 `versions/vk-kernel-identity.tsv`（regen）与 `versions/vk-ledger-known-issues.tsv`（逐臂 `num_ne_tag`/`uts_dup` 理由）⇒ `check-doctor §5d` 报一批 FAIL 而无人看（实测 2026-10-12 Q28 七臂 vk116–vk123 + vk124：FAIL=10）。**把「`check-doctor` FAIL=0」当作会话收尾门**，不是 nice-to-have。
- 重生成身份表的差异必须**逐列审查**：合法变化只有「新增行」+「flag 列计数/标签集合变化」（如新增 `q28/upstream-combined` tag、`uts_dup15→24`）；`kbin`/`src commit`/`tree head` 等历史列**不得变**（变了说明 ref 解析被后续 merge/rebase 改写）。最快审查：`diff <(cut -f1-4 old) <(cut -f1-4 new)` 应只有 `Na...` 新增行。
## Verification
1. scripts/check-doctor.sh 退出码 0 且第 5/5d 节无 FAIL。
2. 每项校验都做负向验证证明非空转（零写入法）：§5 内嵌 python 抽到 /tmp 后把白名单路径改为不存在 → 应出 FAIL（白名单在场 0 FAIL）；VK_RULE_EPOCH=0 → 身份门应大面积 FAIL（默认 OK）；身份表副本注入假 kbin → --check rc=1；截两行 → rc=1；仅改 (unversioned) 行 → rc=0；真表 → rc=0。传统「移走仓库内白名单文件」可行但窗口期会给并发会话造成假 FAIL，优先零写入法。
3. git -C geekidos-linux tag -l | sort -V 与 registry/kernel-history 对照表中的 tag 集合一致。
4. 未波及在途：git status --porcelain out/ 只有并发会话自己的 untracked manifest、无 modified；重生成身份表前 pgrep 确认无构建在跑，并连生成两次 diff -q 相同。
5. 写入 registry 注记的三个数字（legacy 欠账数、不同内核二进制数、号≠源号镜像数）由独立脚本复算得出，不抄旧注记。