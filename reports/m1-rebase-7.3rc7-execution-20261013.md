# M1 重基到 7.3-rc7：解冲突与系列完成执行报告（2026-10-13）

> 任务 H · lane m1-rebase-exec · 纯主机侧，不推分支、不碰设备
> 工作树 = `build/m1-upstream/clean-tree-73`（分支 `m1-payload`）
> 基线：upstream-v7.2 = `237a1c39e8df`（Linux 7.2）；onto = `24a19b953e`（Linux 7.3-rc7）
> payload 压缩提交 = `2e28b969d1`（父 = upstream-v7.2，树 = downstream `ba28ec16f0` 的树）
> 处置口径见 `reports/upstream-policy-20261013.md` §1 三问门 / §3 Q3 违例清单 / §6 下游隔离清单

## §1 状态与配方

### 1.1 现状（接手时）

- 工作树 = `build/m1-upstream/clean-tree-73`，git 工作树指向 `geekidos-linux/.git/worktrees/clean-tree-73`；分支 `m1-payload`，**rebase 中断态**。
- `HEAD`（also onto）= `24a19b953e`（Linux 7.3-rc7）；`REBASE_HEAD` = `2e28b969d1`（squashed elden payload）；`rebase-merge/done` = `pick 2e28b969d1 # elden payload: downstream v7.2-elden tree state (squashed)`，msgnum=end=1。
- `git diff --name-only --diff-filter=U` 列出 **16** 个 unmerged 文件（与任务给出的一致）。

```sh
$ cd build/m1-upstream/clean-tree-73
$ git rev-parse HEAD                       # 24a19b953e2a3d0ea5a8c4951a0ab8f32720c907
$ cat .git/rebase-merge/done
pick 2e28b969d162474b85cd4f4664c9b05a6fd58789 # elden payload: downstream v7.2-elden tree state (squashed)
$ git diff --name-only --diff-filter=U | wc -l
16
```

### 1.2 配方

- 上游锚点 `upstream-v7.2` = `237a1c39e8df`（Linux 7.2 tag）；onto = `24a19b953e`（7.3-rc7）。
- rebase 实际应用的补丁 = `git diff 237a1c39e8df:<file> 2e28b969d1:<file>`（= elden payload 相对 v7.2 tag 的增量）。**本报告逐文件用该 diff 提取 elden 增量**，避免混入 7.2→7.3 的纯上游漂移。
- 处置口径（任务策略）：
  1. 以上游 7.3-rc7 侧为基，不回退上游新代码；只重新贴回 elden 专有增量。
  2. 丢弃 `upstream-policy-20261013.md` §3（Q3 违例）与 §6（下游隔离）hunk，逐处登记（§3 表）。
  3. 拿不准 → 取上游 + 登记「未决：elden 增量待重新移植」（§4 表）。

### 1.3 逐文件处置（草案）

见 §2；丢弃登记见 §3；未决见 §4。

## §2 逐文件处置表

> 口径见 §1.2。`取上游` = `git checkout --ours`（rebase 中 ours = onto = 7.3-rc7）；`取 elden` = `--theirs`。
> 列「依据」指向 `reports/upstream-policy-20261013.md` 节号或上游漂移事实。

### 2.1 rebase 冲突（16 文件）

