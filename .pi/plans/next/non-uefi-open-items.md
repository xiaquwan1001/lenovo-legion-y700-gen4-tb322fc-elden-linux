# 非 UEFI 开放项梳理（只读分析 · 2026-11-04）

> 范围：**排除 UEFI/G1-29/N1 线**，梳理其余全部开放项。
> 方法：只读仓库（`TASKS/README.md` §0/§2/§4/§7、`reports/upstream-status-20261029.md`、`PROGRESS.md` §2–§4、
> `TASKS/sessions/2026-11-0*.md`）。**未上机、未改仓库、未投递。**
> 证据写法：`file:line` 或命令。凡不确定一律标 **未证**。

## 0. 一句话结论

**除 UEFI 外，真正「已过门禁、只等用户放行」的投递件只有 1 件：M6 B5 v2（4 枚 / +673 −6 / 门禁绿）**；
其余在途系列全部是「等 review」或「需返工/需真机」，**没有第二件可以立刻发**。
最近 1–2 周最高性价比**不在投递，而在 3 件纯主机工作**：M6 B5 v2 的「发或永久封存」决策、
T17 换根（S2–S7）的主机侧前置、C3/G3 的取证脚本化（详见 §6）。

证据基线：`TASKS/README.md` §7 头部 11-02 批次（547–555 行）、`reports/upstream-status-20261029.md`、
`reports/mail-triage-20261102.md`（**最后一份全量邮件分诊**）、`TASKS/sessions/2026-11-02-B5v2收尾修门控缺陷.md`。

## 1. M 系列：有没有「已过门禁、只等用户批准投递」的件？

### 1.1 M6 B5 v2 —— **是（唯一一件），但同时卡在用户裁决 + 自设发布条件**

| 项 | 事实 | 证据 |
|---|---|---|
| 门禁 | **全绿**：checkpatch 4/4 `0E/0W`（0002 唯 1 CHECK=udelay 已释）、`W=1` 编译 rc=0/0 warning、`check-series-selfcontained` **PASS=4 FAIL=0 WARN=0** | `TASKS/README.md:552`；`patches/upstream/m6-b5-v2-20261102/GATES.md` §0 |
| 形态 | base = 公开 `6628e7d4c6`（Linux v7.4-rc1），4 枚 **+673 −6**，含一处崩溃级门控修复（`msm_dsi_host_get_bonded_cfg()`） | 同上；`TASKS/sessions/2026-11-02-B5v2收尾修门控缺陷.md` §1 |
| 阻塞① | **用户裁决**：2026-11-02「保守处理，本轮不发，等下一轮项目全盘审计与重构」 | `TASKS/sessions/2026-11-02-B5v2收尾修门控缺陷.md` §4；`TASKS/README.md:552` ③ |
| 阻塞② | **自设发布条件未满足**：v7.4-rc1 树内 6 块 `qcom,dual-dsi-mode` 板**无一是 SM8750**、也无一块需要 command-mode bonded ⇒ 「树内无使用者」 | `TASKS/sessions/2026-11-02-B5v2收尾修门控缺陷.md` §2；`reports/m6-b5-v2-parent-review-20261102.md` |
| 落地形态 | cover 已改为如实声明「使用者板级件另发」+ 讲清 data-gate（覆盖方案 B） | 同上 §2 |

⇒ **判定**：属「已过门禁、只等用户批准」，但**批准本身需要先回答「无使用者要不要发」**——这是技术叙事决定，不是纯行政审批。
材料可直接 `send-email`；一次性 worktree `/tmp/wt-b5v2fix` 已删，分支 `b5/v2-fixed` 留在 `build/m3v2-7.3rc7`（复跑按 `GATES.md` §5 三步）。

### 1.2 M4 camss csiphy 2.4.0 —— **不是待投件（不可独立投）**

| 项 | 事实 | 证据 |
|---|---|---|
| 门禁 | 绿：**+125 −0**、checkpatch `0E/0W/0C`、`W=1` camss 编译 rc=0/0 warning | `TASKS/README.md:553` |
| 阻塞 | v7.4-rc1 **树内无使用者**：`camss.c` 无 SM8750 表项 ⇒ `CAMSS_8750` 无赋值方 | `TASKS/README.md:553` |
| 落点 | 改为挂 Hangxiang Ma `[v6 0/7]` 线程的增量/回帖；材料在 `patches/upstream/camss-csiphy-24-20261102/` | 同上 |
| 用户裁决 | 同批「保守处理，本轮不发」 | `TASKS/sessions/2026-11-02-B5v2收尾修门控缺陷.md` §4 |

