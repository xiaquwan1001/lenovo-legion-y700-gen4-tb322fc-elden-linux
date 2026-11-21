# dwc3 v11 门禁账（2026-11-21，**SENT-ready，未投递**）

> 本文件 = v11 的门链实测。命令与输出**原文照抄**（日志在同目录 `logs/`，均由本轮现跑生成）。
> 门编号沿用 v10（`../../reports/dwc3-v10-plan-20261120.md` 的 G1–G7），数字全部本轮实测。
> 与 v10 的差异只有三处代码改动（见 `MANIFEST.md` §2），所以门链形状不变。

## 0. 数字结论

| 门 | 命令形状 | 结果 |
|---|---|---|
| G0 基线 | `build/elden-tree` @ `aebb727447` | = **v7.4-rc3**（与 v10 声明基线同一 commit） |
| G1 落树 | `git apply --check` + `git apply` ×3（pristine worktree） | **3/3 干净，rc=0，无 offset/fuzz**；落树后 blob：yaml `7a9cb5a115a6`、drd.c `906cac4f3e6e`、core.c `ce30979286`、core.h `e6cf7b240b`、debugfs.c `82e7a334b1`、roles/class.c `ee186d542a` |
| G2 checkpatch | `--strict --no-signoff --no-tree` ×3 | 1/3 **0E/0W/0C（115 行）** · 2/3 **0E/0W/0C（63）** · 3/3 **0E/0W/0C（624）** |
| G3 `W=1` 编译 | `ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=1 drivers/usb/dwc3/ drivers/usb/roles/` | **rc=0，0 warning / 0 error**，22 个 `.o`（dwc3 21 + roles 1） |
| G4 `dt_binding_check` | **不带** `DT_SCHEMA_FILES`（全量 schema） | **rc=0，0 条 schema 诊断**；`DTC [C]` 样例 5420 个 |
| G5 `dtbs_check` | `CHECK_DTBS=1`（**不带** `DT_SCHEMA_FILES`）4 份 qcom dtb | 补丁树 **4/4 `DTC [C]`，`^arch/.*dtb:` 诊断 0**；同四份 **baseline 树 4/4、0** ⇒ **新增 0** |
| G6 正/负样例 | `dt-validate -s processed-schema.json` | 正样例 **4/4 全 0 诊断**（含「省略 `dr_mode`」「非 mux 的 `port@0/endpoint`」「非 mux 的 `endpoint@0`」）；负样例 **4/4 全被拒**。**对照**：同一批 dtb 喂 v10-as-sent 的 schema ⇒ 2 个正样例被拒（= sashiko 两条 Medium/Low 的复现） |
| G7 上机 | — | **未做**（cover 明写 "No runtime testing is claimed"） |

## 1. 环境与边界（先说清哪些门换了形状）

- **本轮不执行任何 `git commit`/`git am`**（会话硬纪律）。因此 G1 用
  `git apply --check` + `git apply` 在 `build/elden-tree` 的 pristine worktree
  `/tmp/dwc3-v11-base`（`aebb727447`）上落树，并以 **blob 哈希**代替「commit 树哈希」作为逐字节判据。
  `git am` 只多做一件事（把 patch 变成 commit），对 patch 内容的解析能力可由
  `git mailinfo` 单独验证（见 §2 G1）。
- **零设备**：无 adb/fastboot/ssh/qdl；G7 未做。
- 二进制工具：`dtc /usr/bin/dtc`、`dt-validate 2026.9`（`~/.local/bin/dt-validate`）、
  `aarch64-linux-gnu-gcc 15.2.0`。

## 2. 复现命令（逐条可直接跑）

```sh
cd /home/xuqianhui/y700-elden
git -C build/elden-tree worktree add --detach /tmp/dwc3-v11-base aebb727447
cd /tmp/dwc3-v11-base

# ---- G1：三枚按序落树 + 结果 blob
for p in ../../patches/upstream/dwc3-v11-20261121/v11-000{1,2,3}-*.patch; do
  git apply --check -v "$p" && git apply "$p"
done
git hash-object Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml \
                drivers/usb/dwc3/{drd.c,core.c,core.h,debugfs.c} drivers/usb/roles/class.c
# mailinfo 只验「这枚 patch 能不能被 git 的 mail 解析器读成 commit」（不落 commit）
for p in v11-000{1,2,3}-*.patch; do git mailinfo /tmp/mi-msg /tmp/mi-patch < "$p"; done
```

