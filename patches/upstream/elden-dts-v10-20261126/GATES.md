# v10 门禁账（2026-11-26 现跑，**未投递**）

> 基线 = `build/elden-tree` 的 detached worktree `aebb7274476403040d582c61478df8f4a7bf9cd3`
> = **Linux 7.4-rc3**（与 v8/v9 同一基线，可比）。
> 环境：aarch64-linux-gnu-gcc / dtc（内核自带）/ dt-doc-validate / perl / nproc=28；
> 构建槽位 `build-slot take y700-elden:elden-dts-v10 --jobs 8`（id `125018-1370009-…`），收工 `drop`。
> **未做上机**：板件没有 SPMI PMIC/RPMh/console 描述，上不了 shell ⇒ 本文件任何「通过」
> 都只指机械门，**不含启动**。

## 0. 数字结论

| 门 | 结果 |
|---|---|
| G0 `git apply --check -v` | 2/2 **rc=0**，**无 offset / 无 fuzz** |
| G1 落树 blob | `a32cfb30a1` / `e0b65a36c5` / `d8e9ab1272` = 两枚 patch 的 `index` 右值 |
| G2 `checkpatch.pl --strict --no-signoff` | 1/2 **0E/0W/0C**；2/2 **0E/1W/0C**（新文件 MAINTAINERS 提示，v7/v8/v9 同款） |
| G3 `dt_binding_check` 定向 `arm/qcom.yaml`（1/2 改了 binding） | **rc=0**，静默（CHKDT/LINT/STYLE 各一遍，无输出） |
| G4 `dt-doc-validate …/arm/qcom.yaml` | **rc=0** |
| G5 `dtbs_check CHECK_DTBS=1`（elden+mtp+qrd，**未**加 wl2868c binding） | rc=0，3/3 `DTC [C]`；诊断 **1 / 0 / 0**（唯一那条 = v9 同款「缺 schema」） |
| G6 同树 + `wl2868c-v12` 1/2（= for-7.5 的 `84e67d2ee13f`）重跑 G5 | rc=0，3/3 `DTC [C]`；诊断 **0 / 0 / 0** |
| G7 DTB md5 | elden `50f7cede…`（v9 `4707d3de…`）；mtp `ecc15876…` = v9 记录值不变 |
| G8 DTB 反编译 diff（v9 vs v10） | **只多 4 条 `vin*-supply`**，其余逐字节相同 |
| G9 `git am` 路线交叉验证 | 2/2 干净、提交日期 `2026-11-26 21:00:00 +0800`、DTB md5 与 G7 逐字节相同 |
| G10 上机 | **未做**（见头注） |
| G11 发信 | **未做**：`SEND.sh` 本目录**未执行**，其默认模式为本地检查 |

## 1. 复现命令

```sh
cd /home/xuqianhui/y700-elden/build/elden-tree
git worktree add --detach /tmp/v10check aebb72744764
P=/home/xuqianhui/y700-elden/patches/upstream/elden-dts-v10-20261126
cd /tmp/v10check

git apply --check -v $P/v10-0001-*.patch      # G0
git apply --check -v $P/v10-0002-*.patch
git apply $P/v10-0001-*.patch                 # G1
git apply $P/v10-0002-*.patch
git -c core.abbrev=10 hash-object Documentation/devicetree/bindings/arm/qcom.yaml \
        arch/arm64/boot/dts/qcom/Makefile arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts

# G2（必须 stdin，PITFALLS #725）
perl scripts/checkpatch.pl --no-tree --strict --no-signoff - < $P/v10-0001-*.patch
perl scripts/checkpatch.pl --no-tree --strict --no-signoff - < $P/v10-0002-*.patch

# G3/G4
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v10build defconfig
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v10build \
     DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom.yaml dt_binding_check
~/.local/bin/dt-doc-validate Documentation/devicetree/bindings/arm/qcom.yaml

# G5
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v10build CHECK_DTBS=1 \
     qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb

# G6：把 wl2868c binding（for-7.5 `84e67d2ee13f` 对应件）apply 进同一棵树再重跑
git apply \
  /home/xuqianhui/y700-elden/patches/upstream/wl2868c-v12-20261117/v12-0001-regulator-dt-bindings-willsemi-wl2868c-add-the-W.patch
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v10build CHECK_DTBS=1 \
     qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb

# G8：v9 同基线重编对照 + 反编译 diff
git worktree add --detach /tmp/v9dtb aebb72744764
cd /tmp/v9dtb && git apply $P/../elden-dts-v9-20261126/v9-0001-*.patch \
             && git apply $P/../elden-dts-v9-20261126/v9-0002-*.patch
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v9b defconfig
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v9b qcom/sm8750-lenovo-elden.dtb
/tmp/v9b/scripts/dtc/dtc -I dtb -O dts /tmp/v9b/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb -o /tmp/v9-dtb.dts
/tmp/v9b/scripts/dtc/dtc -I dtb -O dts /tmp/v10build/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb -o /tmp/v10-dtb.dts
diff -u /tmp/v9-dtb.dts /tmp/v10-dtb.dts

# G9：am 路线
git worktree add --detach /tmp/v10am aebb72744764
cd /tmp/v10am && git am --keep-cr $P/v10-0001-*.patch && git am --keep-cr $P/v10-0002-*.patch
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v10amb defconfig
make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v10amb qcom/sm8750-lenovo-elden.dtb
```