⇒ camss 侧**当前无「可立即投」的件**（`TASKS/README.md:553` 明写）。"发"这个动作要等 Hangxiang 线程有新版本，属**外部依赖**。

### 1.3 M8 mdss v3 后续 —— **已投出，后续卡在「等 review」+ 一条未做的真机 A/B**

| 项 | 事实 | 证据 |
|---|---|---|
| 状态 | **v3 已于 2026-11-02 投出**（6 封 250：系列 4 + 两条回 Dmitry），lore **14/14** 200，正文 sha256 逐字节一致 | `reports/mail-send-20261102-mdss.md` §0、§1 |
| 形状 | 净 diff **+9/−6**；删 11 行长注释、`items` 三项→两项（drop RSCC） | 同上 §1 |
| 未做 | **上机 0 次**：A7 要求的「发前真机冷起 A/B 证明 CORE+INT2 足够」被跳过，作为开放点写进 cover | `reports/mail-triage-20261102.md` §2 A7；`reports/mail-send-20261102-mdss.md` §0/§4 |
| 阻塞 | ①上游 review（Taniya/Dmitry）；②若要闭合开放点 = **需要设备 + 冷起 POR** | 同上 |

### 1.4 M2 A2 评审状态 —— **纯等 review，我方零欠动作**

- A2 `qcom_battmgr` SM8750：**10-27 21:29 已投**（linux-pm 归档），v2 基线 linux-next；triage 复核「Konrad 10-23 后 **0 条新意见**」（`reports/mail-triage-20261102.md` §3 M2 行）。
- 已知形式失误：**未打 `[PATCH v2]` 标签**，已补一封自回复说明（`TASKS/sessions/2026-11-03-TASKS行692-M2.md` 单元格 6 段末）。
- `TASKS/README.md:566` 的「A2 在评审」= 唯一状态；A1 已撤稿、P3 gamma-LUT 已 10-13 发 ⇒ **本行无待投件**。
- 将来若做厂商通道，落点已定为**方案 B（扩展上游 qcom_battmgr）**；致命互斥已证：厂商 `MSG_OWNER_BC=32778` 与上游 `PMIC_GLINK_OWNER_BATTMGR` 同值（`reports/mail-triage-20261102.md` §1；`TASKS/sessions/2026-11-03-TASKS行692-M2.md`）。

### 1.5 M3 / M4 review 跟踪 —— **均等 review；我方有 2 个「欠动作」但都需用户批**

| 系列 | 投递状态 | 上游最新回信 | 我方欠什么 | 阻塞 |
|---|---|---|---|---|
| **M3-1 dwc3** | v5 于 10-31 投 3 封；11-02 补投 1/2 binding 到 `devicetree@vger.kernel.org`（原 `linux-devicetree@` 被 vger 550） | v5 后 **0 条新意见**（triage §3） | 无（v6 需等 review 或用户批） | 等 review |
| **M4 camss v2 0/2** | 10-31 投 3 封 250，lore 命中 | v2 之后 **0 条新意见**（Loic 意见都在 v1 阶段） | 无 | 等 review |
| **M4 camss 九枚 SM8750 系列** | 已公开放弃 6 枚，只留 3 枚通用修复（10-29 已投） | — | 无 | 已收口 |
| **wl2868c v5 0/4** | 11-02 投（新线程，纠正 v4 误挂旧线程），`cci1_1` 改 gpio111/164 | 待回 | 无 | 等 review |
| **aw86927 5 枚** | 10-27 投；Krzysztof **Acked-by 2/5** | sashiko 4/5、5/5 各 1 条 Medium | **v3 返工**：保持 Ack 原样 + 接两条 Medium | 需人写 + 需用户批投 |
| **M1-U6 q6v5_pas** | 10-27 投 | 0 条（催信只扣分） | 无 | 等 review |
| **M9 GIC ITS** | ⛔ 已撤回（Marc Zyngier 否方案） | 回信已发 | 无 | 已结项 |

- **aw86927 v3 是唯一「我方欠动作且材料已有草案」的 review 项**：草案 `out/mail-20261029b/07-aw86927-v3-note.txt`，但**v3 补丁本身尚未生成**（`patches/upstream/` 下只有 `aw86927-20261027` 与 `-v2`）。
- M4-1 bindings 两枚被要求「给用户」（Mark Brown / Krzysztof：wl2868c「只有 binding 别说 driver」）——**已在 v5 里按 binding+driver+DTS 同系列解决**（`reports/mail-send-20261102-wl2868c.md`）。

## 2. 上游回信/评审意见待回应的线程

### 2.1 已闭环（11-02 那一批把 10-29 分诊的行动表全打完了）

