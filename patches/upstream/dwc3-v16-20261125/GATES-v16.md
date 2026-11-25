# dwc3 v16 门禁账（2026-11-25，**已备料，未投递**）

> 为什么有 v16：sashiko 2026-11-25T08:29:30Z 对 v15 1/3 报两条 `[Low]`
> （`incomplete endpoint schema under port@0`、`inter-version changelog above tearline`），
> 同一时段 08:31:24Z 的系列小结判 **2/3・3/3 无问题**。⇒ 只重出 1/3，2/3、3/3 与 v15 内容相同。
> 原文与逐条判别 = `../../../reports/comm-triage-20261125.md` §2.6、`../../../reports/mobian-phosh-upstream-20261125.md` §2.3 A1；
> 处置报告 = `../../../reports/dwc3-v16-20261125.md`。
>
> **门编号**：本文 G1–G5 按本轮任务单的 5 条门；G6–G8 是附加/未跑项。
> 与 v14/v15 的 `GATES-v14.md` 编号**不一一对应**（那边 G4=binding、G5=dtbs_check、G6=样例）。

## 0. 数字结论（本轮现跑，命令与原始输出摘要逐条给在 §1）

| 门 | 命令形状 | 结果 | 原始日志 |
|---|---|---|---|
| G0 基线 | `git -C build/elden-tree log -1` | `aebb727447` = **v7.4-rc3**（与 v12/v13/v14/v15 同一基线）；worktree `/tmp/dwc3-v16` detached 于此 | — |
| G1 落树 | `git am v16-000{1,2,3}` on 干净 worktree | **3/3 干净，rc=0，无 offset/fuzz/reject** | `logs/G1-apply.log` |
| G2 checkpatch | `--no-tree --strict --no-signoff - < <patch>` ×3 | **0E/0W/0C**（122 / 63 / 624 行） | `logs/G2-checkpatch.log` |
| G3 binding | `dt_binding_check` 定向（`DT_SCHEMA_FILES=`）+ 全量 | 定向 **rc=0**、`snps,dwc3.example.dtb DTC [C]`、0 诊断；全量 **rc=0**、**5420** 个 `DTC [C]`、0 诊断 | `logs/G4-dt-binding-check-targeted.log`、`logs/G4-dt-binding-check-full.log` |
| G4 样例 | `dt-validate -s <schema>` 13 例 × v15/v16 两套 schema | 正例 **5/5 两套都 0 诊断**；负例 **6/6 两套都被拒**；新增负例 **2/2 只在 v16 被拒** | `logs/G6-samples.log` |
| G5 逐字节/blob | `cmp` diff 段 + `git patch-id` + `git hash-object` | 2/3・3/3 **diff 段 cmp 相同**、patch-id 与 v15 相同；1/3 后像 blob = patch `index` 右值 | `logs/G5-identity.log`、`logs/G1-apply.log` |
| G6 dtbs_check（附加） | `CHECK_DTBS=1` 4 板 + 12 板（含基线对照） | 4/4・12/12 `DTC [C]`；12 板诊断 **5 条与基线逐行相同 ⇒ 0 new** | `logs/G5-dtbs-check-4boards.log`、`...-12boards.log`、`...-12boards-BASE.log` |
| G7 上机 | — | **本轮未做**（沿用 v15 的 2026-11-25 真机轮；该轮跑的正是字节相同的 2/3・3/3） | — |
| G8 `W=1` 编译 | — | **未重跑**：2/3・3/3 与 v15 逐字节同内容，1/3 只动 binding ⇒ 编译面零变化 | — |

## 1. 逐门明细

### G0 基线

```
$ git -C build/elden-tree status --short          # 空（无改动）
$ git -C build/elden-tree log -1 --format='%H %s'
aebb7274476403040d582c61478df8f4a7bf9cd3 Linux 7.4-rc3
$ git -C build/elden-tree worktree add --detach /tmp/dwc3-v16 aebb727447
```

