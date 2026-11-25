# v9 门禁账（2026-11-26 现跑，**未投递**）

> 基线 = `build/elden-tree` 的 detached worktree `aebb7274476403040d582c61478df8f4a7bf9cd3`
> = **Linux 7.4-rc3**（与 v8 同一基线，可比）。
> 环境：aarch64-linux-gnu-gcc 15.2.0 / dtc 1.7.2-g53373d13（内核自带）/ dt-doc-validate 2026.9 /
> yamllint 1.38.0 / ruamel.yaml 0.19.1 / perl 5.40.1 / nproc=28。
> **未做上机**：板件未在真机跑过 v7.4-rc3（没有 SPMI PMIC/RPMh/console 描述，上不了 shell）⇒
> 本文件任何「通过」都只指机械门，**不含启动**。

## 0. 数字结论

| 门 | 结果 |
|---|---|
| G0 `git apply --check -v` | 2/2 rc=0，**无 offset / 无 fuzz** |
| G1 落树 blob | `a32cfb30a1` / `e0b65a36c5` / `73f4452f46` = patch `index` 右值（= v8 记录值） |
| G2 与 v8 diff 段 | `cmp` **相同**（1/2 `8f1d00e2b9f5cfc4…`、2/2 `02df60f48c782954…` sha256 前缀） |
| G3 checkpatch `--strict` | 1/2 **0E/0W/0C**；2/2 **0E/1W/0C**（新文件 MAINTAINERS 提示） |
| G4 `dt_binding_check` 全量 | **rc=0**，`DTC [C]` **5420**，0 error / 0 warning |
| G5 `dt_binding_check` 定向 `arm/qcom.yaml` | **rc=0**，静默 |
| G6 `dt-doc-validate …/arm/qcom.yaml` | **rc=0**，无输出 |
| G7 `dtbs_check` elden+mtp+qrd | 3/3 `DTC [C]`；诊断 **1 / 0 / 0** |
| G8 同树 + `wl2868c-v12` 1/2（binding）重跑 G7 | elden 诊断 **0** ⇒ 「等 binding」是实测 |
| G9 上机 | **未做**（见头注） |
| G10 本地发信前断言 | `bash SEND.sh`（local 模式，不连 SMTP） | **rc=0**，六段断言 + 「Waiting on bindings 在前 30 行」全中（第 12 行）；`--dry-run` 另跑：3 封全 `Result: OK` | `logs/local-checks-20261126.txt`、`logs/dry-run-20261126-065602.txt` |
| G11 `git am` 路线交叉验证 | 另起 worktree `git am --keep-cr` 两枚 + defconfig + 编单 dtb | `git am` **2/2 干净**；提交日期 = `2026-11-26 21:00:00 +0800`；DTB md5 **`4707d3de…` 与 G7 逐字节相同** | `logs/am-apply-and-build-20261126.txt` |

## 1. 复现命令（一次性 worktree + 一次性 `O=`，跑完可删）