`reports/mail-triage-20261102.md` §2 行动表 A1–A7 的兑付情况：

| # | 事项 | 兑付 | 证据 |
|---|---|---|---|
| A1 | wl2868c 答 Mark Brown 流程投诉 | ✅ 11-02 随 v5 发（Sent[247]） | `reports/mail-send-20261102-wl2868c.md` §0（6 封 250） |
| A2 | M6 B5 回 Dmitry 四条 | ✅ 11-02 发 1 封（合并回复） | `reports/mail-send-20261102-b5-m3dt.md`（§4 四条对账） |
| A3 | M3-1 补投 binding 到 `devicetree@` | ✅ 11-02 发 | 同上；`TASKS/README.md:554` |
| A4/A5 | wl2868c `cci1_1` 引脚 + 1/4 拆 qcom.yaml | ✅ v5 已改（gpio111/164） | `reports/mail-send-20261102-wl2868c.md` §1/§2 |
| A6 | quic 旧地址纪律 | ✅ 已记规则（未重发补丁） | `reports/mail-triage-20261102.md` §2 A6 |
| A7 | M8 mdss v3 | ✅ 11-02 已发（但「发前真机 A/B」未做） | `reports/mail-send-20261102-mdss.md` §0 |
| — | M3-1 sashiko 8 条（5 High） | ✅ v5 cover **逐条回应 sashiko 12 条**，草案 `out/mail-20261029b/01,02` 被 v5 吸收 | `reports/m3-v5-selfcontained-20261031.md:16`；`reports/m3-v5-recovery-20261030.md:254-255` |

### 2.2 **仍有 3 条未处理**（按紧急度降序）

| 线程 | 待做什么 | 为何未做 | 证据 |
|---|---|---|---|
| **aw86927 v3** | sashiko 4/5、5/5 各 1 条 Medium；v3 需保持 Krzysztof 的 **Acked-by 2/5** 原样 | **v3 补丁本身未生成**（`patches/upstream/` 只有 `aw86927-20261027` 与 `-v2`）；回帖草案 `out/mail-20261029b/07-aw86927-v3-note.txt` 保留未发 | `reports/upstream-status-20261029.md` §1 aw86927 行；`reports/mail-cleanup-20261102.md:296` 区段（07 号文件“C 保留”） |
| **M4-1 gt9764 binding 选路** | 回帖说明“复用 `dongwoon,dw9768.yaml`”或论证独立 binding；并回答“只给 binding 不说 driver” | 草案 `out/mail-20261029b/03-M4-1-gt9764-user.txt` 保留未发；11-02 批只解决了 wl2868c 那一枚 | `reports/upstream-status-20261029.md` §1 M4-1 行；`reports/mail-cleanup-20261102.md:297` |
| **M8 v3 的开放点** | cover 已自认“复位时刻在 PLL 之后”，等上游表态，**不欠回信** | — | `reports/mail-send-20261102-mdss.md` §0/§4 |

补充两条诚实标注：

- **camss 的 Shuai Liu 4 条意见（含 icc 表不一致）未公开收口**：系列已放弃 6 枚、让给 Hangxiang，草案 `05/06` 未发；icc 表的修法已出素材但**归属 Hangxiang、明确不投**（`TASKS/README.md:568` 末段、`reports/camss-icc-table-fix-20261031.md`）。
- **「11-02 之后有没有新回信」= 未证**：最后一份全量邮件分诊窗口止于 **2026-11-02 03:57Z**（`reports/mail-triage-20261102.md` §0）；此后唯一分诊 `reports/uefi-mail-triage-20261103.md` 标题即限定“UEFI/引导链/UFS”。要下结论必须先重跑一次分诊（工具/命令在该文件 §5）。
- **地址纪律缓存**：mdss 系列回信必须用 `abhinav.kumar@linux.dev` / `jesszhan0024@gmail.com`；`quic_*@quicinc.com` 已 550（`reports/mail-triage-20261102.md` §2 A6）。

## 3. 各开放项的最小下一步

### 3.1 T14 用户态服务独立固化

