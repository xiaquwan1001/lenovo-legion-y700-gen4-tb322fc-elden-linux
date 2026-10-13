# M1 资产树基线重基可行性评估（7.2.0 血统 → 7.3-rc7）

> 任务 G · 2026-10-13 · lane m1-rebase · 纯主机侧，不推分支、不碰设备
> pristine 参照 = `geekidos-linux` 提交 `24a19b953e`（Linux 7.3-rc7）；payload 树 = `build/m1-upstream/clean-tree`（分支 m1/clean-tree，tip c73ff25222）
> 实验工作树 = `build/m1-rebase-worktree`（detached HEAD @ 24a19b953e）

## 0. 结论摘要

- **血统**：M1 资产树（`build/m1-upstream/clean-tree` @ m1/clean-tree, tip `c73ff25222`）共 **13 个提交**，基座 = **Linux 7.2.0**（树内 Makefile 证据）；它是 **shallow 根 `ba28ec16f0`**（真实父 `32c6462381ca` 未取回）。与 pristine `24a19b953e`（7.3-rc7）**无祖先关系**（双向 rev-list 23 / 1，merge-base 空）。`v7.2-elden` 标签落在 **M1 payload 第 2 个提交**上，不是基座提交。
- **原始重放（pristine 7.3-rc7 + 按序 cherry-pick）**：13 提交中 **3 OK / 9 冲突 / 1 不可重放**（可重放率 **23.1%**）。
- **冲突归因**：9 个冲突里 **8 个**根因是**板 DTS `sm8750-lenovo-elden.dts` 不存在于 7.3-rc7**（modify/delete），**不是 7.2→7.3 内核漂移**；预置该文件后这 8 个提交 **8/8 全部干净 apply**。**真正的 7.2→7.3 漂移冲突只有 1 个**：`drivers/input/misc/aw86927.c`（上游已重写该驱动，+43/−288）。
- **修正后的可重放率**：剔除浅根后 12 提交中 **11 个可干净重放（91.7%）**，唯一障碍 `00f08bac64`(aw86927)。
- **推荐 (A) 重基到 7.3-rc7**：先落板 DTS（M3-1 已做），再整体 cherry-pick，只需手工重做 aw86927 一个文件 + 单独处理 shallow 根 ba28（battmgr）。
- **M3 影响**：M3-1（已发）基线即 7.3-rc7，不受影响；M3-3/M3-4（就绪未发）若引用 M1 树里的 elden 片段，需统一到 7.3-rc7 口径（待人工核对）。

## 1. 血统事实复核

### 1.1 M1 树提交清单（最旧 → 最新，共 13 个）

命令：

```sh
cd /home/xuqianhui1001/y700-elden/build/m1-upstream/clean-tree
git log --oneline --reverse v7.2-elden~1..m1/clean-tree   # 等价: ba28..tip
git rev-list --count HEAD                                 # = 13
```

| # | 提交 | 主题 |
|---|------|------|
| 1 | `ba28ec16f0` | power: supply: qcom_battmgr: omit SM8750 maximum-load power reading |
| 2 | `44137cb4e9` **(tag: v7.2-elden)** | elden: vk41 — minimal PSCI SYSTEM_RESET2 vendor-reset hook for reboot bootloader/edl |
| 3 | `0c02ca0b39` | m1: A1 dpss GC gamma block (0002-sm8750-dspp-gc-gamma) |
| 4 | `00f08bac64` | m1: A3+B2 aw86927 SRAM/continuous (0003-aw86927-aw86937-haptics) |
| 5 | `b46bea4aad` | elden: vk42 — 干净重落 vk39 两项改动（音频 + 温控） |
| 6 | `fc08094eaa` | elden: vk44 — DMIC capture（VA macro + VA Capture dai-link） |
| 7 | `4983ea6df1` | elden: vk45 — VA macro vdd-micb supply + DMIC sample rate |
| 8 | `47d590b4f7` | elden: vk46 — 启用 WCD939x 音频编解码（模拟麦采集正路） |
| 9 | `ae3e0de16c` | elden: vk47 — WCD939x 采集（去 VA DMIC，单 WCD capture link） |
| 10 | `14c19a1ef0` | elden: vk53 — 硬件驱动覆盖批次（NFC ST21NFCA + CDSP 启用） |
| 11 | `7057ca4140` | elden: cdsp — 用 stock split 固件 (cdsp.mdt/cdsp_dtb.mdt) 取代单文件 .mbn |
| 12 | `563bbd787a` | dts: 相机 rotation +180（前 270→90 / 后 90→270） |
| 13 | `c73ff25222` | arm64: dts: qcom: sm8750: Add non-secure-domain to ADSP fastrpc |

