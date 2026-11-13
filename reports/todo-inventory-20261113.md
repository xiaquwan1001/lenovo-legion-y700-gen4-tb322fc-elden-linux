# 当前待办 + 待测 全量清单（2026-11-13）

> 性质：**规划盘点**，不是新的 SSOT。状态词只用「未解 / 未证实 / 未上机」；「已修复」≠「已验证」。
> 本文件**不写状态数字**（不抄旧文）：G1/G2 完成度只看 `scripts/check-progress-counts.sh`，
> 在机镜像/槽位只看 `DEVICE/README.md` §1.1，版本账只看 `versions/vk-registry.tsv`，
> 上游投递只看 `reports/upstream-status-20261113.md`。
>
> **本轮/近两轮权威增量（用户指定，冲突时以它们最新口径为准）**：
> `reports/upstream-status-20261113.md`、`reports/mail-triage-20261112.md`、
> `reports/camss-v6-rebase-plan-20261113.md`、`reports/upstream-merge-candidates-20261112.md`、
> `reports/git-tidy-20261113.md`、**`reports/upstream-74-replay-20261113.md`（最新，2026-11-13 17:58）**。
> 辅助：`reports/upstream-watch-20261113.md`、`DEVICE/README.md` §1.1/§1.4/§2.2、`TASKS/README.md` §1/§2/§4/§5/§7、
> `reports/uefi-vk188-fbcon-20261112.md`、`reports/t14-userland-recipe-20261111.md`。
>
> **A 与 C 的关系**：A = 「需要用户放行/裁决」的闸门（发信、上机、写盘、凭据）；C = 设备侧待测清单本体。
> 同一事实可能两边都出现（C 里标「闸门 = A**n**」），**两份计数各自独立**，不重复算工作量。

---

## A. 待用户裁决 / 批准（24 条）