- **现状**：10-28 真机 `verify.sh` **FAIL=0 WARN=0**（80 条含 19 unit 逐字一致，`TASKS/README.md:123`）；但**重建性**仍缺——清单里 7 个 ELF **4 ok / 3 missing**（`reports/userland-service-inventory-20261025.md:37`）：`ffrumble`（静态、无源）、`waydroid-sensord`（动态 musl、无 recipe）、`waydroid-sensord-udp`（动态 musl、有 Makefile 缺宿主交叉 recipe）（`:55-58`）。
- **最小下一步（纯主机）**：
  1. **30 min**：重写 `ffrumble` 源（按 `reports/motor-haptics-vk127-20261017.md` 的 EV_FF 用法）⇒ WARN 3→2（`reports/userland-service-inventory-20261025.md:133`）。
  2. **1–2 h**：补齐 `waydroid-sensord(-udp)` 宿主构建 recipe（debootstrap/docker 里装 `libgbinder-dev libglibutil-dev` 后 `make -C patches-userland/waydroid-sensord-udp`），产物路径写回 `sources.tsv`（`:135-136`）。
  3. 第三步（`/init` 与 local.d 5 个重复入口收敛）**需改 boot.img** ⇒ 归入 T17。
- **阻塞**：无（步骤 1–2 零设备、零写盘）。
- **为什么重要**：这两个 sensord 是 **G2 传感器 HAL 的唯一真源**；Mobian/glibc 下动态 musl 必重编，**编不出来 = 容器传感器直接消失**（`reports/userland-service-inventory-20261025.md:57,62`）。

### 3.2 T17 Alpine→Mobian（S2–S7）

- **现状**：交界面核对完成（零写盘）；S1/S2 完成、S3🟡缺一块、S4🟡方法已验、S5⬜、S6🟡已渲染未部署、S7⬜（`reports/mobian-migration-plan-20261021.md:130-136`）。
- **最小下一步（主机侧，按依赖序）**：S3 补传感器 DSP 目录 `/usr/share/qcom/sm8750/LENOVO/TB322FC` 进 firmware 包（`reports/modular-mobian-transition-20261026.md:150-153`）→ S4 `depmod -b <暂存根> <UTS>`（已实测 rc=0、免 root，`:49-57`）→ S5 `initramfs-tools` hook → S6 18 个 systemd unit 铺进暂存树 + `systemd-analyze verify`（`reports/modular-mobian-transition-20261026.md:173-174`）。
- **需设备的关口只在 S7**：一条 `fastboot boot` 换根（`ROOTARGS=elden_root=LABEL=linux17`，内核/DTB/ramdisk 零变更，`reports/modular-mobian-transition-20261026.md:43-45`）；回退 `reboot2 bootloader` + `fastboot reboot`。
- **阻塞**：主机侧不阻塞；**S7 需设备**；另外前置是 T14 步骤 3（`/init` 入口收敛，否则新 init 双启）。

### 3.3 C3 Play Integrity / DRM 取证

- **现状**：本机取证已做——GMS 已登录、**Widevine 不存在**（仅 clearkey）、build = `userdebug` + `test-keys`、PI/SafetyNet 回包待装检测 App（`TASKS/README.md:74`）。
- **最小下一步（已从“社区三做法各变一变量”压缩为一次取证）**：装一个 PI 检查器 APK，取 `BASIC/DEVICE/STRONG` 三档回包 + 记 `ro.build.fingerprint`/`ro.build.tags`/`ro.product.first_api_level`（`reports/research-next-20261102.md:147`、§4 R3）。
- **阻塞**：**需设备 + 上行网络 + APK 侧载（需用户确认）**（`TASKS/README.md:74` 末句）。
- **证据已写明上限**：PIFork 是 Zygisk 模块且 A13+ 连 `DEVICE` 都要 locked bootloader + 硬件背书（`reports/research-next-20261102.md:135-136`）⇒ **STRONG/DEVICE 结构性不可达**；TrickyStore（伪造 keybox）应按硬规则 2 **不投入**（`:148-149`）。

### 3.4 G3 Box64 / Steam / gamescope

- **现状**：Box64 0.4.5 + Wine 9 PoC ✅；**官方 ARM64 Steam 客户端已到登录界面**（3/3 轮 `SetLoginState: WaitingForCredentials`、`steamwebhelper` 恒 7 进程、0 SIGSEGV；截图判据 10-29 已闭环）（`TASKS/README.md:17`）。
- **最小下一步（路线已换代）**：技术选型从 “Box64+Wine” 改为 **Valve ARM64 steamrt（或 Canonical arm64 snap）+ FEX-2610 + Proton(ARM64)**，跑**一个 Frame-verified 标题**并记启动时间/能否进游戏/帧率（`reports/research-next-20261102.md:161-163`、§4 R3）。
- **阻塞**：**需设备 + 2–4 h（含下载与依赖）**；无不可回退副作用（只装用户态包，`reports/research-next-20261102.md` §4 R3 末行）。
- **gamescope 现状**：本仓 `grep -rl gamescope reports/ TASKS/ patches-userland/` = **0 命中**（命令已实跑）⇒ 它**不在** G3 任何计划里；不建议自行引入（未证收益）。

