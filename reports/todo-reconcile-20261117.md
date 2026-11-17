# 待办对账 — `todo-inventory-20261113.md` → 2026-11-17 真实状态

> lane：待办对账（只读 + 本文件）。未改其它文档、未发信、未 push、未动设备、未删文件。
> 被对账对象：`reports/todo-inventory-20261113.md`（A1–A24 / B0–B19 / C-U0–13 / C-I1–14 = **72 条**，X1–X11 为冲突登记不单独计工作量）。
>
> **判定三源**：① 2026-11-14 之后的会话与报告（`TASKS/sessions/2026-11-1[4-7]-*.md`、`PITFALLS/sessions/3xx`、`reports/*2026111[4-7]*`）；
> ② `INDEX.md` §0（核对日期 2026-11-17）/ `TASKS/README.md` §2/§4/§7 现口径；③ 产物路径 `ls` 实测。
>
> **状态词**（五类，互斥）：**已闭环**（动作完成且有证据指针）/ **已作废**（谁裁决的写在行内）/ **主机侧可做** / **需设备窗口** / **需用户批准（发信/写盘/凭据）**。
> 「已闭环」= 该条描述的动作已做完，不等于上游已合并；「等维护者回复」按动作完成计闭环，并单列在 §5 需批准里（若下一步是重发/撤回）。

## 0. 计数（现查依据）

| 系列 | 条数 | 已闭环 | 已作废 | 主机侧可做 | 需设备窗口 | 需用户批准 |
|---|---|---|---|---|---|---|
| A（用户裁决/批准） | 24 | 4 | 2 | 0 | 9 | 9 |
| B（主机侧自主） | 20 | 9 | 2 | 5 | 0 | 4 |
| C-U（未上机） | 14 | 3 | 3 | 0 | 6 | 2 |
| C-I（判据不足） | 14 | 1 | 2 | 1 | 10 | 0 |
| **合计** | **72** | **17** | **9** | **6** | **25** | **15** |

计数依据 = 本文件 §1–§4 逐条行的状态词（`grep -c` 可复核），不是抄旧文；差异来源见 §6「对账中发现的口径漂移」。

---

## 1. A 系列对账（A1–A12）

| # | 原条目（缩写） | 现状判定 | 证据 / 裁决指针 |
|---|---|---|---|
| A1 | mdss 2/3 回 Dmitry 两问 + 重发 v4 | **已闭环**（v4 11-13 发、v5 11-14 发＝答 sashiko「0xa000 独立域」、3/3 只收窄 message、3 个 R-b 保留）；下一步「若被判不可接受则发 v6 删 3/3」= 需批准 | `patches/upstream/m8-mdss-v4-20261113/`、`m8-mdss-v5-20261114/`、`reports/mail-send-20261114-mdss-v5.md`、`INDEX.md` §0 第 6 条 |
| A2 | dpu gamma LUT v2（补 `Fixes:`） | **需用户批准**：备料已完成 1 枚，对 7.4-rc3 final `aebb727447` apply rc=0 + checkpatch 0 error | `patches/upstream/dpu-gamma-lut-v2-20261113/`、`reports/artifacts/apply-check-7.4rc3-20261116/` |
| A3 | dsi/phy v1 → v2 还是撤回 | **已闭环**：v2 已发（2026-11-16 22:50 错前缀 + 23:03 `[PATCH v2]`，两发 250，三列表归档逐字节一致） | `patches/upstream/dsi-phy-muxes-v2-20261116/`、`reports/upstream-status-20261113.md` §1、`TASKS/sessions/2026-11-17-早间批处理-…md` §1 |
| A4 | dwc3 v9（Rob 结构性要求） | **需用户批准**：备料 4 枚已完成（binding+DTS+driver 三件同改、`dt_binding_check`/`dtbs_check` 过），对 7.4-rc3 final 4/4 rc=0 | `patches/upstream/dwc3-v9-20261113/`（`v9-0000..0004`） |
| A5 | elden 板 DTS 收成单提交 | **需用户批准**：备料 1 枚已完成、apply rc=0、`dtbs_check` 绿 | `patches/upstream/board-dts-single-20261113/` |
| A6 | haptics aw86937 v2（bot 两条） | **需用户批准**：备料 6 枚已完成（0006 已 rebase 掉只存在于 linux-next 的上下文行 ⇒ 6/6 rc=0） | `patches/upstream/haptics-v2-20261113/`、`TASKS/sessions/2026-11-16-UEFI收尾…md` §1② |
| A7 | counter/dispcc reset RFC v2 或撤 | **已作废（2026-11-16 裁决：与 `m8-mdss v4` 内容重复 ⇒ 走 v4、不再单独出 v2）** | `reports/artifacts/apply-check-7.4rc3-20261116/README.md`；`patches/upstream/dispcc-reset-v2-20261113/` 仅留作沿革 |
| A8 | M6 / dsi bonded 5 连发重做 | **需用户批准**：已重切成 `m6-dsi-pll v2` 1 枚、apply rc=0；base 争议随「不追 7.4」裁决消解（见 B0） | `patches/upstream/m6-dsi-pll-v2-20261113/`、`TASKS/README.md` 开放待办 §4-2 |
| A9 | camss 接 Qualcomm v6 后上机出流 | **需设备窗口**（前置：11-15 RFC 已发、2.4.0 delta 2 枚备料在档但受「binding 与在飞 v6 撞段 + 需一次上机」约束） | `reports/camss-csiphy-24-delta-20261115.md`、`reports/camss-csiphy-v6-vs-240-20261113.md`、`INDEX.md` §0「卡什么」 |
| A10 | UEFI 线上机两发（vk188b initrd + pstore console） | **已作废（被 11-15/11-16 全链取代）**：根因定案 = Mu initrd buffer 落进 `ramoops@c2000000`；修法①（内核守卫）已上机闭环并持久化 vk192，vk188b 那件不再是路径 | `reports/uefi-grub-initrd-rootcause-20261115.md`、`reports/pstore-ram-initrd-guard-20261116.md`、`INDEX.md` §0 第 4/5 条 |
| A11 | G1-29 剩余两件（`boot_a` 冷启 + 屏上菜单） | **已闭环（2026-11-16）**：`set_active a` 暖启 44 s、**14:46 用户断电冷启**菜单正常屏显 5 条、默认臂起进 Linux | `TASKS/sessions/2026-11-16-UEFI收尾与q28看门狗修复.md`、`reports/artifacts/uefi-daily-v8-20261116/30-cold-por-grub-menu.jpg` |
| A12 | Gunyah S2 上机对照（`gh_vmtest`） | **需设备窗口**（非主线、需排期；前置 B15 两空） | `reports/gunyah-73-port-20261112.md`、`TASKS/README.md` §4 N2 条 |