`build/elden-tree` 收工状态 = 与被借用前一致（`status --short` 空、`worktree list` 无 `/tmp/dwc3-v16`，见 §3）。

### G1 落树（`git am`）

命令与原始输出全文 = `logs/G1-apply.log`。摘要：

```
$ git am v16-0001-...patch v16-0002-...patch v16-0003-...patch
应用：dt-bindings: usb: snps,dwc3: describe two connectors on one HS data bus
应用：usb: roles: look up role switches attached to a graph endpoint
应用：usb: dwc3: select the shared HS data bus with a mux controller
rc=0
```

三条 commit message 里 `Changes since` 命中数 = **0+0+0**（`git am` 确实没把 tearline（`---`）以下的 changelog 收进提交信息 —— 这正是 sashiko 第 2 条要的行为）。

### G2 checkpatch

```
$ perl scripts/checkpatch.pl --no-tree --strict --no-signoff - < v16-0001-...patch
total: 0 errors, 0 warnings, 0 checks, 122 lines checked
$ ... v16-0002-...patch
total: 0 errors, 0 warnings, 0 checks, 63 lines checked
$ ... v16-0003-...patch
total: 0 errors, 0 warnings, 0 checks, 624 lines checked
```

**必须喂 stdin**：直接传文件路径会被当源码解析、报 4 条假 `trailing whitespace`（PITFALLS #725）。全文 = `logs/G2-checkpatch.log`。

### G3 `dt_binding_check`

构建环境：`make -j26 ARCH=arm64 O=/tmp/kb-dwc3-v16 defconfig`（日志 `logs/G3-defconfig.log`）。

定向（本轮唯一改动的 binding + 带 examples 的父 binding）：

```
$ rm -f $O/Documentation/devicetree/bindings/processed-schema.json
$ make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v16 \
    DT_SCHEMA_FILES=Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml:Documentation/devicetree/bindings/usb/snps,dwc3.yaml \
    dt_binding_check
rc=0
  DTEX    Documentation/devicetree/bindings/usb/snps,dwc3.example.dts
  DTC [C] Documentation/devicetree/bindings/usb/snps,dwc3.example.dtb
```

> 为什么带两个文件：`snps,dwc3-common.yaml` 是 fragment，**没有 `examples:`**；只写它时 `CHK_DT_EXAMPLES` 为空，
> 命令虽然 rc=0 但等于什么都没编译（本轮先这样跑过一次，`logs/` 未留该次）。加 `snps,dwc3.yaml` 才有
> `snps,dwc3.example.dtb` 真正走一遍 schema。

全量：

```
$ rm -f $O/Documentation/devicetree/bindings/{processed-schema.json,.dt-binding.checked,.yamllint.checked,.dt-style.checked}
$ make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v16 dt_binding_check
rc=0    DTC [C] 计数 = 5420    含 error/warning 的行 = 0
```

5420 与 v14 GATES 记的同一个数（本机 dtschema 2026.9 固定）。原始日志 880 KB，`logs/` 里存的是裁剪版
（只删 `DTC [C]` 逐样例回显与 HOSTCC 噪声，保留计数、首尾与全部含 error/warning 的行）。

### G4 正/负样例

样例目次 `gates/`（13 个 `.dts`）：v14 的 11 个原样搬来 + 本轮新增 2 个：

| 新文件 | 形状 | 证明哪一处 |
|---|---|---|
| `neg-nomux-endpoint-role.dts` | 单连接器、无 mux，`port@0/endpoint` 带 `usb-role-switch` + `mux-state` | 第 1 处（else 分支补 `$ref: /schemas/graph.yaml#/properties/port`） |
| `neg-mux-endpoint-a.dts` | 有 mux，`port@0` 里第三个端点是 `endpoint@a` | 第 2 处（pattern 由 `([2-9]\|[1-9a-f][0-9a-f]+)` 改为 `([2-9a-f]\|[0-9a-f]{2,})`） |

