# 全系列 linux-next 去重核对（2026-10-27 晚）

> 目的：**投递前**先确认「上游是不是已经有了 / 我们的补丁还能不能套」。2026-10-13 已经因为漏查
> `drm-msm-next` 而把一枚与 `3389406e6a03` 逐字重复的补丁（M2 A1）投了出去，只能撤稿；
> 那次之后没有系统化的核对动作。本报告 = 把**所有在途系列**对 `linux-next` **master** 过一遍。
> 基线：`git.kernel.org/…/next/linux-next.git` **master**（2026-10-27 抓取）。纯主机、零设备。

## §0 结论（先数字）

| 系列 | 上游是否已有 | 我们的补丁还能套吗 | 裁决 |
|---|---|---|---|
| **M2 A2** battmgr `power_now` | **没有**（驱动里 `sm8750` 命中 0，`POWER_NOW` 仍在 SM8550 属性表里） | **能**（5 hunk 全过，偏移 1/1/27/27） | ✅ 出 v2（已 rebase 到 linux-next，见 `patches/upstream/m2-a2-linuxnext-20261027/`） |
| **M2 P3** gamma LUT 越界 | **没有**（`_dpu_crtc_get_gc_lut()` 仍直接解引用 `state->gamma_lut->data`，无长度校验） | 未逐 hunk 验（P3 已投、无回包） | ✅ 保持 |
| **M3-1** dwc3 双连接器 | **没有**（`include/linux/usb/role.h` 无 `usb_role_switch_at_endpoint()`；`dwc3/core.c` 无 `port-select`） | — | ✅ 等 review 不变 |
| **M3-3** `aw88461` binding | **没有**（`bindings/sound/awinic,aw88461.yaml` = 404） | — | 保持封存 |
| **M3-4** panel nt36536 模式/时序 4 枚 | **没有** | **能**：4/4 顺序 `git apply` 成功（linux-next `panel-novatek-nt36536.c` 14107 B） | 保持封存 |
| **M4-1** 三枚 binding（gt9764 / s5kjns / wl2868c） | **没有**（三个 yaml 均 404） | — | ✅ 已投、无重复 |
| **M6 L1** DSI `PLL_SYSTEM_MUXES` | **没有**（linux-next 的 `0xc0` 写仍只在 `dsi_pll_enable_pll_bias()` 里；`dsi_7nm_phy_enable()` 未加） | — | ✅ 保持 |
| **M6 B5-P4** RFC | 未发 | — | 备料不变 |
| **M8** dispcc MDSS 复位 | **没有**（`dispcc-sm8750.c` 只有 resets 表 `.resets=`，probe 无 reset 调用） | — | 保持 |
| **M1-U6** `qcom_q6v5_pas` DTB 固件泄漏 | **上游仍有此泄漏**（成功路径 0 处 `release_firmware`；linux-next 只在 `qcom_mdt_pas_load()` 失败分支 `qcom_pas_metadata_release()` + `release_firmware()`） | **能**（`git apply --check` rc=0，直接套 linux-next） | ✅ 可直接投（等用户批准） |
| **aw86927 5 提交系列** | ⚠ **部分被上游占据** | **不能**：`0001/0002/0004` 可套，**`0003/0005` 冲突** | ⛔ 必须重构（见 §2） |

**一句话**：除 aw86927 外，全部系列在 linux-next 上都**没有**被重复实现；A2 与 U6 可直接在 linux-next 基线上出件。

## §1 方法（可复现）

```sh
export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890   # 本机代理；--noproxy '*' 直连不通
B='https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/plain'

# ① 存在性（binding = 404 即上游没有）
curl -sSL -o /dev/null -w '%{http_code} %{url_effective}\n' "$B/Documentation/devicetree/bindings/media/i2c/giantec,gt9764.yaml?h=master"

# ② 功能面是否存在（grep 目标符号）
curl -sSL "$B/drivers/power/supply/qcom_battmgr.c?h=master" | grep -c sm8750            # 0
curl -sSL "$B/drivers/remoteproc/qcom_q6v5_pas.c?h=master"  | grep -c release_firmware  # 1（仅错误路径）

# ③ 补丁能不能套（最小仓只放目标文件，git apply --check）
```

## §2 ★ aw86927 系列：上游已内置「驱动内波形」，我们的「固件装载」被半路占据

linux-next 的 `drivers/input/misc/aw86927.c`（24637 B）**已含 SRAM 波形装载**，但走的是
**驱动内置正弦表**，不是固件：