| # | 一句话 | 阻塞点 | 证据指针 |
|---|---|---|---|
| **A1** | 回 **mdss v3 2/3** 的 Dmitry 两问（INT2 是否中断控制器 / 不 reset 的副作用与测法）并重发 **v4** | **✅ 已推进（2026-11-14）：v4 已发（11-13，4×250，patchwork 14978766/67）；收到 Konrad R-b + sashiko Medium 质疑（0xa000 是未 attach 的独立域）；质疑成立 ⇒ 已回信（承认 + 给出测量边界 + 无 datasheet 直证）并发 v5（3/3 只改 message、diff 逐字节相同，4×250）。等维护者回信；若被要求则发 v6 删 3/3** | `reports/mail-triage-20261112.md` §5 W2；`upstream-watch-20261113.md` §A（14931324）；`TASKS/README.md`:1320 |
| **A2** | **dpu gamma LUT 出 v2**：补 `Fixes: 39a750ff5fc9`，正文与已给的 RV 原样保留 | 新版本 = 发信，需批准（备料 → B5） | `mail-triage-20261112.md` §3.1 T3 + §5 W3 |
| **A3** | **dsi/phy v1 → 决「出 v2」还是「撤回并说明上游已覆盖」** | Dmitry 只要注释搬家；但 `upstream-74-replay-20261113.md` §3 证明 **7.4 上游 `dsi_pll_enable_pll_bias()` 已等价写 `0xc0`** ⇒ 在 7.4 上语义重复 ⇒ 先裁决基线（见 X10），再决定动作 | `mail-triage-20261112.md` §3.2 Q3 + §5 W4；`upstream-status-20261113.md` §2 dsi/phy 行；`upstream-74-replay-20261113.md` §3 |
| **A4** | **dwc3 v9**（Rob 结构性要求：`port@0` 双 endpoint / 删 `port@2` / `port-select-gpios`→gpio mux） | **当前不具备投递条件**：driver+DTS 未改；`mux_control_select` 持锁与 role-switch 回调（可能中断上下文）兼容性未评估；工作量最大、未排期 | `mail-triage-20261112.md` §5 W5 + §6.1-3；`upstream-status-20261113.md` §2 dwc3 行；`patches/upstream/dwc3-v9-draft-20261111/` |
| **A5** | **elden 板 DTS 串**按 Krzysztof 意见收成**单个「add new hardware」提交**并重发（v6 之后 dts 串一直未再投） | 发信批准（备料 → B8）；且与 camss v6 binding rebase、7.4 重放的先后顺序要排 | `upstream-watch-20261113.md` §A（14942836）+ §D #2；`TASKS/README.md` §7 M3 行 |
| **A6** | **haptics aw86937 出 v2**：采纳 bot 两条（`GENMASK(6,5)`、`devm_add_action_or_reset`） | 发信批准（备料 → B9）；AW8695/AW8697 同 binding 文件冲突风险 | `upstream-status-20261113.md` §2 haptics 行；`upstream-watch-20261113.md` §A（14918448）+ §B6 |
| **A7** | **counter/dispcc reset RFC**：出 v2（挪 display 侧 + `reset_control_*` + simple-framebuffer 在场对照）**或直接撤** | 两轮追问 0 维护者回信；二选一需裁决 | `upstream-status-20261113.md` §2 counter/dispcc 行；`upstream-watch-20261113.md` §A（14909706） |
| **A8** | **M6 / dsi bonded 5 连发重做**（删无保护对象的锁、明确 base、主从按 DT 推导、per-SoC cfg 收敛到 sm8650 字段、块注释格式）并重切投递 | 全串 patchwork `handled-elsewhere`（等于未收）；4 枚备料受 §7 M6 三条复启条件约束；**7.4 重放后 base 要改成 7.4-rc3 线**（X10）；发信批准 | `upstream-watch-20261113.md` §A（14929539/42/43）；`TASKS/README.md` §7 M6 行 + §4:172；`patches/upstream/m6-b5-v2-20261102/` |
| **A9** | **camss 改接 Qualcomm v6 后上机验证出流**（2.3.0 路线；B1 对账已于 2026-11-13 夜完成 ⇒ **前提已变，见右**） | 上机需批准。**★B1 复核结论（`reports/b1-csiphy-recheck-20261113.md`）：我们的树已有 2.4.0 且在役**（`CAMSS_8750` 走 `lane_regs_2_4_0`、103/103 地址与 vendor 相同、仅 4 条 SKEW_CAL 分歧）⇒ **接 v6 是降级到 v2.1.2 表**，A9 优先级应下调 | `reports/camss-v6-rebase-plan-20261113.md` §2/§5；`upstream-status-20261113.md` §2 相机 camss 行 |
| **A10** | **UEFI 线上机两发**：① 验 `out/boot-elden-vk188b.img` 的 initrd 修复；② A2 臂复测 pstore console 是否还 Oops | 需 `fastboot boot` 放行；**ESP `BOOTAA64.EFI` 现为 v5（A2 + `panic=0`）会挂住不重启**，用人前必须先 `--activate` 回 v3b | `reports/uefi-vk188-fbcon-20261112.md` §3/§6/§7.1-2；`TASKS/README.md`:160 |
| **A11** | **G1-29 剩余两件**：`boot_a` 冷启动（物理 POR）回归 + 屏上 BDS/GRUB 菜单交互取证 | 需物理断电/人盯屏；`boot_a` 现 = UEFI pc1，需先 `set_active a` | `TASKS/README.md`:51（§1 G1-29 行「剩余」）；`DEVICE/README.md` §1.1 首条 |
| **A12** | **Gunyah S2 上机对照实验**：`gh_vmtest` 最小探针（4 MiB LEND + 1 vCPU + 16 B，不走 crosvm），并做「故意喂违规 DTB 看错码是否变 8」 | 需用户排期；前提 = 补 B15 两空（未证实 `0xA` = RM 太老还是状态机 bug）；风险自限：全程 `fastboot boot`、不 `fork()` 持 lend 页 | `TASKS/README.md`:175-176；`reports/gunyah-73-port-20261112.md`、`gunyah-s1-static-diff-20261111.md` |
| **A13** | **C3 唯一剩余动作**：装 SPIC 取一次三档（BASIC/DEVICE/STRONG）回包 | 需批准装 APK；判据表含「全绿则推翻现判读」 | `TASKS/README.md` §2 C3 行 + §5 Q1（:1090）；`reports/c3-pi-tiers-closeout-20261110.md` |
| **A14** | **C5 只剩 U7 App 实开预览**（容器已识别 1 个相机、`/dev/video100` bind 已持久化） | 需上机 + 人开 App 看预览 | `TASKS/README.md` §2 C5 行（:90） |
| **A15** | **C9 十用例打分表出数**（`README.md §6` §5 的 10 条用例 + 阈值） | 模板就绪，未上机打分 | `TASKS/README.md` §2 C9 行（:94）；§5 Q6（:1095） |
| **A16** | **Q5 残余两项**：30 s 传感器 CSV、5 App 录屏 | 需人工 + Google 账号；**只能在 U1 的 stock a 槽采**（U2 a 槽已被 UEFI pc1 覆盖，见 X6） | `TASKS/README.md` §5 Q5（:1094）；`DEVICE/README.md` §1.1 + §2.2 |
| **A17** | **T18 充电抖动现场复现**：等下一次抖动，用户跑报告 §4 三条只读现场命令（30 s 定候选表）；补负向测试 | 必须有人在机旁插拔/换口；驱动拒绝手动降档（`echo 100000 > input_current_limit` 报 I/O error）⇒ 负向只能等真实重插 | `TASKS/README.md`:177；`reports/t18-charging-timing-20261111.md`、`t18-usb-charging-triage-20261111.md` |
| **A18** | **G1-38 真机四类样本**（Firefox/GTK3/Qt 各一例：弹起·失焦收·Alt+Tab 漏收·无抖动）；候选窗若重做，验收必须先证「组字期间 `NotifyFocusOut` = 0」 | 需人在解锁后的桌面会话操作；候选窗方案 A 已实测更糟并撤下 | `TASKS/README.md` §1:60-64 + §4:141；`PITFALLS #644/#645/#646` |
| **A19** | **`qbootctl.service` 受控窗口对齐**（设备用 distro 包单元，仓库却声明 override） | 审计标「**高风险，需受控窗口**」；动的是槽位/启动计数单元 | `TASKS/README.md`:144；`reports/script-redundancy-audit-20261112.md` §3 |
| **A20** | **`reboot edl` 真机 9008 触发实测**（DLOAD TCSR 已补好，`dtbs`/`dtbs_check` 绿，真机未验） | 需用户同意承担一次进 EDL | `TASKS/README.md` §1 G1-24 行（:46）+ §5 Q23；`reports/twrp-parity-edl-dload-20261020.md` |
| **A21** | **U1 mainline 重做 GPT 手术**（U1 已逆手术：`linux17` 删、`/data` 回 211 GiB） | 写盘高风险，需批准 + 三选一备份；U1 现是唯一「stock a 槽 + root」单元，做完即丢 | `DEVICE/README.md` §2.2/§2.3；`TASKS/README.md` §5 §4 风险登记 |
| **A22** | **上游合并候选「可选 9 条」（#4–#12）是否排期**（pinctrl UAF / uefisecapp 溢出 / dwc3 ×3 / camss ×1 组 / drm-msm ×2 / ath12k ×2 / cmd-db ×1） | 改 `build/daily` 内核树 + 需上机回归；**批 1（必修 3 + 顺带 3）已随 vk189 上机，可选 9 条未批准** | `TASKS/README.md`:142；`reports/upstream-merge-candidates-20261112.md` §0 + §2 批 2/批 3 |
| **A23** | **GitHub 侧 `attic/*` tag 补推**（hook 拒绝、120 s 超时；USTC 已有） | 需 PAT / 网页手动，agent 不代填凭据 | `reports/git-tidy-20261113.md` §1「仍未收束」+ §5.2 |
| **A24** | **`patches/` 大目录是否立项裁剪**（`patches/upstream/` 40 个系列目录、`patches/uefi/` 225 件） | git-tidy 明确「合并会破坏审计链 ⇒ 如需精简应单独立项」⇒ 需裁决是否立项、按什么判据裁 | `reports/git-tidy-20261113.md` §5.3 |

