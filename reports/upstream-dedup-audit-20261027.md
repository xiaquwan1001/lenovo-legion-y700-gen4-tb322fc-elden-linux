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
| **aw86927 5 提交系列** | **没有**（驱动内波形表上游早有，来自 `df53055c540f`；无 `AW86937`、无 `request_firmware`） | **能**，`0003` 只需 1 行 include 漂移即可套；`0005` 属系列内依赖 | ✅ 已重切为 **v2（5 枚，去固件 + 拆 `Fixes:`）**，见 §2 |

**一句话**：**全部系列**在 linux-next 上都没有被重复实现（aw86927 的「被占据」是上一版误判，已纠正，见 §2）；A2 与 U6 可直接在 linux-next 基线上出件。

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

## §2 ★ aw86927：先纠正本报告上一版的错判（已重切为 v2）

**上一版这一节写错了**，写成「上游半路占据了波形装载，10-13 的结论两周就过时」。实际是：

| 事实 | 出处 |
|---|---|
| 上游**驱动内正弦表早就在**（`aw86927_waveform[]` + `sram_waveform_header` + `aw86927_ram_init()` 写入路径） | `df53055c540f`「Input: aw86927 - add support for Awinic AW86938」，**7.3-rc7 就含**（`grep -c aw86927_waveform` = 3） |
| U4 报告说的是「上游无**固件**装载路径」——这句**一直是对的** | `reports/u4-aw86927-sramwindow-20261027.md`、v1 README「hardcodes one sine waveform ... no request_firmware() path」 |
| linux-next 相对 7.3-rc7 在这个文件上**只漂移 1 行**（新增 `#include <linux/interrupt.h>`） | `diff` 该文件 = 3 行增删（含 diff 头） |
| 因此 `0003` 套不上的真因 = 那行 include 落在它第一个 hunk 的上下文里 | `git apply` 报错行号 10（include 块） |
| `0005` 套不上 = 上下文含 `0003` 新增的行，**系列内依赖**（本来就该最后套） | 0005 hunk 上下文 `u32 waveform_index;` |

⇒ 「必须重构」的理由不成立（改 1 行 include 就能套）。**但重构仍然做了，理由换成更站得住的一条**：
把「用厂商固件替换上游内置正弦表」当第一炮打是最容易被否的一块（要论证板级波形、DT 属性、校验格式），
应先交无争议部分。**v2 = 5 枚**：`Fixes: 0x11→0x09` 单枚 + binding(AW86937) + AW86937 驱动 + AW8693X 寄存器布局 + suspend/shutdown；
删掉固件装载与随它而来的 SRAM 几何数据表。门禁：逐提交编译 5/5 rc=0、`checkpatch --strict` 4 枚 0E/0W/0C
（0001 有 1 W = 本地仓 shallow 认不到 `Fixes:` 的 commit id）、`dt-doc-validate` rc=0、**linux-next 上 5/5 顺序 apply OK**。
产物 `patches/upstream/aw86927-20261027-v2/`，报告 `reports/aw86927-series-v2-20261027.md`，v1 目录已加 ⛔ 取代标记。

**教训**：①「没有固件装载」≠「没有波形装载」，读结论要连谓语一起读；②`git apply` 失败先看失败 hunk 的行号与上下文再归因；
③ 去重核对照做（binding 404 / apply 检查），但归因要分层。

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
3. **aw86927**：v2 已成型待批准投递（`linux-input`，To Dmitry Torokhov）；固件波形留作后续 RFC。
4. 其余系列（M3-1 / M4-1 / M8）继续等 review，**不再加料**。
