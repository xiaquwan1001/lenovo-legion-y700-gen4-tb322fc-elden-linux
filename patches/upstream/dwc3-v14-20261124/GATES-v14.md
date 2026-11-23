# dwc3 v14 门禁账（2026-11-24，**已备料，未投递**）

> 为什么有 v14：sashiko 2026-11-23 11:29Z 对 v13 1/3 报了 3 条 [Low]（原文与逐条判别见
> `../../reports/upstream-recheck-20261124.md` §3）。三条**全部成立**，其中第 3 条是逻辑错误
> （两个端点缺 `mux-state` 时 `oneOf` 两分支同时匹配 ⇒ 必然失败）。⇒ 只重出 1/3，2/3、3/3 与 v13 逐字节相同。

## 0. 数字结论（本轮现跑）

| 门 | 命令形状 | 结果 |
|---|---|---|
| G0 基线 | `build/elden-tree` worktree @ `aebb727447` | = **v7.4-rc3**（与 v12/v13 同一基线） |
| G1 落树 | `git apply` ×3 + 生成 commit 后 `format-patch` | 3/3 干净；v14 六件 blob：**yaml `dcfa8c3a81c5`**（只有这一枚变了，见下）、class.c `ee186d542a`、core.c `ce30979286`、core.h `e6cf7b240b`、debugfs.c `82e7a334b1`、drd.c `906cac4f3e6e` —— 后五枚与 v11/v12/v13 逐个相同 |
| G2 checkpatch | `--strict --no-signoff --no-tree` ×3 | **0E/0W/0C**（116 / 63 / 624 行） |
| G2' 逐字节 | v14 2/3、3/3 的 `diff --git` 段 ↔ v13 | **相同**（仅 `index` 行缩写 10 vs 12 位不同，blob 哈希一致） |
| G4 `dt_binding_check` | `make -j26 ARCH=arm64 … dt_binding_check`（**不带** `DT_SCHEMA_FILES`） | **rc=0，0 条 schema 诊断**；`DTC [C]` 样例 **5420** 个；`snps,dwc3.example.dts` 编译通过 |
| G5 `dtbs_check` | `CHECK_DTBS=1` 四份 qcom dtb（sm8250-mtp/sm8650-mtp/sm8750-mtp/sm8750-qrd） | **4/4 `DTC [C]`，`^arch/.*dtb:` 诊断 0** |
| G6 正/负样例 | `dt-validate -s processed-schema.json`，**v14 与 v13 两套 schema 对照** | 正例 **5/5 零诊断**（含新增「两端点但无 mux」）；负例 **6/6 全被拒**，其中新增两例（mux 下的 plain `endpoint`、`endpoint@2`）在 **v13 schema 下不被拒** ⇒ 本轮补齐的正是这两处覆盖 |
| G7 上机 | — | 未做（本系列不声称 runtime 测试） |

**G6 对照矩阵（`logs/G6-samples.log` 原文）**

| 样例 | v13 schema | v14 schema | 期望 |
|---|---|---|---|
| `pos-v11` / `pos-no-dr-mode` / `pos-nonmux-endpoint` / `pos-nonmux-endpoint0` | 0 | 0 | 通过 |
| `nomux-two-endpoints`（新增正例：两端点、无 mux、无 role 属性） | **2 条诊断（误拒）** | **0** | 修好 sashiko 第 3 条 |
| `neg-same-state` / `neg-one-endpoint` / `neg-no-role-props` / `neg-dr-mode-host` | 2–3 | 2–3 | 被拒 |
| `neg-mux-plain-endpoint`（新增反例） | **0（漏拒）** | **2** | 修好 sashiko 第 2 条 |
| `neg-mux-endpoint2`（新增反例） | **0（漏拒）** | **2** | 同上 |

## 1. 三处改动（相对 v13 1/3）

1. `mux-controls:` 加 **`maxItems: 1`**（sashiko ①）。
2. `port@0` 的 **`mux-controls` 分支**内：`properties: endpoint: false` +
   `patternProperties: {'^endpoint@([2-9]|[1-9a-f][0-9a-f]+)$': false}` ⇒ mux 总线上只允许
   `endpoint@0`/`endpoint@1`（sashiko ②；单连接器形态完全不动，避免给上游既有树加严）。
3. 把「两端点 `mux-state` 必须相反」的 **`oneOf` 搬进 `then:`（有 mux）分支**，并删掉冗余的
   `dependentRequired` 与 else 分支的 `mux-controls: false`（sashiko ③）。

## 2. 复现命令

```sh
cd /home/xuqianhui/y700-elden
git -C build/elden-tree worktree add --detach /tmp/dwc3-v14 aebb727447
cd /tmp/dwc3-v14
for p in ../../patches/upstream/dwc3-v13-20261123/v13-000{1,2,3}-*.patch; do git apply "$p"; done
# 再按 §1 改 1/3 的 yaml（或直接取 v14-0001 的 diff 段）
make -j26 ARCH=arm64 O=/tmp/kb-dwc3-v14 defconfig
rm -f /tmp/kb-dwc3-v14/Documentation/devicetree/bindings/processed-schema.json
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v14 dt_binding_check
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v14 CHECK_DTBS=1 \
     qcom/sm8250-mtp.dtb qcom/sm8650-mtp.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
# G6：gates/*.dts 逐个 dtc → dt-validate -s processed-schema.json（对照组用 v13 patch 的树另出一套 schema）
```

## 3. 未做 / 边界

- **G3（`W=1` 编译）未重跑**：2/3、3/3 与 v13 逐字节相同，1/3 只动 binding ⇒ 编译面零变化。
- **未投递**：按 `TASKS/README.md` §7「按系列逐次批准」，等用户放行。投递命令与收件人见
  `../../patches/upstream/dwc3-v12-20261123/SENT.md`（同一套），只是文件名换成 `v14-000*.patch`。
- 临时 worktree `/tmp/dwc3-v14`、`/tmp/dwc3-v13ctl` 与两个 `O=` 构建目录**已在收尾时删除**（`git worktree list` 无残留）。