### 3.5 N2 Gunyah / T9 suspend

- **N2 Gunyah VM**：**终局裁决 2026-10-25 = 本 firmware 下不做**（`TASKS/README.md:131`；`reports/gunyah-decision-20261025.md`）。不是“阻塞”，是**已结项**；6.12 驱动集仅作 G1 上游补丁素材（§7 M9）。**最小下一步 = 无**。
- **T9 suspend 掉电率**：2026-10-28 用户裁决 **优先级最低、暂不排期**（`TASKS/README.md:132`）。**最小下一步 = 无**（恢复时按 `reports/qca-fw-download-suspend-20261021.md` 历史口径）。

## 4. 纯主机、零风险、不需要设备的项

判据：**不碰 GPT/AVB/槽位、不要 `fastboot`/`adb`、不写设备盘、不向外发信**。

| # | 项 | 为何零风险 | 证据 |
|---|---|---|---|
| H1 | **T14 ffrumble 重写**（30 min） | 只改仓库内源文件 + `verify.sh` | `reports/userland-service-inventory-20261025.md:133` |
| H2 | **T14 sensord 构建 recipe**（1–2 h） | 在 debootstrap/docker 里 `make`，不动设备 | 同上 `:135-136` |
| H3 | **T17 S3/S4/S5/S6**（主机侧换根物料） | 全部落在 `out/stage-debian/` 暂存树；`depmod -b` 已实测免 root | `reports/modular-mobian-transition-20261026.md:49-57,173-174`；`reports/mobian-migration-plan-20261021.md:130-136` |
| H4 | **邮件重分诊**（1 h） | IMAP 只读（`BODY.PEEK`，不置 `\Seen`） | `reports/mail-triage-20261102.md` §0/§5 |
| H5 | **aw86927 v3 生成 + 门禁**（3–4 h） | 只改 `patches/`；发信需用户批（不在本项内） | `reports/upstream-status-20261029.md` §1 |
| H6 | **M4-1 gt9764 选路论证**（0.5 h） | 纯文档：选 `dongwoon,dw9768.yaml` 还是独立 binding | `reports/upstream-status-20261029.md` §1 M4-1 |
| H7 | **M6 B5 v2 复跑门禁 + 发信计划书**（1 h） | 只在 `build/m3v2-7.3rc7` 的 `b5/v2-fixed` 分支跑 checkpatch/`git am` | `reports/m6-b5-v2-20261102.md`；`GATES.md` §5 |
| H8 | **M8 v3 开放点的主机侧预备**（2 h） | 设计“复位时刻在 PLL 之后”的 A/B 矩阵，不需要当时上机 | `reports/mail-send-20261102-mdss.md` §4 |
| H9 | **M1 树重放**（半天，可选） | ⚠️ `build/m1-upstream/` **实测不存在**（`ls` 报 No such file），行内 MIGRATION-LOST 标注**属实** | `TASKS/README.md:565`；`TASKS/sessions/2026-11-03-TASKS行691-M1.md` |

**不属于本类（易误判）**：

- `packaging/elden-userland/tools/verify.sh` 的**真机**门禁（80 条含设备比对）**需设备**；只有其静态部分（`render.py`/`check-coupling.sh`）可离线跑。
- T17 的 S7、C3、G3、以及 M8 的真机 A/B —— **均需设备**。
- 任何“回信/投递”动作 = **需用户批准**（§7 口径“按系列逐次由用户批准”），不计入零风险项。

## 5. 总表

列说明：**性价比排序**= 综合「收益/工时/风险」的我方主观排序（1 最高），依据见 §1–§4 各条证据。