| # | 文件 | 冲突块 | 处置 | 依据 / 备注 |
|---|------|-------|------|------|
| 1 | `fs/crypto/block.c` | 2 | 取上游；并在后续修复提交把整个 vendor fscrypt/dm-default-key 回退 | §6（C2 隔离）；7.3 已把 inline_crypt.c 重构为 block.c |
| 2 | `sound/soc/codecs/Makefile` | 2 | **保留双方**（上游 `aw88399-lib` + elden `aw88461`） | 相邻行伪冲突 |
| 3 | `sound/soc/qcom/qdsp6/q6apm-lpass-dais.c` | 1 | 取 HEAD（保留上游 TDM case）；elden MI2S mclk/bclk 增量已自动合并 | 不回退上游 |
| 4 | `sound/soc/qcom/sc8280xp.c` | 3 | 取上游全部 | 7.3 已含 `qcom_snd_soc_common` per-SoC 框架 + `sm8750` 特判；elden 硬编码被取代 |
| 5 | `drivers/net/wireless/ath/ath12k/qmi.h` | 1 | 保留 elden `ATH12K_QMI_QDSS_CFG_FILE`，丢弃死宏 `ATH12K_FIRMWARE_MODE_OFF` | 上游改用 `ATH12K_QMI_FIRMWARE_MODE_OFF` 枚举；宏无引用 |
| 6 | `drivers/pmdomain/qcom/rpmhpd.c` | 2 | 保留 elden `presync_floor`，丢弃 `skip_retention_level` | 7.3 已删该字段；`presync_floor` 逻辑（非冲突块）已应用，须保留字段 |
| 7 | `drivers/remoteproc/qcom_q6v5.c` | 1 | 取 HEAD（去掉多余 `}`）；elden handover IRQ 优化保留 | 7.3 把 `if(ret){...}` 简化为单行 |
| 8 | `drivers/remoteproc/qcom_q6v5_pas.c` | 2 | 取上游全部 | elden `dtb_firmware` 局部化被 7.3 `qcom_pas_metadata_release` 释放路径取代（§4-6） |
| 9 | `drivers/iommu/dma-iommu.c` | 1 | 取上游全部（丢 elden `qcom,msi-iova` 固定 MSI IOVA） | §6（C4 框架级隔离） |
| 10 | `drivers/i2c/busses/i2c-qcom-cci.c` | 1 | 取上游全部 | 7.3 用 `devm_pm_runtime_set_active_enabled` 取代 elden remove 重写（§4-2） |
| 11 | `drivers/gpu/drm/msm/dsi/dsi_host.c` | 2 | 保留双方：上游 `byte_intf_clk_div_2` + elden `byte_intf_clk_rate`/dma seq；并补回被 7.3 删掉的 `byte_intf_clk_rate` 字段 | elden 代码引用该字段，7.3 改名会致编译失败 |
| 12 | `drivers/gpu/drm/msm/dsi/dsi_manager.c` | 1 | 保留上游 `atomic_*` 命名 + elden `enable/disable`（→ 7.3 `.atomic_enable/.atomic_disable`） | 上游 7.3 移除非原子 enable/disable |
| 13 | `drivers/gpu/drm/msm/msm_iommu.c` | 2 | 保留双方 include；保留 elden `msm_iommu_alloc` 拆分 + 把上游 ARM32 detach 变通放入 `msm_iommu_new` | 不回退上游 |
| 14 | `drivers/gpu/drm/panel/Kconfig` | 2 | 取 elden（`select DRM_DISPLAY_DSC_HELPER/HELPER` + module note） | elden 面板需 DSC |
| 15 | `drivers/gpu/drm/panel/panel-novatek-nt36536.c` | 8 | 取 elden 全部 8 块 | 8 块均为 elden 面板增量（DSI0 master、accum_err、extra modes、backlight 顺序）；无 `force_hz`/`module_param`（§3 已清） |
| 16 | `drivers/gpu/drm/msm/msm_fbdev.c` | 5 | 取上游全部 | 7.3 已做等价的 iova pin/unpin + vma 引用修复 |

### 2.2 cherry-pick（12 提交）