收尾（已按此清）：三个 worktree `remove --force`、`rm -rf /tmp/v10build /tmp/v10amb /tmp/v9b`、
`build-slot drop 125018-1370009-y700-elden_elden-dts-v10`。

## 2. 原始输出

### G0（`logs/apply-check-verbose-20261126.txt`，逐字）

```
### v10-0001-dt-bindings-arm-qcom-document-the-Lenovo-Legion-Y700.patch
正在检查补丁 Documentation/devicetree/bindings/arm/qcom.yaml...
rc=0
### v10-0002-arm64-dts-qcom-sm8750-lenovo-elden-add-Lenovo-Legion-Y700-Gen4.patch
正在检查补丁 arch/arm64/boot/dts/qcom/Makefile...
正在检查补丁 arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts...
rc=0
```

### G1（`logs/git-apply-blobs-20261126.txt`）

```
a32cfb30a1874f5e9facd251e6b756edd9d0ad71
e0b65a36c5b1fe836b1359860db4d69cb5392861
d8e9ab127236f3b2be9d2c0bdfec116eaa7ff9d5
```

### G2（`logs/checkpatch-v10.txt`，逐字）

```
== v10-0001  ==
total: 0 errors, 0 warnings, 0 checks, 7 lines checked

"[PATCH v10 1/2] dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4" has no obvious style problems and is ready for submission.
== v10-0002  ==
WARNING: added, moved or deleted file(s), does MAINTAINERS need updating?
#59: 
new file mode 100644

total: 0 errors, 1 warnings, 0 checks, 142 lines checked
```
（该 warning = 新文件常规提示，`ARM/QUALCOMM SUPPORT` 已覆盖 `arch/arm64/boot/dts/qcom/`，不修；
v7/v8/v9 同款，见 `../elden-dts-v9-20261126/GATES.md` G3。）

### G3/G4（`logs/dt-binding-check-qcomyaml-20261126.log`）

```
make[1]: 进入目录“/tmp/v10build”
  CHKDT   /tmp/v10check/Documentation/devicetree/bindings
  LINT    /tmp/v10check/Documentation/devicetree/bindings
  STYLE   /tmp/v10check/Documentation/devicetree/bindings
make[1]: 离开目录“/tmp/v10build”
```
`dt-doc-validate` rc=0，无输出。

### G5（`logs/dtbs-check-3dtb-no-binding-20261126.log`）

```
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb: /soc@0/geniqup@8c0000/i2c@888000/pmic@2f: failed to match any schema with compatible: ['willsemi,wl2868c']
```
（这一条是 v9 已记的、等 binding 的那条，措辞逐字相同；boost 顺序里 rc=0。）

### G6（`logs/dtbs-check-3dtb-with-wl2868c-binding-20261126.log`）

```
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
```
**无任何诊断行** ⇒ 新增 4 条 supply 属性被 binding 接受（binding 是
`additionalProperties: false` + `regulators` 子节点 `additionalProperties: false`，
拼错/多余属性会报 "Additional properties are not allowed"）⇒ **属性名与 merged binding 逐字一致**是被这条门证过的。

### G7（`logs/dtb-md5-20261126.txt`）

```
apply 路线（/tmp/v10build，G5/G6）：
50f7cede1d01a45f9c1eb647b4577cc4  arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
ecc158767f04c8facf5fde6735b339da  arch/arm64/boot/dts/qcom/sm8750-mtp.dtb

am 路线（/tmp/v10amb，G9）：
50f7cede1d01a45f9c1eb647b4577cc4  arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb

v9 记录值（对照）：4707d3defd057e70e3aa5216320ac777 / ecc158767f04c8facf5fde6735b339da
v9 复现（/tmp/v9b，本机重编同基线同补丁）：4707d3defd057e70e3aa5216320ac777
```
（v9 值本机重编复现成功 ⇒ 「只差预期改动」这个比较是同一工具链下的比较。）