```
（G1 输出原文，`/tmp/v11-logs/G1-apply.log`）
正在检查补丁 Documentation/devicetree/bindings/usb/snps,dwc3-common.yaml...
applied v11-0001-dt-bindings-usb-snps-dwc3-describe-two-connectors-on.patch
正在检查补丁 drivers/usb/roles/class.c...
applied v11-0002-usb-roles-look-up-role-switches-attached-to-a-graph-endpoint.patch
正在检查补丁 drivers/usb/dwc3/debugfs.c...
applied v11-0003-usb-dwc3-select-the-shared-HS-data-bus-with-a-mux-controller.patch
7a9cb5a115a63286cf001d232904ad5bbd81dc2a   snps,dwc3-common.yaml
906cac4f3e6e5ac2816fd3611682e40127491edf   drivers/usb/dwc3/drd.c
ce309792864b3aa6ba89cffd3e58710ed3c6384e   drivers/usb/dwc3/core.c
e6cf7b240b23eab7d2c1059d5f3a355216653f65   drivers/usb/dwc3/core.h
82e7a334b135821c92921c320ee5a09ec31a0ab4   drivers/usb/dwc3/debugfs.c
ee186d542a1018237d10cc664699fe67096163e5   drivers/usb/roles/class.c
```

```sh
# ---- G2
for p in /home/xuqianhui/y700-elden/patches/upstream/dwc3-v11-20261121/v11-000{1,2,3}-*.patch; do
  perl scripts/checkpatch.pl --strict --no-signoff --no-tree "$p"
done
```

```
（G2 输出原文，`/tmp/v11-logs/G2-checkpatch.log`）
total: 0 errors, 0 warnings, 0 checks, 115 lines checked
…/v11-0001-…patch has no obvious style problems and is ready for submission.
total: 0 errors, 0 warnings, 0 checks, 63 lines checked
…/v11-0002-…patch has no obvious style problems and is ready for submission.
total: 0 errors, 0 warnings, 0 checks, 624 lines checked
…/v11-0003-…patch has no obvious style problems and is ready for submission.
```

```sh
# ---- G3（CONFIG_MULTIPLEXER / USB_ROLE_SWITCH 必须 =y，否则 drd.c 的 mux 代码被 #if 掉 ⇒ 门等于没跑）
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v11 defconfig
./scripts/config --file /tmp/kb-dwc3-v11/.config -e MULTIPLEXER -e USB_ROLE_SWITCH \
     -e USB_DWC3 -e USB_DWC3_DUAL_ROLE -e USB_DWC3_QCOM -e USB_GADGET -e FTRACE -e DEBUG_FS
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v11 olddefconfig
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v11 W=1 \
     drivers/usb/dwc3/ drivers/usb/roles/
```

```
（G3 输出原文节选，`/tmp/v11-logs/G3-W1-build.log`，全文 153 行）
  CC      drivers/usb/dwc3/core.o
  CC      drivers/usb/dwc3/trace.o
  CC      drivers/usb/roles/class.o
  CC      drivers/usb/dwc3/drd.o
  CC      drivers/usb/dwc3/dwc3-qcom.o
  …
  AR      drivers/usb/roles/built-in.a
  AR      drivers/usb/dwc3/built-in.a
rc=0   warning/error 行数=0   dwc3/*.o=21  roles/*.o=1
drivers/usb/dwc3/core.o: ELF 64-bit LSB relocatable
drivers/usb/dwc3/drd.o:  ELF 64-bit LSB relocatable
$ nm drivers/usb/dwc3/drd.o | grep dwc3_role_mux
00000000000000e0 t dwc3_role_mux_exit.isra.0
0000000000000180 t dwc3_role_mux_init
（dwc3_role_mux_deselect 被内联，无独立符号 ⇒ 用源码 + 两个非内联符号确认 mux 代码确实编进去）
```

```sh
# ---- G4（先删旧 bundle，否则读到上一版 schema）
rm -f /tmp/kb-dwc3-v11/Documentation/devicetree/bindings/processed-schema.json
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v11 dt_binding_check
```

