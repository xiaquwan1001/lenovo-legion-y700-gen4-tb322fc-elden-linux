# #751 删 `out/boot-elden.img`（无版本号默认产物）会让 §5d 内核身份表新鲜度变 **FAIL**，而它的修复提示（重跑 `vk-identity.py`）是本项目的禁区

**场景**：2026-11-28 早轮收尾跑 `scripts/check-doctor.sh`，见到存量 WARN「无版本号构建拷贝 1 个（`build-boot.sh` 默认产物，不拦构建；收口时改名或删）：`boot-elden.img`」，
按提示删掉它（`out/boot-elden-vk197.img` 同 sha `12eb016a…` 已留档，85 816 296 B 重复件）。下一次 doctor 立刻在 **§5d** 红：
`[FAIL] 内核身份表已过期 → 跑 scripts/vk-identity.py > versions/vk-kernel-identity.tsv 并重提交`。

**根因**：`versions/vk-kernel-identity.tsv` 里有一行 `(unversioned)  boot-elden.img`（第 81 行），§5d 的新鲜度检查（`scripts/doctor/05-vk.sh` 读 `vk-identity.py --all` 的 `C` 行）
是「表 ↔ 现存 `out/boot-elden-*.img` 集合」的对账：文件消失 ⇒ `C=1` ⇒ 判「表过期」。**不是内核变了**。

**陷阱**：doctor 给的修复建议是重跑 `scripts/vk-identity.py` —— 而 `AGENTS.md` 项目记忆明确写着 **禁重跑**
（镜像/源树缺失时会产出 `(slot-dump)/(no-payload)` 甚至清空整表；2026-10 已吃过一次代价）。⇒ 照着门上的建议做，会把 139 行历史账毁掉；门与实际操作互相打脸。

**判据 / 处置**：
- 先本地复现，别猜：`python3 scripts/vk-identity.py --all | grep -E '^C\s'` —— `C 0` = 一致、`C 2` = 降级一致（源树不可核，只比可离线列）、`C 1` = 过期。
- 缺的若是 `(unversioned)` 行那一个文件：`cp out/boot-elden-vk197.img out/boot-elden.img`（同 sha 才可）后重跑上面的命令应回到 `C 0`；此时 WARN「无版本号构建拷贝」会回来 —— **两者是一对，不能只取一边**。
- 真要清空间就删**带版本号**的旧件（`scripts/out-archive.py` 默认 dry-run），不要动无版本号那个。

**一句话**：`boot-elden.img` 是身份表的一行实体，不是垃圾文件；WARN 文案里的「收口时改名或删」只对「表里没有它」的情形成立（表是这个 WARN 出现**之后**才生成的，或已按流程重生成）。