---

## B. 可自主推进的主机侧任务（20 条，不占设备、不需要发信）

### B0（★用户指定第一条候选）：把现役 payload 重放到上游 7.4-rc3 线

| 项 | 内容 |
|---|---|
| 目标 | 以 `build/daily`（7.3.1 + payload v2 `88cd0bc0f4f`）为源，重放到 `gh/master = 9d66f26fefa`（7.4-rc3 线），解 15 文件 / 19 hunk 冲突 → 出可编译树 → 再上机（C-U0） |
| 已验数字 | **107 文件自动干净 + 26 新文件自动落地 + 15 文件 / 19 冲突 hunk**；显示/DSI/camss/ath12k/remoteproc/`sm8750.dtsi` **零冲突**；对照组（从 `linux/` 7.2 快照出发）是 27 文件 / 46 hunk（2.4 倍） |
| 真需判断的 3 处 | `pcie-qcom.c`（上游重写 `iommu-map` 解析，4 hunk）、`dpu_encoder_phys_vid.c`（我们删了上游 DSC `timing->width` 缩放块，**回退来源要查清**）、`q6apm` 组（3 文件相邻插入） |
| 必须顺手收窄 payload | ① `panel-novatek-nt36536.c` 上游已有（Pengyu Luo），我们只剩 8 行 delta；② `PLL_SYSTEM_MUXES=0xc0` 上游 `dsi_pll_enable_pll_bias()` 已等价 ⇒ **retire**；③ `rpmhpd skip_retention_level` 上游无条件 skip ⇒ **删字段保语义**；④ `rpmhpd presync_floor` 上游没有 ⇒ 保留但重写形状 |
| 硬禁忌 | 不 cherry-pick treewide `devm_kzalloc_obj`（202 文件，正是多数机械冲突来源）；不从 `linux/` 出发；`git worktree` 用完必须 `remove` + `prune`（否则 `check-doctor` 身份账漂） |
| 判据 / 时间盒 | `dtbs_check` 对 `sm8750-lenovo-elden.dtb` 0 诊断 + `scripts/build-kernel.sh`（禁裸 `make`）+ `make -j26` + `.ko` 数与在机树比对；估 **半天到一天 / 2–3 个 agent 轮次** |
| 证据 | `reports/upstream-74-replay-20261113.md` §0–§4/§6；原始记录 `reports/artifacts/r74-20261113/{replay-conflicts.txt,replay-status.txt}` |
| 注意 | 「上 7.4」的价值 = **换基线，不是取功能**（`upstream-merge-candidates-20261112.md` §0.2：master 相比 7.4-rc2 只有 treewide 机械转换）；且它**不替代** A22 的可选 9 条 |

