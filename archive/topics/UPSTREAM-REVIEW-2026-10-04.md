# UPSTREAM-REVIEW — 本地内核树 vs 主线 v7.2 可上游性审查（2026-10-04）

> 证据层档案（只增不改）。方法＝机械检查（checkpatch / dtc / dt-validate / dt-doc-validate /
> 基线 diff）＋逐子系统人工阅读。基线＝`linux-7.2.tar.xz`（kernel.org，sha 见 §6），
> 被审对象＝`geekidos-linux` @ `elden/vk42-audio-thermal` `5a70ade46`（工作区干净）。
> **只审查，未做任何重构。**

## 0. 数字结论

| 指标 | 值 |
|---|---|
| 相对主线改动文件 / 改动行数(±) | **125 个 / ≈7077 行** |
| 相对主线新增代码文件 / 行数 | **11 个驱动/DTS / ≈5300 行**（另有 11 个 `arch/arm64/configs/*.config` 发行版片段，不计） |
| 其中最大件 | 板 DTS 3124 行、panel 驱动 545 行、camss 新代 ~700 行、ath12k PEACH ~800 行、hci_qca PERI 359 行 |
| bindings | 改 19 + 新 6，**dt-doc-validate 全过**；仅缺 `giantec,gt9764`（致动器）binding |
| checkpatch（elden 系列 9 补丁） | 9×ERROR＝**全缺 Signed-off-by**；17 warning（多为 commit 描述超 75 列）；代码风格本身干净 |
| checkpatch（9 个新驱动整文件 --strict） | **0 error / 0 warning / 2 check** |
| 板 DTS：dtc 编译 | 0 warning |
| 板 DTS：dt-validate | **仅 1 个红点节点**（`usb@a600000`，见 §3.4）；对照主线 `sm8750-mtp` 0 红点，验证器工作正常 |

**总体判断**：这套 payload ≈ 一个标准的「新 Qualcomm 平板上游化」工程。
**约 60% 的行数（DTS/camss/ath12k/panel/新 codec/regulator 一族）是主线本来就缺的硬件支持，方向正确、可以立项分批上游**；
约 25% 需要先重构结构（psci/dsi/audio 全局变量）；约 15% 是本地实验/发行版内容，**永远不进上游**（§4 D 类）。
前置阻塞：reboot-mode 系列未合并、ADSP 固件版本耦合、dm-default-key 走的是 Android vendor ABI。

## 1. 分类总表（A=可直发 / B=需重构 / C=有外部阻塞 / D=永不上游）

### A 类 — 立即可整编成上游补丁（改写 commit、加 SoB 即可）
| # | 内容 | 证据 |
|---|---|---|
| A1 | `dpu_hw_catalog.c`：sm8750 DSPP **GC 块补目录**（+6 行，上游漏项→CRTC GAMMA_LUT/Night Light） | `dpu_crtc.c` 以 `sblk->gc.base` 判定 color mgmt |
| A2 | `qcom_battmgr.c`：SM8750 QBG `power_now` 语义错误（GetMaxLoad 冒充瞬时功率，+103 行，GEEKiDoS 写的英文 commit 质量高） | commit `ba28ec16f` |
| A3 | `aw86927.c`：AW86937/938 SRAM 窗口 0x1000→0x2000（厂商 waveform 到 0x1ef5，原版直接 -EINVAL） | 纯修复 |
| A4 | `leds-qcom-flash.c`（522 行改动）：电源供给缺失/0 预算等健壮性修复 | 注释完整，可拆 |
| A5 | **板 DTS** `sm8750-lenovo-elden.dts` + `qcom.yaml` 登记（`lenovo,elden` L1125）+ `sm8750.dtsi` 节点补全（+478/−7） | dtc 0 warning；dt-validate 仅 1 红点（§3.4） |
| A6 | 新驱动一族（binding 齐、checkpatch 净）：`panel-novatek-nt36536`（去 D 项后）、`novatek-nvt36xxx-spi`、`s5kjns`、`gc08a8`、`wl2868c-regulator`、`aw88461` | 各自 yaml 全过 dt-doc-validate |