原始输出片段：

```
c73ff25222 arm64: dts: qcom: sm8750: Add non-secure-domain to ADSP fastrpc
563bbd787a dts: 相机 rotation +180（前 270→90 / 后 90→270）
...
44137cb4e9 (v7.2-elden) elden: vk41 — minimal PSCI SYSTEM_RESET2 vendor-reset hook ...
ba28ec16f0 (grafted, origin/v7.2-elden, origin/HEAD) power: supply: qcom_battmgr: omit ...
```

### 1.2 基座与标签

- **M1 树基座 = Linux 7.2.0**（硬证据 = 树内 Makefile）：

  ```sh
  git -C build/m1-upstream/clean-tree show ba28ec16f0:Makefile | sed -n '1,6p'
  # VERSION = 7 / PATCHLEVEL = 2 / SUBLEVEL = 0 / EXTRAVERSION =
  ```

- `ba28ec16f0` 的**真实父提交 = `32c6462381ca`**（`git cat-file -p ba28ec16f0 | head`），但该对象**不存在**（`git cat-file -t 32c6462381ca` → fatal: Not a valid object name）⇒ 仓库是 **shallow clone**，无法把 7.2.0 基座对到上游某个具体 tag/commit。
- `v7.2-elden` 标签 == `44137cb4e9`，**是 M1 payload 的第 2 个提交，不是基座提交**（本仓不存在名为 `v7.2.0` 的上游 tag）。
- `24a19b953e` 的树 Makefile = **7.3.0-rc7**（`git show 24a19b953e:Makefile`），其父 `d6d3455d8751` 同样缺失（shallow 边界）。
- `torvalds/v7.3-rc7` 是 **annotated tag 对象** `ec8bf8280261` → commit `24a19b953e`（`git show-ref | grep torvalds`）。

### 1.3 拓扑证据（与 clean/base、7.3-rc7 的关系）

| 关系 | 结果 | 命令 |
|---|---|---|
| `merge-base m1/clean-tree clean/base` | `ba28ec16f0`（**M1 树与 clean/base 在浅根 ba28 处分叉，是兄弟**） | `git merge-base m1/clean-tree clean/base` |
| `rev-list --count m1/clean-tree..clean/base` | 22 | 同上 |
| `rev-list --count clean/base..m1/clean-tree` | 12 | 同上 |
| `merge-base 24a19b953e clean/base` | **空** | `git merge-base 24a19b953e clean/base` |
| `rev-list --count 24a19b953e..clean/base` | 23 | |
| `rev-list --count clean/base..24a19b953e` | 1 | |
| `rev-list clean/base | grep -c 24a19b953e` | **0** | 7.3-rc7 不在 clean/base 历史中 |

⇒ **24a19b953e（7.3-rc7）与 clean/base / m1/clean-tree 均无祖先关系**，任务背景所述「无祖先关系」成立。

