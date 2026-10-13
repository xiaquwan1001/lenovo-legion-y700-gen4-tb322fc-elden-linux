# M3-2 板基础片切分台账（2026-10-13）— ⛔ 未完成

> **状态**：本文件是 **lane B（`m3-boardsplit` worker）被 deliberately 停止时留下的空骨架**，**没有任何数据**（数字结论/台账/编译验证四节均为空）。派工单要求的分段落盘提醒生效，故只落盘了表头。
> 停止原因：用户指示结束当前子代理（该 lane 已运行 >1 h 无产出）。
> **接手方 = 主会话**；重建时按下述配方，并遵守 `reports/upstream-policy-20261013.md` 的方法学（判"上游有无驱动"必须查 of_device_id 表，不能只 grep compatible 字符串——面板 `novatek,nt36536` 曾因此被误判）。

## 重建配方（可直接照跑）

```sh
R=/home/xuqianhui1001/y700-elden/geekidos-linux ; P=24a19b953e   # pristine = tag 提交
M1=/home/xuqianhui1001/y700-elden/build/m1-upstream/clean-tree
# 1) 板 DTS 顶层节点 + 行号（作为台账骨架）
grep -n "^&[a-z_0-9]*\|^/ {" $M1/arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts
# 2) 每个节点的 compatible 是否上游齐（binding 查 enum/const，驱动查 of_device_id）
git -C $R grep -l -- '<compatible>' $P -- Documentation/devicetree/bindings
git -C $R grep -n -- '<compatible>' $P -- drivers/ sound/
# 3) 子集编译验证
cd $M1 && make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs
# 4) schema（必须用"本系列自带 binding"口径）
export PATH=/home/xuqianhui1001/venv-dtschema/bin:$PATH
dt-validate -s Documentation/devicetree/bindings arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dtb
```

**参考数据**（已由主会话独立取得，可直接引用，避免重复劳动）：`reports/m3-missing-support-matrix-20261013.md`（逐 compatible 的上游支持面 + payload 改动规模）。