### B 类 — 功能正当、结构需重做后再发
| # | 内容 | 问题 → 上游姿势 |
|---|---|---|
| B1 | `psci.c` +37 行 vendor SYSTEM_RESET2（reboot→bootloader/edl，G1-24 S2 依赖） | 板级硬编码混进通用文件 → 改 `reboot-mode` 驱动+DT；上游对应 13-patch 系列**未合并**（commit 自注），当前钩子留作下游过渡是合理选择 |
| B2 | `aw86927.c` AW8693X 连续模式（反汇编厂商 ko，+82） | 0x7f/0x04/0xff 魔数应提升为 DT 属性+binding 更新；`haptic_hv_l/r` 参数已在 DTS |
| B3 | `hci_qca.c` +359 PERI 固件下载协议（WCN7861 ELF patch/TME） | 协议为高通下游私有；发 linux-bluetooth 需先谈接口，或推动固件重刷（参考 wcn7850 上游路径） |
| B4 | q6apm-lpass-dais **start-at-prepare**（+36，MI2S 时钟顺序/BE-before-FE） | 上游有同类讨论，做成通用修复+回归说明可谈（ALSA devel RFC） |
| B5 | `dsi_host/dsi_phy_7nm/dsi_manager/dsi.h` 一族（~940 行：`dsi_clk_init_6g_v2_9`、bonded polling、intr 管理） | 散落的 `of_device_is_compatible("qcom,sm8750-dsi-ctrl")` → 上游要求收进 per-SoC cfg 结构；拆 3–4 个功能补丁 |
| B6 | `ath12k` PEACH/WCN7861 hw2.0 支持（qmi/wifi7/core ~800 行，TME-lite、board_api1_only） | 新增 HW 支持是 ath12k 维护者明确接受的类型；需拆分「框架扩展（tmel/board_api1）」与「PEACH 数据表」，附固件名与来源声明 |
| B7 | `pwrseq-qcom-wcn.c` +591（WCN7861 上电时序）+ `include/linux/pwrseq/qcom_wcn.h` | 若为新芯片时序数据，可上游；需与 binding（qca6390-pmu.yaml 已改）配套说明 |
| B8 | camss 一族（`camss.c` +367、新 `camss-csid-980.c`/`camss-vfe-gen4.c`、csiphy +120、video/vfe 改）＋ 3 个 sensor/actuator subdev | **最有价值块**：SM8750 camss 主线缺失。要过 media 框架审查（新代 VFE/CSID 数据化、mc API 合规）；gt9764 补 binding |

### C 类 — 外部依赖/上游未合，先挂账
| # | 内容 | 说明 |
|---|---|---|
| C1 | 音频 ADSP 耦合：`q6apm.c` GET_SPF_STATE 带 APM 头、`audioreach.c` **全局** `apm_src_port` setter/getter | 上游必然 NAK 跨模块全局变量 → 收进 `struct q6apm` + per-SoC compat 判定；根本问题=本机 ADSP 是下游 SPF 行为，需按 firmware variant 分支（或验证新版 ADSP 是否收敛到上游行为） |
| C2 | `dm-default-key` + `fscrypt` ABI（`__FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED`，Android wrappedkey_v0） | 上游不收 hfscrypt 风格 vendor key ABI；这是 **G2/Waydroid 需求**——建议从上游包剥离，作为持久根 out-of-tree patchset 维护 |
| C3 | `a6xx_catalog.c` +304 GGX 寄存器 init | 上游规则逐寄存器说明用途（regcat 清洗工作量），暂挂 |
| C4 | `clk.c` orphan reparent / `gdsc` / `dma-iommu` fixed MSI IOVA / `arm-smmu` 改动 | 核心框架改动需通用复现与论证，暂挂；先查是否可被上游新补丁取代 |
| C5 | `sm8750.dtsi` 中 −7 行（q6apm/q6prm service reg、PCIe iommu-map） | 与 C1/B3 关联，待其定型 |