DONE: A1–A12

## 2. A 系列对账（A13–A24）

| # | 原条目（缩写） | 现状判定 | 证据 / 裁决指针 |
|---|---|---|---|
| A13 | C3 装 SPIC 取三档回包 | **已闭环（2026-11-15）**：SPIC v1.4.0 一次回包 `deviceRecognitionVerdict = []` ⇒ BASIC/DEVICE/STRONG 三档全不满足，书面判读未被推翻 | `reports/c3-spic-verdict-20261115.md`、`INDEX.md` §0 第 2 条、`TASKS/README.md` §2 C3 行 |
| A14 | C5 U7 App 实开预览 | **需设备窗口**：容器侧 1 个相机 + `/dev/video100` bind 已持久化，仍差人开 App 看预览 | `TASKS/README.md` §2 C5 行 |
| A15 | C9 十用例打分表出数 | **需设备窗口**：模板 `README.md §6` §5 定稿，一份分未打（`TASKS` §2 C9 仍 ⬜） | `TASKS/README.md` §2 C9 行、§2.1 A15 行（模板） |
| A16 | Q5 残余（30 s 传感器 CSV / 5 App 录屏） | **需设备窗口**：仍需人工 + Google 账号，且只能在 U1 的 stock a 槽采（U2 `boot_a` = UEFI pc1） | `TASKS/README.md` §5 Q5、`DEVICE/README.md` §1.1 |
| A17 | T18 充电抖动现场复现 | **需设备窗口**：主因未定、负向测试必须真实重插（驱动拒手动降档） | `reports/t18-usb-charging-triage-20261111.md` §4、`TASKS/README.md` §4 T18 条 |
| A18 | G1-38 真机四类样本 | **需设备窗口**：主链已通，缺 GTK3/Qt、Alt+Tab 漏收、候选窗重叠、XWayland 四类样本 | `TASKS/README.md` §1 G1-38 行、`PITFALLS` #644–#646 |
| A19 | `qbootctl.service` 受控窗口对齐 | **需设备窗口**：动槽位/启动计数单元，审计标「高风险，需受控窗口」；仓库侧脚本已在（`scripts/slot-switch.sh`、`fix-ab-mark-successful.sh`）但未见 override 对齐证据 | `reports/script-redundancy-audit-20261112.md` §3、`TASKS/README.md` §4:144 |
| A20 | `reboot edl` 真机 9008 实测 | **需设备窗口**：DT/`dtbs_check` 已绿，真机未验（需用户同意进一次 EDL） | `TASKS/README.md` §1 G1-24 行、§5 Q23、`reports/twrp-parity-edl-dload-20261020.md` |
| A21 | U1 mainline 重做 GPT 手术 | **需用户批准**（写盘高风险 + 三选一备份；U1 现为唯一 stock a 槽 + root 单元，做完即丢） | `DEVICE/README.md` §2.2/§2.3 |
| A22 | 上游合并候选「可选 9 条」是否排期 | **需用户批准**：批 1 六枚已随 vk189 上机；可选 9 条未批准（`TASKS` §4 仍记「值得合并 12 条 = 必修 3 + 可选 9」，批 1 已完成） | `reports/upstream-merge-candidates-20261112.md` §0/§2、`versions/vk-registry.tsv` vk189 行 |
| A23 | GitHub 侧 `attic/*` tag 补推 | **需用户批准**（PAT / 网页手动；agent 不代填凭据）。11-14 之后无任何会话再提，仍停在 hook 拒绝 | `reports/git-tidy-20261113.md` §1「收束后远端」+ §5.2 |
| A24 | `patches/` 大目录是否立项裁剪 | **需用户批准**（裁决）：git-tidy 结论「合并会破坏审计链 ⇒ 单独立项」；本轮只见 `patches/config-history-20261113.tar.zst`（15/15 sha OK）与清盘动作，未见 `patches/` 裁剪立项 | `reports/git-tidy-20261113.md` §5.3、`reports/disk-cleanup-20261115.md` §2 |

