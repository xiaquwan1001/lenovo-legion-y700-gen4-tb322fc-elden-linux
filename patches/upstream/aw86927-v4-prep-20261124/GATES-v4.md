# aw86927 v4 门禁账（2026-11-24，**已备料，未投递**）

> 为什么有 v4：sashiko 对 **v3 6/6** 的报告（`sashiko-bot@kernel.org`，2026-11-24T02:03:12Z）给了
> **1 High + 2 Medium + 1 Low**，四条全部成立（判别见 `reports/comm-triage-20261124-c.md` §2）⇒ 必须出 v4。
> 另把 Joonhoe Kim 2026-11-21 给 **v2 4/6、5/6** 的 `Tested-by` 收进本版（`reports/comm-triage-20261123.md` A2 开放项）。

## 0. 数字结论

| 门 | 命令形状 | 结果 |
|---|---|---|
| 基线 | 内核 worktree @ `aebb727447`（v7.4-rc3） | 与 v3 同基线；**未**在 linux-next 上复验（本地无该树） |
| G1 落树 | `git apply --index` ×6（顺序） | **6/6 干净**（`logs/G1-apply.log`） |
| G2 checkpatch | `scripts/checkpatch.pl --strict --no-signoff --no-tree` ×6（**在内核树内跑**） | **0 ERROR / 0 真 WARNING**（唯一两条 = `Unknown commit id 'df53055c540f'`，`Fixes:` 指向 input 树里的提交、mainline tag 里没有 ⇒ 已知假阳性，v2 起就有）（`logs/G2-checkpatch.log`） |
| G3 编译 | `make -j16 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-aw-v4 W=1 drivers/input/misc/aw86927.o`（defconfig + `CONFIG_INPUT_AW86927=y`） | **rc=0，0 warning / 0 error**（`logs/G3-W1-build.log`）；`nm` 见 `aw86927_{reset,open,suspend,resume,shutdown}` 全部落地 ⇒ 编的是**打了本系列**的树 |
| G4 绑定了 schema | `make -j16 ARCH=arm64 O=… DT_SCHEMA_FILES=…/awinic,aw86927.yaml dt_binding_check` | **rc=0**（LINT/STYLE/DTEX/DTC 全过；dtschema 2026.9）（`logs/G4-dt-binding-check.log`） |
| G5 上机 | — | 未做（触觉驱动，需设备；在机内核 vk189 不带本系列） |
| G6 邮件可解析 | `git mailinfo` ×7 | **7/7 OK** |

## 1. 相对 v3 的改动（只在 6/6，外加两枚 tag）

| # | sashiko 意见（v3） | 处置 |
|---|---|---|
| 1 | **[High]** 6/6 提交信息缺 `Signed-off-by` | 补回（与其余 5 封同作者行），并从**整系列**重新 `format-patch` 生成 ⇒ 同时修复 v3 那封单独生成造成的断行错位（76 列） |
| 2 | [Medium] `aw86927_reset()` 对**未初始化** `play_work` 调 `disable_work_sync()` | `INIT_WORK(&haptics->play_work, …)` 提前到 `devm_add_action_or_reset()` **之前**（probe 后续任何失败路径都安全） |
| 3 | [Medium] `close()` 里 `level=0` 让 memless timer 重排 `play_work` | 新增 `enabled` 标志：`close()` 在 `input->event_lock` 下清 `enabled` + `level` 再排空 work；`aw86927_haptics_play()` 在 `suspended` 或 `!enabled` 时直接返回；新增 `->open()` 置回 `enabled` |
| 4 | [Low] 注释/提交信息把 standby 写成 power-down/reset；`Changes since` 位置 | 措辞改为 standby 语义，changelog 移到 `---` 之下 |

**Tested-by 收取（v4 新增）**：4/6、5/6 各加一枚
`Tested-by: Joonhoe Kim <26rote@gmail.com> # Lenovo Y700 Gen 5 (TB323FU)`。
判据 = 这两枚的 **diff 正文与已投 v2 4/6、5/6 逐字节相同**（只有 `index` 行与 hunk 偏移因基线从
linux-next 换到 7.4-rc3 而变，`@@` 内容一致 —— 现查：

```sh
cd patches/upstream
for i in 4 5; do diff <(sed -n '/^diff --git/,$p' haptics-v2-20261117/000$i-*.patch | sed -E 's/^@@.*@@.*$/@@/; s/^index .*//') \
                     <(sed -n '/^diff --git/,$p' aw86927-v4-prep-20261124/v4-000$i-*.patch | sed -E 's/^@@.*@@.*$/@@/; s/^index .*//') \
                && echo "v2 $i/6 == v4 $i/6 (modulo offsets)"; done
```

**6/6 故意不收 tag**：v3 与 v4 两次都实质改动了它，他当时测的是 v2 版本；cover 里已请其复测。
不把未经复测的 tag 挂到改过的补丁上是纪律（`PATCHES` 规则：内容实质变化 ⇒ tag 不沿用）。

## 2. 复现命令

```sh
cd /home/xuqianhui/y700-elden
git -C build/elden-tree worktree add --detach /tmp/aw4-apply aebb727447
cd /tmp/aw4-apply
for p in /home/xuqianhui/y700-elden/patches/upstream/aw86927-v4-prep-20261124/v4-000[1-6]-*.patch; do
  git apply --index "$p" || echo "FAIL $p"
done

make -s -j16 ARCH=arm64 O=/tmp/kb-aw-v4 defconfig
./scripts/config --file /tmp/kb-aw-v4/.config -e INPUT_MISC -e INPUT_AW86927 -e INPUT_EVDEV
make -s -j16 ARCH=arm64 O=/tmp/kb-aw-v4 olddefconfig
make -j16 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-aw-v4 W=1 drivers/input/misc/aw86927.o
make -j16 ARCH=arm64 O=/tmp/kb-aw-v4 \
  DT_SCHEMA_FILES=Documentation/devicetree/bindings/input/awinic,aw86927.yaml dt_binding_check

for p in /home/xuqianhui/y700-elden/patches/upstream/aw86927-v4-prep-20261124/v4-000[1-6]-*.patch; do
  ./scripts/checkpatch.pl --strict --no-signoff --no-tree "$p"
done
```

## 3. 边界与未做

- **未投递**（`TASKS/README.md` §7 逐系列批准）。放行后 `bash SEND.sh`（默认 dry-run，`--yes` 才真发）。
- 未在 **linux-next master**（v2/v3 的原基线）复验落树：v3 那次迁移过上下文，本版 1–5 与 v3 逐字节同、
  6/6 是 7.4-rc3 上下文重生成 ⇒ 若维护者树以 linux-next 为准，投前建议补跑一次 `git apply`（预期最多 1 行 include 漂移）。
- 未上机（触觉实际行为、suspend/close/shutdown 三条路径）。
- 临时 worktree（`/tmp/aw4-apply`）与 `O=/tmp/kb-aw-v4` 构建目录已在收尾时删除（§2 可重建）；
  生成树 `/tmp/aw86927-v4`（`build/elden-tree` worktree @ `aebb727447` + 6 枚 am）**保留** —— 只作下一版迭代用，**不是权威件**，权威 = 本目录 7 封 patch。