| 项 | 现状 | 阻塞 | 下一步动作 | 需设备? | 预估工时 | 性价比排序 |
|---|---|---|---|---|---|---|
| **M6 B5 v2**（4 枚 / +673 −6） | 门禁全绿（checkpatch `0E/0W` ×4、`W=1` rc=0、`check-series-selfcontained` PASS=4）；base 公开 `6628e7d4c6` | ①用户裁决「本轮不发」②自设条件「树内无 SM8750 使用者」未满足 | 用户给「发/永久封存」决定；若发则复跑 `GATES.md` §5 三步后 `send-email` | 否 | 1 h（复跑+发） | **1**（唯一可立即成事的上游件） |
| **M4 camss csiphy 2.4.0**（+125 −0） | 门禁绿，但 `camss.c` 无 SM8750 表项 ⇒ `CAMSS_8750` 无赋值方 | 外部依赖：需等 Hangxiang Ma `[v6 0/7]` 出新版本才能挂增量 | 无自主动作；线程有新版时把材料以增量/回帖形式挂上 | 否 | 0（等） | 12（不可自主推进） |
| **M8 mdss v3**（+9 −6） | 11-02 已投 6 封 250，lore 14/14 命中，正文 sha256 一致 | ①上游 review（Taniya/Dmitry）②cover 自认的「复位时刻在 PLL 之后」开放点未闭合 | 等 review；闭合开放点需真机冷起 A/B（主机侧只可先设计 A/B 矩阵） | 是（A/B 部分） | 主机 2 h / 真机 1 h | 6 |
| **M2 A2 `qcom_battmgr`** | 10-27 已投（linux-pm 归档），v2 基线 linux-next；Konrad 10-23 后 0 条新意见；未打 `[PATCH v2]` 已自回复说明 | 纯等 review | 无；将来厂商通道走「方案 B 扩上游」（互斥已证：`MSG_OWNER_BC=32778` 同值） | 否 | 0（等） | 13（零欠动作） |
| **M3-1 dwc3 v5** | 10-31 投 3 封；11-02 补投 1/2 binding 到 `devicetree@`；v5 后 0 条新意见 | 等 review | 无（v6 需等 review 或用户批） | 否 | 0（等） | 13 |
| **M4 camss v2 0/2** | 10-31 投 3 封 250、lore 命中；v2 后 0 条新意见（Loic 意见全在 v1 阶段） | 等 review | 无 | 否 | 0（等） | 13 |
| **wl2868c v5 0/4** | 11-02 投（新线程，纠正 v4 误挂），`cci1_1` 改 gpio111/164，binding+driver+DTS 同系列 | 等 review | 无 | 否 | 0（等） | 12 |
| **aw86927 v3**（§2.2 线程①） | 10-27 投 5 枚，Krzysztof **Acked-by 2/5**；sashiko 4/5、5/5 各 1 条 Medium | **v3 补丁本身未生成**（`patches/upstream/` 仅 `aw86927-20261027` 与 `-v2`）；发信需用户批 | 生成 v3：保持 Ack 原样 + 接两条 Medium；回帖草案 `out/mail-20261029b/07-aw86927-v3-note.txt` 已有 | 否 | 3–4 h（+门禁） | **2**（唯一我方欠动作且有草案的 review 项） |
| **M4-1 gt9764 binding 选路**（§2.2 线程②） | 上游问「复用 `dongwoon,dw9768.yaml` 还是独立 binding」+「只给 binding 不说 driver」；草案 `03-M4-1-gt9764-user.txt` 未发 | 需人写论证 + 用户批投 | 写 0.5 h 的选路论证（纯文档），再随系列投 | 否 | 0.5 h（+发信待批） | **4** |
| **M8 v3 开放点**（§2.2 线程③） | cover 已如实自认「复位时刻在 PLL 之后」，**不欠回信** | 等上游表态 | 无回信动作；可先做主机侧 A/B 矩阵设计 | 否（矩阵）/是（实测） | 2 h | 9 |
| **M1-U6 q6v5_pas** | 10-27 投，0 条回信（催信只扣分） | 等 review | 无 | 否 | 0 | 13 |
| **M9 GIC ITS** | ⛔ 已撤回（Marc Zyngier 否方案），回信已发 | —（已结项） | 无 | 否 | 0 | —（结项） |
| **T14 用户态服务独立固化** | 10-28 真机 `verify.sh` FAIL=0 WARN=0（80 条含 19 unit 逐字一致）；重建性 **4 ok / 3 missing**（`ffrumble`、`waydroid-sensord`、`waydroid-sensord-udp`） | 无（步骤 1–2）；步骤 3（`/init` 收敛）需改 boot.img ⇒ 归 T17 | ①重写 `ffrumble` 源（30 min）②补 sensord 宿主构建 recipe（1–2 h） | 否 | 1.5–2.5 h | **3**（G2 传感器 HAL 唯一真源，编不出来=容器传感器消失） |
| **T17 Alpine→Mobian S2–S7** | S1/S2 完成、S3🟡缺传感器 DSP 目录、S4🟡方法已验（`depmod -b` 实测 rc=0 免 root）、S5⬜、S6🟡已渲染未部署、S7⬜ | 主机侧不阻塞；**S7 需设备**；前置 = T14 步骤 3 | S3 补 firmware 包目录 → S4 `depmod -b` → S5 initramfs hook → S6 18 个 unit + `systemd-analyze verify`；最后 S7 一次 `fastboot boot` 换根 | S7 是，其余否 | 主机 4–6 h / S7 0.5 h | **5**（物料全可主机做，风险集中在最后一步且可回退） |
| **C3 Play Integrity / DRM 取证** | 本机已取证：GMS 已登录、**Widevine 不存在**（仅 clearkey）、build=`userdebug`+`test-keys`、PI/SafetyNet 回包未取 | 需设备 + 上行网络 + APK 侧载（需用户确认） | 装 PI 检查器 APK，取 BASIC/DEVICE/STRONG 三档回包 + 记 `ro.build.fingerprint`/`ro.build.tags`/`ro.product.first_api_level` | 是 | 2–3 h | 8（结论上限已知：STRONG/DEVICE 结构性不可达；TrickyStore 按硬规则 2 不投入） |
| **G3 Box64 / Steam** | Box64 0.4.5 + Wine 9 PoC ✅；官方 ARM64 Steam 客户端已到登录界面（3/3 轮 `WaitingForCredentials`、`steamwebhelper` 恒 7 进程、0 SIGSEGV） | 需设备 + 2–4 h（含下载与依赖） | 选型换代：Valve ARM64 steamrt（或 Canonical arm64 snap）+ FEX-2610 + Proton(ARM64)，跑一个 Frame-verified 标题并记启动时间/进游戏/帧率 | 是 | 2–4 h | 7（无不可回退副作用，纯用户态包） |
| **N2 Gunyah VM** | 终局裁决 2026-10-25 = 本 firmware 下**不做**；6.12 驱动集只作 G1 素材 | —（已结项） | 无 | 否 | 0 | —（结项） |
| **T9 suspend 掉电率** | 2026-10-28 用户裁决**优先级最低、暂不排期** | 用户排期 | 无（恢复时按 `reports/qca-fw-download-suspend-20261021.md` 历史口径） | 是（若恢复） | 未估 | —（暂不排期） |