命令（两套 schema 对照；v15 那套是把本轮两处改动**反向**写回 yaml 后重生成的
`processed-schema.json`，见 `logs/G6-schema-regen-v15-yaml.log`）：

```
$ dtc -I dts -O dtb -o <sample>.dtb gates/<sample>.dts          # 13/13 无 stderr
$ dt-validate -s /tmp/schema-{v15,v16}.json <sample>.dtb
```

| 样例 | v15 schema | v16 schema | 期望 |
|---|---|---|---|
| `pos-v11`（两端点、相反 mux-state、`dr_mode=otg`） | 0 | 0 | 通过 |
| `pos-no-dr-mode`（同上、省 `dr_mode`） | 0 | 0 | 通过 |
| `pos-nonmux-endpoint`（单连接器、plain `port@0/endpoint`） | 0 | 0 | 通过 |
| `pos-nonmux-endpoint0`（单连接器、`port@0/endpoint@0` 无 role 属性） | 0 | 0 | 通过 |
| `nomux-two-endpoints`（两端点、无 mux） | 0 | 0 | 通过 |
| `neg-same-state` | 2 | 2 | 被拒 |
| `neg-one-endpoint` | 2 | 2 | 被拒 |
| `neg-no-role-props` | 3 | 3 | 被拒 |
| `neg-dr-mode-host`（mux + `dr_mode=host`） | 2 | 2 | 被拒 |
| `neg-mux-plain-endpoint`（mux 下 plain `endpoint`） | 2 | 2 | 被拒（**v14 修的那处，本轮未回退**） |
| `neg-mux-endpoint2`（mux 下 `endpoint@2`） | 2 | 2 | 被拒（同上） |
| `neg-mux-endpoint-a`（**新增**） | **0（漏拒）** | **2** | 被拒 |
| `neg-nomux-endpoint-role`（**新增**） | **0（漏拒）** | **2** | 被拒 |

新增两例在 v15 schema 下是 0 诊断、v16 下 2 诊断 ⇒ 两处改动**各自**都有可复现的判别证据。
诊断原文（`logs/G6-samples.log`）：

```
neg-mux-endpoint-a: ports:port@0: False schema does not allow {'reg': [[10]], 'usb-role-switch': True, ...}
neg-nomux-endpoint-role: ports:port@0:endpoint: Unevaluated properties are not allowed
                          ('mux-state', 'usb-role-switch' were unexpected)
```

> 判定看**诊断行数**，不看 `rc`：dt-validate 2026.9 即使报诊断也退 0（本轮实测，见日志首行注释）。

### G5 blob / 逐字节

```
                                  patch index 右值   落树 hash-object        patch index 左值（基线）
snps,dwc3-common.yaml             1f23840fd1f2       1f23840fd1f2188fec4d…   6c0b8b653824（基线）
drivers/usb/roles/class.c         ee186d542a10       ee186d542a1018237d10…   edec139b68b5
drivers/usb/dwc3/core.c           ce309792864b       ce309792864b3aa6ba89…   372737f4750b
drivers/usb/dwc3/core.h           e6cf7b240b23       e6cf7b240b23eab7d2c1…   f3dabb37f806
drivers/usb/dwc3/debugfs.c        82e7a334b135       82e7a334b135821c9292…   01ebd73198e0
drivers/usb/dwc3/drd.c            906cac4f3e6e       906cac4f3e6e5ac2816f…   f3e37d383627
```

后 5 枚 blob 与 v15 `CHECKLIST.md` 记的**逐字相同**（`ee186d542a10`/`ce309792864b`/`e6cf7b240b23`/`82e7a334b135`/`906cac4f3e6e`）
⇒ 2/3・3/3 落树后的文件内容与 v15 完全一致；只有 1/3 的 yaml 从 `dcfa8c3a81c5` 变成 `1f23840fd1f2`。

内容同一性（`logs/G5-identity.log`）：

