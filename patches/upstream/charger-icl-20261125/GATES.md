# charger-icl-20261125 门禁账（本轮现跑 = 2026-11-25 主机侧整理轮，**未投递**）

> 口径 = `../README.md` §1（机械门）+ §3（发送纪律）。所有门在**本机**跑，不碰设备、不联网。
> 基线 = `build/elden-tree` @ `aebb727447` = **v7.4-rc3**（`git describe` 现查）。
> 结论先行：**G1/G3/G4/G5/G6 绿；G2 = 0E/1W（红，处置见 P0）；G7 上机证据 = 昨日已完成（本轮未重跑）。**

## 1. 门禁结论表（数字全部本轮现跑）

| 门 | 命令形状（原文见 §2） | 结果 |
|---|---|---|
| G0 基线 | `git -C build/elden-tree describe --tags` + `status --porcelain` | `v7.4-rc3`；工作区 **clean**（无未提交改动） |
| G1 落树 | 在 `/tmp/m12-gates`（`aebb727447` worktree）跑 `git apply --check` → `git apply` → `git am` | **rc=0**，无 offset/fuzz；`git am` 后 `git show --stat` = `drivers/power/supply/qcom_battmgr.c \| 63 +++…`，**1 file changed, 63 insertions(+)** |
| G2 checkpatch | `TMPSER=$(mktemp -d); cp *.patch "$TMPSER"/; (cd "$TMPSER" && perl <tree>/scripts/checkpatch.pl --strict --no-tree *.patch)` | **0 errors, 1 warning, 0 checks, 87 lines checked** ⇒ **红**（详见 §3） |
| G2′ 记录复现性 | 同枚 patch 用 `TASKS` 记录的 `-f` 文件模式 | **1 error（false positive）/ 0 warnings / 126 lines** ⇒ 记录里的「0E/0W」不可复现（§3） |
| G3 编译 | `/tmp/m12-gates` + `O=/tmp/kb-m12`：`make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig` 然后 `… O=/tmp/kb-m12 W=1 drivers/power/supply/qcom_battmgr.o` | **rc=0，0 warning / 0 error**；产物 `ELF 64-bit LSB relocatable, ARM aarch64`；`.config` 里 `CONFIG_BATTERY_QCOM_BATTMGR=m`（来自 `arch/arm64/configs/defconfig`，未手改） |
| G4 变体边界 | `git diff` 复核 `sc8280xp/x1e80100` 相关 desc 与 `:1730/:1710` 注册点 | 未动；新回调对两变体显式 `-EINVAL`（补丁内 `battmgr->variant ==` 判定） |
| G5 收件人 | 在**树根**跑 `<tree>/scripts/get_maintainer.pl --no-git-fallback --no-rolestats 0001-*.patch` | `sre@kernel.org` / `linux-arm-msm@vger.kernel.org` / `linux-pm@vger.kernel.org` / `linux-kernel@vger.kernel.org`（**无** Bjorn/Konrad ⇒ 列 `README.md` §3 待裁决） |
| G6 cover 自查 | ① cover 是否含 what/why + A/B 表 + 三条边界 + AI 披露在 `---` 之下；② 空目录 patch 模式跑 `checkpatch --strict --no-tree 0000-*.patch` | ① 逐条对照 = **4/4 在**（披露段在 tearline 之下，位置用 `grep -n '^---$' 0000-*.patch` 现查）；② cover = **0 errors, 0 warnings**（"no obvious style problems and is ready for submission"） |
| G6′ 投递 dry-run | `bash SEND.sh`（默认 dry-run） | **rc=0**：2/2 封邮件解析 OK、smtp 配置齐（`smtp.ustc.edu.cn:465`）、4 个 RCPT 全 `Result: OK`；件内 `[PATCH v2]` 触发**非致命告警**（首投前必须做 §4 第 4 步） |
| G7 上机 A/B | 今日未重跑（需设备；按纪律不碰） | 昨日结果 = `TASKS` §7 M12 行 + `README.md` §2：clamp 两端对、`unknown message` = 0、A/B 两轮可重复；**边界见 cover 第三条** |

## 2. 复跑命令（逐条可复制）