### D 类 — 永不进上游系列（发上游前从系列剔除）
| # | 内容 |
|---|---|
| D1 | `dsi_host.c` timing `dev_info` 调试打印（+7） |
| D2 | panel `force_hz` 模块参数测试钩子 |
| D3 | `btqca.c` `tlv_nvm->data[1] &= ~0x01`（WCN7861 IBS 全局禁用；**根因未定**，bt-link 假设 H4/H2 未判别完——且它改变所有 WCN7861 板行为） |
| D4 | `ath12k/mhi.c` `MHI_TIMEOUT 90000→3000` 全局改动（掩盖 WCN 上电时序，正确解=probe defer；注释自己承认靠 bind 重探） |
| D5 | vk 系列实验历史（vk40 调试插桩、vk34-recon 回退、vk48 draft）——发上游须压平重排 |
| D6 | `arch/arm64/configs/*.config` 11 个发行版片段（上游只谈 defconfig 开关） |
| D7 | `usb-psy-name` 等 vendor-only DT 属性（板 DTS 里，连带 schema） |

## 2. 流程性缺口（代码之外）
1. **commit 规范**：elden 系列 9 个 commit 全中文、0 个 `Signed-off-by`；上游要按子系统拆系列、英文、
   `get_maintainer.pl` 收件人、cover letter、`Tested-by` 链。GEEKiDoS 基底那 1 个 commit 是合格范例。
2. **浅克隆**：本树 git 历史只有 1 个 commit，GEEKiDoS 基底无法追溯——本审查用基线 tarball diff 补齐。
   上游化工程需另起干净的「upstream tip + payload 重放」树，不在本树上做。
3. **发行版内核**：GEEKiDoS 树是发行版内核；本项目 diff 已可独立剥离（本档案的 125+11 文件清单即边界）。
4. `patches/candidate-*.patch`（BT/TF 共 9 个）全部是诊断/实验提案（标注 DO NOT COMMIT），与上游包无关。

## 3. 机械检查详情
1. **checkpatch --strict**：elden 系列 9 补丁合计 9E/17W/1C；唯一 ERROR 类型=Missing Signed-off-by。
   完整输出：`/tmp/upstream-review/checkpatch-full.txt`（临时）；系列导出于同目录 `elden-series/`。
2. **新驱动整文件 --strict**：9 文件 0E/0W/2C（wl2868c 宏参数复用 CHECK ×2）。
3. **bindings**：改动 19 + 新增 6 全部 `dt-doc-validate` 通过；缺 `giantec,gt9764` binding（驱动在 `drivers/media/i2c/gt9764.c`）。
4. **板 DTS dt-validate 红点**（唯一）：`usb@a600000 (qcom,sm8750-dwc3)` 被 `qcom,snps-dwc3.yaml` 拒绝——
   缺 `usb-role-switch`、`dr_mode` 期望 `otg`、且 `port-select-gpios/ports/usb-psy-name/…` 17 个属性 unevaluated。
   根因=把 vendor dwc3 属性直接写进容器节点 + 自改的是 `snps,dwc3-common.yaml` 而非 qcom wrapper。上游 CI 会红。

## 4. 建议的推进顺序（不在本轮执行）
1. **M1 上游资产树**：干净 `linux-6.x-tip` fork + 按本清单文件级重放（不带 vk 历史/config/D 类）。
2. **M2 首发小系列**（练手+建立联系）：A1+A2+A3（各 1 补丁，独立、可测、含 Fixes: 标签）。
3. **M3 板支持系列**：A5+D7 清理+修 §3.4 红点 → qcom-soc DT 列表（binding 先行）。
4. **M4 大件立项**：B8 camss（media）、B6 ath12k（wifi）各成一个多轮 review 工程；B3/B1 跟踪上游系列合入。
5. **M5 剥离项**：C2 dm-default-key 移出上游包，进持久根 patchset。