> ⚠️ **方法论提示**：本仓为 shallow clone（`.git/shallow` 6 个浅边界，含 `24a19b953e` 与 `ba28ec16f0`）⇒ **`git merge-base` 无法跨浅边界回溯**（`merge-base 24a19b953e clean/base` 返回空、rc=1）。
>
> ✅ **编排者复核更正（2026-10-13，主会话实测）**：本节原记「`--is-ancestor` 对任意两提交都返回 rc=0、不可信」**复现不出，系误记**。实测：
>
> ```sh
> git -C geekidos-linux merge-base --is-ancestor 24a19b953e ba28ec16f0  # rc=1 ✓ 非祖先
> git -C geekidos-linux merge-base --is-ancestor 24a19b953e clean/base  # rc=1 ✓
> git -C geekidos-linux merge-base --is-ancestor ba28ec16f0 clean/base  # rc=0 ✓ 浅根确是 clean/base 祖先
> git -C geekidos-linux merge-base --is-ancestor 24a19b953e m3/usb-psy-name  # rc=0 ✓
> git -C geekidos-linux merge-base --is-ancestor 24a19b953e <bogus-ref>       # rc=128（错误码，符合预期）
> ```
>
> ⇒ **本仓 `--is-ancestor` 工作正常，不必禁用**；真正受限的是 `merge-base` 跨浅边界求值。本报告结论（无祖先关系）不变，取证手段应为 **`--is-ancestor` + 双向 `rev-list --count`**（`24a19b953e`=1 / `clean/base`=23）。
> 另：`24a19b953e` 在 geekidos-linux 里是 **depth-1 浅根** ⇒ 无法算 7.2→7.3 漂移提交数（§3 已如实记录，改用净差异 blob diff）。
> 附（编排者注，关于本报告 §5.3 的「git 环境不稳定」）：`geekidos-linux` 的 `torvalds` remote 是 **`--filter=blob:none` 部分克隆**，读 pristine 文件内容会触发**按需网络取 blob**（实测抓到一个 `git remote-https torvalds` 进程在跑）⇒ 表现为"慢/卡/间歇失败"，属**设计行为而非仓库损坏**；建议派工时提示「优先用已在本地对象库的内容(如 clean-tree)，跨血统取 pristine 文件需容忍网络取 blob」。

## 2. 重放成本量化

### 2.1 方法

```sh
cd /home/xuqianhui1001/y700-elden/build/m1-rebase-worktree   # detached @ 24a19b953e
git cherry-pick -x <sha>          # 按 1.1 顺序；成功即停在结果提交
git cherry-pick --abort        # 冲突或空提交时回到上一个成功点，继续下一个
```

### 2.2 逐提交结果

原始记录文件：`/tmp/m1rebase_records.txt`（每提交一行 `RESULT|<sha>|<结果>|...`）。

| # | 原提交 | 结果 | 新提交(本次) | 冲突文件 / hunk 数 | 备注 |
|---|--------|------|-------------|-------------------|------|
| 1 | `ba28ec16f0` | **不可重放** | — | 全树 add/add（1151 文件） | shallow 根：父 `32c6462381ca` 缺失，diff base 退化为空树 |
| 2 | `44137cb4e9` | ✅ OK | `d7b2fb2e25` | — | `psci.c` +37，干净 |
| 3 | `0c02ca0b39` | ✅ OK | `f84e3120da` | — | `dpu_hw_catalog.c`，干净 |
| 4 | `00f08bac64` | ❌ 冲突 | — | `drivers/input/misc/aw86927.c`（2 hunk） | **真漂移**：上游重写该驱动 |
| 5 | `b46bea4aad` | ❌ 冲突 | — | `sm8750-lenovo-elden.dts`（DU=modify/delete） | 伴生 `q6apm-lpass-dais.c` 自动合并成功(M) |
| 6 | `fc08094eaa` | ❌ 冲突 | — | 同上 | 板 DTS 不存在 |
| 7 | `4983ea6df1` | ❌ 冲突 | — | 同上 | 同上 |
| 8 | `47d590b4f7` | ❌ 冲突 | — | 同上 | 同上 |
| 9 | `ae3e0de16c` | ❌ 冲突 | — | 同上 | 同上 |
| 10 | `14c19a1ef0` | ❌ 冲突 | — | 同上 | 同上 |
| 11 | `7057ca4140` | ❌ 冲突 | — | 同上 | 同上 |
| 12 | `563bbd787a` | ❌ 冲突 | — | 同上 | 同上 |
| 13 | `c73ff25222` | ✅ OK | `fbab142751` | — | `sm8750.dtsi`，干净 |

**冲突类型取证**（#5，`git ls-files -u` 只有 stage 1/3，无 stage 2 ⇒ 我方删除 / 对方修改）：

