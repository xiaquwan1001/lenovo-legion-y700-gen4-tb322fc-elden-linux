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