```sh
cd /home/xuqianhui/y700-elden/build/elden-tree
timeout -k 5 120 git worktree add --detach /tmp/v9wt aebb727447

P=/home/xuqianhui/y700-elden/patches/upstream/elden-dts-v9-20261126
cd /tmp/v9wt
timeout -k 5 60 git apply --check -v $P/v9-0001-*.patch     # G0
timeout -k 5 60 git apply --check -v $P/v9-0002-*.patch
timeout -k 5 60 git apply $P/v9-0001-*.patch                # G1
timeout -k 5 60 git apply $P/v9-0002-*.patch
git hash-object Documentation/devicetree/bindings/arm/qcom.yaml \
                arch/arm64/boot/dts/qcom/Makefile \
                arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts | cut -c1-10

# G3（必须 stdin，PITFALLS #725）
timeout -k 5 120 perl scripts/checkpatch.pl --no-tree --strict --no-signoff - \
        < $P/v9-0001-*.patch
timeout -k 5 120 perl scripts/checkpatch.pl --no-tree --strict --no-signoff - \
        < $P/v9-0002-*.patch

# G4–G7
timeout -k 10 300  make -j28 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v9build defconfig
timeout -k 15 2400 make -j28 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v9build dt_binding_check
timeout -k 15 900  make -j28 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v9build \
      DT_SCHEMA_FILES=Documentation/devicetree/bindings/arm/qcom.yaml dt_binding_check
timeout -k 5 120 ~/.local/bin/dt-doc-validate Documentation/devicetree/bindings/arm/qcom.yaml
timeout -k 15 900  make -j28 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v9build \
      CHECK_DTBS=1 qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb

# G8：把 wl2868c binding（for-7.5 的 84e67d2ee13f 对应件）apply 进同一棵树再重跑
timeout -k 5 60 git apply \
  /home/xuqianhui/y700-elden/patches/upstream/wl2868c-v12-20261117/v12-0001-regulator-dt-bindings-willsemi-wl2868c-add-the-W.patch
timeout -k 15 900  make -j28 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=/tmp/v9build \
      CHECK_DTBS=1 qcom/sm8750-lenovo-elden.dtb qcom/sm8750-mtp.dtb qcom/sm8750-qrd.dtb
```

收尾（本次已按此清）：
```sh
git -C /home/xuqianhui/y700-elden/build/elden-tree worktree remove --force /tmp/v9wt
rm -rf /tmp/v9build
```

## 2. 原始输出

### G0 apply（`logs/apply-check-verbose-20261126.txt`，逐字）

```
### v9-0001-dt-bindings-arm-qcom-document-the-Lenovo-Legion-Y700.patch
正在检查补丁 Documentation/devicetree/bindings/arm/qcom.yaml...
rc=0
### v9-0002-arm64-dts-qcom-sm8750-lenovo-elden-add-Lenovo-Legion-Y700-Gen4.patch
正在检查补丁 arch/arm64/boot/dts/qcom/Makefile...
正在检查补丁 arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts...
rc=0
```
（`git apply` 默认**不做 fuzz**；`-v` 下无任何 `offset N lines` ⇒ 命中行号精确。）

### G1 blob（`git hash-object` 输出）

```
a32cfb30a1     Documentation/devicetree/bindings/arm/qcom.yaml
e0b65a36c5     arch/arm64/boot/dts/qcom/Makefile
73f4452f46     arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
```
与 `v9-0001` 的 `index 121ca557ce..a32cfb30a1`、`v9-0002` 的 `index 88230c4e00..e0b65a36c5` /
`0000000000..73f4452f46` 右值一致；`73f4452f46` 同时是 v7、v8 的记录值 ⇒ **板件本体零改动**。

### G3 checkpatch（`logs/checkpatch-v9-000{1,2}.txt`）

```
== v9-0001  ==
total: 0 errors, 0 warnings, 0 checks, 7 lines checked
"[PATCH v9 1/2] dt-bindings: arm: qcom: document the Lenovo Legion" has no
obvious style problems and is ready for submission.

== v9-0002  ==
WARNING: added, moved or deleted file(s), does MAINTAINERS need updating?
#56:
new file mode 100644
total: 0 errors, 1 warnings, 0 checks, 136 lines checked
```
（2/2 那条 warning = 新文件常规提示，v7/v8 同款，不修：`MAINTAINERS` 的 `ARM/QUALCOMM SUPPORT`
已覆盖 `arch/arm64/boot/dts/qcom/`，无需新增条目。）

### G4/G5/G6（`logs/dt-binding-check-full-20261126.log` 摘要、`…-qcomyaml-20261126.log`）