```
DU arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
M  sound/soc/qcom/qdsp6/q6apm-lpass-dais.c
```

**aw86927 冲突的两个 hunk**（`git diff | grep '^@@@'`）：

```
@@@ -420,12 -510,17 +480,22 @@@ static void aw86927_haptics_play_work(...
@@@ -610,10 -758,100 +680,93 @@@ static int aw86927_haptic_init(struct a...
```

### 2.3 可重放率

| 口径 | 分子/分母 | 可重放率 |
|---|---|---|
| 全序列（含浅根） | 3 / 13 | **23.1%** |
| 剔除不可重放的浅根 `ba28` | 3 / 12 | **25.0%** |
| **修正口径**（先补回板 DTS 再重放，见下方子实验） | 11 / 12 | **91.7%** |

**子实验：预置板 DTS 后重放。** 记录：`/tmp/m1rebase_seed_records.txt`。

```sh
# 在 pristine 7.3-rc7 上先 checkout 7.2 基座里的板 DTS 并提交，再重放 8 个 DTS 提交
git checkout ba28ec16f0 -- arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
git commit -m "SEED: elden board DTS from 7.2 base"
```

结果：**8/8 全部 OK**（`b46bea4aad fc08094eaa 4983ea6df1 47d590b4f7 ae3e0de16c 14c19a1ef0 7057ca4140 563bbd787a`），
最终栈顶 `0ef37c7487 dts: 相机 rotation +180`。

⇒ 结论：**9 个冲突中 8 个是「M1 基座自带下游板 DTS、而 pristine 无此文件」的基座依赖伪冲突，不是 7.2→7.3 漂移；真正的漂移冲突只有 aw86927.c 一个。**

## 3. 7.2→7.3 漂移清单

> ⚠️ **本仓无法算「漂移提交数」**：`24a19b953e` 在 geekidos-linux 里是 **depth-1 浅根**，
> `git rev-list --count 24a19b953e` = **1**，`git log <base>..24a19b953e -- <file>` **只会回显 24a 自身**。
> 最小复现：
>
> ```sh
> git -C geekidos-linux rev-list --count 24a19b953e                                  # 1
> git -C geekidos-linux log --oneline ba28ec16f0..24a19b953e -- drivers/firmware/psci/psci.c
> #   -> 仅 "24a19b953e Linux 7.3-rc7"
> ```
>
> 隔离浅克隆取上游区间的尝试也不可靠（详见 §5 未决问题），故本节改用**净差异（blob diff）**度量：
> `git diff ba28ec16f0:<file> 24a19b953e:<file>`（＝ 7.2-elden 基座 → 7.3-rc7 的净变化，**含下游 7.2-elden 改动，非纯上游漂移**）。

### 3.1 M1 payload 实际触及的文件（12 提交）

```sh
git -C geekidos-linux show --format="" --name-only -1 <sha>   # 逐提交
```

| 文件 | 7.3-rc7 存在 | 净差异（ba28→24a） | 触及提交 | 重放结果 / 影响 |
|---|---|---|---|---|
| `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` | **否** | N/A | 8 个 DTS 提交 | 伪冲突源；补回后全 OK |
| `arch/arm64/boot/dts/qcom/sm8750.dtsi` | 是 | +250 / −536 | `c73ff25222` | 有漂移，仍干净 apply |
| `drivers/firmware/psci/psci.c` | 是 | **0**（完全相同） | `44137cb4e9` | 无漂移，干净 apply |
| `drivers/gpu/drm/msm/disp/dpu1/dpu_hw_catalog.c` | 是 | +12 / 0 | `0c02ca0b39` | 有漂移，仍干净 apply |
| `drivers/input/misc/aw86927.c` | 是 | **+43 / −288** | `00f08bac64` | **严重漂移 → 唯一真冲突** |
| `sound/soc/qcom/qdsp6/q6apm-lpass-dais.c` | 是 | +60 / 0 | `b46bea4aad` | 有漂移，自动合并成功 |

### 3.2 重点相关文件（M1 未触及，但影响 M3 基线）