| # | 一句话 | 退出条件 / 判据 | 证据指针 |
|---|---|---|---|
| **B1** | **camss CSIPHY 对账**：用**现成** `gh/master`（`9d66f26fef`，7.4-rc3，`build/m3v2-7.3rc7` 部分克隆里已有）先确认 `csiphy_res_kaanapali` 是否在 7.4 内；在则与 vendor 2.4.0 表（2ph 103 条 / 3ph 72 条）逐条比地址+掩码；不在则记录「须等 v6 合入」 | **✅ 已收口（见右）** | 产出差集表（有差集 ⇒ 备 2.4.0 delta；无 ⇒ 接 v6）；**「7.4 是否含 kaanapali 表」当前未证实**
| **B2** | **camss `0007`（起流失败回退）**独立价值评估（v6 不碰 `camss-video.c`） | **✅ 已收口（2026-11-13 夜）：已由我们自己的 v2 系列覆盖，不再独立投**——`b2-camss-0003-recheck-20261113.md` | `camss-v6-rebase-plan-20261113.md` §1/§5.3 |
| **B3** | **mdss 2/3 取证**：查 `sm8750 dispcc` 复位表与 `msm_mdss.c` 里 `mdss_intr` 实际用法，写准「是不是中断控制器」+ 副作用（command DMA timeout / 只有背光无 DRM 设备）+ 测法 | 三段文字可直接进 commit message（供 A1） | `mail-triage-20261112.md` §6.1-2；`upstream-watch-20261113.md` §A（14931324） |
| **B4** | **dsi/phy v2 备料**（注释搬进 commit message，代码只留 `writel(0xc0, …)` + 一行理由）——**若 A3 裁决为「撤回」则本项改产出「上游已覆盖」的撤回说明** | `checkpatch --strict` 0/0/0 + `git am` 干净 | `mail-triage-20261112.md` §5 W4；X10 |
| **B5** | **dpu gamma LUT v2 备料**：加 `Fixes: 39a750ff5fc9`，正文/RV 原样 | 同上 | `mail-triage-20261112.md` §3.1 T3 |
| **B6** | **dwc3 v9 三件改造**：`drd.c` 改 `devm_mux_control_get` + `mux_control_select(…, endpoint->mux_state)`；sm8750 DTS 改双 endpoint；删 `port@2`；跑 `dt_binding_check` + `dtbs_check`；**评估持锁与 role-switch 回调兼容性** | 门禁全绿 + 兼容性有结论；否则回 A4 说明不可投 | `mail-triage-20261112.md` §5 W5 + §6.1-3 |
| **B7** | **fastrpc 证据包**：为「为什么不能简单写 non-secure」备寄存器/固件证据；跟踪 `accel/qda` v4、`deprecate qcom,nsessions`、Ard 的 32 MB pool | 一页证据可答 Konrad；并给 M10 v3 是否改形状下结论 | `upstream-status-20261113.md` §2 fastrpc 行；`upstream-watch-20261113.md` §B3/B4/B5 |
| **B8** | **elden 板 DTS 单提交备料**（合成「one logical action」）+ 与 camss v6 binding、7.4 重放的依赖图 | `dtbs_check` 绿 + 顺序写清（供 A5） | `upstream-watch-20261113.md` §A（14942834/14942836） |
| **B9** | **haptics v2 备料** + MAINTAINERS 冲突核查（AW8695 Griffin v3 / AW8697 armandas v3 用同一 `awinic,aw86927` binding 文件） | 冲突结论 + 两点已采纳（供 A6） | `upstream-watch-20261113.md` §A + §B6 |
| **B10** | **dispcc reset RFC v2 备料**（挪 display 侧、`reset_control_*`、补 simple-framebuffer 在场对照） | 备料完成即交 A7 裁决「发 or 撤」 | `upstream-watch-20261113.md` §A（14909706） |
| **B11** | **可选 9 条逐枚 `git apply --check` 冲突预处理**（camss v2 四连在 daily 有 2 处冲突、drm dp 有冲突、UBWC 只取 1/7+3/7） | 逐枚 rc 记录 + 冲突裁决建议（apply 等 A22） | `TASKS/README.md`:142；`upstream-merge-candidates-20261112.md` §1/§2 |
| **B12** | **SN 锚定剩余**：① UEFI（Mu）侧 SMBIOS/`SerialNumber` 是否锚原厂 SN（未核）；② `adb`/Waydroid 侧是否也暴露常量 SN；③ initramfs 内 gadget 待下次重建 ramdisk 才生效（脚本已改） | 三问各给「是/否 + 证据」；认设备权威判据仍 = `fastboot getvar serialno` | `TASKS/README.md`:145；`PITFALLS #549/#626` |
| **B13** | **脚本欠账**：写死 SN/IP 5 条、默认输入已删 5 条、模块部署三套实现 1 条；把「a 槽 dtbo 清零」写进设备分派脚本 | `scripts/verify.sh` FAIL=0；分派脚本幂等 + 带备份/读回 | `TASKS/README.md`:144 + §1 G1-29 行（:51）；`script-redundancy-audit-20261112.md` §3 |
| **B14** | **T14「Mobian 换根重建 recipe 可执行化」**（★2026-11-14：S3/S4/S6 三步已实现在 `elden-firmware/paths-qcom.txt` + `stage.sh` 并已离线复核——`reports/t14-s3s4s6-offline-verify-20261114.md`；剩余只有「自家 ELF 不可重建」= hapticd/sensord/ffrumble）：P0 chroot → R1 dry-run → R2 `all.sh --apply` → R3 门禁 → R4 `render.py` | R1–R4 全绿；D1–D5 部署验收留设备（C-U8） | `TASKS/README.md`:157；`reports/t14-userland-recipe-20261111.md`（含 4 个需人决策项） |
| **B15** | **Gunyah 必须先补的两个空**：读 `iceland` 16 补丁正文（逐条）；反汇编本机 `gh_rm_drv.ko`，确认 RM 是否认 `0x51000018`/`0x56000032-34` | 结论 = `0xA` 是「RM 太老」还是状态机 bug（决定 A12 是否值得上机） | `TASKS/README.md`:175-176；`reports/gunyah-s1-static-diff-20261111.md` |
| **B16** | **QEMU 复刻 `GRUB → vk188 → 串口 dmesg` 全链**（`-device ramfb`；`-M virt` 必须 `acpi=off`） | QEMU 内能看到 `Linux version` + dmesg ⇒ 替掉 UEFI 线拍屏取证 | `uefi-vk188-fbcon-20261112.md` §5（未完成项）；`qemu-usage-survey-20261112.md` §3 |
| **B17** | **分诊盲区修补**：① `b4`/查 `next`/`drm-misc-next` 核 maintainer 树是否已悄悄应用；② `/covers/` 全量 54 个按窗口过 comments；③ 把「在审系列清单」固化进 TASKS 口径 | 盲区 U1/U6/U7 关闭；「0 已合并」只对 patchwork 侧成立的限定写清 | `mail-triage-20261112.md` §6.2 U1/U6/U7 |
| **B18** | **相机闪光灯两缺口主机侧备料**：libcamera 不认 `MEDIA_ENT_F_FLASH`（`cam` 无闪光灯控制）+ flash LED NTC 温度监控 | 代码/补丁可编译；上机归 C-U6 | `TASKS/README.md` §1 G1-5 行「闪光灯」段；`patches/0013-flash-led-ntc-thermal.patch` |
| **B19** | **升 phoc 0.59~rc1 退役一份本地补丁**（0.58→0.59 唯一相关 diff = 我们自己已进上游的 `bb1f7465`） | 退役后 `verify.sh --rebuildable` 仍 FAIL=0；**明确写清「OSK 不弹不因此解决」**（版本门逐字未变） | `upstream-merge-candidates-20261112.md` §0.5 + §1b；`PITFALLS #615` |