DONE: A13–A24

## 3. B 系列对账（B0–B13）

| # | 原条目（缩写） | 现状判定 | 证据 / 裁决指针 |
|---|---|---|---|
| B0 | payload 重放到上游 7.4-rc3 线（半天–1 天，产出可编译树） | **已作废（用户 2026-11-13 裁决：「7.4 没有对我们有用的功能增量 ⇒ 本轮不追 7.4」，只留可合性结论与复用路径）**。星号：`build/m1-upstream` 至今不存在，无 7.4 树产物 | `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-3（逐字引裁决）、`reports/upstream-74-replay-20261113.md` §0–§4 |
| B1 | camss CSIPHY 对账（7.4 是否含 kaanapali） | **已闭环**：7.4-rc3（final `aebb727447` 复查）**无** `sm8750-csi2-phy` / camss 里无 `kaanapali`；lane 表已迁 `phy-qcom-mipi-csi2-3ph-dphy.c: lane_regs_x1e80100[]`（= vendor v2.1.2），地址 103/103 同、13 data 字节差 ⇒ 需 2.4.0 delta | `reports/camss-csiphy-v6-vs-240-20261113.md`、`reports/camss-csiphy-24-delta-20261115.md`、`INDEX.md` §0「卡什么」 |
| B2 | camss `0007` 独立价值评估 | **已闭环（2026-11-13 夜）**：已由我们自己的 v2 系列覆盖，不再独立投 | `reports/b2-camss-0003-recheck-20261113.md` |
| B3 | mdss 2/3 取证（是否中断控制器 + 副作用 + 测法） | **已闭环**：三段文字已成 v4/v5 message 正文（并据 sashiko 质疑收窄为「不是 interrupt controller、0xa000 未做单变量」） | `reports/mdss-int2-evidence-20261113.md`、`reports/mail-send-20261114-mdss-v5.md` |
| B4 | dsi/phy v2 备料 | **已闭环**：v2 件已出**且已发**（2026-11-16 两发 250，三列表归档） | `patches/upstream/dsi-phy-muxes-v2-20261116/` |
| B5 | dpu gamma LUT v2 备料 | **需用户批准**（备料本体已完成 = 1 枚 + `Fixes:` 已补 + apply rc=0）；发信动作见 A2 | `patches/upstream/dpu-gamma-lut-v2-20261113/README.md` |
| B6 | dwc3 v9 三件改造 + 兼容性评估 | **需用户批准**（备料本体已完成：`devm_mux_control_get` / 双 endpoint / 删 `port@2` / 门禁 4/4 rc=0）；发信动作见 A4 | `patches/upstream/dwc3-v9-20261113/README.md` |
| B7 | fastrpc 证据包（non-secure 寄存器/固件证据） | **已闭环**：证据报告已落盘，可答 Konrad；线程仍等上游 `accel/qda` v4 与 `nsessions` 定调（不在我们动作面） | `reports/fastrpc-nonsecure-evidence-20261113.md`、`INDEX.md` §0「卡什么」fastrpc 条 |
| B8 | elden 板 DTS 单提交备料 + 依赖图 | **需用户批准**（备料本体已完成 = 1 枚 rc=0）；发信动作见 A5 | `patches/upstream/board-dts-single-20261113/README.md` |
| B9 | haptics v2 备料 + MAINTAINERS 冲突核查 | **需用户批准**（备料本体已完成 = 6 枚、0006 已 rebase、6/6 rc=0）；发信动作见 A6 | `patches/upstream/haptics-v2-20261113/README.md` |
| B10 | dispcc reset RFC v2 备料 | **已作废（2026-11-16 裁决：与 `m8-mdss v4` 内容重复 ⇒ 发 v4、本项不再出 v2）** | `reports/artifacts/apply-check-7.4rc3-20261116/README.md` |
| B11 | 可选 9 条逐枚 `git apply --check` 预处理 | **已闭环**：2026-11-16 对 mainline 7.4-rc3 final 全量按序 apply（board DTS / dwc3 ×4 / m8-mdss ×3 / dpu-gamma / m6-dsi-pll / haptics ×6 / camss delta ×2 全部 rc=0，逐条日志在档） | `reports/artifacts/apply-check-7.4rc3-20261116/{README.md,apply-check.log}` |
| B12 | SN 锚定三问 | **已闭环**：① UEFI SMBIOS **否**（cmdline serialno 是 CRC32）；② adb/Waydroid 未见常量 SN；③ initramfs gadget 已在 vk191 重建生效（`iSerial=HA2EXB0E`）⇒ 三问各给答案 | `reports/sn-anchoring-audit-20261113.md`、`TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-2/§4-1 |
| B13 | 脚本欠账（写死 SN/IP 5 条、默认输入 5 条、模块部署三套、a 槽 dtbo 清零） | **主机侧可做**：`scripts/verify.sh` 在本仓**不存在**（现役门禁是 `packaging/elden-userland/tools/verify.sh`），且 11-14 之后无会话收口该批欠账 ⇒ 判据未过 | `reports/script-redundancy-audit-20261112.md` §3、`TASKS/README.md` §4:144 |