| # | 提交 | 结果 | 处置 / 备注 |
|---|------|------|------|
| 1 | `44137cb4e9` psci | OK（+43） | 干净 |
| 2 | `0c02ca0b39` dpu GC | OK（+6） | 干净 |
| 3 | `00f08bac64` aw86927 | **无冲突**（+77） | 与任务预期不同（payload 已含 SRAM 窗口部分）；丢弃 §3 B2 连续模式魔数函数 `aw8693x_cont_play()` 及其调用，见 §3 |
| 4 | `b46bea4aad` vk42 音频+温控 | OK | 板 DTS 已在树内，干净 |
| 5 | `fc08094eaa` vk44 DMIC | OK | 干净 |
| 6 | `4983ea6df1` vk45 VA macro | OK | 干净 |
| 7 | `47d590b4f7` vk46 WCD939x | OK | 干净 |
| 8 | `ae3e0de16c` vk47 WCD939x 采集 | OK | 干净 |
| 9 | `14c19a1ef0` vk53 NFC+CDSP | OK | 干净 |
| 10 | `7057ca4140` cdsp split 固件 | OK | 干净 |
| 11 | `563bbd787a` 相机 rotation | OK | 干净 |
| 12 | `c73ff25222` ADSP fastrpc | OK | 干净 |

> 12 个 cherry-pick 中 **11 个完全干净**，仅 `00f08bac64` 需要内容修剪（且不是 git 冲突）。

### 2.3 后续修复提交（rebase 后编译暴露）

| 提交 | 内容 | 原因 |
|------|------|------|
| `abab55b77c` M1: 7.3-rc7 rebase fallout fixes | ① vendor fscrypt/dm-default-key 全量回退；② dsi_manager `.enable/.disable` → `.atomic_enable/.atomic_disable` | ① payload 的 §6 内容与 7.3 的 block.c 重构混合后编译失败；② 7.3 `drm_bridge_funcs` 已无非原子 enable/disable |

## §3 丢弃登记表

> 每条：文件 | 内容摘要 | 依据条款。均以「上游 7.3-rc7 为基、仅回退 payload 增量」实现，不回退上游新代码。

| # | 文件 | 丢弃内容摘要 | 依据 |
|---|------|-------------|------|
| D1 | `drivers/md/dm-default-key.c`、`drivers/md/{Makefile,Kconfig}`、`Documentation/admin-guide/device-mapper/dm-default-key.rst`(+index) | `dm-default-key` target 与 Kconfig/Makefile/文档 | policy §6（C2：out-of-tree patchset = M5） |
| D2 | `fs/crypto/fscrypt_private.h`、`fs/crypto/keyring.c`、`include/linux/fscrypt.h`、`include/uapi/linux/fscrypt.h`、`tools/include/uapi/linux/fscrypt.h` | vendor wrappedkey ABI（`blk_key`、`fscrypt_inode_should_skip_dm_default_key` 等） | policy §6（C2） |
| D3 | `block/bio.c`、`block/blk-crypto-fallback.c`、`include/linux/blk-crypto.h` | `bio_set_skip_dm_default_key` 序列与 blk-crypto fallback 改动 | policy §6（C2） |
| D4 | `drivers/iommu/dma-iommu.c` | `qcom,msi-iova` 固定 MSI IOVA（`iommu_dma_alloc_fixed_msi_iova` 等） | policy §6（C4 框架级） |
| D5 | `drivers/i2c/busses/i2c-qcom-cci.c` | elden `cci_remove` pm_runtime 重写 | policy §4/§6（框架级；7.3 已重构） |
| D6 | `drivers/remoteproc/qcom_q6v5_pas.c` | elden `qcom_pas_load` `dtb_firmware` 局部化重构 | 上游 release 路径取代（§4-2 待复核） |
| D7 | `drivers/gpu/drm/msm/msm_fbdev.c` | elden fbdev pin/unpin/vma 重写 | 7.3 已等价修复 |
| D8 | `sound/soc/qcom/sc8280xp.c` | elden `sm8750-sndcard` 硬编码 mclk/bclk 分支 | 上游 per-SoC priv 框架已含 |
| D9 | `drivers/net/wireless/ath/ath12k/qmi.h` | `ATH12K_FIRMWARE_MODE_OFF` 宏 | 上游改枚举，宏无引用 |
| D10 | `drivers/pmdomain/qcom/rpmhpd.c` | `skip_retention_level` 字段/注释 | 7.3 已删 |
| D11 | `drivers/gpu/drm/msm/dsi/dsi_manager.c` | 非原子 `.enable/.disable` 回调名 | 7.3 `drm_bridge_funcs` 改 `atomic_enable/atomic_disable`（功能以新 API 保留） |
| D12 | `drivers/input/misc/aw86927.c` | `aw8693x_cont_play()` 连续模式（魔数 `0x7f/0x04/0xff`）及其调用 | policy §3（B2：反汇编魔数 → 须 DT 化） |