### G8（`logs/dtb-decompile-diff-v9-vs-v10.txt`，去掉 dtc 对 sm8750.dtsi 的既有告警后）

```
--- /tmp/v9-dtb.dts
+++ /tmp/v10-dtb.dts
@@ -794,6 +794,10 @@
 					reset-gpios = <0x36 0x7e 0x01>;
 					pinctrl-names = "default";
 					pinctrl-0 = <0x37>;
+					vin12-supply = <0x38>;
+					vin34-supply = <0x38>;
+					vin5-supply = <0x38>;
+					vin7-supply = <0x38>;
 					vsys-supply = <0x38>;
```
（`0x38` = `wl2868c_vsys` 的 phandle，与 `vsys-supply` 同源；注释不进 DTB；
dtc 反编译对 `sm8750.dtsi` 的 18 条既有告警两版完全相同，不属本次改动。）

### G9（`logs/am-apply-20261126.txt`）

```
应用：dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4
应用：arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet
44c4370eb3d4 2026-11-26 21:00:00 +0800 arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet
ee467f16e0a5 2026-11-26 21:00:00 +0800 dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4
defconfig rc=0
  DTC     arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
build rc=0
50f7cede1d01a45f9c1eb647b4577cc4  arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
```

## 3. 未做的门（写明理由）

- **全量 `dt_binding_check`**：本轮 1/2 与 v9 1/2 逐字节相同（只有代次变），
  v9 已跑全量（rc=0，5420 `DTC [C]`，0 error/warn，见 `../elden-dts-v9-20261126/logs/dt-binding-check-full-20261126.log`）；
  2/2 不动 binding ⇒ 只跑定向 `arm/qcom.yaml`（G3）。若编排者要求，可原样重跑全量。
- **上机**：见头注。
- **发信**：`SEND.sh` 未执行（包含 `--dry-run` 也未跑，避免任何 SMTP 触点）。

## 12. 父代理复核后的两处修订（2026-11-26 晚，**同轮重跑**）

### 12.1 措辞：把「同一轨」的硬件推断降级为显式 stand-in

原稿提交信息与 DTS 注释写成「The camera PMIC is fed from the always-on system rail … VIN12/34/5/7 feed the LDOs」——
那是**推断**（`reports/elden-v10-vin-supply-20261126.md` §6-1/§6-2 自己写明：无原理图、VIN12 输入上限未知），
补丁正文却按事实陈述。已改为：

- 提交信息：`The camera PMIC has five inputs on this board: VSYS … and VIN12, VIN34, VIN5 and VIN7, which feed the LDOs in use. The SPMI PMICs that generate those rails are not described yet, so all five are modelled as one always-on fixed regulator standing in for them; the board's actual input wiring is not documented in the sources this file was derived from.`
- DTS 注释同义改写（不再断言板上实际连线）。

上游读者据此不会被误导；我们仍保留「五条 supply 指向同一 placeholder」的功能等价建模。

### 12.2 修正一个真缺陷：hunk 计数与正文不符（135 → 136）

改措辞时正文多出 1 行，但 `@@ -0,0 +1,135 @@` 未同步 ⇒ **`git apply` 会把文件末尾的 `};` 吃掉**，
`dtc` 报 `syntax error`（我在 `/tmp/v10check` 复现：`135.4-136.1 syntax error`）。
已把计数改为 `+1,136`，重跑：`git apply` 2/2 干净、`wc -l` = 136、文件末尾 `};` 完整。

### 12.3 修订后重跑（父代理跑的，原始输出）

| 门 | 结果 |
|---|---|
| G0 `git apply`（新 worktree `aebb72744764`） | **2/2 干净**（无 offset/fuzz） |
| G2 checkpatch（stdin 法） | 1/2 **0E/0W/0C**；2/2 **0E/1W/0C**（MAINTAINERS 提示，同前） |
| G7' DTB md5（只重编 elden dtb） | **`50f7cede1d01a45f9c1eb647b4577cc4` = 与修订前 G7 逐字节相同** ⇒ 改动纯注释/措辞，DTB 未变（因此 G5/G6 的 `dtbs_check` 结论对本次修订继续成立，未重跑） |

> 附带一条工具事实：`git worktree add /tmp/v10check` 在 `/tmp` 被清空后会留下「丢失但已注册」的
> worktree，必须 `git worktree prune` 才能重建（否则 `fatal: 是一个丢失但已经注册的工作区`）。