DONE: B0–B13

## 4. B/C 系列对账（B14–B19、C-U、C-I）

### 4.1 B14–B19

| # | 原条目（缩写） | 现状判定 | 证据 / 裁决指针 |
|---|---|---|---|
| B14 | T14 换根重建 recipe 可执行化（P0 chroot → R1–R4） | **主机侧可做**（部分完成）：S3/S4/S6 已实现在 `elden-firmware/paths-qcom.txt` + `stage.sh` 并离线复核通过；剩 P0 chroot → R1 dry-run → R2 `all.sh --apply` → R3 门禁 → R4 `render.py`；唯一不可重建件 = 自家 ELF（hapticd/sensord/ffrumble） | `reports/t14-s3s4s6-offline-verify-20261114.md`、`reports/t14-userland-recipe-20261111.md`、`TASKS/README.md` §4 T14 条 |
| B15 | Gunyah 必须先补的两个空（读 iceland 16 补丁 + 反汇编 `gh_rm_drv.ko`） | **主机侧可做**：11-14 之后无任何会话产出这两空的结论（`gunyah-s1-static-diff-20261111.md` 仍是「两空约束」版本） | `reports/gunyah-s1-static-diff-20261111.md`、`TASKS/README.md` §4 N2 条 |
| B16 | QEMU 复刻 `GRUB → vk188 → 串口 dmesg` 全链 | **已闭环**：`scripts/qemu-full-chain-smoke.sh` 固化，PASS 4/4、单轮 ≈35 s；后续 11-16 又加 `scripts/qemu-ramoops-initrd-ab.sh`（守卫 A/B） | `reports/qemu-full-chain-20261113.md`、`reports/pstore-ram-initrd-guard-20261116.md` §5 |
| B17 | 分诊盲区修补（U1/U6/U7：b4/next/drm-misc-next 核、`/covers/` 54 个过 comments、在审清单固化进 TASKS） | **主机侧可做**：11-14 之后无收口证据；11-17 的两份 lane 报告（`upstream-replies-20261117.md` 仍「结论数字表（待填）」）只做了查询工具与部分实投账 | `reports/mail-triage-20261112.md` §6.2、`reports/upstream-replies-20261117.md`（未完成） |
| B18 | 相机闪光灯两缺口主机侧备料（libcamera `MEDIA_ENT_F_FLASH` + NTC 温控） | **主机侧可做**（部分完成）：NTC 件在 `patches/0013-flash-led-ntc-thermal.patch`（未上机，归 C-U6）；libcamera 侧无闪光灯控制的代码缺口**未见产物** | `TASKS/README.md` §1 G1-5「闪光灯」段、`patches/0013-flash-led-ntc-thermal.patch` |
| B19 | 升 phoc 0.59~rc1 退役本地补丁 | **已闭环**：phoc 已换 `0.59~rc1-powerfix` 自编件（`scripts/phoc-install.sh` + divert/hold），并含 T20 电源键修复；OSK 不弹**不因此解决**（版本门口径未变）已写明 | `TASKS/README.md` §4 T20 条、`PITFALLS` #654、`out/phoc-syncobj-arm64-20261114/` |

