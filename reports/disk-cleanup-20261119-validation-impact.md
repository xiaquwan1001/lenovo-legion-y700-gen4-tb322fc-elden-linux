# 2026-11-19 磁盘清理对「验证面」的影响与处置

> 一句话：清理 `build/` + `geekidos-linux/` 让 **§5d 内核身份表整体变成「不可核」**（77 FAIL），
> 处置 = 给身份表加**显式「源树已档」登记**（`versions/kernel-src-archive.tsv`）+ 新鲜度门降级档（C=2）+
> 布局登记改为「已移除」，**没有**用静默白名单把「读不出」说成「没问题」。
> 现状：`check-doctor` **FAIL=0 / WARN=6**（6 条 WARN 逐条见 §6：2 条既有项 + 4 条「本轮不可核」的显式声明）。

---

## 1. 事实（谁删了什么、留了什么）

| 时点 | 动作 | 证据 |
|---|---|---|
| 2026-11-19 09:36 | 删 `build/`（37 G，含全部内核构建树/worktree）前，把 `m3v2-7.3rc7` 工作树脏改动导成 patch 并提交 | `git show --stat 0c98d793`（`reports/build-m3v2-7.3rc7-dirty-20261119.patch`，250 行） |
| 同一轮 | 删 `geekidos-linux/`（2.1 G，上游 `GEEKiDoS/linux` 浅克隆）⇒ 仓库根的 `linux -> geekidos-linux` 软链成死链 | `ls -d geekidos-linux linux`（不存在）；`git ls-files -s linux`（曾是 mode `120000`） |
| 清理后 | `build/` 只剩 `phoc-src-*` / `phosh-src-*`（3.5 M），无任何内核树 | `du -sh build`、`ls build/` |

**未被删除**：`out/`（24 个 boot 镜像 + manifest）、`backup/git-slim-20261113/{main,geekidos,m3v2}-all-20261113.bundle`
（515/301/394 M，`git bundle list-heads …geekidos… | wc -l` = **140 refs**，实测可读）⇒ 源树可离线重建（§5）。

## 2. 后果 A：§5d 77 FAIL 的分解（不是 77 个新事故，是 1 个前提消失）

`scripts/vk-identity.py` 的 §5d 判据里，`src_missing / src_unreachable / num_ne_tag / uts_lvs`
**全部要靠源树的 git refs**（`git -C geekidos-linux rev-list/for-each-ref/cat-file`）。
源树一没，`resolve()` 对每一行都返回 `missing` ⇒ 每个「有源提交」的行都变成 `src_missing` 硬错；
同时 `--check` 的逐行比对必然不一致 ⇒ 「表已过期」FAIL。实测分解：

| 来源 | 条数 |
|---|---|
| §5d `新构建踩到硬错 → <行>: src_missing` | 75 |
| §5d 新鲜度 `内核身份表已过期`（C=1） | 1 |
| §14 布局注册表（`geekidos-linux` / `linux` 登记但磁盘不存在） | 1 |
| **合计** | **77**（改前基线 FAIL=0 / WARN=2） |

**关键区分**：这批行的 `build / image / 镜像内 UTS / kbin_sha / src_sha / tree_head` **全部来自镜像与
manifest 本身**，仍然成立且可离线重算；只有「该 sha 在源树里是否可达、该提交上有哪些 vk tag」这两个
判断失去材料。⇒ 真实状态是 **「暂不可核」，既不是「核对失败」，也不是「核过没问题」**。

## 3. 后果 B：pre-commit 门被绕过

`check-layout.sh`（doctor §14 / pre-commit `--staged-fast`）要求 `versions/layout.tsv` 登记的每条都
在盘上 ⇒ `geekidos-linux/` 与软链 `linux` 两条让门 FAIL，上一个代理只能用 `ELDEN_HOOK_SKIP=1` 提交。
本轮的处置（§4.2）让该门在**不绕过钩子**的前提下 PASS。

## 4. 处置

### 4.1 §5d / 新鲜度：加「源树已档」显式状态（不是白名单）

1. 新文件 **`versions/kernel-src-archive.tsv`**（companion，入库）：13 行文件头写死
   删除日期、仓库内可现查的证据命令、恢复命令、以及「源树在盘时本表必须为空」的契约；
   表体 75 行 = `build / image / src_sha` 三列，**由已提交的 `versions/vk-kernel-identity.tsv` 生成**
   （`python3 scripts/vk-identity.py --src-archive-write`），不是由当前扫描生成 ——
   否则等于「把自己算出的 missing 写成豁免理由」。
2. `scripts/vk-identity.py`：
   - `src_tree_present()`：源树在盘 ⇒ 登记表**整体不生效**，照旧全列核对；
   - `gate_lines()`：源树不在盘时，**只有** `build+image+src_sha` 三列与现扫描**逐字相等**的行，
     把 `src_*` 这一项从硬错里摘出、汇总成 **1 条 WARN**（75 行名单 + 指向登记表）；
     表外的新行 / sha 对不上的行 → 单独 **FAIL**「源树缺失且未逐行登记（无法证明是暂不可核）」，
     其它硬错（`payload_mismatch` / `tree_drift` / `dirty_drift` …，只读 manifest）**判定不变**；
   - `fresh(..., degraded=True)`：源树不在盘且登记表覆盖完整时，只比对**不依赖源树的列**
     （`build/image/reg/img_uts/kbin_sha/src_sha/tree_head/tree_state` + 剔除 `src_*`/`num_ne_tag`/`uts_lvs` 的 flag），
     结果用 `C=2` 表达（`0`=全列一致，`1`=真过期，`2`=降级一致）；
   - `--check` 在降级一致时打印明确的「只比了离线列」说明后返回 0；`git cat-file` 的 stderr 一并吞掉
     （否则源树缺失时每行一句 `fatal: cannot change to …`，75 行噪声会把真错误挤出视野）。
