# dwc3 v11 MANIFEST（2026-11-21）

> 本目录 = **v11**，替代 `../dwc3-v10-20261120/`。
> **v10 目录一字未动**（v10 → superseded 只记在本文件与 `../../reports/dwc3-v11-20261121.md`）。
> 未发信、未投递；投递由用户放行（`GATES-v11.md` §5 是放行清单）。

## 0. 目录内容

| 文件 | 内容 | 与 v10 的关系 |
|---|---|---|
| `v11-0000-cover-letter.patch` | 系列信：理由 + AI 披露 + 对 sashiko 4 条的逐条处置 + Known gaps + G1–G7 实数 | 新写（v10 cover 是 `git format-patch --cover-letter` 产物，本轮**手工组装**，见 §1 注） |
| `v11-0001-dt-bindings-…-one-HS-data-bus.patch` | dt-binding（`snps,dwc3-common.yaml`）98+/1- | 基底 = `../dwc3-v10-20261120/v10-0001`；**新增 1 行改动**（§2.1） |
| `v11-0002-usb-roles-…-graph-endpoint.patch` | `drivers/usb/roles/class.c` 45+ | **逐字节同 v10-0002**（除版本号/日期） |
| `v11-0003-usb-dwc3-…-mux-controller.patch` | `core.c` 116+/2-、`core.h` 43+、`debugfs.c` 4+、`drd.c` 329+/1- | 基底 = `../dwc3-v10-20261120/v10-0003`；**唯一差异 = `dwc3_drd_exit()` 里 deselect 的位置**（§2.2） |
| `GATES-v11.md` | 门禁账：命令 + 输出原文 + 跑不了的门为何跑不了 | 重跑（v10 的 `GATES-20261121.md` 是 v10 内容的结果） |
| `gates/*.dts|*.dtb` | G6 正/负样例 8 份 | v11 新增 2 份正样例（`pos-no-dr-mode`、`pos-nonmux-endpoint0`），2 份沿用 v9 |
| `logs/*.log` | 本轮全部门禁日志（G4/G6 的 schema 编译日志 `.gz`） | 新 |

## 1. 底座与一条必须记录的版本账事实

- **底座**：`build/elden-tree` @ `aebb727447` = `v7.4-rc3`（与 v10 声明同源）。
- **事实（本轮现查）**：**v10 实际投出的 1/3 不是仓库里 `../dwc3-v10-20261120/v10-0001-*.patch` 的内容。**

  | 证据 | 值 |
  |---|---|
  | patchwork `15007992` 的 `diff` 字段（`api/1.2/patches/15007992/`） | `index 6c0b8b6538..57e3c1d9ed`，正文含 `$defs:` / `$ref: '#/$defs/hs-port'` |
  | `../dwc3-v10-20261118/v10-0001-*.patch`（11-18 版） | `index 6c0b8b6538..57e3c1d9ed` ⇒ **与投出的逐字节相同** |
  | `../dwc3-v10-20261120/v10-0001-*.patch`（11-20 重写版） | `index 6c0b8b6..5dd032c` ⇒ **从未投出** |
  | `/tmp/dwc3-am-20261121`（HEAD `51f63f8edf`，就是 v10 cover 里的 `From` 值） | yaml blob = `57e3c1d9ed03` |
  | `/tmp/dwc3-v10-final`（重写版链） | yaml blob = `5dd032c76ac2` |

  ⇒ 11-21 那封 v10 是从 11-18 补丁链（`/tmp/dwc3-am-20261121`）`format-patch` 出来的，
  11-20 16:29 做的 binding 重写**留在盘上没进信**。所以 sashiko 对 `$defs`/`hs-port` 的两条意见
  **不是过时意见**，而是针对真实投出内容；v11 的 1/3 基底因此取「11-20 重写版」（它正好就是这两条意见的修法）。