```
（G4 输出原文，`/tmp/v11-logs/G4-dt-binding-check.log`，880 KB）
  SCHEMA  Documentation/devicetree/bindings/processed-schema.json
  DTC [C] Documentation/devicetree/bindings/…  （共 5420 行 DTC [C]）
make[1]: 离开目录“/tmp/kb-dwc3-v11”
rc=0   含 "from schema" 的诊断行=0   含 "warning:"/"Warning" 的行=0
```

```sh
# ---- G5 补丁树（baseline 对照另建 /tmp/kb-dwc3-v11-base @ aebb727447 + 独立 O=）
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/kb-dwc3-v11 CHECK_DTBS=1 \
     qcom/sm8250-mtp.dtb qcom/sm8650-mtp.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
```

```
（G5 输出原文，`/tmp/v11-logs/G5-dtbs-check.log`）
  DTC [C] arch/arm64/boot/dts/qcom/sm8650-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8250-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
rc=0   DTC [C]=4   ^arch/.*dtb: 诊断=0
```

```
（G5 baseline 对照原文，`/tmp/v11-logs/G5-baseline-control.log`）
  SCHEMA  Documentation/devicetree/bindings/processed-schema.json
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8250-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8650-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
rc=0   DTC [C]=4   ^arch/.*dtb: 诊断=0     ⇒ 新增 0
```

```sh
# ---- G6（样例在同目录 gates/，dtc 现编）
cd /home/xuqianhui/y700-elden/patches/upstream/dwc3-v11-20261121/gates
for f in *.dts; do dtc -I dts -O dtb -o ${f%.dts}.dtb $f; done
S=/tmp/kb-dwc3-v11/Documentation/devicetree/bindings/processed-schema.json
for f in pos-* neg-*; do dt-validate -s $S ${f%.dtb}.dtb; done
```

```
（G6 输出原文，`/tmp/v11-logs/G6-dt-validate-samples.log`）
===== dt-validate -s v11-schema pos-v11.dtb
（无诊断）
===== dt-validate -s v11-schema pos-no-dr-mode.dtb      # dr_mode 省略，靠 usb-drd.yaml 默认 otg
（无诊断）
===== dt-validate -s v11-schema pos-nonmux-endpoint.dtb # 单口、无 mux、port@0/endpoint（不带 reg）
（无诊断）
===== dt-validate -s v11-schema pos-nonmux-endpoint0.dtb # 单口、无 mux、port@0/endpoint@0（无 role 属性）
（无诊断）
===== dt-validate -s v11-schema neg-same-state.dtb
neg-same-state.dtb: usb@a600000 (snps,dwc3): ports:port@0: 'oneOf' conditional failed, one must be fixed:
	1 was expected
	from schema $id: http://devicetree.org/schemas/usb/snps,dwc3.yaml
neg-same-state.dtb: usb@a600000 (snps,dwc3): Unevaluated properties are not allowed ('dr_mode', 'mux-controls', 'ports', 'usb-role-switch' were unexpected)
	from schema $id: http://devicetree.org/schemas/usb/snps,dwc3.yaml
===== dt-validate -s v11-schema neg-one-endpoint.dtb
neg-one-endpoint.dtb: usb@a600000 (snps,dwc3): ports:port@0: 'endpoint@1' is a required property
	from schema $id: http://devicetree.org/schemas/usb/snps,dwc3.yaml
neg-one-endpoint.dtb: usb@a600000 (snps,dwc3): Unevaluated properties are not allowed ('dr_mode', 'mux-controls', 'ports', 'usb-role-switch' were unexpected)
	from schema $id: http://devicetree.org/schemas/usb/snps,dwc3.yaml
===== dt-validate -s v11-schema neg-no-role-props.dtb
neg-no-role-props.dtb: usb@a600000 (snps,dwc3): ports:port@0:endpoint@1: 'usb-role-switch' is a required property
	from schema $id: http://devicetree.org/schemas/usb/snps,dwc3.yaml
neg-no-role-props.dtb: usb@a600000 (snps,dwc3): ports:port@0:endpoint@1: 'mux-state' is a required property
	from schema $id: http://devicetree.org/schemas/usb/snps,dwc3.yaml
===== dt-validate -s v11-schema neg-dr-mode-host.dtb
neg-dr-mode-host.dtb: usb@a600000 (snps,dwc3): dr_mode:0: 'otg' was expected
	from schema $id: http://devicetree.org/schemas/usb/snps,dwc3.yaml

（按 "from schema" 计数：pos-* 4/4 = 0 条；neg-same-state=2、neg-one-endpoint=2、
  neg-no-role-props=3、neg-dr-mode-host=2 条 ⇒ 4/4 被拒）
```