```sh
cd /home/xuqianhui/y700-elden
SER=$PWD/patches/upstream/charger-icl-20261125
TREE=$PWD/build/elden-tree
CP=$TREE/scripts/checkpatch.pl

# G1：干净 worktree + 落树 + am
git -C "$TREE" worktree add --detach /tmp/m12-gates aebb727447
cd /tmp/m12-gates
git apply --check "$SER"/0001-*.patch && git am "$SER"/0001-*.patch && git show --stat HEAD | tail -3

# G2：必须在**空目录**里跑（在仓库根/树根跑会退化成文件模式 = 假绿）
TMPSER=$(mktemp -d); cp "$SER"/*.patch "$TMPSER"/
( cd "$TMPSER" && perl "$CP" --strict --no-tree *.patch ); echo "checkpatch rc=$?"

# G3：编译门
cd /tmp/m12-gates
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-m12 defconfig
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-m12 W=1 \
     drivers/power/supply/qcom_battmgr.o
file /tmp/kb-m12/drivers/power/supply/qcom_battmgr.o

# G5：收件人（必须在树根，否则 get_maintainer 直接报 "not a kernel tree"）
cd "$TREE" && ./scripts/get_maintainer.pl --no-git-fallback --no-rolestats "$SER"/0001-*.patch

# G6′：投递 dry-run（默认 dry-run，不发信）
bash "$SER"/SEND.sh

# 收尾：清临时件（否则 worktree 残留）
git -C "$TREE" worktree remove --force /tmp/m12-gates; rm -rf /tmp/kb-m12
```

## 3. G2 为什么是红的，以及「0E/0W」是怎么来的

`checkpatch` 只有**patch 模式**（把补丁当邮件/补丁解析）才会跑 patch 级检查（Subject、签名区、
commit message 折行/拼写）；`-f` 文件模式把它当**源码**扫，patch 级检查**全部跳过**。

| 跑法 | 输出 |
|---|---|
| 空目录 + 默认（patch 模式） | `WARNING: 'acknowledgement' may be misspelled - perhaps 'acknowledgment'?` + `total: 0 errors, 1 warnings, 0 checks, 87 lines checked` |
| 空目录 + `--strict --no-signoff` | 同一条 warning |
| `-f` 文件模式（= 记录用的跑法） | `ERROR: trailing whitespace`（命中的是 diff 里的**上下文行** `" $"`，属 false positive）+ `total: 1 errors, 0 warnings, 126 lines checked` |

⇒ 记录里的「`--no-tree -f` 0E/0W（1824 行）」既不是 patch 模式的数、也复现不出来；
**真数 = 0E / 1W**，唯一的 warning 是 commit message 里一个拼写建议。

## 4. P0 —— 投前必须先做的一步（需放行改 commit message）

本任务的硬约束是「不改 `0001` 正文」，所以下列 4 处**只登记、不执行**。放行时按顺序做一次即可，
注意 `0001` 的 **diff 段不得变动**（改完用 `diff -u` 与现文件比 diff 段，应只差 header/changelog）：

1. **拼写**：commit message 的 `acknowledgement` → `acknowledgment`（消 G2 唯一 warning）。
2. **收窄未证表述**：`reported as 100 mA on several devices` → `on this device`（我们只在 TB322FC 上测过）。
3. **补 AI 披露段**：`Signed-off-by` 与 `---` 之间不动，在 `---` 之后、`diff --git` 之前插入与
   `../dwc3-v14-20261124/` 同形的披露段（`0001` 现有件缺这段，`0000` cover 已带）。
4. **重生成版本号**：本系列从未投递过，首投不应带 `[PATCH v2]` ⇒
   `git am` 进干净 worktree → 改上述 1–3 → `git format-patch --cover-letter -1` ⇒ 得 `0000`/`0001`
   两枚（编号自动为 `0/1`、`1/1`），用生成件替换本目录两枚后重跑 §2 的 G1/G2，再 `bash SEND.sh`。
   做完把 cover 里 G2 那一行同步改成 `0 errors, 0 warnings`。

## 5. 未做 / 边界

- **G7 上机未重跑**：本轮禁碰设备；证据沿用昨日（零写盘 `fastboot boot` 测试核，非日常核）。
  cover 第三条边界已写明「900 mA 档被 SDP 端口顶在 ~500 mA，不宣称全档达成」。
- **未做插拔重下发测试**（旧 README §5.2 那条）：原始 A/B 脚本只做「写 → 采样」，没有 unplug/re-plug。
  cover 的「Not tested」第 2 条已如实写明「没测固件是否会在新一次充电器通知时重置限流」。
- **PD 充电器回归未在硬件上跑**：`sc8280xp/x1e80100` 与 PD 路径只有编译/静态判据（G3/G4）。
- **未联网核 lore/patchwork 是否已有人做同一件事**（本轮禁联网；`reports/m12-charger-upstream-20261125.md`
  §1 已把检索式与「未核实」标注留给下一轮）。
- 临时 worktree `/tmp/m12-gates`、构建目录 `/tmp/kb-m12` **已在收尾时删除**；`build/elden-tree` 工作区
  保持 clean（`git status --porcelain` 空）。