- **注（cover 形态）**：本轮不执行 `git commit`，所以 cover 不是 `format-patch --cover-letter` 产物，
  是照 v10 cover 的版式手写的（`From 0000…` 占位）。放行时若走 `git am` + `format-patch`，会得到版式相同的真件。
  同理 `v11-0001`/`v11-0003` 顶部 `From 0000…` 是占位（内容改过，v10 的 commit hash 已不对应）；
  `v11-0002` 内容未变，保留原 `From 04565834…`。

## 2. 改了哪些行、为什么（逐条）

### 2.1 `v11-0001`（binding）—— 唯一一行相对 v10 重写版的改动

`snps,dwc3-common.yaml`，allOf 的 `mux-controls` 分支（patch 第 73 行；新文件第 34 行）：

```diff
-      required: [dr_mode, ports, usb-role-switch]
+      required: [ports, usb-role-switch]
```

- **为什么**：sashiko `[Low]` —— `usb-drd.yaml` 里 `dr_mode` 默认 `otg`，驱动侧
  `dwc3_get_dr_mode()` 在 `usb-role-switch` 存在时也把「缺省」当 `otg`；把它列进 `required`
  ⇒ **省略 `dr_mode` 的合法树被 schema 拒**。实测复现（`GATES-v11.md` §2 G6 对照）：
  v10 schema 对 `pos-no-dr-mode.dtb` 报 `'dr_mode' is a required property`；v11 schema 0 诊断。
- **保留 `properties.dr_mode: const: otg`**：`dr_mode = "host"/"peripheral"` 与 `mux-controls`
  同时出现仍然被拒（负样例 `neg-dr-mode-host` 实测被拒），因为 mux 路径只由 OTG/role-switch 进入。
- 该 patch 其余 98+/1- 全部来自 11-20 重写版（**不是本轮新改**），它同时是 sashiko 另两条意见的处置：

  | sashiko 条目 | 重写版对应内容（新文件行号） | 实测 |
  |---|---|---|
  | `[Medium]` `port@0` 无条件 `$ref` 破坏非 mux 的 `port@0` | 顶层 `port@0` 改为 `$ref: graph.yaml#/$defs/port-base` + `unevaluatedProperties: false` + `patternProperties '^endpoint@[01]$'`（L454 起：`$ref: graph.yaml#/$defs/port-base` 在 L460，`patternProperties` 在 L464）；双 endpoint/`#address-cells`/`#size-cells`/`usb-role-switch`/`mux-state` 只在 allOf 的 mux 分支 `required`（L29–L48：`required: [ports, usb-role-switch]` 在 L34） | v11：`pos-nonmux-endpoint`（不带 reg）、`pos-nonmux-endpoint0`（带 reg、无 role 属性）**均 0 诊断**；v10-as-sent schema 拒后者（3 条诊断） |
  | `[Low]` 未吸收维护者 schema 风格（`$defs`） | 文件里**没有** `$defs:`；`grep -c '^\$defs' = 0`（现查）；端点 schema 内联进 `patternProperties` | `grep` 现查 |
  | `[Low]` 驱动实现细节写进 binding | mux 分支的注释不再提 `dwc3_get_dr_mode()` / `dwc3_get_extcon()` / `dwc3_drd_init()` / `usb_role_switch_at_endpoint()` | `grep -n 'dwc3_\|usb_role_switch_at_endpoint'` 在 yaml 中 **0 命中** |

### 2.2 `v11-0003`（driver）—— 唯一一处相对 v10 的改动

`drivers/usb/dwc3/drd.c` 的 `dwc3_drd_exit()`（patch 第 639–651 行删除段 / 第 693–706 行新增段；
落树后新文件 L944–L954）：

```diff
 	cancel_work_sync(&dwc->drd_work);
 
-	/* The mode worker is drained: no switch can select the mux any more. */
-	dwc3_role_mux_deselect(dwc);
-
 	/* debug user might have changed role, clean based on current role */
 	switch (dwc->current_dr_role) {
 	…
 	}
 
+	/*
+	 * Deselect only after the active role has been torn down, in the same
+	 * order as __dwc3_set_mode(): mux_control_deselect() switches the shared
+	 * High Speed lines back to the mux' idle state, which would cut the data
+	 * path off underneath a host or gadget instance that is still running.
+	 * The mode worker is drained, so nothing can select the mux again.
+	 */
+	dwc3_role_mux_deselect(dwc);
+
 	if (dwc->otg_irq)
 		free_irq(dwc->otg_irq, dwc);
```