## 5. 与其他文档的关系
- G1-24（psci reboot）的「上游合入后可替换」预判在本档案 B1 落档。
- BT D3 判定依赖 bt-link 的根因结论，未定稿前 D3 保持实验状态。
- 任务台账：`TASKS.md §7 M1–M5`。

## 6. 取证命令与可复现性
```
基线: https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.tar.xz (160,068,116 B, sha256 见下)
diff: git ls-files -co --exclude-standard {drivers,sound,include,arch,net,fs,mm,kernel,lib,...} × cmp
checkpatch: scripts/checkpatch.pl --strict --no-tree /tmp/.../elden-series/*.patch
DT:  cpp -nostdinc -I include -undef -x assembler-with-cpp <dts> | scripts/dtc/dtc -@ -I dts -O dtb
     dtschema(venv) dt-validate -s Documentation/devicetree/bindings <dtb>; dt-doc-validate <yamls>
```
sha256(linux-7.2.tar.xz) = `f9fef3d14c0df53819026f4be74459835c2a0b0dcbf5b5bbd9ea19f0829402b3`；工具链：树内 `scripts/dtc/dtc`、pip venv `dtschema`。

## 7. M2 执行记录（2026-10-13 追加；本节只增）

- **准备完成（未发送，等用户点头）**：基线 = upstream **v7.3-rc7**（`24a19b953e`），工作树 `build/m2-worktree`（分支 `m2/series`），产物 `patches/upstream/m2-2026-10-13/`。
  - Patch 1 `8d70ccd476` drm/msm/dpu: add the missing GC block to the SM8750 DSPP catalog（+7 行）→ To dri-devel + linux-arm-msm。
  - Patch 2 `9995d8a131` power: supply: qcom_battmgr: do not report power_now on SM8750（+27/−2）→ To linux-pm + Sebastian Reichel。
  - 两枚**独立成帖**（非 series）；`checkpatch --strict` = 0/0；`make … dpu_hw_catalog.o qcom_battmgr.o` 仅 CC 行、无 warning；`git send-email --dry-run` 两路均 `Result: OK`。
- **A3 分类更正**：上游 v7.3-rc7 的 `aw86927.c`（882 行）**没有** firmware waveform 装载路径（无 `request_firmware()`/`aw86927_ram_load()`/`AW86937`），而「SRAM 窗口 0x1000→0x2000」只对那条路径有意义 ⇒ 无对应上游代码可修补，**从 A 级降为 B/C 级，不进 M2**。
- **A2 的新增事实**：上游 binding 已有 `qcom,sm8750-pmic-glink` 且 `sm8750-mtp/qrd` 已在用，但 `qcom_battmgr_of_variants[]` **没有该条目** ⇒ SM8750 回落到 SM8350 变体并暴露错误的 `power_now`（本补丁补变体+描述符）。

## 8. M2 投递结果（2026-10-13 追加）

- Patch 1 `drm/msm/dpu: add the missing GC block to the SM8750 DSPP catalog`：Message-ID `20261013002124.332074-1-xiaqinghuan@mail.ustc.edu.cn`；`git send-email` 250 OK；**linux-arm-msm 已归档**（raw 复核，body sha256 `b8fu5G/OnuGOyXYY…`）。
- Patch 2 `power: supply: qcom_battmgr: do not report power_now on SM8750`：Message-ID `20261013002124.332111-1-xiaqinghuan@mail.ustc.edu.cn`；**linux-pm / linux-arm-msm / lkml 已归档**（同一 body sha `xg0wufdtQ6dk83lO…`）。
- `dri-devel` / `freedreno` 在 lore 无对应 inbox（归档在 lists.freedesktop.org）；如 48 h 后无回音，考虑单独 ping 或改走 `freedreno` 镜像。