### 4.2 C-U（未上机，14 条）

| # | 原条目 | 现状判定 | 证据 / 指针 |
|---|---|---|---|
| C-U0 | 7.4-rc3 重放树上机验证 | **已作废**（随 B0 用户裁决：不追 7.4，无树可上） | `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-3 |
| C-U1 | UEFI `boot-elden-vk188b.img` initrd 修复 | **已作废**（被守卫核 + 64 MB initrd 的新路径取代；`Initramfs unpacking` 问题已由 11-15/11-16 根因+修法闭环） | `reports/uefi-grub-initrd-rootcause-20261115.md`、`reports/pstore-ram-initrd-guard-20261116.md` |
| C-U2 | ESP `BOOTAA64.EFI` v5(`panic=0`) 陷阱回收 | **已闭环（2026-11-16 14:03 ESP 归位）**：现役 = 日常用嵌入菜单 GRUB `f5dcf599…`（默认臂直载 vk192 守卫核 + `elden.dtb` + 64 MB initrd + `earlycon`），a 槽暖启 44 s | `INDEX.md` §0 第 4 条第 5 项⑤、`reports/artifacts/uefi-daily-v8-20261116/` |
| C-U3 | GRUB v2 件（显示模块 + `gfxmode` + `timeout=30`） | **已作废**（该件已被 11-16 日常嵌入菜单 EFI 取代；gfxmode/timeout 需求落在新件里） | 同上；`TASKS/sessions/2026-11-16-UEFI收尾…md` |
| C-U4 | camss 接 v6 + dts rebase 后出流 | **需设备窗口**（= A9） | `reports/camss-csiphy-24-delta-20261115.md` |
| C-U5 | 可选 9 条 apply 后回归 | **需用户批准**（先批 A22 才 apply），apply 通过后再进设备窗口 | `reports/artifacts/apply-check-7.4rc3-20261116/`、`reports/upstream-merge-candidates-20261112.md` §4 |
| C-U6 | flash LED NTC 温度监控补丁上机 | **需设备窗口**：补丁在 `patches/0013-…`，未上机（判据 = NTC 进 thermal zone + 高温降档不触发硬保护） | `TASKS/README.md` §1 G1-5 行 |
| C-U7 | phoc 0.59 件替换后回归 | **已闭环**：0.59~rc1 已安装并经 T20 上机验收（短按熄屏/再按亮屏/长按菜单正常），本地 keyboard-grab 补丁退役未复发 | `TASKS/README.md` §4 T20 条、`PITFALLS` #654 |
| C-U8 | T14 D1–D5 部署验收 | **需设备窗口**（依赖 B14 剩余主机侧步骤先做完） | `reports/t14-userland-recipe-20261111.md` |
| C-U9 | Gunyah `gh_vmtest` 最小探针 | **需设备窗口**（= A12，前置 B15） | `reports/gunyah-73-port-20261112.md` |
| C-U10 | C3 SPIC 三档回包 | **已闭环（2026-11-15）**（= A13） | `reports/c3-spic-verdict-20261115.md` |
| C-U11 | `reboot edl` → 9008 | **需设备窗口**（= A20） | `TASKS/README.md` §1 G1-24 行 |
| C-U12 | U1 GPT 手术 + RAM 零写盘验收 | **需用户批准**（= A21） | `DEVICE/README.md` §2.2/§2.3 |
| C-U13 | `qbootctl.service` override + C5 App 预览 | **需设备窗口**（两半分别 = A19 / A14） | `TASKS/README.md` §4:144、§2 C5 行 |

### 4.3 C-I（已上机但判据不足，14 条）

| # | 原条目 | 现状判定 | 证据 / 指针 |
|---|---|---|---|
| C-I1 | s2idle / 待机功耗 | **需设备窗口**：T9 第二轮取数（11-16，124 行/8 boot/最长 23.3 h）**仍无待机窗**（`suspend_stats` 全程 `0/0`）⇒ 要判必须先造待机窗 | `TASKS/README.md` §4 T9 条★11-16 轮、`reports/artifacts/t9-suspend-resource-20261116.tsv` |
| C-I2 | 相机「撤掉物理连续约束」 | **需设备窗口**：只证正常路径不回归（前摄 5 帧 rc=0），非连续 sg 场景未构造 | `reports/camss-v6-rebase-plan-20261113.md` §3 |
| C-I3 | T18 充电抖动 | **需设备窗口**（= A17） | `reports/t18-usb-charging-triage-20261111.md` §4 |
| C-I4 | `boot_a` 冷启动 + 屏上菜单（G1-29） | **已闭环（2026-11-16 用户断电冷启 + 菜单 5 条屏照）** | `reports/artifacts/uefi-daily-v8-20261116/30-cold-por-grub-menu.jpg` |
| C-I5 | G1-38 OSK 四类样本 / 候选窗 | **需设备窗口**：IME 配置层 11-15 全绿（`ime-candidates-check.sh` 11 PASS/0 FAIL），**行为层**（画候选那一半）仍按 #646 撤下、待真人样本 | `TASKS/sessions/2026-11-15-IME候选回归台账.md` §3b/§3c、`PITFALLS` #646 |
| C-I6 | Q33 WCD939X 冷起 5425 行 `ASoC error (-16)` | **需设备窗口**：仍需抓调用栈 + 确认 `soc_component_read_no_lock()` EBUSY 来源 | `TASKS/README.md` §5 Q33、`reports/vk163-por-boot-latency-20261026.md` §3 |
| C-I7 | Q12 温控 OEM 层 | **需设备窗口**：≥2 h 长载 + 壳温/限频层级未测 | `TASKS/README.md` §5 Q12 |
| C-I8 | C9 十用例打分 | **需设备窗口**（= A15） | `TASKS/README.md` §2 C9 行 |
| C-I9 | Q5 残余 | **需设备窗口**（= A16） | `TASKS/README.md` §5 Q5 |
| C-I10 | M8（dispcc reset v2）疗效 | **已作废**：Q28 已结项为「已规避」（运营线 8/8 无坏发、预注册规则停手），v2 疗效不再追（同时 B10/A7 已并入 m8-mdss v4 统计口径 p=0.003） | `INDEX.md` §0「已结项、勿重推」、`patches/upstream/mdss-v5-q28-evidence-20261116/` |
| C-I11 | M3-1 v5（dwc3 双口）启动期失联根因 | **已作废（被 dwc3 v9 取代）**：Rob 结构性要求已按「binding+DTS+driver 三件同改」重做成 v9，M3-1 v5 不复活 | `patches/upstream/dwc3-v9-20261113/README.md`、`reports/dwc3-v9-plan-20261111.md` |
| C-I12 | Gunyah S1 静态结论（两空约束） | **主机侧可做**（依赖 B15；两空补齐即可把三条差异结论定/否） | `reports/gunyah-s1-static-diff-20261111.md` |
| C-I13 | G1-8 GL vs Vulkan 公平对比 | **需设备窗口**：Alpine 无 `glmark2` ⇒ GLES 侧仍只有 vsync 上限 | `TASKS/README.md` §1 G1-8 行 |
| C-I14 | G1-5 闪光灯「能用」App 路径 | **需设备窗口**：torch/strobe 寄存器级已过，libcamera 无闪光灯控制 ⇒ App 路径未验（代码缺口 B18 + 上机 C-U6） | `TASKS/README.md` §1 G1-5 行 |

DONE: B14–B19、C-U0–13、C-I1–14

---

## 5. 三张汇总表

### 5.1 主机侧可做（6 条，按价值排序；不需要设备、不需要发信）

| 序 | 条目 | 下一步具体动作 | 判据 | 预计耗时 |
|---|---|---|---|---|
| 1 | **B14** T14 换根重建 recipe 可执行化 | 在 chroot（P0）里跑 `dry-run`（R1）→ `all.sh --apply`（R2）→ 门禁（R3）→ `render.py`（R4）；S3/S4/S6 已在 `elden-firmware/{paths-qcom.txt,stage.sh}` | R1–R4 全绿；`packaging/elden-userland/tools/verify.sh --rebuildable` FAIL=0；`hapticd` 不可重建要显式登记豁免 | 2–4 h（chroot 首次构建为主） |
| 2 | **B15** Gunyah 两空 | ① 逐条读 `reference/gunyah-*/`（或 iceland-gvm 上游）16 补丁正文并写一页摘要；② `objdump -d` 本机/`out/gunyah-73/gh_rm_drv.ko`，核 RM 是否认 `0x51000018` / `0x56000032-34` | 结论一句「`0xA` = RM 太老 还是 状态机 bug」+ 逐条证据行；直接决定 A12 是否值得上机 | 2–3 h（反汇编为主，无需设备） |
| 3 | **B13** 脚本欠账清账 | 现查 `grep -rn "HA2CB1KY\|192\.168\.7\.1" scripts/ rootfs/`、模块部署三套实现合并、a 槽 dtbo 清零写进设备分派脚本 | `bash packaging/elden-userland/tools/verify.sh` FAIL=0；`scripts/check-doctor.sh` FAIL=0；分派脚本幂等 + 带备份/读回 | 1.5–2.5 h |
| 4 | **B18** libcamera 闪光灯缺口 | 备料 `MEDIA_ENT_F_FLASH` 媒体实体识别 + `cam` 侧闪光灯控制（NTC 件已在 `patches/0013-…`） | 补丁可编译（`W=1` 0 warning）+ 与 `patches/0013` 无冲突；上机判据归 C-U6 | 2 h（代码 ~1 h + 编译核验） |
| 5 | **C-I12** Gunyah S1 三条差异结论定/否 | 承 B15 结论，回填 `gunyah-s1-static-diff-20261111.md` 三处「未证实」 | 三条差异各给「成立/否证 + 证据」 | 0.5 h（纯写作，B15 之后） |
| 6 | **B17** 分诊盲区 U1/U6/U7 | ① 查 b4/next/drm-misc-next 维护者树是否已悄悄应用；② `/covers/` 54 个按窗口过 comments；③ 「在审系列清单」固化进 TASKS §7 口径 | 三盲区逐条关闭；「0 已合并」限定写清（只对 patchwork 侧成立） | 1.5–2 h（lore/patchwork 抓取为主，注意 `lore` 直连 403 ⇒ 走 `scripts/lore-fetch-raw.py`） |

> 合计 ≈ 10–13 h，全部可在一次设备离线窗口内并行；**顺序建议 2 → 5 → 1 → 3 → 4 → 6**（B15 解锁 Gunyah 全线的判定）。

### 5.2 需设备窗口（25 条）

| 组 | 条目 | 一句话判据 |
|---|---|---|
| 相机 | A9 / C-U4、C-I2、C-I14（+ C-U6 NTC） | v6 + 2.4.0 delta 出流 5 帧 rc=0；非连续 sg 场景；闪光灯 App 路径 |
| Gunyah | A12 / C-U9 | `VM_START` 回 0 + 违规 DTB 错码 `8`（前置 B15） |
| UEFI/EDL/槽位 | A19 / C-U13、A20 / C-U11 | `systemctl cat qbootctl` 与仓库一致；`lsusb` 见 `05c6:9008` |
| 待机/功耗 | C-I1、C-I7 | 造 + 采出待机窗（`suspend-resource-sample.sh cycles`）；≥2 h 长载温控层级 |
| 桌面/输入 | A18 / C-I5（含 11-15 配置层已绿的行为层） | GTK3/Qt 各一例 + Alt+Tab 漏收 + 候选窗不重叠 |
| 兼容层验收 | A14 / C-U13、A15 / C-I8、A16 / C-I9 | App 预览出画面；10 用例打分表；30 s CSV + 5 App 录屏（只能 U1 stock a 槽） |
| 电源/温度取证 | A17 / C-I3、C-I6 | 真实重插一次抓翻转；Q33 抓 `EBUSY` 调用栈 |
| T14 部署 | C-U8 | D1–D5（前置 B14） |
| 图形基准 | C-I13 | Alpine 装 `glmark2` 后 GLES 真分 |

### 5.3 需用户批准 / 裁决（15 条）

| 类型 | 条目 | 待批的具体动作 |
|---|---|---|
| **发信（6）** | A2 / B5、A4 / B6、A5 / B8、A6 / B9、A8 | 五个系列备料全部 apply rc=0、checkpatch 0 error，只差放行：dpu-gamma v2（1 枚）、dwc3 v9（4 枚）、board DTS（1 枚）、haptics v2（6 枚）、m6-dsi-pll v2（1 枚）。**按系列逐次批准** |
| **裁决 A1 后续** | A1 尾巴 | 若维护者判 v5 的 3/3 不可接受 ⇒ 发 v6 删 3/3（并发回 1/3 应有的 Rob Acked-by）；当前只需等回信，不需动作 |
| **写盘/手术（2）** | A21 / C-U12 | U1 mainline GPT 手术（三选一备份 + 高风险）；做完 stock a 槽即消失（与 A16 抢窗口，**A16 必须先采**） |
| **改树/回归（2）** | A22 / C-U5 | 可选 9 条是否排期（改 `build/daily` + 需上机回归） |
| **凭据/网页（1）** | A23 | GitHub `attic/*` tag 补推（PAT 或网页，agent 不代填） |
| **立项裁决（2）** | A24、A7/B10 的替代口径 | `patches/` 是否立项裁剪（判据与范围）；dispcc reset 已并入 m8-mdss v4，仅需确认「不再单独出 v2」 |

> **优先级建议**：五个发信系列是当前唯一「备料全绿、零风险、只差一句话」的批量动作，建议一次批准整批（沿用 2026-10-31「全部允许」批的形态）；
> A21 与 A16 存在顺序约束（先采 Q5 残余，再做 GPT 手术）。

---

## 6. 对账中发现的口径漂移（供编排者并入 SSOT 时裁决）

1. **`todo-inventory-20261113.md` 自身计数与实到条数不符**：文件头写「A 24 / B 20 / C-U 14 / C-I 14」= 72，但 `TASKS/sessions/2026-11-14-TASKS-4-沿革下沉.md` §4-3 记的当时口径是「A 22 / B 18 / C 27（未上机 13 + 判据不足 14）」⇒ 11-13 夜到 11-14 之间清单被扩过（B0/B14–B19 等后补）。**本次以文件内实际存在的行为准（72 条）**。
2. **`TASKS/README.md` §4 仍留 B 组「18 条全部收口」的旧口径**，同时又说「发信仍等下轮统一批准」——与「B5/B6/B8/B9 只差放行」一致，但「收口」一词容易读成已闭环；建议改为「备料收口、待放行 5 系列」。
3. **`reports/upstream-status-20261113.md` 的日期名已过期**：正文已按 11-16/11-17 更新（dsi/phy v2 已发、欠账 2 → 1 件），但文件名仍是 `-20261113`，且 `TASKS/README.md` §7 头把它当「当前一页」。建议改名或加「内容已更新至 11-17」头注。
4. **A10 / C-U1 / C-U3 三条属同一批 UEFI 旧路径产物**（vk188b initrd、GRUB v2 件、ESP v5 panic=0 陷阱）：11-16 ESP 归位后**全部失效**，但它们仍各自占一行，容易被新会话当活待办重做。建议在 SSOT 里合并成一行「UEFI 线：已闭环，旧件仅留沿革」。
5. **`scripts/verify.sh` 不存在**（B13 判据写的就是它）：现役门禁是 `packaging/elden-userland/tools/verify.sh`。旧条目按旧路径写判据，会导致新会话「判据命令跑不起来」而不自知。
6. **A7 / B10 / C-I10 的「已作废」依据只在 11-16 会话正文里**（「dispcc-reset-v2 与 m8-mdss-v4 内容重复 ⇒ 发 v4」、Q28 结项「已规避」），`patches/upstream/dispcc-reset-v2-20261113/` 目录仍在且 README 未标作废 ⇒ 目录与结论不同步。

---

## 7. 覆盖度声明

- 已对账：A1–A24（24）、B0–B19（20）、C-U0–C-U13（14）、C-I1–C-I14（14）= **72/72 条，无跳过**。
- 未对账（按任务口径不计）：`todo-inventory-20261113.md` 的 **D 段（已结项/已取消，只列 ID）** 与 **X1–X11（冲突登记）**——本次只核 X10/X11 的裁决是否仍成立：X10（7.4 基线）已随「不追 7.4」裁决消解、X11 口径澄清仍有效；其余 X 项未被 11-14 之后证据推翻（未逐条重查，留待编排者）。
- 未做的事：未发信、未 push、未 commit、未删文件、未动设备、未改其它文档。

收尾: 72/72 条对账完成（已闭环 17 / 已作废 9 / 主机侧可做 6 / 需设备窗口 25 / 需用户批准 15），另列 6 条口径漂移供 SSOT 并入。