- **为什么**：sashiko `[Medium]`。`mux_control_deselect()` 在 mux 有 `idle-state`（≠ `MUX_IDLE_AS_IS`）
  且当前口不是 idle 口时，会把 HS 差分线**切回 idle 口**；原顺序（deselect → `dwc3_host_exit()`/
  `dwc3_gadget_exit()`）等于「实例还在跑、线已被切走」。`__dwc3_set_mode()` 的顺序一直是
  「先 exit 角色、再动数据通路」（`v11-0003-*.patch` 内 `@@ -233,8 +249,60 @@` 段的注释即此义），
  `dwc3_drd_exit()` 现在与之对齐。
- **没有动的部分**：`dwc3_role_mux_exit(dwc)` 仍在函数最前（先拒绝新请求再 drain work，顺序理由在
  `dwc3_role_mux_exit()` 自己的注释里）；`__dwc3_set_mode()` 的 deselect→select 配对、
  `active_port` 记账、`devm_mux_control_get()` 生命周期、`err:` 路径的
  `dwc3_role_mux_exit → cancel_work_sync → dwc3_role_mux_deselect` 三者顺序全部不动。
  `diff` 现查：v11-0003 的 diff 与 v10-0003 的 diff 差异**只有**该 hunk + `index` 行缩写（7→12 位）。

### 2.3 `v11-0002`（roles/class.c）

零改动。`diff` 与 v10-0002 逐字节相同（`sed` 只换了 `Subject: [PATCH v11 2/3]` 与 `Date:`）。
单一职责 = 「按图 endpoint 查 role switch」，本系列其余两枚不依赖它的内部实现。

## 3. 单一职责边界（为什么不是「合并成一个 patch」）

| patch | 只做一件事 | 依赖 |
|---|---|---|
| 0001 | 只描述**设备树形状**（不含驱动行为） | 无 |
| 0002 | 只加 `usb_role_switch_at_endpoint()` 查找（对现有用户零行为变化） | 无 |
| 0003 | 只用 mux 控制器驱动共享 HS 通路（含 deselect 时序） | 0001 的 `mux-controls`/`mux-state`、0002 的 endpoint 查找 |

拆法沿用 v9/v10，未因 sashiko 意见而合/拆 patch（意见都是「某枚 patch 内某处」）。

## 4. 相对 v10 的净差额

| 项 | v10（实际投出） | v11 |
|---|---|---|
| 文件数 / 增删 | 6 files / 650+ / 5- | **6 files / 632+ / 4-** |
| checkpatch | 146/63/618 行，0E/0W/0C | 115/63/624 行，0E/0W/0C |
| G5 `dtbs_check` | 4/4，0 诊断（新增 0） | 4/4，0 诊断（新增 0） |
| G6 正样例 | 1 份 | **4 份**（+ 省略 `dr_mode`、非 mux 的两种 endpoint 形状） |
| G6 负样例 | 4 类 | **4 类**（把「legacy v8 形状」换成「`dr_mode=host`+mux」，因为 v10 起已无 v8 形状可测） |
| sashiko 意见 | 4 条未处置 | 4/4 接受并落地（`reports/dwc3-v11-20261121.md` §2） |

## 5. 复现

见 `GATES-v11.md` §2（逐条命令 + 输出原文）。一句话：

```sh
git -C build/elden-tree worktree add --detach /tmp/dwc3-v11-base aebb727447
cd /tmp/dwc3-v11-base && for p in .../dwc3-v11-20261121/v11-000{1,2,3}-*.patch; do git apply "$p"; done
# yaml=7a9cb5a115a6 drd.c=906cac4f3e6e core.c=ce309792864b core.h=e6cf7b240b debugfs.c=82e7a334b1 class.c=ee186d542a
```