| 事实 | 位置 |
|---|---|
| `static const u8 aw86927_waveform[]`（二补码正弦，注释写明 `round(84 * sin(x / 16.25))`） | 文件 ~209 行 |
| `struct aw86927_sram_waveform_header` + `sram_waveform_header`（version 0x01 + start/end 地址） | ~224 行 |
| `aw86927_ram_init()` 里先写 header、再 `regmap_noinc_write()` 写波形、再走 VBAT 检测 | ~654–696 行 |
| **没有** `request_firmware()`（`grep firmware` = 0 命中） | 全文 |
| **没有** `AW86937`（`enum aw86927_model` 只有 `AW86927`/`AW86938`） | ~186 行 |
| `AW86938_PLAYCFG1_BST_7000MV 0x11` 仍在（我们的 `Fixes: 0x11→0x09` 依然成立） | ~51 行 |
| binding `awinic,aw86927.yaml` **已在上游**（200），我们的 0001 是**改**它（+AW86937 + firmware 属性），不是新建 | — |

补丁套用结果（逐枚 `git apply`，基座 = linux-next 的 `aw86927.c` + `binding` + `drivers/input/misc/Kconfig`）：

```
0001 rc=0   0002 rc=0   0003 rc=1（aw86927.c 冲突）   0004 rc=0   0005 rc=1（依赖 0003）
```

⇒ **两处硬冲突**：`0003`（固件波形装载）撞上上游刚加的内置波形 `aw86927_ram_init()`；`0005`（suspend/shutdown）依赖 0003 的上下文。

**这条印证了 U4 报告里预判的评审风险**（「维护者可能主张用驱动内波形、不要固件」）——**它已经发生了**。
三条出路（需你拍板，本轮不动）：

1. **放弃固件路径**：只交 `AW86937` 支持 + `BST 0x11→0x09` Fixes + suspend/shutdown，波形沿用上游内置表 —— 最小、最可能被收；
2. **固件作可选覆盖**：`firmware-name` 属性存在才用固件，否则用内置表 —— 保留能力、需论证为什么板级要换波形（本机现有 `/lib/firmware/awinic/y700-gen4-haptic.bin` 5881 B 是厂商波形）；
3. 整系列暂缓，先在列表上问「是否接受 firmware 覆盖」再动手。

## §3 M1-U6 的新事实（顺带核实）

linux-next 的 `qcom_q6v5_pas.c` 已经引入 `qcom_pas_metadata_release()`，但仍然**只在
`qcom_mdt_pas_load()` 失败分支**释放 `pas->firmware`/`pas->dtb_firmware`
⇒ 成功路径每次 `rproc_boot()` 泄漏一份 `adsp_dtb.mdt`/`cdsp_dtb.mdt`，**与 7.3-rc7 同病**。
我们的 `patches/upstream/m1-pas-dtbfw-20261027/` 在 linux-next 上 `git apply --check` **rc=0**
⇒ 补丁有效且无需改动，只等投递批准（顺带：基线说明要改成 linux-next，正文里「7.3-rc7 仅 1 处 release_firmware」的计数在 linux-next 变成 2 处，需要按新基线重写那一句）。

## §4 文档资产路径核对（同轮新增门禁）

同轮发现另一类「文档说谎」：三条 lane 的产物提交在各自分支上，主仓 `main` 只有收口总结
⇒ `TASKS/README.md §7` 与 `reports/upstream-status-20261027.md` 引用的 8 条路径**在主仓不存在**。
处置：

- 三个 lane 分支**已合入 main**（`ea6c518` b5-resoc、`41f9996` aw86927-series、`72acfd3` devcam-ab）；
- 新增 `scripts/check-doc-assets.sh`（前缀截断按 glob 解析 + 豁免表 `scripts/doc-assets-allowlist.txt`），
  并接进 `scripts/check-doctor.sh` **§13**：入口文档 + 最新 upstream 状态页里被反引号引用的
  `patches/ reports/ scripts/ rootfs/ packaging/ bootslot-b/` 路径必须存在（当前 `checked=384 missing=0`）。

## §5 下一步（按代价排）

1. **A2 v2**：等 §2 形状裁决后投 `linux-pm`（v2 已在 `patches/upstream/m2-a2-linuxnext-20261027/`，0E/0W/0C + 编译 0 warning）。
2. **M1-U6**：改基线说明 → 投 `linux-remoteproc`（Bjorn Andersson）。
3. **aw86927**：走 §2 的三选一；选 1 的话系列从 5 提交缩到 3 提交，重做很快。
4. 其余系列（M3-1 / M4-1 / M8）继续等 review，**不再加料**。
