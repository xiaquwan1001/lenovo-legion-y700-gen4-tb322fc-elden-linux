# #471 · `dt-validate` 的**退出码恒为 0**（与第 470 条同类，但工具不同）

- 日期：2026-10-30（M3-1 v5 修复 lane 实测）
- 相关：#470（`make dt_binding_check` rc 恒 0）——本条是**独立工具**的同一个陷阱

## 现象

`dtschema/dtb_validate.py` 的 `main()` **没有 `sys.exit(...)`**，因此：

```bash
~/.local/opt/dtschema-venv/bin/dt-validate foo.dtb ; echo $?   # 永远是 0
```

即使输出几十行 `... is not of type 'object'` / `... is a required property` 也是 0。

## 后果（已发生的误判）

- `reports/m3-v5-recovery-20261030.md` §3.2 用「`dt-validate` rc=0 ⇒ 通过」推理，得出
  「binding 的 mux-state 互斥没被校验」这一结论 —— 实际是**误判**（schema 有牙）。
- 2026-10-30 复跑时我在板上镜像也用 `dtvalidate_rc=0` 判过 DTB，同样无效，只是当时靠
  「`compatible_errors=0`」旁证才没出事。

## 正确判据

① **只看诊断文本**：`| grep -c 'is not of type\|is a required property\|does not match'`，或看输出**是否为空**；
② 用例驱动：构造**正/反例** DTS（如 `dup1`/`dup0`/`nomuxprop`/`extraep`/`boardshape`），
   反例必须**报错文本**、正例必须**静默**，才算 binding 有牙；
③ 同一规则适用于 `dt-doc-validate`（本条未验证其退出码，用前先测）。

## 复现

```bash
cd build/m3v5-fix
V=~/.local/opt/dtschema-venv/bin
$V/dt-validate /tmp/bad.dtb ; echo "rc=$?"       # rc=0 但上面有报错
$V/dt-validate /tmp/good.dtb | wc -l             # 0 = 真通过
```

## 关联

- `reports/m3v5-fix-20261030.md` §5（5 例正/反向探针，全部按诊断文本判定）
- 与 `#470` 合并理解：**这一族工具的退出码都不能当门禁判据**，只能当「命令跑没跑完」