---

## C. 必须在设备上做 / 待测（28 条）

### C-U：已改代码/已出件/已画出路径但**未上机验证**（14 条）

| # | 项 | 现状（未上机） | 判据 | 证据指针 |
|---|---|---|---|---|
| **C-U0** | **7.4-rc3 重放树的上机验证**（B0 产出后第一步） | 只做了 worktree 演练，**树未建、未编、未上机** | `fastboot boot` 零写盘一发，判据 = vk185 那 10 项（10 s SSH / DSI connected / 2 张声卡 / WiFi 关联 / `/dev/fastrpc-adsp` + `qrtr svc 400` + SensorProxy 三项 / zram / 温度）**另加**：Night Light 色温（GC 块）、相机 5 帧、`dmesg \| grep -i devm` 无新 warning；通过后才谈写 `boot_b` | `upstream-74-replay-20261113.md` §5（1–4 步） |
| **C-U1** | UEFI `out/boot-elden-vk188b.img`（换 `ramdisk-vk181-working.cpio.gz`） | 件已重打、设备 `/boot/initrd.img` 已换，**未上机验** | `Initramfs unpacking` 不再报 `no cpio magic`、`Run /init`、gadget/SSH 同通（闸门 = A10） | `uefi-vk188-fbcon-20261112.md` §3.3/§7.1 |
| **C-U2** | ESP `BOOTAA64.EFI` = v5（A2 + `panic=0`）**陷阱回收** | 未回收 ⇒ 从 a 槽起会「挂住不重启」，看着像死机 | `scripts/esp-install-grub.sh --efi out/grub-20261112/grubaa64-v3b-bigfont.efi --tag v3b-restore --activate` 后菜单 96 px + A 臂 `panic=15` 自恢复 | `uefi-vk188-fbcon-20261112.md` §6 |
| **C-U3** | GRUB v2 件（补显示模块 + `gfxmode` + `timeout=30`，sha `4f91a8fd…`） | 已 `--activate`，**未上机验** | 菜单可见 + 30 s 超时行为正确 | `TASKS/README.md`:160（③） |
| **C-U4** | camss 接 Qualcomm v6（7 补丁）+ 板级 dts rebase 后出流 | **未上机**；2.3.0/2.4.0 分歧未判（未证实） | 前/后摄 `camera-stream-up.sh` rc=0 满帧数；坏帧则走 2.4.0 delta | `camss-v6-rebase-plan-20261113.md` §2/§5（闸门 = A9） |
| **C-U5** | 可选 9 条 apply 后的回归（ath12k reg、dwc3 host RxDetect、camss v2 四连、UBWC、cmd-db、pinctrl UAF、uefisecapp、drm dp） | 未 apply、未上机 | 每条带自己的复测项（WiFi 关联 / xHCI / 相机出流 / s2idle 回来 / DP） | `TASKS/README.md`:142；`upstream-merge-candidates-20261112.md` §4 门 1–4（闸门 = A22） |
| **C-U6** | flash LED NTC 温度监控补丁（`patches/0013`） | 提案在手，**未上机** | NTC 读数进 thermal zone + 高温降档不触发硬保护 | `TASKS/README.md` §1 G1-5「闪光灯」段 |
| **C-U7** | phoc 0.59 件替换后回归（B19 产物） | 未上机 | OSK 抓焦 `Visible=true` 与现状一致（回归不退化）+ 本地 keyboard-grab 补丁已退役仍无 grab 崩溃 | `upstream-merge-candidates-20261112.md` §1b；`TASKS/README.md` §4:138 ③ |
| **C-U8** | T14 换根 recipe 的 D1–D5 部署验收 | recipe 未可执行化 ⇒ 验收本身「待上机」 | 见 `t14-userland-recipe-20261111.md` D1–D5 | `TASKS/README.md`:157（依赖 B14） |
| **C-U9** | Gunyah `gh_vmtest` 最小探针 | 驱动已编译（`out/gunyah-73/`，10 个 `.ko`），**未上机** | `VM_START` 回 0；违规 DTB 对照错码是否 `8`（闸门 = A12，前置 = B15） | `TASKS/README.md`:175-176 |
| **C-U10** | C3 SPIC 三档回包 | 未装 APK ⇒ 仍是推理不是实测 | 三档逐项对判据表（闸门 = A13） | `TASKS/README.md` §2 C3 行 |
| **C-U11** | `reboot edl` → 9008 | DT 已修、脚本已改，**真机未验** | `lsusb` 见 `05c6:9008`（闸门 = A20） | `TASKS/README.md` §1 G1-24 行 |
| **C-U12** | U1 GPT 手术 + RAM 零写盘验收 | U1 为逆手术态，mainline 未重做 | `findmnt /`=`/dev/sda17` + `fastboot boot` 零写盘验收（闸门 = A21） | `DEVICE/README.md` §2.2/§2.3 |
| **C-U13** | `qbootctl.service` override 落地 + C5 容器相机 App 实开预览 | 单元未对齐；App 未实测 | `systemctl cat qbootctl` 与仓库声明一致 + App 内预览出画面（闸门 = A19/A14） | `TASKS/README.md`:144、§2 C5 行 |