| 件 | `cmp` diff 段 | `git patch-id --stable` | 整文件差异 |
|---|---|---|---|
| 2/3 | **相同**（sha256 `daa8e9365529164f…`，与 v15 CHECKLIST 同值） | v15 = v16 = `5688adec43ea…` | 6 行，全是生成器头部（`From`/`Date`/`Subject`） |
| 3/3 | **相同**（sha256 `83eae25253cffc12…`，同上） | v15 = v16 = `60721b9fb7fb…` | 6 行，同上 |
| 1/3 | 不同（预期） | v15 `aa6ed734239b…` → v16 `4aa77681f9b6…` | 见 §2 |

> **「逐字节相同」的口径**：与 v14→v15 一致 —— 指 `diff --git` 起的全部 patch 内容；
> `From:`/`Date:`/`Subject:` 由 `git format-patch` 重写，物理上不可能也不该保持不变。
> 整文件 `cmp` 会因这 3 行而不同，故同时给出「diff 段 cmp + patch-id + 整文件差异行逐一列出」三证据。

### G6 dtbs_check（附加，非任务单要求）

改动的 else 分支作用在**所有**单连接器 dwc3 节点上，所以额外做了一次真实 DTS 回归：

```
$ make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v16 CHECK_DTBS=1 \
    qcom/sm8250-mtp.dtb qcom/sm8650-mtp.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
rc=0    DTC [C] 4    诊断行 0
```

再取「树里有 dwc3 节点且含 `port@0`」的 12 块板
（`sm8250-mtp`、`sdm845-db845c`、`sc8280xp-crd`、`qdu1000-idp`、`apq8096-db820c`、`imx8mp-evk`、
`rk3588-rock-5b`、`rk3399-roc-pc`、`sun50i-h6-pine-h64`、`zynqmp-zcu104-revA`、`k3-am62a7-sk`、`exynos5433-tm2`）：

```
patched: DTC [C] 12   诊断 5 条
base   : DTC [C] 12   诊断 5 条
$ diff <(base 诊断) <(patched 诊断)   → 空（DIAGNOSTICS IDENTICAL）
```

5 条全是既有的、与本系列无关的项（`fcs,fusb302` 的 `connector` 两处、`qcom,msm8996-dwc3` 的 `extcon` 两处、`syscon` 一处）。

## 2. 1/3 相对 v15 的全部改动（三处，diff 段原文见 `logs/G5-identity.log`）

1. then 分支 pattern：`'^endpoint@([2-9]|[1-9a-f][0-9a-f]+)$'` → `'^endpoint@([2-9a-f]|[0-9a-f]{2,})$'`（1 行改 1 行）。
2. else 分支 `port@0`：补 `$ref: /schemas/graph.yaml#/properties/port`（+1 行）与 5 行注释。
3. `Changes since v13` 段原来在 1/3 的 commit message 里，现在整体移到 tearline（`---`）之下，并按 v16 重写为 `Changes since v15`（+24 行文字，不占 diffstat）。

diffstat 由 `99 insertions` 变 `105 insertions`（`106` 行变动）—— 全在 binding 一枚里。

## 3. 收尾状态

```
$ git -C build/elden-tree status --short          # 空
$ git -C build/elden-tree worktree list           # 无 /tmp/dwc3-v16
$ build-slot drop <id>                            # 构建槽位已释放
```

`/tmp/dwc3-v16`（worktree）与 `/tmp/kb-dwc3-v16`（`O=` 构建目录）在收尾时删除；`build/elden-tree` 未被改动。

## 4. 未做 / 边界

- **G7 真机**：未重做，理由 = 2/3・3/3 与 v15 逐字节同内容、1/3 只动 binding（无运行时影响）；
  cover 的 `Testing on hardware` 段照抄 v15（2026-11-25 那轮），未新增任何未测声明。
- **G8 `W=1` 编译**：未重跑（同上理由）。
- **未投递**：按 `TASKS/README.md` §7「按系列逐次批准」，等用户放行。
- **`dtbs_check` 未做全树**：只做 4 板 + 12 板对照（见 G6）；全树 `make CHECK_DTBS=y` 不在本轮时间面内。
