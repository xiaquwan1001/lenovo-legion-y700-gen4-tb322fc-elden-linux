# 收尾 WARN 治理（2026-11-25 晚）—— 6 条 → 3 条，每条都给复现/取舍

> 起点：`scripts/check-doctor.sh` = **FAIL=0 / WARN=6**（全部 C 类存量，长期「习惯性噪声」）。
> 原则（用户本轮指示）：**能复刻的给出复现方式；不能复刻的走浅层恢复、不做全量；已确认淘汰/被包含的删除**。
> 结果：**FAIL=0 / WARN=3**，且剩下 3 条都有可复现的判据与书面结论。

## 0. 前后对照

| # | 原 WARN | 本轮处置 | 现状 |
|---|---|---|---|
| ① | 源树不可核（67 行身份） | 诊断到**具体断链 sha**：`a2795d9c`（可取回）、`32c6462381`（三处远程都取不到）；做了 327 MB 浅层重建实验 | **保留 WARN**（结论：不可复刻，见 §1） |
| ② | vk 账本已登记例外 | 逐条核对：都是 `uts_dup` / `num_ne_tag` 的**已裁决**例外 | **保留 WARN**（设计如此，`versions/vk-ledger-known-issues.tsv`） |
| ③ | 4 件 `posctrl-markspin` 内核段不可读 | 它们不是内核（UEFI 正控载荷），早已 `RETIRED`；文件**移入** `backup/out-history-20261105/retired-uefi-posctrl/`（不删，退出 vk 身份表扫描面），同步改 `ROLLBACK.sh` 与身份表 4 行 | **WARN 消失** |
| ④ | `out/boot-elden.img` 无版本号构建拷贝 | 无 manifest、无身份、`build-boot.sh` 默认可重生（`versions/out-images-sha256-20261105.tsv` 早有 RETIRED 行） | **删除，WARN 消失** |
| ⑤ | 内核身份表降级一致（C=2） | 是 ① 的连体：只要源树历史残缺就只能是「降级一致」 | **保留 WARN**（随 ①） |
| ⑥ | 无构建树可用 ⇒ 模块化门禁跳过 | **重建 `build/daily`**：`git worktree add build/daily 4da9a8b69fc8` + `patches/config-daily-c3-uinput-20261113`；门禁与真编译都跑通 | **WARN 消失，且日常线重新可编** |

## 1. ①/⑤ 的复现方式与「为什么不可复刻」

复现（只读、禁掉隐式联网，`PITFALLS #727`）：

```sh
export GIT_NO_LAZY_FETCH=1
git -C geekidos-linux rev-list --all --count         # ⇒ rc=1：Failed to traverse parents of 79a907…
git -C geekidos-linux cat-file -t a2795d9c65bd…     # ⇒ 缺对象
```

诊断结论（本轮新事实）：

- `a2795d9c65bd`（stable 7.3.1 的父提交）**可取回**：`git fetch --depth=1 --filter=tree:0 <stable> <sha>` 成功；
- `32c6462381ca`（`v7.2-elden` 基座 `ba28ec16` 的父提交）在 `gregkh/linux`、`torvalds/linux`、`GEEKiDoS/linux`
  **三处都取不到** ⇒ 该对象只存在于当年的本地历史，**不可复刻**。

浅层重建实验（**327 MB，替代 6.4 GB**，全程 `--filter=tree:0`，非全量）：

1. `git init` 新仓 → `fetch --depth=100 --filter=tree:0 <stable> v7.3.1`（补上 `a2795d9c`）；
2. `git bundle unbundle backup/git-slim-20261113/geekidos-all-20261113.bundle` + `git update-ref --stdin`（140 refs）；
3. 把断链处标成 shallow 边界 ⇒ `rev-list --all --count` **rc=0（28 013 提交）**。

结果：`vk-identity.py` 从「降级」切到**全量核对**，但立刻报 **11 条 FAIL**（`vk184/vk185/vk189/vk192…` `src_unreachable/src_missing`）——
因为**当年 `replay-731` 那条开发线的分支 ref 从未归档**（承诺对象在、ref 不在；`git ls-files` 侧没有证据能把 ref 补回来，
硬造 ref 等于自己给自己发证明）。⇒ **退回原树**（保留 6.4 GB），把「不可复刻 + 重建实验结论」写进 `versions/kernel-src-archive.tsv` 头。
判据可复跑：`python3 scripts/vk-identity.py --gate`（现 **0 FAIL**）、`--check`（现「降级一致」）。

## 2. ⑥ 的复现方式（日常线恢复可编）

```sh
git -C geekidos-linux worktree add --detach ../build/daily 4da9a8b69fc8   # vk184/vk189 的源头
cp patches/config-daily-c3-uinput-20261113 build/daily/.config
bash scripts/check-modular-config.sh        # ⇒ 3 PASS（锚点 27 个 / olddefconfig 幂等 / tristate 自洽）
bash scripts/build-kernel.sh Image.gz       # ⇒ Image.gz 21 057 110 B，符号守卫 OK
```

编译产物 UTS = `7.3.1-debug-vk189-suspend-g4da9a8b69fc8`，与身份表 `vk184/vk189` 行的 `src_sha=4da9a8b69fc8` 一致
⇒ 「设备在跑的日常核」现在有了可复现的源树与配置（此前只能靠 `out/` 里的旧镜像）。
**未做**：没有重刷设备（日常核在机 vk189 不变），本轮只证明「能重编」。

## 3. ③ 的处置细节（为什么移而不删）

这 4 件是 **UEFI 正控载荷**（`versions/patches-uefi-status.tsv` 早期已标 `RETIRED`：`text_offset=0` 已固化进
`scripts/uefi-repack-v2aligned.py`），不是 Linux 内核；doctor 的判据「内核段解不出」对它们永远成立。
它们同时是 `backup/out-history-20261105/` 的归档件（不可再生），所以：

- **不删**：移入子目录 `retired-uefi-posctrl/`（`vk-identity.py` 的扫描面是 `out/` 与 `backup/out-history-*/` 的**直下** `*.img`，
  子目录不进扫描）；
- 同步：`ROLLBACK.sh` 的 4 行路径 + `versions/vk-kernel-identity.tsv` 删掉对应 4 行（这 4 行 `reg='-'`，无 registry 依赖）；
- 判据：`python3 scripts/vk-identity.py --check` = 一致；doctor §5d 不再出现该条。

## 4. 剩余 3 条的口径（不再当噪声，但也不假装修好）

| WARN | 为什么可以留 |
|---|---|
| 源树不可核（67 行） | 断链 sha 已指名、恢复实验已做、结论已入 `versions/kernel-src-archive.tsv` 头；**补齐需要当年没归档的 ref，无法从网络得到** |
| vk 账本已登记例外 | 每条都在 `versions/vk-ledger-known-issues.tsv` 有理由（`uts_dup` / `num_ne_tag`），是**裁决过的**，不是漏网 |
| 身份表降级一致（C=2） | 是第一条的连体判据：源树历史残缺时只能比离线列，脚本已按「降级」明确报出 |