### C-I：已上机但**判据不足**（14 条）

| # | 项 | 判据缺什么 | 证据指针 |
|---|---|---|---|
| **C-I1** | **s2idle / 待机功耗** | 只有短窗计数（`rtcwake -m mem -s 45` 2/2 vk190、3/3 vk189）；**无待机电流实测、无小时级驻留** ⇒ 「待机功耗线已重启」属**未证实收益** | `DEVICE/README.md` §1.1 首条；`TASKS/README.md`:146 |
| **C-I2** | 相机「撤掉物理连续约束」 | 只证明**正常路径不回归**（前摄 5 帧 rc=0）；**未构造非连续 sg** ⇒ 不能声称「非连续可用」 | `camss-v6-rebase-plan-20261113.md` §3 |
| **C-I3** | **T18 充电抖动** | 10 min 窗零翻转 + 现场翻转抓到（ICL 0/250 mA 反复），但**主因未定**；负向测试未做 | `TASKS/README.md`:177；`t18-usb-charging-triage-20261111.md` §4 |
| **C-I4** | `boot_a` 冷启动 + 屏上菜单交互（G1-29） | flashed 形态只验暖起 37.0 s / p69 129.2 s；**未做物理 POR、未取屏上菜单判据** | `TASKS/README.md`:51；`DEVICE/README.md` §1.1（闸门 = A11） |
| **C-I5** | **G1-38 OSK** | 主链（弹/收/Firefox 真 IC/候选窗）已验；**GTK3/Qt 各一例、Alt+Tab 漏收、候选窗与 stevia 是否重叠、XWayland** 未验；候选窗重做前置未验 | `TASKS/README.md` §1:60-64 |
| **C-I6** | **Q33 WCD939X 冷起 5425 行 `ASoC error (-16)`** | 未抓调用栈、未确认 `soc_component_read_no_lock()` 的 EBUSY 来源 ⇒ 只知「多等 20 s」不知因 | `TASKS/README.md` §5 Q33（:1114）；`reports/vk163-por-boot-latency-20261026.md` §3 |
| **C-I7** | **Q12 温控 OEM 层** | 只有 81.9 °C 峰值（短载）；**≥2 h 长载 + 壳温/限频层级未测** | `TASKS/README.md` §5 Q12（:1106）、§2「温控 OEM 层」行 |
| **C-I8** | C9 十用例打分 | 模板就绪，**一份分未打** ⇒ 兼容层「可用」仍无量化结论 | `TASKS/README.md` §2 C9 行（:94）（闸门 = A15） |
| **C-I9** | Q5 残余（30 s 传感器 CSV / 5 App 录屏） | 主体已采（getprop/Widevine L1/42 传感器清单），**App 行为项 0 份** | `TASKS/README.md` §5 Q5（:1094）（闸门 = A16） |
| **C-I10** | **M8（dispcc reset v2）疗效** | 2026-10-30 三发基线臂现场正常 ⇒ 坏发未复现、按预注册规则停手未刷 v2 ⇒ **v2 是否治 Q28 未证实** | `TASKS/README.md` §5「M8 续测结果（2026-10-30）」 |
| **C-I11** | **M3-1 v5（dwc3 双口）** | 上机 A1 启动期失联（USB 零枚举、串口零输出、pstore 空）⇒ **根因未证实**；第二发复现后判定 pristine 血统不是有效载体 | `TASKS/README.md` §5「2026-10-30 23:38 上机 A1」+「2026-10-31 10:26 第二发」 |
| **C-I12** | **Gunyah S1 静态结论** | 受「`gh_rm_drv.ko` 未反汇编 / iceland 16 补丁未读」两空约束 ⇒ 三条差异结论**未证实** | `TASKS/README.md`:175；依赖 B15 |
| **C-I13** | **G1-8 GL vs Vulkan 公平对比** | GLES 数 = vsync 上限（Alpine 无 `glmark2`）⇒ 只有 Vulkan 侧真分；「物体挤左上角」未查（判非阻塞） | `TASKS/README.md` §1 G1-8 行 |
| **C-I14** | **G1-5 闪光灯「能用」** | torch/strobe 寄存器级实测通过，但 libcamera 侧无闪光灯控制 ⇒ **App 路径未验**（代码缺口在 B18） | `TASKS/README.md` §1 G1-5 行 |

