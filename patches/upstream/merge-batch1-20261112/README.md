# 上游合并批 1 —— 必修 3 + 顺带 3（2026-11-12 备料，**尚未 apply**）

依据 `reports/upstream-merge-candidates-20261112.md` §1（lane D，逐枚实测双树 `git apply --check` rc=0）。
本目录只放**取回的原始 mbox**（patchwork 原样）+ sha，不改任何构建树。

## 内容

| 文件 | patchwork | 上游标题 | 类型 | 为什么现在带 |
|---|---|---|---|---|
| `pw-14971425.mbox` | 14971425 | soc: qcom: llcc-qcom: Reserve ISLAND1 ways on SM8750 | 必修 | s2idle 时 LPASS 无票 → PS_HOLD 复位；我们仍 `bonus_ways=0x7fffffff`（应 `res_ways`）。**只在 `CONFIG_SUSPEND=y` 下爆** |
| `pw-14970417.mbox` | 14970417 | clk: qcom: gcc-sm8750: Use retention for USB power domains | 必修 | s2idle + USB host 回来 SMMU fault / xHCI 死；我们 `gcc_usb30_prim_gdsc`/`gcc_usb3_phy_gdsc` 仍 `PWRSTS_OFF_ON`（Abel Vesa 已 RV；同族 `gcc-sa8775p` 版已 accepted） |
| `pw-14924748.mbox` | 14924748（**accepted**，`afe52f52d6`） | arm64: dts: qcom: sm8750: Fix iommu stream ID masks for CDSP compute CBs | 必修 | **开 CDSP/NPU 前必修**；我们 `compute-cb@12`/`@14` 仍是未修掩码。master 尚无此修 |
| `pw-14957689.mbox` | 14957689（系列 3/3，**只取 dwc3 这一枚**） | usb: dwc3: remove redundant `pm_runtime_dont_use_autosuspend()` | 顺带 | 单枚自包含，删一行冗余调用 |
| `pw-14944477.mbox` | 14944477（系列 1/2） | thermal: tsens: Drop `__init` from `init_common` | 顺带 | 单枚自包含；**2/2（`14944478` tsens-v1）在 `build/daily` 冲突，本批不带** |
| `series-1203899.mbox` | 系列 1203899（**整套 3 枚**） | phy: qcom-qmp-usb-ss 加 shared SS-link-state submode / qmp-combo 选 LFPS / dwc3-qcom 传 live SS-link 状态 | 顺带（suspend 线前置） | **3/3 依赖 1/3+2/3**（缺前两枚会编译失败）⇒ 必须整系列一起 apply |

## 应用（两台树都验过 rc=0；任一步失败就 `git checkout -- .` 回滚）

```bash
cd /home/xuqianhui/y700-elden
B=$PWD/patches/upstream/merge-batch1-20261112
for T in build/m3v2-7.3rc7 build/daily; do
  echo "== $T"
  for f in pw-14971425 pw-14970417 pw-14924748 pw-14957689 pw-14944477 series-1203899; do
    git -C $T apply --check "$B/$f.mbox" && git -C $T apply "$B/$f.mbox" && echo "  applied $f"
  done
done
```

## 最小验证门（apply 之后、重编之前）

```bash
T=build/m3v2-7.3rc7
make -C $T -j26 O= ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  drivers/soc/qcom/llcc-qcom.o drivers/clk/qcom/gcc-sm8750.o \
  drivers/usb/dwc3/dwc3.o drivers/usb/dwc3/dwc3-qcom.o drivers/thermal/qcom/tsens.o
make -C $T -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8750-lenovo-elden.dtb
make -C $T ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=1 qcom/sm8750-lenovo-elden.dtb  # 0 error
```

## 判据（上机才有意义）

- llcc/gcc 两条：**必须开 `CONFIG_SUSPEND=y` 并做 s2idle 回归**（`/sys/power/state` 写 `mem` → 唤醒后看
  `dmesg | grep -Ei 'arm-smmu|xhci|PS_HOLD'` 与 `uptime`）；当前日常树 `CONFIG_SUSPEND=n`，合了也看不到差别。
- CDSP mask：`remoteproc1` running + `dmesg | grep -i 'compute-cb\|iommu'` 无 `-EINVAL`。
- 回滚：`git -C <tree> checkout -- .`（本目录的 mbox 是原样件，可反复 apply）。

## 口径提醒

- 这些**不是**主线随机增量（master 对本树功能性增量为 0，见报告 §0.2），而是 patchwork 上与我们文件重合的
  在审/已收补丁；投递/回应仍按 `TASKS/README.md` §7 的「按系列逐次批准」。
- 三条我们**自己投出去的**系列（dwc3 v8、wl2868c、ADSP fastrpc）**不在**本批——不能当外部增量读回本地。