## §4 未决项

| # | 未决项 | 需要什么证据 / 下一步 |
|---|--------|----------------------|
| U1 | **elden DSI 一族仍在树内**（`dsi_host.c` bonded-command DMA、`dsi_manager.c` `msm_dsi_host_bonded_*`、私有 `CMD_DMA_CTRL.MASTER_EN` 等） | 属 policy §4 B5 / §6；需按 **per-SoC cfg 结构**重构后再谈上游。本轮只保证「不回退上游 + 编译通过」。 |
| U2 | `dsi_mgr_bridge_enable/disable` 语义映射到 `.atomic_enable/.atomic_disable`（第二参 `struct drm_atomic_commit *`） | 需上机确认 enable 时序（原非原子回调在 prepare 之后、video enable 之前）；纯静态无法判定。 |
| U3 | `rpmhpd.c` `presync_floor`（GMU 轨在 sync_state 前钳到最低功能档） | 属框架级 workaround（policy §6 C4 类）；需通用复现 + 上游 RFC 论证。 |
| U4 | `aw86927.c` SRAM 窗口边界 `0x1000/0x2000` 仍是 C 内常数 | policy §3 B2 延伸：应提升为 DT 属性/数据表。基线 `awinic,aw86927.yaml` 尚无 `cont_drv1_lvl/time` 属性。 |
| U5 | `panel-novatek-nt36536.c` 8 块均取 elden 版，其中 `to_primary_dsi()` 返回 `ctx->dsi[0]`（DSI0 广播 master） | 依赖 U1 的 bonded-command 路径；B5 重构时须同步。 |
| U6 | `q6v5_pas.c` elden 的 `dtb_firmware` 局部化被丢弃 | 若其原始目的（避免 dtb firmware 释放/泄漏问题）在 7.3 的 `qcom_pas_metadata_release` 路径下仍存在，需复核 diff。 |
| U7 | `00f08bac64` 的连续模式被整体丢弃后，AW86937 只剩 SRAM 波形路径 | 需上机验证触觉是否可用；若必须连续模式，则先做 §3 B2 的 DT 化。 |
| U8 | `24a19b953e` 的 `fs/crypto` 仅在 `CONFIG_FS_ENCRYPTION=y` 下编译；上游 arm64 `defconfig` 默认关闭 | 本轮验证时手动 `scripts/config -e FS_ENCRYPTION`；发行版 config 片段需确认开启。 |
| U9 | 未跑全量内核编译（任务要求） | 已跑 3 批目标对象 + 板 DTB（见 §6）；全量编译由编排者做。 |

## §5 最终 `git log --oneline` 与工作树状态

