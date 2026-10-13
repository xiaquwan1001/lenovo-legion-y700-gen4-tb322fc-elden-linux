# M4 camss 立项 — 已就绪补丁草案（2026-10-13）

面向上游投递的 **binding 草案**（M4-1 先行小件）。规则 = `reports/upstream-policy-20261013.md`；
拆解方案 = `reports/m4-camss-project-20261013.md`。

## 内容

| 文件 | 主题 | 覆盖 binding |
|---|---|---|
| `0001-gt9764.patch` | dt-bindings: media: i2c: add Giantec GT9764 camera lens actuator | `giantec,gt9764.yaml` |
| `0002-wl2868c.patch` | dt-bindings: regulator: add Will Semiconductor WL2868C PMIC | `willsemi,wl2868c.yaml` |
| `0003-s5kjns.patch` | dt-bindings: media: i2c: add Samsung S5KJNS image sensor | `samsung,s5kjns.yaml` |

每枚 = 新 binding + MAINTAINERS 新条目（新增文件必须随行 MAINTAINERS，否则 checkpatch 报 FILE_PATH_CHANGES）。

## 验证（全部通过）

```sh
K=build/m1-upstream/clean-tree-73
for f in patches/upstream/m4-camss-2026-10-13/*.patch; do
  (cd $K && perl scripts/checkpatch.pl --strict --no-tree "$OLDPWD/$f")
done
# 0001: 0 errors, 0 warnings, 0 checks, 83 lines checked → ready for submission
# 0002: 0 errors, 0 warnings, 0 checks, 79 lines checked → ready for submission
# 0003: 0 errors, 0 warnings, 0 checks, 132 lines checked → ready for submission

E=~/venv-dtschema/bin/dt-doc-validate
(cd $K && $E Documentation/devicetree/bindings/media/i2c/giantec,gt9764.yaml     )  # rc=0
(cd $K && $E Documentation/devicetree/bindings/regulator/willsemi,wl2868c.yaml   )  # rc=0
(cd $K && $E Documentation/devicetree/bindings/media/i2c/samsung,s5kjns.yaml     )  # rc=0

# 可应用于 pristine
git -C build/m1-rebase-worktree apply --check patches/upstream/m4-camss-2026-10-13/0001-gt9764.patch   # RC=0
```

## 未决

- MAINTAINERS 条目的 `M:` 为占位身份 `Elden Mainline Agent <elden-mainline@localhost>`，**投递前必须替换为真实维护者**（项目口径：凭据/身份属外部干预，须用户决定）。
- 本草案只含 binding + MAINTAINERS，**不含驱动**；对应驱动在 M4-1 系列（`drivers/media/i2c/*.c`、`drivers/regulator/wl2868c-regulator.c`）。
- 未做全量构建/上机验证（binding 只需 schema 校验）。