**表外必读两条**（不进排序，但影响上表判断）：

- **「11-02 之后有没有新回信」= 未证**：最后一份全量分诊窗口止于 2026-11-02 03:57Z；此后唯一分诊 `reports/uefi-mail-triage-20261103.md` 标题即限定 UEFI/引导链/UFS。**上表所有「等 review」行的时效性都建立在这个未证前提上** ⇒ 重分诊（H4，1 h）应视为所有上游行的前置。
- **camss Shuai Liu 4 条意见（含 icc 表不一致）未公开收口**：系列已放弃 6 枚、让给 Hangxiang，草案 `05/06` 未发、icc 修法素材明确不投（`TASKS/README.md:568` 末段）。

## 6. 推荐（最近 1–2 周最值得做的 3–5 项）

并联前提：**UEFI 上机轮占用的是 U2**（`DEVICE/README.md:27` 在机条；U1 已逆手术、mainline 需重做 GPT 手术，`DEVICE/README.md:144`）。所以**所有需设备的非 UEFI 项与 UEFI 轮都是串行关系**（同一个 fastboot/adb 通道、同一块盘）；只有**纯主机项能与 UEFI 轮真并行**。排法与 §5 性价比列一致。

### R1 M6 B5 v2 的「发 or 永久封存」决定（1 h）· 纯主机零风险

- **为何现在做**：它是除 UEFI 外**唯一已过全部门禁**的上游件（`TASKS/README.md:552`；`patches/upstream/m6-b5-v2-20261102/GATES.md` §0）。放着不发不是“等”，是**持续衰减**：base 是 v7.4-rc1，拖到 rc4 后 rebase 成本与风险都上升。而它卡的不是技术，是一个**一句话就能回答的策略问题**（“树内无使用者”要不要发）。
- **需设备?** 否。复跑门禁只需 `build/m3v2-7.3rc7` 的 `b5/v2-fixed` 分支（`GATES.md` §5 三步）。
- **与 UEFI 轮并行**：**可完全并行**。
- **风险**：零（不发只损失时间；发信本身需用户批准，不在本项内）。

### R2 邮件重分诊 + aw86927 v3 生成（1 h + 3–4 h）· 纯主机零风险

