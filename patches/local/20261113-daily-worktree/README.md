# 2026-11-13：`build/daily` 工作区全量快照（= vk190 内核的源侧状态）

## 为什么有这份

`build/` 整个目录在仓库 `.gitignore` 里（内核树 13 GB 量级，不可能入库）。但 **vk190（在机内核）的源侧状态
并不全在仓库里**——`build/daily` 的 HEAD 是 `4da9a8b69fc8`（上游 7.3.1 + payload v2），
其后叠了 6 枚上游补丁、ADSP DT 一行修复、ramoops DT、以及**未入库的 Gunyah 移植源码**（12 MB 目录）。
树一旦被删/重建（历史上发生过：`build/m1-73` 丢失事故），这些增量就只能从报告里重做。

本文件把该工作区**逐字**存成一份 patch（`git diff`，含 intent-to-add 的新文件），
作为「vk190 可复现」的最后一道保险。

## 内容（38 文件 / +8976 −15，sha256 `7b6b5137c6f8…`）

| 组 | 文件 | 说明 |
|---|---|---|
| 上游合并批 1（6 枚） | `drivers/soc/qcom/llcc-qcom.c`、`drivers/clk/qcom/gcc-sm8750.c`、`drivers/thermal/qcom/tsens.c`、`drivers/usb/dwc3/{core,dwc3-am62,dwc3-qcom}.c`、`drivers/phy/qualcomm/phy-qcom-qmp-combo.c` | 原始 mbox 在 `patches/upstream/merge-batch1-20261112/`（未 commit，故也出现在本 diff 里） |
| **ADSP fastrpc non-secure** | `arch/arm64/boot/dts/qcom/sm8750.dtsi` | **vk190 相对 vk189 的唯一功能增量**；源头 `patches/upstream/sm8750-adsp-nonssecure-20261107/`（已投上游） |
| ramoops `record-size` | `arch/arm64/boot/dts/qcom/sm8750-lenovo-elden.dts` | `patches/dt/0001-…ramoops-record-size.patch` |
| CDSP compute-CB stream-ID mask | `sm8750.dtsi` 的 `compute-cb@12/@14` | 上游 accepted `14924748`（开 CDSP 前必修） |
| **Gunyah 7.3 移植** | `drivers/virt/gunyah/`（10 个源文件）、`arch/arm64/gunyah/`、`include/{linux,uapi/linux}/gunyah.h`、`include/linux/gunyah_qtvm.h`、`include/linux/phy/phy-qcom-qmp-usb-ss.h`、`arch/arm64/{Kbuild,include/asm/gunyah.h}`、`drivers/virt/{Kconfig,Makefile}` | 来自 piano 代次 `ff6cf0aa`（`yzddmr6/linux-sm8750-piano`），API 适配 1 处 = `vma_interval_tree_foreach` → `mapping_rmap_tree_foreach`；见 `reports/gunyah-73-port-20261112.md` |

**不含**：`.config`（另存 `patches/config-daily-c2-suspend-20261113`）、构建产物 `.o`/`Image*`/`.ko`。

## 怎么用（重建后回灌）

```bash
# 前提：worktree 的 HEAD 必须是 4da9a8b69fc8（7.3.1 + payload v2）
git -C build/daily log --oneline -1
git -C build/daily apply --check patches/local/20261113-daily-worktree/0001-daily-worktree-state-vk190.patch \
  && git -C build/daily apply patches/local/20261113-daily-worktree/0001-daily-worktree-state-vk190.patch
cp patches/config-daily-c2-suspend-20261113 build/daily/.config      # 再 make olddefconfig 一次
scripts/build-kernel.sh Image.gz dtbs                                # → 与 out/boot-elden-vk190.img 同源
```

**自检判据**（本文件生成时现跑）：

```bash
git -C build/daily apply --check --reverse patches/local/20261113-daily-worktree/0001-daily-worktree-state-vk190.patch
# 反向能打 = patch 与当前工作区逐字一致
```

## 教训

`build/` 被 gitignore 是必要的，但**「内核树里的脏状态」必须有一份入库的等价物**——
否则「在机内核可复现」只是口头承诺。以后每出一个要持久化的内核号，收尾时同步出一份这样的 worktree patch
（或把增量全部转成 `patches/upstream|local/<topic>/` 下的独立 mbox），两者至少有一个。