```
== 全量 ==
rc=0
DTC [C] 计数 = 5420
Error/error:/警告行计数 = 0
  CHKDT   /tmp/v9wt/Documentation/devicetree/bindings
  LINT    /tmp/v9wt/Documentation/devicetree/bindings
  STYLE   /tmp/v9wt/Documentation/devicetree/bindings

== 定向 DT_SCHEMA_FILES=…/arm/qcom.yaml ==
make[1]: 进入目录“/tmp/v9build”
  CHKDT   /tmp/v9wt/Documentation/devicetree/bindings
  LINT    /tmp/v9wt/Documentation/devicetree/bindings
  STYLE   /tmp/v9wt/Documentation/devicetree/bindings
make[1]: 离开目录“/tmp/v9build”
rc=0

== dt-doc-validate（直调） ==
（无输出）rc=0
```

### G7 dtbs_check（`logs/dtbs-check-3dtb-20261126.log`，逐字）

```
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb: /soc@0/geniqup@8c0000/i2c@888000/pmic@2f: failed to match any schema with compatible: ['willsemi,wl2868c']
```
诊断计数：elden **1**、mtp **0**、qrd **0**（`grep -cE '^arch/arm64/boot/dts/qcom/.*\.dtb: '` = 1）。
rc=0（`CHECK_DTBS` 的诊断不走 exit code，故**以 grep 计数为准**，不以 rc=0 当作零诊断）。

### G8 落 binding 后重跑（`logs/dtbs-check-3dtb-with-wl2868c-binding-20261126.log`，逐字）

```
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-mtp.dtb
  DTC [C] arch/arm64/boot/dts/qcom/sm8750-qrd.dtb
```
诊断计数 = **0**（`grep -c` 返回 0 命中）。⇒ v9 cover「带 binding 0 条 / 不带 1 条」是**本轮实测**。

### DTB 指纹（仅供同配置回归比对）

```
4707d3defd057e70e3aa5216320ac777  sm8750-lenovo-elden.dtb
ecc158767f04c8facf5fde6735b339da  sm8750-mtp.dtb
```
> ⚠ **不要**与 `../elden-dts-v9-prep-20261124/GATES-v9.md` 的 `2d2d92662785a7aa07edb6aba78a9341`
> 直接比：那轮树里额外 apply 了 dwc3 binding 与 USB 补丁（改过 `sm8750.dtsi` 和板件），**不是同一配置**。
> 本文件这组值只用于「同 worktree 同 `O=` 配置下」的回归比对。

## 3. 边界（读结论时请连带读这段）

1. 全部机械门只覆盖 **DT/binding 层**；本系列**不开机**，也没有 `W=1` 全量内核编译（不涉及 `.c`）。
2. 未重跑 v8 的负样例（去 1/2 后根节点不合法）：它测的是「1/2 是否必需」，与 v9 的文字改动无关；
   v8 原件在 `../elden-dts-v8-20261125/logs/dtbs-check-no-binding-entry-20261125.log`。
3. `dt_binding_check` 全量的 5420 与 `v9-prep` 的 5421 差 1 = **本树没有 wl2868c binding**（正是 G8 加的那份）。
   两个数字**自洽**，不是回归。

### G10/G11 补充原文

`bash SEND.sh --dry-run`（2026-11-25T22:56Z，**不投递**）3 封全 `Result: OK`，RCPT = 11 个地址
（andersson/konradybcio + abelvesa/Pengyu/robh/krzk+dt/conor+dt/devicetree/arm-msm/lkml）。

`git am` 路线（= 维护者用 b4/`git am` 取件时的实际形状）：

```
应用：dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4
应用：arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet
1a1fe8cdc082 arm64: dts: qcom: sm8750-lenovo-elden: add Lenovo Legion Y700 Gen4, ...
98caf6d4f1c2 dt-bindings: arm: qcom: document the Lenovo Legion Y700 Gen4
aebb72744764 Linux 7.4-rc3
  DTC     arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
4707d3defd057e70e3aa5216320ac777  sm8750-lenovo-elden.dtb   ← 与 G7（git apply 路线）逐字节相同
```
⇒ 「patch 文字改动没碰内容」在**两条取件路线**上都成立。
