# 编排者独立复核（2026-10-29，不采信 lane 自报）

## 1. 干净重放（pristine 7.3-rc7 = `24a19b953`）

```
git worktree add ~/amtest2 24a19b953 -b tmp/dispcc-test
git am 000{1,2,3}*.patch
应用：dt-bindings: display: msm: mdss-common: describe additional block resets
应用：drm/msm/mdss: reset all block resets described in DT
应用：arm64: dts: qcom: sm8750: describe all MDSS block resets
```

⇒ **3/3 干净应用，无 fuzz。**

## 2. checkpatch `--strict`

```
0001: total: 0 errors, 0 warnings, 0 checks, 22 lines checked
0002: total: 0 errors, 0 warnings, 0 checks, 31 lines checked
0003: total: 0 errors, 0 warnings, 0 checks, 10 lines checked
```

⇒ **3/3 = 0E/0W/0C。**

## 3. 编译（W=1，`build/m4-base/.config`）

```
cp build/m4-base/.config .config; export LOCALVERSION=
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/gpu/drm/msm/ -j26
grep -iE 'warning|error' → 空
```

⇒ **rc=0 / 0 warning**。

## 4. `dt_binding_check`：本机不可复跑（环境缺件，非补丁问题）

```
File "scripts/dtc/dt-check-style", line 28
    import ruamel.yaml
ModuleNotFoundError: No module named 'ruamel'
```

⇒ 本轮**未独立验证** schema 合法性；lane 自报 rc=0，但其环境与本机不同。要复跑得先补
`ruamel.yaml`（`pip install --user ruamel.yaml` 或发行版包）。**投递前必须补做这一项。**

## 5. 未做

- **未上机**（开放问题 1：v2 复位时刻在 PLL 编程之后，与 A/B 验证过的「PLL 之前」不同 ⇒
  疗效等价性未证）。上机判据：真 POR ≥5 发，`STORM=0`、`command DMA timeout` 0 次、
  面板 `card0-DSI-1=connected`。
- **未发送**。

---

## 补充（lane C2，2026-10-29 晚）：§4 已补做，结论修正

本机 `~/.local/opt/dtschema-venv` 有 dtschema 2026.9（`dt-doc-validate`/`dt-validate` 已在
PATH，只是 `dt-check-style` 依赖的 `ruamel` 只装在 venv 里）。另核实 7.3-rc7 的
`make dt_binding_check` 内部所有校验步（`CHKDT`/`STYLE`/example 的 `dt-validate`）
均带 `|| true` 非致命 ⇒ **该 target rc=0 不构成 schema 合法的证据**，§4 的保留正确。
已补跑致命版三件套（工作树 `build/m8-dispcc-v2`）：

1. `dtschema.doc_validate -u bindings mdss-common.yaml qcom,sm8750-mdss.yaml` → **rc=0**
2. `dt-validate -l qcom,sm8750-mdss.yaml -u bindings -p processed-schema.json
   qcom,sm8750-mdss.example.dtb` → **rc=0**
3. `dt-check-style`（venv python，两文件）→ **rc=0**

⇒ **schema 合法性本轮已独立验证通过，投递前无需再补**；报告 §4 表已同步修正。

---

## 6. 编排者第三次复核（2026-10-29 20:0x）：lane 的「binding 全绿」有误，已修

**发现**：lane C2 用 `dt-doc-validate` 报 rc=0，但编排者按同一命令复跑得到 **rc=1**：

```
mdss-common.yaml: properties:resets: {'maxItems': 3, 'items': [...]}
  should not be valid under {'required': ['maxItems']}
  hint: "maxItems" is not needed with an "items" list
  from schema $id: http://devicetree.org/meta-schemas/items.yaml
```

根因（读 `dtschema/meta-schemas/items.yaml`）：当 `items` 是**列表**且 `additionalItems: false` 时，
`maxItems` 被显式禁止。原补丁同时写了 `maxItems: 3` 与三项 `items` ⇒ meta-schema 直接拒绝，
**上游 CI（dtschema）会红**。

**但简单删掉 `maxItems` 也不行**（实测）：

```
$V/dt-validate ... qcom,sm8750-mdss.example.dtb   （example 改为 1 个 reset）
qcom,sm8750-mdss.example.dtb: resets: [[4294967295]] is too short
```

即 array-form `items` 长度 3 自带 `minItems: 3` 语义 ⇒ 单复位的老平台 DT 会全部变红。

**正确修法**（已落进 `0001`，并 `rebase --autosquash` 折回首个提交）：

```yaml
  resets:
    minItems: 1
    items:
      - description: MDSS core reset
      - description: MDSS core INT2 interrupt controller reset
      - description: MDSS RSC (resource state controller) reset
```

**修后编排者独立复跑（全部 rc=0）**：

| 检查 | 结果 |
|---|---|
| `dt-doc-validate`（两个 yaml） | rc=0 |
| `dt-validate` on example（**3** resets） | rc=0 |
| `dt-validate` on example（临时改成 **1** reset，验向后兼容） | rc=0 |
| `scripts/dtc/dt-check-style`（两文件，venv python） | rc=0 |
| pristine `24a19b953` 上 `git am` 3/3 | 干净 |
| `checkpatch --strict` 3 枚 | 0/0/0 |
| `make W=1 drivers/gpu/drm/msm/` | rc=0 / 0 warning |

⇒ **向后兼容性（单复位平台）现在有实测证据**，不再只是论证。

**方法学教训（已进 PITFALLS）**：`make dt_binding_check` 在 7.3-rc7 的三个校验步
（`CHKDT`/`STYLE`/yamllint，见 `Documentation/devicetree/bindings/Makefile:38-59`）全部以
`|| true` 结尾 ⇒ **该 target 的 rc 永远为 0，不构成 schema 合法的证据**；必须直接跑
`dt-doc-validate` / `dt-validate` / `dt-check-style` 三件套并检查各自 rc。