```sh
$ cd build/m1-upstream/clean-tree-73
$ git log --oneline 24a19b953e..HEAD
abab55b77c M1: 7.3-rc7 rebase fallout fixes
e09444a9f7 arm64: dts: qcom: sm8750: Add non-secure-domain to ADSP fastrpc
7e69ad9f00 dts: 相机 rotation +180（前 270→90 / 后 90→270）
8bb52e336b elden: cdsp — 用 stock split 固件 (cdsp.mdt/cdsp_dtb.mdt) 取代单文件 .mbn
c939c629ee elden: vk53 — 硬件驱动覆盖批次（NFC ST21NFCA + CDSP 启用）
992a1c2223 elden: vk47 — WCD939x 采集（去 VA DMIC，单 WCD capture link）
4560799568 elden: vk46 — 启用 WCD939x 音频编解码（模拟麦采集正路）
dad074b59c elden: vk45 — VA macro vdd-micb supply + DMIC sample rate
835045a0f0 elden: vk44 — DMIC capture（VA macro + VA Capture dai-link）
657b8dff91 elden: vk42 — 干净重落 vk39 两项改动（音频 + 温控）
edc8ac7343 m1: A3+B2 aw86927 SRAM/continuous (0003-aw86927-aw86937-haptics)
ae33b8dbcc m1: A1 dpss GC gamma block (0002-sm8750-dspp-gc-gamma)
6776a30860 elden: vk41 — minimal PSCI SYSTEM_RESET2 vendor-reset hook for reboot bootloader/edl
640b0e49db elden payload: downstream v7.2-elden tree state (squashed)
# 24a19b953e Linux 7.3-rc7  <- onto

$ git rev-list --count 24a19b953e..HEAD        # 14
$ git status --porcelain | wc -l                # 0
$ git rev-parse HEAD                             # abab55b77cb867a3766ddf7677556c49bb36a23c
$ git grep -l '^<<<<<<<\|^>>>>>>>'              # (无输出)
$ git diff --stat 24a19b953e HEAD | tail -1      # 162 files changed, 15985 insertions(+), 691 deletions(-)
```

- 分支 `m1-payload`，工作树 `clean`（0 未提交/未跟踪）。
- 结构 = `7.3-rc7 (24a19b953e)` → 1 个 squashed elden payload → 12 个 cherry-pick → 1 个 rebase 修复提交。
- 修复提交 `abab55b77c` 不属于原 12+1 配方，是「§6 隔离 + 7.3 API 适配」的必要收尾（见 §2.3）。

## §6 验证命令

> 全量内核编译由编排者做；本节只登记本任务实际跑过的、且**通过**的检查。构建用 `O=/tmp/m1build73`（不污染工作树）。

### 6.1 结构与冲突

```sh
cd build/m1-upstream/clean-tree-73
git diff --name-only --diff-filter=U          # (空：冲突全部解决)
git status --porcelain | wc -l               # 0
git grep -l '^<<<<<<<\|^>>>>>>>'            # (空)
```

### 6.2 交叉编译（`aarch64-linux-gnu-gcc 15.2.0`，arm64 defconfig + 按需开启配置）

```sh
export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
make O=/tmp/m1build73 defconfig
# 批1：16 冲突文件对应对象 + aw86927
make -j8 O=/tmp/m1build73 drivers/gpu/drm/msm/dsi/dsi_host.o ... fs/crypto/block.o
#   -> rc=0（16 个 CC）
# 批2：整个 msm / sound/soc/qcom / ath12k / remoteproc / pmdomain / i2c / soc-qcom
make -j8 O=/tmp/m1build73 drivers/gpu/drm/msm/ sound/soc/qcom/ drivers/net/wireless/ath/ath12k/ \
     drivers/remoteproc/ drivers/pmdomain/qcom/ drivers/i2c/busses/ drivers/soc/qcom/
#   -> rc=0（296 个对象）
# 批3：panel/touchscreen/camss/regulator/codecs/bluetooth/media-i2c + 板 DTB
make -j8 O=/tmp/m1build73 qcom/sm8750-lenovo-elden.dtb drivers/gpu/drm/panel/ \
     drivers/input/touchscreen/ drivers/media/platform/qcom/camss/ drivers/regulator/ \
     sound/soc/codecs/ drivers/bluetooth/ drivers/media/i2c/
#   -> rc=0（229 个对象 + sm8750-lenovo-elden.dtb，无 dtc warning）
```

关键错误定位与修复（证据）：