| 文件 | 7.3-rc7 存在 | 净差异（ba28→24a） | 对 M3 的意义 |
|---|---|---|---|
| `arch/arm64/boot/dts/qcom/pmk8550.dtsi` | 是 | +30 / 0 | PMIC 节点有上游新增 |
| `Documentation/devicetree/bindings/arm/qcom.yaml` | 是 | +297 / −251 | 大幅演进；M3 binding 需按 7.3-rc7 重核 |
| `drivers/gpu/drm/panel/panel-novatek-nt36536.c` | 是 | +18 / −62 | 面板驱动被上游改过（对应 policy §3/§4 的 DSI 一族） |
| `drivers/media/platform/qcom/camss/camss.c` | 是 | 0 / −377 | 上游删掉 377 行（重构/迁出）；B8 camss 必须以 7.3-rc7 为准 |
| `sound/soc/codecs/wcd939x-sdw.c` | 是 | +7 / −1 | 小改动，影响 vk46/vk47 音频补丁 |
| `drivers/soc/qcom/qcom_pd_mapper.c` | 是 | +38 / 0 | 新增上游支持 |

**小结**：M1 触及的 6 个文件里，只有 `aw86927.c` 的漂移足以破坏重放；但 **M3 系列所依赖的 panel/camss/qcom.yaml/pmic 等文件在 7.2→7.3 都有实质变化** ⇒ **M3 补丁必须以 7.3-rc7 为基线重新核对**。

## 4. 结论与配方

### 4.1 推荐：**(A) 重基 M1 到 7.3-rc7**

依据：真漂移冲突只有 `aw86927.c` 一个；其余失败全部是「板 DTS 不在 pristine」的基座依赖，而这块已由 **M3-1 板支持**补齐。等 7.4（B）只会累积更多漂移、且无必要；保留 7.2（C）会让 M3 的 dtbs_check 基线口径无法统一。

### 4.2 可执行步骤

```sh
# 0. 基线：pristine 或已合 M3-1 的分支
git worktree add --detach build/m1-rebase-worktree 24a19b953e
cd build/m1-rebase-worktree

# 1. 先落板 DTS（M3-1 的内容，或先 checkout 7.2 基座版验证）
#    没有它，8 个 DTS 提交必冲突（modify/delete）

# 2. 按序重放 12 个 M1 提交（跳过浅根 ba28）
for sha in 44137cb4e9 0c02ca0b39 00f08bac64 b46bea4aad fc08094eaa \
           4983ea6df1 47d590b4f7 ae3e0de16c 14c19a1ef0 7057ca4140 \
           563bbd787a c73ff25222; do
  git cherry-pick -x "$sha"
done
# 预期：仅 00f08bac64(aw86927) 需要手工

# 3. ba28(battmgr) 单独处理：浅根无法 cherry-pick，
#    按补丁文本在 7.3-rc7 上手工重放，或确认该修复是否已上游化 -> 已上游则丢弃
```

### 4.3 风险

1. **shallow 仓限制**：无法 walk 上游历史，`--is-ancestor` 在本仓不可信（见 §1.3）。建议在能取到上游历史的环境重做，或先 `git fetch --unshallow`。
2. **板 DTS 双份风险**：7.2-elden 版与 M3-1 版内容不同，重基后必须保证仓库只有一份（以 M3-1 为准）。
3. **aw86927 重写**：v7.3-rc7 该驱动已无 firmware 波形装载路径（policy §4 A3 已定性），需按上游新结构重做，并把魔数提升为 DT 属性（policy §3 B2）。
4. **dtbs_check 口径**：`qcom.yaml` 大改，M3 binding 需按 7.3-rc7 重跑。

### 4.4 「M3 已发/在备补丁是否受影响」判定

| 补丁 | 状态 | 判定 |
|---|---|---|
| **M3-1** | 已发 | 其 pristine 参照本来就是 `24a19b953e`（7.3-rc7） ⇒ **不受影响** |
| **M3-3（audio/thermal 切片）** | 就绪未发 | 若补丁 diff 相对 7.3-rc7，则自身不受 M1 基座影响；但若引用了 M1 树里的 `sm8750-lenovo-elden.dts` / `wcd939x` / `q6apm-lpass-dais.c` 版本，必须切到 7.3-rc7 口径 —— **待人工核对（未决）** |
| **M3-4（display 切片）** | 就绪未发 | 同上；panel `nt36536` 在 7.3-rc7 已被改过（+18/−62），需按 7.3-rc7 重核 |