```
（G6 对照：把同一批 dtb 喂 **v10-as-sent** 的 schema bundle，
  `/tmp/v11-logs/G6-v10sent-control.log`；schema 来自 `/tmp/dwc3-am-20261121`
  = 实际投出的 v10 内容，yaml blob 57e3c1d9ed03）
pos-v11.dtb            diag=0
pos-no-dr-mode.dtb     diag=2  ← 'dr_mode' is a required property（sashiko Low #2 复现）
pos-nonmux-endpoint.dtb  diag=0
pos-nonmux-endpoint0.dtb diag=3 ← endpoint@0 缺 usb-role-switch/mux-state（sashiko Medium #2 复现）
```

## 3. 门形状的三个坑（本轮再次确认）

1. **`DT_SCHEMA_FILES` 对公共片段恒空转**：`scripts/Makefile.dtbs` 传 `dt-validate -l`，
   只保留 `$id` 命中**且自己 `select` 到节点**的 schema；`snps,dwc3-common.yaml` 是没有
   `select:` 的片段 ⇒ 零诊断的「假绿」。本轮 G5 用**不带** `DT_SCHEMA_FILES` 的形状 + baseline 对照。
2. **`cmd_dtb_check` 末尾 `|| true`** ⇒ rc 恒 0；判绿只能数输出里的 `^arch/.*dtb:` 诊断行。
3. **`dt-validate` 的自有退出码也不可信**（本轮新测）：负样例明确报错，`rc` 仍是 **0**
   （`timeout … dt-validate -s $S neg-same-state.dtb; echo $?` → `0`）。判据只能是输出里
   `from schema $id:` 的行数，不能看 rc。这条与 v10 GATES §2 的「镜片」互补。

## 4. 跑不了 / 未跑的门（以及上机要验什么）

| 门 | 状态 | 为什么跑不了 | 上机要验什么 |
|---|---|---|---|
| G7 运行期 mux 切换 | **未跑** | 硬纪律禁 adb/fastboot/ssh；且板级 DTS（0004）不在本次投递内、`sm8750-lenovo-elden.dts` 未上游 | ① 插 A 口出 host/gadget、拔插 B 口后 HS 线真的切过去（`debugfs` 的 mux 计数 + `dmesg` 的 `failed to select USB port`）；② 同角色换口（host→host）必须重建实例（`dwc3_enable_susphy(false)` + `dwc3_set_prtcap`）；③ unbind 时 `mux_control_deselect()` 之后 mux 回到 idle（示波器看 select 线电平）；④ `dwc3_drd_exit()` 的 deselect 现在在 teardown 之后：unbind 期间不能出现「实例还在跑、线已被切走」的窗口（kprobe `mux_control_deselect` vs `dwc3_host_exit` 次序） |
| `dtbs_check` 覆盖 `idle-state` | **结构上不可能** | `gpio-mux.yaml` 的 `idle-state` 无 `type`/边界 ⇒ 越界值 0 诊断（`PITFALLS #696` 追加条） | 上机看 select 线在 deselect 后的电平 |
| 真板 DTS 的 `dtbs_check` | **未跑** | 板件 DTS 不在本系列（见 cover「Known gaps」） | 随板件系列一起跑 |

## 5. 待放行（不改代码即可发）

1. **用户放行**（`TASKS/README.md` §7：按系列逐次批准）。
2. `git send-email --dry-run` 一次：收件人沿用 v10 = Thinh Nguyen / linux-usb（To）；
   robh / krzk+dt / conor+dt / gregkh / linux-devicetree / linux-arm-msm / lkml（Cc）。
3. 线程：`--in-reply-to='<20261121022104.1507987-1-xiaqinghuan@mail.ustc.edu.cn>'`（v10 cover）。
4. `v11-0001`/`v11-0003` 顶部的 `From 0000…` 行是占位（内容改过，v10 的 commit hash 已不对应）；
   放行时由 `git am` 重新成 commit 后 `git format-patch` 现生成，会填真 hash。
5. 0004（板 DTS，GPIO 29 + 双 endpoint）继续 hold。