```text
# 首轮编译暴露 2 类真实错误：
drivers/gpu/drm/msm/dsi/dsi_manager.c:546:10: error: 'const struct drm_bridge_funcs' has no member named 'enable'
  -> 7.3 的 drm_bridge_funcs 只有 atomic_enable/atomic_disable；已按新签名端口（§2.3）
fs/crypto/block.c:29:17: error: 'struct super_block' has no member named 's_cop'
  -> 原因是 defconfig 未开 CONFIG_FS_ENCRYPTION（s_cop 字段在 #ifdef 内）；
     且 7.3 block.c 与 payload 的 vendor fscrypt_private.h 混用 -> 已把后者整族回退（§3 D1-D3）；
     开启 CONFIG_FS_ENCRYPTION 后 fs/crypto/block.o 编译通过。
```

### 6.3 未被本任务覆盖的检查（留给编排者）

- 全量 `make -jN Image.gz dtbs`（含 NFC/相机/音频等未在 defconfig 打开的 elden 驱动，需发行版 config 片段）。
- 上机功能对照（相机/触觉/显示/音频）；本任务为纯主机侧，**不写「已修复」**。

---

> **产物**：本报告 + 工作树 `build/m1-upstream/clean-tree-73`（`m1-payload`，HEAD `abab55b77c`）。
> 未推分支、未动 `clean-tree`/设备，未改领域层文档。

## §7 编排者复核（2026-10-13，主会话独立重跑）

复核结论：**lane 的解冲突方向正确，但其「3 批相关目录编译 rc=0」不足以证明树可编译——全量构建暴露了一个跨文件族的漏改，已由编排者修复并复验通过。**

1. **发现并修复：vendor `dm-default-key` 残留调用点导致全量构建失败**。首次 `make -j8 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image.gz dtbs` 失败：

```
fs/f2fs/data.c:539:18: error: implicit declaration of function 'fscrypt_inode_should_skip_dm_default_key'
fs/f2fs/data.c:540:17: error: implicit declaration of function 'bio_set_skip_dm_default_key'
fs/f2fs/data.c:553:26: error: implicit declaration of function 'bio_should_skip_dm_default_key'
make[4]: *** [scripts/Makefile.build:290：fs/f2fs/data.o] 错误 1
```

   根因：§3 丢弃登记把 vendor ABI 从 `fs/crypto/` + `include/linux/fscrypt.h` 整族回退，但**调用方** `fs/f2fs/data.c`（2 hunk）与 `include/linux/blk_types.h`（1 hunk，`bi_skip_dm_default_key`）未回退 ⇒ 树自相矛盾。修复提交 `ed6f232d10`「M1: drop the remaining vendor dm-default-key call sites (f2fs, blk_types)」（两文件 `git checkout 24a19b953e --`）。
2. **修复后全量构建复验**：`BUILD_RC=0`，`error:`/`Error [0-9]` 计数 **0**，`warning:` 计数 **0**；产物 `arch/arm64/boot/Image.gz` = **20 798 473 B**、`sm8750-lenovo-elden.dtb` = **153 262 B**。
3. **残留核对（相对 7.3-rc7 的改动行数）**：`fs/crypto/block.c` 0、`include/linux/fscrypt.h` 0、`fs/f2fs/data.c` 0、`msm_fbdev.c` 0（= 取上游，正确）；panel `panel-novatek-nt36536.c` **74 行 = 与 7.2 基座树逐字相同的 elden 增量**（取 elden 未回退上游 7.3 代码）；`dsi_host.c` 496 / `dsi_manager.c` 218 / `msm_iommu.c` 82 / `ath12k/qmi.h` 64（B5/C1 类 elden 增量保留）。
4. **重基后总量**：`git diff --stat 24a19b953e HEAD` = **147 files, +15361 / −687**（原 payload 173 文件 / +16120 / −672）。
5. **分支收口（编排者）**：分支 `m1-payload` 已更名为 **`m1/clean-tree-7.3rc7`**（tip = `ed6f232d10`）；同名占位分支（原指 24a19b953e）已删除。

**派工教训（已同步到技能 `fabric-dispatch-checklist`）**：跨文件族的「丢弃/回退」必须由**全量构建**兜底——「相关目录编译通过」会漏掉调用方；编排者不得以 lane 的局部编译替代全量门。

