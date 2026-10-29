# #470 `make dt_binding_check` 的 rc 恒为 0，不能当 schema 合法的证据

## 结论（2026-10-29 实测）

- `make dt_binding_check` 在 7.3-rc7 里的三个校验步全部以 `|| true` 结尾
  （`Documentation/devicetree/bindings/Makefile:38-59`）：
  - `quiet_cmd_yamllint` → `... && touch $@ || true`
  - `quiet_cmd_chk_bindings`（`CHKDT`，即 `dt-doc-validate -u`）→ `... && touch $@ || true`
  - `quiet_cmd_chk_style`（`STYLE`，即 `dt-check-style`）→ `... && touch $@ || true`
  ⇒ **target 的退出码永远 0**，schema 写错也照样"通过"。
- 实测翻车：lane 用 `dt-doc-validate` 报 rc=0，编排者同一命令复跑得 **rc=1**：
  ```
  mdss-common.yaml: properties:resets: {'maxItems': 3, 'items': [...]}
    should not be valid under {'required': ['maxItems']}
    hint: "maxItems" is not needed with an "items" list
  ```

## 定式

① 判 binding 合法性**只认三件套各自的 rc**，不认 `make dt_binding_check`：
```sh
V=~/.local/opt/dtschema-venv/bin
$V/dt-doc-validate -u Documentation/devicetree/bindings <file1>.yaml <file2>.yaml
$V/dt-validate -l <binding>.yaml -u Documentation/devicetree/bindings \
               -p Documentation/devicetree/bindings/processed-schema.json <binding>.example.dtb
$V/python scripts/dtc/dt-check-style <file1>.yaml <file2>.yaml
```
（`processed-schema.json` 用 `make PYTHON3=$V/python dt_binding_schemas` 生成；
`dt-check-style` 依赖 venv 里的 `ruamel.yaml`，系统 python3 没有。）

② **array-form `items` 的两条 meta 规则**（`dtschema/meta-schemas/items.yaml`）：
- `items` 是列表时**禁止**再写 `maxItems`（写了直接红）；
- `items` 列表长度 ≥2 时**自带 `minItems: len` 语义** ⇒ 只写 1 项的旧 DT 会报
  `resets: [[...]] is too short`。要向后兼容必须显式 `minItems: 1`。

③ 兼容性要**实测**而不是论证：把 example 临时改成 1 项重新生成 `.example.dtb` 再 `dt-validate`，
两条都 rc=0 才算数（本机做过，见 `patches/upstream/q28-dispcc-v2-20261029/GATES.md` §6）。

## 关联

- `patches/upstream/q28-dispcc-v2-20261029/`（M8 v2，首个踩到这个坑的补丁集）
- `GATES.md` §6 有完整命令与修前/修后的输出
