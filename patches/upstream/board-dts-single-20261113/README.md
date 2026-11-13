# elden 板 DTS 单提交备料（B8，2026-11-13）

> 只读 lane。产物 = 单枚 `0001-*.patch`。**不发信**（本轮统一发信在下一轮）。

## 来源与动作

- 输入 = v6 串的 `patches/upstream/wl2868c-20261104-v6/v6-0004-*.patch`（加板子）+
  `v6-0005-*.patch`（WL2868C 稳压器）。两者只动 `arch/arm64/boot/dts/qcom/Makefile` 与新建的
  `sm8750-lenovo-elden.dts`，所以合并成「one logical action」没有内容损失。
- 合成方法（可复跑）：在 7.4-rc2 基点 `f66469d990` 上依次 `git apply` 0004、0005，
  `git diff HEAD -- Makefile sm8750-lenovo-elden.dts`，再补 From/Subject/正文。临时树 = `/tmp/b9/tree`（副本，已留）。
- 标题按 Krzysztof 原文：**「add Lenovo Legion Y700 Gen4, a Qualcomm SM8750-based tablet」**
  （patchwork 14942834 的措辞要求）。

## 门禁

| 门 | 结果 |
|---|---|
| `git apply --check` @ 7.4-rc2 基点 `f66469d990` | **rc=0** |
| `checkpatch.pl --strict --no-signoff` | **0E / 1W / 0C**（1W = “added, moved or deleted file(s), does MAINTAINERS need updating?”；qcom 板级 dts 已由现有 MAINTAINERS 覆盖，属提示不属错误） |
| `dt-doc-validate` binding | 不适用（本枚不动 binding） |
| `dtbs_check` 对 `sm8750-lenovo-elden.dtb` | **未跑**（需要整树 `dtbs` + DTC，本轮时间盒到上限）。今晚命令见下 |

今晚跑 dtbs_check 的命令（不改仓库，只在 /tmp 树上）：

```sh
cd /tmp/b9/tree            # 或任意 7.4 树副本
git checkout -q f66469d990 && git apply <本目录 0001>
source /home/xuqianhui/y700-elden/scripts/env-build.sh
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- qcom/sm8750-lenovo-elden.dtb
make -j26 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CHECK_DTBS=y qcom/sm8750-lenovo-elden.dtb \
  2>&1 | tee /tmp/dtbs-b8.log ; grep -c 'Warning\|Error' /tmp/dtbs-b8.log   # 期望 0
```

## rebase 依赖顺序（与 camss v6 binding、7.4 重放）

1. **7.4 重放树/B0 树先行**（板文件本身与 7.4 零冲突，但它引用的 `sm8750.dtsi` 必须来自同一基线）。
2. 本枚（板 DTS 单提交）**不依赖 camss v6 binding**：它只描述板级 GPIO/时钟/WL2868C，
   相机节点留在 payload 里，v6 合入后再单独 rebase `0009 arm64: dts: sm8750: add the camera subsystem`。
3. 若 v6 先合入：本枚 rebase 到含 v6 binding 的树，`camera` 相关节点仍不并入本提交
   （Krzysztof 的 one-logical-action 只针对「新增硬件」这一件事，相机是另一件事）。
4. 顺序建议：**7.4 重放/基线确定 → 本枚单提交 →（v6 合入后）相机 dts 0009 rebase**。

## 未完成

- `dtbs_check` 未跑（命令已给，今晚一条命令的事）。
- 未与 v6 的 `4/5+5/5` 原件逐字节对比（本轮用 apply 后 diff 生成，等价性靠 apply rc=0 保证）。