---

## D. 明确已结项 / 已取消（只列 ID，不展开）

- **G1**：G1-0、G1-1、G1-2、G1-3、G1-4、G1-6、G1-7、G1-8、G1-9、G1-10（取消·无 NFC 硬件）、G1-11、G1-12…21、G1-22、G1-23、G1-24（除 `reboot edl`）、G1-25…G1-28、G1-30（取消·slim 不作日常）、G1-31、G1-32、G1-33、G1-34、G1-35、G1-36、G1-37
- **G2**：C0、C1、C2、C4、C6、C7、C8（书面结论，未立项）、C10、C11、C12
- **Q 行**：Q2、Q7、Q8、Q9、Q10、Q11、Q13、Q14、Q16、Q17、Q18、Q19、Q20、Q21（并入 Q24）、Q22、Q23、Q24（关闭·不值得取证）、Q25、Q26、Q27（幻影引用）、Q28、Q29、Q30、Q31、Q32、Q34、Q35
- **M 系列**：M1（树已建，历史路径失效）、M2-A1（撤稿·与上游重复）、M5（立项完成·封存）、M7（不需要我方补丁）、M9 / M9-收口（撤回）、M4-1（已投归档）
- **其它**：T9（暂不排期）、T17、H1、H2（每轮收尾制）、`dtbo_a` 真根因、`logfs` 写入语义、kexec 显示（M9 撤回后定位为调试快环）、vk189/vk190（已上机+持久化）、合并批 1 六枚（已随 vk189 上机）、进 fastboot 入口整顿（`to-fastboot.sh` 唯一入口）、UEFI issue #12 闭环回帖（comment 6847932534）、wl2868c **W1**（v11 已发）、git-tidy 的分支收束与 config 快照归档（`patches/config-history-20261113.tar.zst`，15/15 sha OK）、`history/pre-vk34`（决定保留作历史锚点）

---

## X. 冲突登记（裁决顺序：`upstream-74-replay` / `upstream-status-20261113` / `git-tidy-20261113` / TASKS §7 最新增量 > 旧行文）