- **为何现在做**：①**所有「等 review」行的时效性都建在未证前提上**——最后一份全量分诊止于 2026-11-02 03:57Z（§2.2 补充条），此后的分诊只扫 UEFI/UFS 线程；不重分诊，“0 条新意见”可能已经是错的。②aw86927 是**全项目唯一「我方欠动作 + 草案已在手」的 review 项**（Krzysztof Acked-by 2/5，sashiko 两条 Medium，草案 `out/mail-20261029b/07-aw86927-v3-note.txt`），而 **v3 补丁本身至今未生成**（`patches/upstream/` 仅 `aw86927-20261027` 与 `-v2`）。放越久，Acked-by 被后续版本作废的风险越高。
- **顺序**：先重分诊（1 h，IMAP `BODY.PEEK` 只读，`reports/mail-triage-20261102.md` §5 有现成命令）→ 若 aw86927 线程无新意见再生成 v3；若已有新意见，先并入 v3 一并发。
- **需设备?** 否。**与 UEFI 轮并行**：**可完全并行**（只读邮件 + 只改 `patches/`）。
- **风险**：零。**注意**：本项产出**不包含发信**（发信待用户逐系列批准）。

### R3 T14 重建性收尾（1.5–2.5 h）· 纯主机零风险

- **为何现在做**：10-28 真机 `verify.sh` 已 FAIL=0 WARN=0，但**重建性 7 个 ELF 中 4 ok / 3 missing**（`ffrumble` 静态无源、两个 `waydroid-sensord*` 动态 musl 无/缺宿主 recipe，`reports/userland-service-inventory-20261025.md:37,55-58`）。这两个 sensord 是 **G2 传感器 HAL 的唯一真源**——一旦 T17 换到 glibc（Mobian），动态 musl 二进制**编不出来就等于容器传感器直接消失**。所以它的优先级**随 T17 进度上升**，现在做是给 T17 拆盲。
- **需设备?** 否（debootstrap/docker 里 `make`）。**与 UEFI 轮并行**：**可完全并行**。
- **风险**：零（只改仓库内源 + recipe；真机复验另计）。

### R4 T17 主机侧 S3–S6（4–6 h）· 纯主机零风险（S7 才能需设备）

- **为何现在做**：全部落在 `out/stage-debian/` 暂存树，`depmod -b` 已实测 rc=0 免 root（`reports/modular-mobian-transition-20261026.md:49-57,173-174`）；独立于 UEFI。做完后换根就只剩**一条 `fastboot boot`**（`ROOTARGS=elden_root=LABEL=linux17`，内核/DTB/ramdisk 零变更）。
- **需设备?** 否（S3/S4/S5/S6）；**S7 是，占用 U2 的 fastboot，与 UEFI 轮串行**。
- **前置**：T14 步骤 3（`/init` 与 local.d 5 个重复入口收敛）否则新 init 双启；所以 **R3 → R4** 有顺序。
- **风险**：主机侧零；S7 可回退（`reboot2 bootloader` + `fastboot reboot`）。

### R5（需设备，可选，不与 UEFI 轮并行）G3 Steam 选型换代试跑（2–4 h，U2）

- **为何现在做**：官方 ARM64 Steam 客户端已到登录界面且无 SIGSEGV（`TASKS/README.md:17`），说明设备侧瓶颈不在“能不能跑”，而在**路线选择**：从 “Box64+Wine” 换到 “Valve ARM64 steamrt（或 Canonical arm64 snap）+ FEX-2610 + Proton(ARM64)” 并用**一个 Frame-verified 标题**给结论。这是唯一能推进 G3 的动作。
- **需设备?** **是（U2）**。**与 UEFI 轮并行**：**不能真并行**（同一台 U2 的 fastboot/adb）；但 UEFI 轮是**零写盘单发、结果 10 s 内可见**（`reports/uefi-payload-execution-20261104.md`），所以可“排在两发 UEFI 之间”做长下载，实操上只需避免同时操作 adb。
- **风险**：无不可回退副作用（只装用户态包）。**不建议**同时引入 gamescope（仓内 0 命中，收益未证）。

### 明确不做 / 不在本窗口

- **M4 camss csiphy 2.4.0 / M4-1 gt9764 回帖**：前者等 Hangxiang 新版本（外部依赖），后者只在有下一波 camss 投递时顺带；单独立项性价比低。
- **C3 PI/DRM 取证**：结论上限已知（STRONG/DEVICE 结构性不可达），且需侧载 APK（需用户确认）——**等用户开口再做**，不宜自推。
- **M8 v3 真机冷起 A/B**：只有上游真的追问“复位时刻”时才值得占 U2；提前上机是浪费。
- **N2 Gunyah / T9 suspend**：均已结项或暂不排期，本窗口不碰。

### 一句话窗口建议

**纯主机闸内（与 UEFI 轮完全并行、零风险）**：R1（1 h 决策）→ R2（4–5 h）→ R3（2 h）→ R4（5 h）≈ **两个工作日**；
**设备窗口**：优先 UEFI 轮，**G3 作为 UEFI 两发之间的填充**；C3/M8-A/B 只在用户明确要求时排。

DONE-NONUEFI

