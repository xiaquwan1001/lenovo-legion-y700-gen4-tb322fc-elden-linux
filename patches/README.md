# patches/ —— 补丁与内核配置的管理规则（SSOT）

> 本目录管两件事：**内核改动的补丁存档** 与 **内核配置（fragment / 快照）**。
> 迭代流程本身不在这里写，见 `scripts/build-kernel.sh`、`scripts/iterate.sh`、`scripts/mod-loop.sh`
> 的头部注释与 `RUNBOOK-BRINGUP/README.md`。

## 0. 内核树指针

日常线树 = `patches/current-tree`（唯一一行有效内容，现指 `build/daily`）。
`scripts/env-build.sh` 的 `KDIR` 默认值从它读；`iterate.sh` / `mod-loop.sh` / `build-kernel.sh` /
`apply-kernel-fragment.sh` 全部经它取树。**裸跑脚本编错树是历史事故**（PITFALLS #162 同类），
换树只改这一行，临时覆盖用 `KDIR=`。

## 1. 补丁从哪来、放哪

改动**只在树里做**，然后导出成补丁入库，不给「工作只在树里」留欠账：

```bash
# 在目标树里（build/daily 或一次性验证树）提交后导出
git -C build/daily format-patch -o ../patches/upstream/<系列名>/ <base>..HEAD
```

- 一个逻辑改动一个提交；`From`/`SoB` 与投递版一致（`git format-patch` 生成，不手写）。
- 投递过的系列进 `patches/upstream/<系列名>/`，同目录 `README.md` 记：投递日期、Message-ID/URL、
  reviewer 意见、v2/v3 变更、是否 superseded。**状态以 `reports/upstream-status-*.md` 为准**。
- 候选/未实施补丁（`candidate-*.patch`、`draft-*.patch`）**保留备查**，文档里明确写「保留备查，不实施」。

## 2. 目录索引

| 目录 | 装什么 | 权威文件 |
|---|---|---|
| `upstream/` | 向上游投递过的系列备料 + 状态 | 各系列 `README.md`；`reports/upstream-status-*.md` |
| `kernel-history/` | 内核历史增量补丁集（浅克隆仓的权威文本记录） | `RESOURCES/README.md` §3 |
| `uefi/` | UEFI / EDK2 线的补丁与配方 | `versions/patches-uefi-status.tsv` |
| `local/`、`dt/`、`extmod/` | 本地驱动/DT/外部模块改动 | 各目录 README（无则看补丁头） |
| 各特性目录（`aw86927-*`、`m4-camss-*`、`gunyah/`、`phoc-*`、`waydroid-camera-*` …） | 一次性系列的备料与产物说明 | 目录内 `README.md` |
| `config-history-20261113/` | 历史 `.config` 快照归档（tar.zst + 逐件 sha） | 该目录 `README.md` |
| `MODULAR-BOUNDARY.md` | 哪些驱动能 `=m`、哪些必须 `=y`、判据 | 本文档自身 |

## 3. 内核配置：fragment 是源，快照是记录

- **不要手改 `.config`**。新增/调整符号写进 `patches/fragment-*.config`，每条附一行理由。
- 合并与解析：`FRAG="patches/fragment-a.config patches/fragment-b.config" SNAP=patches/config-<名> bash scripts/apply-kernel-fragment.sh`
  - 脚本会备份当前 `.config` 到 `patches/config-before-fragment-<时间>.bak`（**不入库**，整理轮删盘）；
  - 在**副本**上跑 `make olddefconfig` 解析依赖，并把 `ARCH_QCOM` 等锚点回钉；
  - 逐条核对片段里每个符号的最终取值（被 `bool`/依赖拉回会点名）；
  - 导出新快照。
- **门禁**：`bash scripts/check-modular-config.sh`（锚点不回退 + `olddefconfig` 两遍幂等 + tristate 自洽），
  已接进 `scripts/check-doctor.sh` §12。`scripts/build-kernel.sh` 另查 `ARCH_QCOM` 与 `System.map` 关键符号。
- **ABI 参考**：`scripts/check-abi-config.sh` 取最新 `config-daily-*`；没有时才退回 `config-vk127-working-*`。
  改了直接影响 ABI 的符号（suspend/KVM 等）必须**整套重编模块树**，不能复用同名 UTS 的旧模块。

### config 快照的留/走

- **留在 `patches/` 平铺**：现役 SSOT（`config-daily-c1/c2/c3`）、脚本硬编码件
  （`config-vk40-bringup`、`config-vk127-working-*`、`config-vk163-modular-v2-*`、`config-m3v2-suspend-*`）。
- **进归档包**：被取代的历史快照，攒到整理轮打进 `config-history-<date>.tar.zst`，
  附逐件 `SHA256SUMS` 与索引 `README.md`（见 `config-history-20261113/README.md` 的清单与取回命令）。
- 同一内容不另存第二份：先 `sha256sum` 比对（历史上出现过 3 件逐字节相同的模块化快照）。

## 4. 硬约束

- `boot.img` ≤ **96 MiB**（`boot_a` = 0x6000000）。
- 内核一律用 `scripts/build-kernel.sh`（`ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`）；裸 `make` 会按宿主 x86 重写 `.config`。
- 作者自定义资产（如 `awinic/y700-gen4-speakers.bin`）不要等上游：直接改我们的 DTS/驱动或自造 profile。