| # | 冲突 | 裁决 |
|---|---|---|
| **X1** | `TASKS:1320`（§7 11-12 增量）把 **W1（wl2868c LDOx_SEQ）** 列为「我方欠、需批准」；`upstream-status-20261113.md` §1 记 **v11 已于 11-13 投出**（3×250、lore 逐字节通过，按 datasheet Rev1.4 p.35 + 板上 `0x0a..0x0d=00` 回答） | **以 status 为准 ⇒ W1 结项**（入 D）；仅剩「若 Mark 要求『非零 SEQ 时隐藏 ops』的替代方案」需回，等回信再定 |
| **X2** | `TASKS:142` 尾部仍写批 1「**尚未 apply**」；同条前半段 + `versions/vk-registry.tsv` 的 **vk189** 记「已应用 6 枚并上机 3/3 s2idle」 | **以 registry + DEVICE §1.1 为准 ⇒ 批 1 已 apply 且已上机**；「尚未 apply」是过期句 |
| **X3** | `upstream-watch` §A 把 mdss v3 **2/3** 记为 `handled-elsewhere（未收）`；`mail-triage-20261112.md` §2.2 记 `state=new`、`archived=True` | 字段不一致只影响「是否需重发」的判读，**动作不变**：先答三问（B3）再定 v4（A1）；引用以逐 patch 表为准 |
| **X4** | `TASKS/README.md` §1 G1-38 行**行首**仍写「🟡 静态定案、待上机（2026-11-12）」，同行**行末**已有 11-12/11-13 上机验证与用户目视确认 | 行首过期 ⇒ 以行末增量 + §4:141 为准：**主链已通，剩四类样本**（C-I5 / A18） |
| **X5** | `upstream-watch` §A 要求重做 **dsi bonded 5 连发**（Dmitry 五点、全串 `handled-elsewhere`）；`upstream-status-20261113.md` §2 **未列该系列为欠账** | 以更具体的 watch 行文为准 ⇒ **真实欠账**（A8）；status 缺行属登记遗漏，建议补 |
| **X6** | `TASKS` §5 Q5 说残余「30 s 传感器 CSV + 5 App 录屏」采自「a 槽 stock」；`DEVICE` §1.1 记 **U2 `boot_a` 现 = UEFI pc1** | 以 DEVICE §1.1 为准 ⇒ 只能在 **U1** 的 stock a 槽采（A16），且采完随 A21 手术消失 |
| **X7** | `DEVICE` §2.2 注仍写「★熄屏→整机硬复位：**未解**（间歇性）… `elden_nocamera=1`…」；Q24/G1-33 已 2026-10-24 结项（7.3 血统免疫） | 以 TASKS §5 Q24 + §1 G1-22/G1-33 为准 ⇒ **DEVICE 该注过期**，不作待办；建议 DEVICE 改指针 |
| **X8** | `TASKS` §5「面板 init 间歇失败」补救路径仍写「**温启跑 vk74**」；Q28 已结项（补采样门槛作废） | 以 Q28 结项为准 ⇒ **不作待办**，属沿革残留 |
| **X9** | `TASKS:138`（G1-37 首句）写「只剩一件」+ 后续「剩 ① 组词上屏 ② ZRAM」；同行行末已记 11-09 ZRAM 全链收口、11-11 组词上屏用户目视达成 | 以行末为准 ⇒ G1-37 **无剩余动作**（入 D）；唯一尾巴 = 内核仍纯 LZO，`CONFIG_ZRAM_BACKEND_LZ4` 下次重建生效（非任务） |
| **X10** | `mail-triage-20261112.md` §5 W4 / `upstream-status` §2 要求 **dsi/phy 出 v2**；`upstream-74-replay-20261113.md` §3 实测 **7.4 上游 `dsi_pll_enable_pll_bias()` 已等价写 `0xc0`，我们那 9 行在 7.4 上语义重复、应 retire**；同理 M6 L1（A8）的 base 也过期（`upstream-watch` §A 已在问 "what is your base kernel"） | **以最新 replay 报告为准 ⇒ 先定基线（B0）再决定 A3/A8 的动作**：若坐实走 7.4，A3 改为「撤回 + 说明上游已覆盖」，A8 的 base 改成 7.4-rc3 线；已投的 v1/v3 保持原状不追发 |
| **X11** | `TASKS` §4:142 与 `upstream-merge-candidates-20261112.md` §0 都把「主线增量≈0」写成结论，但 `upstream-74-replay` §0.1 说明 **payload 重放本身能干净落地 107 文件** —— 两者不矛盾（前者指**上游功能增量**，后者指**我们的 payload 可移植性**） | 记录为口径澄清而非冲突：**换基线有收益（冲突面小、可 retire 3 项本地件），取功能靠 patchwork 队列** |

---

## 附：最该先做的 3 条

1. **B0（7.4-rc3 重放）**：15 文件 / 19 hunk、3 处真判断、半天到一天可出可编译树，且能顺手退役 3 项本地补丁（nt36536 delta 收窄、PLL_SYSTEM_MUXES、`rpmhpd skip_retention_level`）——它是 A3/A8/A9 的「基线前提」，越早定越省返工。
2. **A10 + C-U1/C-U2**：UEFI 线只差一次上机就能从「拍屏」变「串口/SSH 可读」；且必须先回收 ESP 上的 `panic=0` 陷阱，否则下一个人从 a 槽起会以为死机。
3. **B1 → A9（camss CSIPHY 对账）**：`gh/master` 已现成，对表零风险；它决定相机上游化是「直接接 v6」还是「带 2.4.0 delta 上机」。

（次优先：**B3 → A1** mdss 2/3 —— 1/3 与 3/3 已双 R-b，写清措辞/副作用/测法即可让整串闭环。）