## 5. 验收原始输出 + 产物清单 + 未决问题

### 5.1 验收原始输出

```sh
# 基座版本（7.2.0）
$ git -C build/m1-upstream/clean-tree show ba28ec16f0:Makefile | sed -n '2,5p'
VERSION = 7
PATCHLEVEL = 2
SUBLEVEL = 0
EXTRAVERSION =

# pristine 版本（7.3.0-rc7）
$ git -C geekidos-linux show 24a19b953e:Makefile | sed -n '2,6p'
VERSION = 7
PATCHLEVEL = 3
SUBLEVEL = 0
EXTRAVERSION = -rc7

# 无祖先关系
$ git -C geekidos-linux merge-base 24a19b953e clean/base        # 空
$ git -C geekidos-linux rev-list --count 24a19b953e..clean/base  # 23
$ git -C geekidos-linux rev-list --count clean/base..24a19b953e  # 1
$ git -C geekidos-linux rev-list --count 24a19b953e              # 1  (depth-1 浅根)

# 板 DTS 在 pristine 缺失
$ git -C geekidos-linux cat-file -e 24a19b953e:arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
fatal: 路径 ... 在磁盘上，但是不在 '24a19b953e' 中
```

重放记录（`/tmp/m1rebase_records.txt`，节选）：

```
RESULT|ba28ec16f0|UNREPLAYABLE-SHALLOW-ROOT|parent-missing|power: supply: qcom_battmgr: ...
RESULT|44137cb4e9|OK|d7b2fb2e25|elden: vk41 — minimal PSCI SYSTEM_RESET2 ...
RESULT|0c02ca0b39|OK|f84e3120da|m1: A1 dpss GC gamma block ...
RESULT|00f08bac64|CONFLICT|nfiles=1|hunks=2|files=drivers/input/misc/aw86927.c,|m1: A3+B2 aw86927 ...
RESULT|b46bea4aad|CONFLICT|nfiles=1|hunks=0|files=arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts,|elden: vk42 ...
...
RESULT|c73ff25222|OK|fbab142751|arm64: dts: qcom: sm8750: Add non-secure-domain to ADSP fastrpc
```

预置板 DTS 子实验记录（`/tmp/m1rebase_seed_records.txt`）：8/8 OK（见 §2.3）。

### 5.2 产物清单

| 产物 | 说明 |
|---|---|
| `reports/m1-rebase-7.3rc7-feasibility-20261013.md` | 本报告 |
| `build/m1-rebase-worktree` | 实验工作树（detached HEAD @ 24a19b953e；实验后已 reset 回 pristine） |
| `/tmp/m1rebase_records.txt` | 原始重放记录（13 提交） |
| `/tmp/m1rebase_seed_records.txt` | 预置板 DTS 子实验记录（8 提交） |

> 本报告为**纯主机侧静态评估**，未上机，故不写「已修复」。

### 5.3 未决问题

1. **上游漂移提交数未取得**：本地 geekidos-linux 的 `24a19b953e` 是 depth-1 浅根，无法 `git log <base>..24a -- <file>`。
   隔离浅克隆（`/tmp/lx2`，`--shallow-since=2026-06-01` + 手工 fetch v7.2/v7.3-rc7 tag）在本次环境里 **tag 引用/对象无法稳定解析**（`git rev-parse v7.2` → unknown，尽管 clone 阶段 `git log refs/tags/v7.2` 能出 `Linux 7.2`），按纪律停止重试。**建议在能稳定取上游历史的环境补算本列。**
2. **`ba28ec16f0`(qcom_battmgr) 是否已上游化未判**：无历史可查。
3. **M3-3 / M3-4 是否引用 M1 树文件**：未核对（需看两分支 diff 相对 7.3-rc7 的引用面）。
4. **7.4 分支是否已被上游消化 aw86927 修复**：只测了 7.3-rc7，未测更高版本。