3. `scripts/doctor/05-vk.sh`：`C=2` → **WARN**，消息点名「降级一致 / 树派生列不可核 / 登记表位置」；
   `C=0` 才算「一致」。

**反静默白名单的负向验证（实跑，不是推理）**：把登记表里 `vk192` 行的 `src_sha` 改成 `deadbeef0000`，
`--gate` 立刻产出 `FAIL 源树缺失且未在 versions/kernel-src-archive.tsv 逐行登记 → vk192(4bdf1711b5c0)`；
恢复该行后 FAIL 归 0。⇒ 这张表不是通配符，**新镜像借它蒙不过去**。

### 4.2 布局与死链：登记为「已移除」+ 重建命令写进注释（方案 a，未重建浅克隆）

- `versions/layout.tsv`：删掉 `work geekidos-linux/` 与 `work linux` 两行（不在盘的条目不能留在表体，
  否则 §14 恒定 FAIL），改为表头注释块记录 2026-11-19 移除、影响与三条重建命令（§5）。
- 软链 `linux -> geekidos-linux` **已 `git rm`**（死链；恢复树后按注释重建）。
- `INDEX.md` §布局「工作区」行加现状脚注（条目仍在「可再生成工作区」分类里，只是当前不在盘）；
  `RESOURCES/README.md` §1.1 的本地状态从 ✅ 改为「2026-11-19 已删 + 重建命令」。

### 4.3 「不可核」的另外两处也点名（措词，不改判定）

`05f-abi.sh`（无 `.config` ⇒ ABI 核对跳过）与 `12-modular.sh`（无构建树 ⇒ 模块化门禁跳过）的 WARN
文案改为「**本轮跳过（不可核，不是核过没问题）**」并给重建入口与影响记录指针 ——
这两条 WARN 以后每轮都会出现，措词必须能自证，否则会退化成「习惯性噪声」。

## 5. 恢复命令（bundle 已在盘，离线可重建，不依赖网络）

```sh
git clone --filter=blob:none backup/git-slim-20261113/geekidos-all-20261113.bundle geekidos-linux
git -C geekidos-linux remote add torvalds https://github.com/GEEKiDoS/linux   # pristine 历史按需取 blob
ln -sfn geekidos-linux linux
```

恢复后必须做三件事（否则登记表会变成陈旧豁免）：
1. `python3 scripts/vk-identity.py --gate`（应 0 FAIL）→ `--check`（应全列一致）；
2. 清空 `versions/kernel-src-archive.tsv` 的表体（源树在盘时它不该有行；`src_tree_present()` 已让它不生效，
   但留着就是「没人复核的历史豁免」）；
3. 把 `geekidos-linux/`、`linux` 两行加回 `versions/layout.tsv` 表体。
   `build/` 内核树同理：`patches/current-tree` 指向的树重建后，§5f/§12 会自动恢复核对。

**禁令不变**：不要用 `scripts/vk-identity.py > versions/vk-kernel-identity.tsv` 重生成身份表
（项目硬规则：镜像/源树不全时会清空整表）——本次处置**没有重跑写表**。

## 6. 现状：WARN=6 逐条（哪条是既有项，哪条是本轮「不可核」声明）

| # | WARN | 性质 |
|---|---|---|
| 1 | `账本已登记的例外（vk-ledger-known-issues.tsv）` | **既有登记项**（`uts_dup` 族的逐镜像理由） |
| 2 | `内核段不可读 4 个 posctrl-markspin 镜像` | **既有登记项**（坏镜像留档，与本次清理无关） |
| 3 | `源树已档：75 行身份暂不可核` | 本轮新增；= §4.1 的显式状态，附逐行名单与登记表指针 |
| 4 | `内核身份表降级一致（C=2）` | 本轮新增；= 只比了离线列 |
| 5 | `未找到任何内核树的 .config → ABI 核对跳过` | 本轮新增；清理 `build/` 的直接后果（不可核） |
| 6 | `无构建树可用 → 模块化门禁跳过` | 本轮新增；同上（`patches/current-tree = build/daily` 已不存在） |
| ~~7~~ | ~~`HISTORY/days 落后`~~ | 独立项（派生物滞后，非清理引起）；本轮已按 WARN 提示重生成（`scripts/gen-history.sh`，同日的 `history:` 派生物提交）⇒ 已消 |

即「WARN≤2」在**不允许说谎**的前提下做不到：3–6 是「材料被删 ⇒ 本轮不可核」的
诚实声明：把它们的措词改绿，等于把「读不出」当「没问题」。

## 7. 后续 agent 注意（踩过就不要再踩）

- `check-doctor` 出现 3/4/5/6 这四条 WARN **不是环境噪声**，是「这些面本轮没核」；不要把它们当绿、
  也不要为消 WARN 去改判据措辞。
- `C=2` ≠ 「表一致」：写到报告/结论里必须写「降级一致（树派生列不可核）」。
- 恢复源树后按 §5 的三步收口；**恢复后仍留着登记表** = 陈旧豁免，比没做更危险。
- 需要核对「某个 vk 号到底装的是哪个内核」时，可用的离线证据链 =
  `out/boot-elden-<build>.img`（UTS + 内核载荷 sha）+ `out/*.manifest` + `versions/vk-kernel-identity.tsv`；
  源树只影响「sha 归属哪条线/哪些 tag」，不影响「镜像里是哪个内核」。
