# A2 审计报告：SSOT 并入核验 与 跨文档矛盾（2026-10-29）

> 只读审计 lane A2。范围 = 会话声明的 SSOT 并入 与 跨文档矛盾。
> 方法：读会话 → 抽「★SSOT 待并入」条目 → grep 目标 README 核验 → 跨文档比对。
> 本文件为本次 lane 唯一写产物；其余文件只读。

## §1 SSOT 并入核验

### 1.0 条目清单与总判定

来源 = `TASKS/sessions/2026-10-28-*.md`（23 个）与 `2026-10-29-*.md`（11 个）全部 34 个文件；`grep -n '待并入\|★SSOT'` 命中 **16 个条目（16 个文件）**。

| # | 会话（行号） | 声明 | 并入目标 | 判定 |
|---|---|---|---|---|
| S1 | 2026-10-28-容器相机gralloc布局.md:8 | 待并入 | TASKS §2 C5 行 + PITFALLS | 部分并入（TASKS ✅ / PITFALLS 未逐条确认）|
| S2 | 2026-10-28-容器相机gralloc上机取证.md:19 | 待并入 | TASKS §2 C5 + PITFALLS×3 + reports/c5-u7-gralloc-layout | 部分并入 |
| S3 | 2026-10-28-dispcc与battmgr回信.md:13 | 待并入 | TASKS M2 A2 行 + Q28 行 + reports/m2-a2-vendor-repo-check | 部分并入（Q28 行未落）|
| S4 | 2026-10-28-G3-Steam首批.md:8 | 待并入 | TASKS §5 G3 行（注：G3 实际在 §0）| 已并入（落点在 §0 G3 行）|
| S5 | 2026-10-28-wl2868c驱动系列.md:37 | 待并入 | TASKS §7 M4-1 行 + INDEX + PITFALLS×2 | 部分并入 |
| S6 | 2026-10-29-容器相机gralloc修法上机.md:26 | 待并入 | TASKS §2 C5 + §6 第 6 条 + DEVICE §2.2 | 已并入 |
| S7 | 2026-10-29-收官-容器相机与camss定调.md:33 | 待并入（声明已并入） | TASKS §0/§2/§7 + DEVICE §2.2 + PROGRESS | 大体已并入；§7 M4 行 10-29 更新**缺** |
| S8 | 2026-10-29-G3截图路径.md:9 | 待并入 | TASKS §5 G3 行 + PITFALLS | 已并入（§0 G3 行）；PITFALLS 未确认 |
| S9 | 2026-10-29-UEFI回帖定稿.md:7 | 待并入 | TASKS §5 Q25 ① + §4 N1 | **未并入** |
| S10 | 2026-10-28-顺序推进-B5第5步-UEFI回帖-容器相机.md:44 | 已并入 | TASKS §7 M6 + §2 C5 + PROGRESS + PITFALLS #458/#459 | 已并入（见 1.1）|
| S11 | 2026-10-28-用户态门禁根画像与overlay真值.md:26 | 已并入 | TASKS §4 T14 + INDEX §3 + PITFALLS 119 行 | 已并入（见 1.2）|
| S12 | 2026-10-28-B5第5步解阻-魔数有上游符号.md:28 | 已并入 | TASKS §7 M6 + PROGRESS + PITFALLS 122 行 | 已并入（见 1.1）|
| S13 | 2026-10-28-M4系列定稿可发.md:32 | 已并入 | TASKS §7 M4 + PROGRESS | 已并入（见 1.3）|
| S14 | 2026-10-28-M4系列投递与复核.md:24 | 已并入 | 同上 + PITFALLS 121 行 | 已并入（见 1.3）|
| S15 | 2026-10-28-Q34蓝牙缺tmel固件定案.md:33 | 已并入 | TASKS §5 Q34 + PITFALLS 118 行 | 已并入（见 1.4）|
| S16 | 2026-10-28-U2原子回调时序取证关闭.md:32 | 已并入 | TASKS §7 M6 + PROGRESS + PITFALLS 120 行 | 已并入（见 1.1）|

### 1.1 M6 线三条（S10/S12/S16）—— 已并入

命令与命中：

```
$ grep -n '第 5 步解阻\|U2（非原子\|★2026-10-28' TASKS/README.md | cut -c1-120
# TASKS/README.md §7 M6 行（L533 起的 M6 单元格）原文摘录：
#  "**★2026-10-28：第 5 步解阻（原判「魔数无文档 ⇒ 永久隔离」被证否）** —— 复核发现 0x44440400 的五个位…都有名字"
#  "**★2026-10-28：U2（非原子→原子回调时序）已证并关闭** —— 现场时间线（ftrace，零写盘 2 轮 blank/wake）8 项判据全 PASS"
#  "**★2026-10-27 RFC 备料完成（只备不发）**…"
```

- S12（B5 第 5 步解阻）：TASKS §7 M6 行有完整段（含 `.text` 逐字节等价 + `0005-dsi-name-fifo-error-bits.patch`）⇒ **已并入**。
- S16（U2 原子回调）：M6 行有「已证并关闭」段 + `scripts/b5-u2-atomic-timeline.sh` 判据 ⇒ **已并入**。
- S10（顺序推进）：其中 B5/C5 部分同上已并入；PROGRESS 侧：

```
$ grep -n '2026-10-28' PROGRESS.md
70:| 2026-10-28 | **Q34 定案 = 缺固件不是服务崩**…
71:| 2026-10-28 | **U2（B5/M6 原子回调时序）上机取证并关闭**…
74:| 2026-10-28 | **B5 第 5 步解阻**：原判「0x001f0200/0x44440400 魔数 bit30/29 上游无描述 ⇒ 永久隔离」被证否…
75:| 2026-10-28 | **C5/U7 容器相机真卡点换人**…
```

PROGRESS 时间线 10-28 有 8 行（L70–L79，覆盖 Q34/U2/B5/C5×4/M4×2/Sashiko）⇒ S10/S12/S16 的 PROGRESS 侧**已并入**；PROGRESS §6 第 8 条（L221）「★2026-10-28 收盘：三项已收掉…Q34 蓝牙…B5 第 1–4 步上机」与 U2 关闭口径一致 ⇒ **已并入**。

### 1.2 T14 用户态门禁（S11）—— 已并入

```
$ grep -n '★2026-10-28 收口：门禁迁到' TASKS/README.md
# TASKS/README.md §4 T14 行：「**★2026-10-28 收口：门禁迁到「根画像 + overlay 真值」** —— 换根到 Debian 后 verify.sh 曾是 FAIL=3 WARN=12 全假阳性…真机 FAIL=0 WARN=0（80 条含 19 个 unit 逐字一致）」
```

TASKS §4 T14 行已带 10-28 收口段；会话声明的「剩余三步已全部落地」也已在 T14 行写明 ⇒ **已并入**（INDEX §3 与 PITFALLS 侧见 1.6）。

### 1.3 M4 camss 线（S13/S14）—— 已并入

```
$ grep -n 'M4-2…M4-4 已投递并复核\|已定稿可发' TASKS/README.md | cut -c1-120
# TASKS/README.md §7 M4 行：「**★2026-10-28：M4-2…M4-4 已投递并复核（用户批准）** —— [PATCH 0/9] media: camss: add SM8750 support，10 封 Result: 250…lore /all/ 10/10 归档…逐字节复核 = raw→mbox→pristine git am 9/9 干净」
$ grep -n '2026-10-28' PROGRESS.md | grep -i 'm4'
72:| 2026-10-28 | **M4-2…M4-4 定稿为可发状态**（未发）：9 提交 / 14 文件 / +1931 −61 …
73:| 2026-10-28 | **M4-2…M4-4 已投递（用户批准）并逐字节复核**：[PATCH 0/9] media: camss: add SM8750 support…
```

⇒ S13（定稿可发）与 S14（投递复核）在 TASKS §7 M4 行与 PROGRESS 时间线 L72/L73 **均已并入**（PITFALLS 侧见 1.6）。

### 1.4 Q34 蓝牙（S15）—— 已并入

```
$ grep -n '已定案（2026-10-28 现场复现）' TASKS/README.md
330:| **Q34** | **`bluetoothd` 冷起偶发 crash**…| ✅ **已定案（2026-10-28 现场复现）= 不是 crash，是 WCN7861 外设固件缺文件**（`PITFALLS #454`）…补文件 + modprobe ⇒ hci0 UP RUNNING…根治 = elden-firmware 加 local-extras.tsv + 新门禁 A2…
```

TASKS §5 Q34 行（L330）已从 🟡 改 ✅ 且含判据与旧口径纠正（「重载服务或重载模块都不解决，必须补文件」）⇒ **已并入**；PROGRESS L70 同日行同步。

### 1.5 容器相机 gralloc 系列（S1/S2/S6）—— TASKS 侧已并入，外围报告待查

```
$ grep -n 'lockYCbCr' TASKS/README.md | cut -c1-160
71:| C5 | 相机共享（v4l2loopback + sampler → 容器） | …（行内含）「★2026-10-28 设备侧判别（lane L1c，已证 E2）…根因 = HandleImporter::lockYCbCrInternal<IMapperV4> 把 IMapper@4.0 的 PlaneLayout 零校验拼成 YCbCrLayout，三平面 YV12 专用…修法（源码已写、未上机）= 布局自洽校验 + …patches-userland/camera-gralloc-20261028/」
71:（同 C5 行）「★2026-10-29 修法已上机 = 有效（父会话执行，非子代理自报）：dl-cam/gen-aidl.sh…四判据：12 个 capture 请求 / 0 崩溃 / 12 次布局修复（y_str 2048 c_str 0 ⇒ y_str 1280 c_str 640…）/ refuse=0…剩余卡点换人：容器 surfaceflinger SIGABRT: Unable to generate SkImage. isTextureValid:0 自杀…另 App 12 请求后不再下请求」
```

- S1（gralloc 走 IMapper V4）：C5 行已按「lockYCbCrInternal<IMapperV4> 零校验拼 YCbCrLayout」表述并入 ⇒ **TASKS 侧已并入**（表述随证据演化，比会话原句更精确）。
- S2（E2 已证 + P0 缓解建议）：C5 行已并入「E2 已证/E1 弱否证/修法未上机」；**但会话要求的「把『先试 YUV_420_888 / NV12 绕过』列为 P0 缓解」在 C5 行无对应文字**（10-29 修法上机后该缓解项事实上已被跳过——S6 直接上机修法）⇒ **部分并入**（缓解项未落，且已被后续进展超越）。
- S6（修法上机有效 + 剩余卡点换人）：C5 行、PROGRESS L80、PROGRESS §6 第 6 条（L219「G2：容器相机 HAL 侧缺陷已闭环（2026-10-29 修法上机，12 请求/0 崩溃/12 次布局修复），只剩容器图形层（surfaceflinger Unable to generate SkImage 自杀）+ App 端请求停止」）三处齐 ⇒ **已并入**（含 §6 侧，S6 声明的两个 TASKS 落点都命中）。
- S6 的 DEVICE §2.2 侧（vendor.img 打过补丁 sha `82769ed6…`）见 1.7。
- S2 附带的「reports/c5-u7-gralloc-layout-20261028.md §2 『ALOGV 打不开』结论需改」见 1.8。

### 1.6 PITFALLS / INDEX 侧（S1/S2/S5/S8/S10~S16）

```
$ sed -n '159,172p' PITFALLS/README.md   # 索引表 118~131 行
118| #454 bluetoothd active 但 No default controller…真因 WCN7861 外设阶段缺 qca/tmel_peach_20.elf…（S15 ✓）
119| #455 换根后用户态门禁 FAIL=3 WARN=12 全是假阳性…（S11 ✓）
120| #456 取证方法两坑：dpms 0444 只读…ftrace 分组…（S16 ✓）
121| #457 投递后按 Message-ID 取 lore raw 复核的三个具体坑…（S14 ✓）
122| #458 判「上游无描述」不能只查 dsi.xml…（S12 ✓）
123| #459 容器相机四个静默坑：create=file 0 字节普通文件…waydroid session start 必须会话用户跑…（S10 声明 ✓）
124| #460 容器相机「metadata is null 是噪声 + BLOB 只在 MJPEG 源 + sizeimage 超 HAL 上限」…（S10 关联 ✓）
127| #463 依赖性系列投递前必须先在 pristine 上 git am（B5 6 枚 0/6）…
128| #464 「起没起窗口」之前先核 DRM 输出：enabled=disabled/dpms=Off 时 grim 报 no supported format found…（S8 ✓）
129| #465 宿主 androidboot.mode=charger 毒化容器…（S6 关联 ✓）
130| #466 dl-cam 手工构 external camera HAL 缺三件套（AIDL 头）…（S6 ✓）
131| #467 「镜像里本来就有 X」必须 pm list packages 现查…（S6 ✓）
$ grep -n 'log.tag\|VERBOSE\|DEAD_OBJECT\|sudo -u\|create mode\|worktree prune\|tmpfs' PITFALLS/README.md
（除 #465 charger 行外零命中）
```

- S1 声明的「PITFALLS 新条（gralloc 走 IMapper V4，没有 lockYCbCr）」：PITFALLS 索引/正文**无对应条目**（#460 是上一轮的 sizeimage/BLOB，不是 IMapper V4/PlaneLayouts）⇒ **未并入**。
- S2 声明的三条（① `log.tag.ExtCamDevSsn@3.4` 带 `@` 能生效（旧记录作废）② DEAD_OBJECT 时须前台抓崩溃 ③ `waydroid-cam-restart.sh` 写死 `sudo -u`）：PITFALLS/README.md **三条均无对应** ⇒ **未并入**。
- S5 声明的两条（cover letter checkpatch `create mode` 假阳性、`/tmp` tmpfs worktree 重启即失须 `git worktree prune`）：**均无对应** ⇒ **未并入**。
- S8 声明的 PITFALLS 新增：#464（L128）已覆盖「输出 disabled/dpms=Off ⇒ grim no supported format found + xwd 未装」⇒ **已并入**。
- INDEX：S11 声明的 INDEX §3 待办行 ✅（L127「T14（用户态固化→Mobian 迁移，三步已落地 + 门禁按「根画像/overlay…」）」）；S5 声明「INDEX 报告清单加 `reports/wl2868c-driver-20261028.md`」：`grep -n 'wl2868c' INDEX.md` 零命中 ⇒ **未并入**（TASKS §7 M4 行 L545 附近已有该报告指针，信息不丢但 INDEX 清单未加）。

### 1.7 DEVICE §2.2 侧（S6/S7）—— 未并入

```
$ grep -n '82769ed6\|vendor.img\|gralloc' DEVICE/README.md
83:- ★2026-10-23 深夜（收尾会话）：设备态与三项设备侧收尾 —— boot_b 仍 = vk152…
112:- **容器（Waydroid）侧在机资产（2026-10-13，TASKS C10 三期）**：/var/lib/waydroid/images/vendor.img 已固化自编 AIDL V2 vibrator HAL…
```

- S6 声明「DEVICE §2.2：容器 vendor.img 当前为打过 gralloc 补丁的版本（sha256 `82769ed6…`），回退件路径」：DEVICE/README.md **无任何 gralloc 补丁 / `82769ed6` 记录**（§2.2 台账与 §1.1 基线均未更新）⇒ **未并入**。
- S7 声明「DEVICE §2.2 已并入」：同上 ⇒ **未并入**（且 DEVICE §1.1 的最新在机状态仍停在 10-27 记录，无 10-29 vk181/vk182 行，见 §2 矛盾 ①）。
- 旁证：§2.2 是「唯一登记处；刷机状态变化当场更新」，10-29 的 boot_b 变更（vk173→vk181-daily→回滚）在该登记处无痕。

### 1.8 涉及报告文件的更正（S2/S3）—— 见 §2.3/§2.4 交叉引用核验

S2 附带要求「reports/c5-u7-gralloc-layout-20261028.md §2 的『ALOGV 打不开』结论需改」、S3 附带要求「reports/m2-a2-vendor-repo-check-20261026.md §1 措辞需带指针到 10-28 更正」——两份报告的现状与判定在 §2 矛盾清单中一并给出。

### 1.9 wl2868c 驱动系列（S5）TASKS 侧 —— 已并入

```
$ grep -n 'wl2868c 驱动本体系列备好未投' TASKS/README.md | cut -c1-200
# TASKS/README.md §7 M4 行：「**② wl2868c 驱动本体系列备好未投**：patches/upstream/wl2868c-driver-20261028/（cover + binding 重发 + driver，2 枚，父独立复跑 checkpatch --strict 0E/0W/0C（91/186 行）/dt_binding_check rc=0 / dt-check-style rc=0 / drivers/regulator/ 0E0W）…未上机、未投；报告 reports/wl2868c-driver-20261028.md」
```

会话声明「M4-1 行补一句『driver 系列备料完成、可投递（未发）』+ 门禁数字」：M4 行（M4-1 所在行）已有同义内容与门禁数字 ⇒ **TASKS 侧已并入**；INDEX/PITFALLS 侧未并入（见 1.6）。综合判定 S5 = **部分并入**。

### 1.10 G3 两项（S4/S8）—— 已并入（落点在 §0，会话写 §5 系口径漂移）

```
$ grep -n 'Steam' TASKS/README.md | head -3 | cut -c1-120
14:| **G3** x86 模拟（Steam 载体） | 2（Box64 0.4.5 + Wine 9 PoC 成功；官方 ARM64 Steam 客户端已起到登录界面，2026-10-28 设备实测 3/3 轮 SetLoginState: WaitingForCredentials - OK…截图判据 2026-10-29 已可闭环：当时失败真因是面板输出 enabled=disabled/dpms=Off…当前 dpms=On 下 grim 一次成功出图…降级路径见 reports/g3-steam-screenshot-paths-20261029.md）
```

TASKS §0 G3 行已含 S4（登录界面 3/3 + 失败根因）与 S8（截图判据闭环 + 降级路径指针）。会话原文写「§5 G3 行」——TASKS §5 是 GAPS 表，G3 并不在 §5；实际唯一 G3 状态行在 §0 总览。⇒ **已并入**（落点标注与实际不一致，属会话文件笔误，非并入缺口）。

### 1.11 UEFI 回帖定稿（S9）—— 未并入

```
$ grep -n '0x402' TASKS/README.md | cut -c1-160
176:  我方 10-21 静态分析追问（0x402 不是 config tag + UFS.c+2326 是独立第二故障）3 天 0 回复 ⇒ 唯一信息入口未通；
301:| Q25 | G1-29 路线 A 为何卡在 UFS 初始化（2026-10-21 口径升级：…① 0x402 = 运行期注册表条目类型字段（不是 PlatformConfigurationMapLib 的 config tag…）解引用未映射 0xD6ABB030；② UFS.c+2326 = UFSSmmuConfig 失败…
```

- S9 要求把 §5 Q25 ① 改为「0x402 = 请求上下文偏移 0 的 opcode（0x401..0x404 分派表），崩溃点为其 +4 字段被当指针解引用」：Q25 行（L301）**仍是 10-21 旧文案**「运行期注册表条目类型字段」⇒ **未并入**。
- 更严重的是：§4 N1 单元格（L182 附近）已有 10-24 晚更正「**根本不存在「运行期表」**，原「缺提供者」假设作废」，与 §5 Q25 行（L301）的「0x402 = 运行期注册表条目类型字段」**在同一份 SSOT 内自相矛盾**（详见 §2.5）。
- S9 要求「§4 N1 单元格可加『回帖定稿已就绪，待用户批准发送』」：N1 单元格最后更新停在 10-27（uefi-control-experiment 指针），**无 10-28 回帖已发（comment 6460500452）、无 10-29 定稿就绪** ⇒ **未并入**。
- 定稿件存在：`reports/uefi-issue12-reply-final-draft-20261029.md`（会话声明的证据指针，文件在盘）。


## §2 跨文档矛盾

> 每条给：文档位置 + 原文摘录 + 建议以哪处为准 + 理由。原文均为 grep/sed 直取。

### 2.1 ① 在机 `boot_b` 与 `uname` —— 同仓 5 处口径并存，DEVICE（自封唯一权威）过期最重

| 位置 | 原文摘录 |
|---|---|
| `TASKS/README.md:19`（§0 运维行首）| 「**2026-10-29 在机状态**：`boot_b` = **`boot-elden-vk181-daily.img`**（UTS `…-debug-vk172`，`uname -v #28`），今日曾刷入 `vk182-camssv3`…后**已回滚**」 |
| 同 `TASKS/README.md:19`（行中段）| 「内核迭代至 vk182…**在机 boot_b = `vk173`**（2026-10-26 21:26 刷入…）；日常线仍 vk152 载荷 / 在机 `f2fs-root`」 |
| `TASKS/README.md:304`（§5 Q28 行）| 「在机 `boot_b` = **`vk163`**（模块化，2026-10-26 晚刷入），唯一权威 `DEVICE/README.md` §1.1」 |
| `DEVICE/README.md` §1.1（L28 起，最新两段）| 「★2026-10-26 21:26 起（在机 `boot_b` = vk173…）」「★2026-10-27（当前在机状态…`boot_b` 未改，仍是 vk173）」——**无 10-29 行**（`grep -n 'vk181\|vk182\|2026-10-29' DEVICE/README.md` 零命中）|
| `TASKS/README.md` §4 T4 行 | 「`boot_b` **仍 = `m1-baseline-f3`**（写盘未做）」（10-17 时点快照）|
| `reports/m4-camss-v3-20261029.md` §7 | 「复原：复验后 `scripts/flash-b.sh out/boot-elden-vk181-daily.img --reboot` 已回滚，设备当前 `#28`（10-27 23:26）」 |

**建议以哪处为准**：`TASKS/README.md:19` 行首（10-29 快照）+ `versions/vk-kernel-identity.tsv:59`（vk181-daily，UTS `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`）。
**理由**：它是唯一与 `versions/` 三表（registry L286 vk181-daily=「B5 实验后还原日常线树重打的无标记镜像（设备复原用）」、known-issues L351-352 `uts_dup`/`num_ne_tag` 已审查例外）和 m4-camss-v3 §7 复原记录互证的口径；vk163/vk173/vk152/m1-baseline-f3 均为各时点快照未清。`DEVICE §1.1` 自称唯一权威却停在 10-27，`§5 Q28` 行引用它还额外写死了一个更旧的 vk163 —— 双重失效。`uname` 侧注意：vk172/vk173/vk181/vk182 四号**共享 UTS**（`uts_dup` 刻意钉住，`#468` 记录 dwc3=m 依赖），`uname` 无法区分四者，只能靠 `versions/` 账本与 `uname -v` 构建序（#28 vs #31）——该陷阱 §0 行已隐含（`uname -v #28`）但 DEVICE 侧无任何说明。

### 2.2 ② 内核版本号账本（`versions/` 与 §0）—— 大体一致，M9 撤回状态未回填 §0

```
$ grep -n 'vk181-daily\|vk182-camssv3' versions/vk-registry.tsv | cut -c1-120
286: vk181-daily  b5-verify   2026-10-27  B5 实验后还原日常线树重打的无标记镜像（设备复原用）
287: vk182-camssv3 m4-v3       2026-10-29  M4 camss v3（csid-980 锁 + write-then-clear）上机复验镜像…
$ grep -n '内核迭代至\|vk161' TASKS/README.md | cut -c1-150
19: 内核迭代至 vk182…实验线最新功能件 = vk161（kexec ITS/LPI 修法，上游已投 M9）…
```

- §0「内核迭代至 vk182」+「vk182-camssv3 已在 versions/ 三表登记」与 `versions/` 三表一致 ✓。
- **矛盾**：§0 同行「vk161…上游已投 M9」vs `TASKS §7 M9-收口`「✅ **已撤回（2026-10-26）**…不发 v2」+ `reports/upstream-status-20261027.md` §0「M9 = ✅ 已撤回」。
- **建议以哪处为准**：§7 M9-收口与 upstream-status 页；§0 该半句应补「（已于 10-26 撤回）」。**理由**：投递（10-24）与撤回（10-26）都是事实，但 §0 只写前者会让读者误判系列在途；M9 的权威状态行已两处更新。

### 2.3 ③ 相机 camss 状态（§0 / §7 M4 / `reports/m4-camss-v3-20261029.md`）—— M4 行缺 10-29 段，且 10-29 更新挂错小节

| 位置 | 原文摘录 |
|---|---|
| `TASKS/README.md` §7 M4 行（最后更新 10-28 晚）| 「**上游已回信要求暂缓 camss v2**（Hangxiang Ma：等 SoB/Author 补齐）+ **CSIPHY 必须改走 `phy-qcom-mipi-csi2-core`**…两封回信已发…**v2 未投**」 |
| `TASKS/README.md:622-623`（§7 尾部「**用户态上游（phoc/phosh）**」小节内）| 「**★2026-10-29 上机复验（父会话，镜像 `vk182-camssv3`）**：v3…**无回归**…另出**上游 v6 对照**…推荐 **C→B**（先 3 句回信定调，落地只发 **0007 / 0003 / 0006** 三枚通用修复」——**camss 内容挂在 phoc/phosh 用户态小节末尾** |
| `PROGRESS.md:82` | 「**camss 线程回信已发**（`<179325717815…>`，lore `/linux-media/` 命中）：发送前发现上游最新是 **`[PATCH v23 00/15] media: qcom: camss: Add Kaanapali support`**（Hangxiang Ma，10-28）…」 |
| `reports/m4-camss-v3-20261029.md` §7 | 「v3 **无回归**…但 sashiko #4 [High]『多 RDI 累积位』的**修复效果本轮未被判别**…需要构造同一 CSID 多端口并发」 |
| `reports/upstream-status-20261027.md` §0（L15）| 「**M4-2…M4-4**（camss 驱动主体）| ⬜ 备料完成，**未投**」——落后两拍（10-28 已投 10 封、10-29 已回信并定调只发 3 枚）|

**建议以哪处为准**：时间线 = PROGRESS L82 + `m4-camss-v3-20261029.md` §7（最新事实：10-29 回信已发、v3 复验无回归、#4 未判别）；任务状态 = `TASKS §7 M4` 行（但**需补 10-29 段**）。**理由**：a) M4 行是 M 系列唯一权威任务行，止于 10-28 晚，10-29 的「放弃 6 枚 / 保留 0007/0003/0006」决定只存在于错位的 L623 段与 PROGRESS；b) L623 段挂在「用户态上游（phoc/phosh）」小节，主题不符，将来按小节检索必然漏掉；c) L623「推荐 C→B（先 3 句回信定调）」与 PROGRESS「回信已发」读起来像两回事，实际是同一天的先后两步（推荐→已执行），需在 M4 行用一句话收拢。

### 2.4 ④ G2 C5/U7 状态（§2、§0）—— §0 G2 行三重过时，C5 行内含被 #467 推翻的陈述

| 位置 | 原文摘录 |
|---|---|
| `TASKS/README.md:16`（§0 G2 行）| 「进行中 1（**C8 上机探测**）…未开始 1（C5 ②b 已完成 2026-10-19…剩 **U7 App 实开预览（需装 APK）** + C3 身份/DRM 实测）」 |
| `TASKS/README.md` §0 拓展行 | 「**Gunyah 已终局裁决 2026-10-25 = 不做**」（= C8 的裁决） |
| `TASKS/README.md:71`（§2 C5 行 10-28 段）| 「① **不需要装 APK** —— 镜像里本来就有 `net.sourceforge.opencamera`（还有 Google Camera fishfood）」 |
| `PITFALLS/README.md:172`（#467）| 「『镜像里本来就有 X』必须 `pm list packages` 现查（**10-28 记的 Binary Eye、10-23 记的 OpenCamera 本机都已不存在**）」 |
| `TASKS/README.md:71`（C5 行 10-29 段）+ `PROGRESS.md:219` | 「★2026-10-29 修法已上机 = 有效…剩余卡点换人…surfaceflinger `SIGABRT: Unable to generate SkImage` 自杀…另 App 12 请求后不再下请求」／「G2：容器相机 **HAL 侧缺陷已闭环**…只剩**容器图形层…+ App 端请求停止**」 |

**建议以哪处为准**：§2 C5 行 10-29 段 + `PROGRESS.md:219`。**理由**：① §0 G2 行「C8 上机探测」与同文件 §0 拓展行「Gunyah 结项」直接冲突；② 「需装 APK」先被 10-28 推翻（不用装）、再被 10-29 `#467` 二次推翻（镜像里本来就没有，10-28 的观测是错的）——C5 行 10-28 段的「镜像里本来就有 OpenCamera」未加任何「后被 #467 否证」标注；③ §0 表内 G3 行已更新到 10-29 而 G2 行停在 10-19/10-23，更新不完整会让 §0 失去「总览」意义。

### 2.5 ⑤ 邮件在途系列状态（§7 与 `reports/upstream-status-20261027.md`）—— 「当前页」指针指向过期快照

| 位置 | 原文摘录 |
|---|---|
| `TASKS/README.md` §7 顶部 | 「本节维护 M1–M9 状态（**当前一页 = `reports/upstream-status-20261027.md`**）」 |
| `reports/upstream-status-20261027.md` §0 | 「M4-2…M4-4 = ⬜ 备料完成，**未投**」／「M8 = Taniya 反对复位归属，我方 10-23 已回（接受搬 `msm_mdss_reset()`）」——**无 10-28/10-29 动态** |
| `TASKS/README.md` §7 M8 行 | 「**★2026-10-28 回信已发（lane，父复核）**：Taniya Das **否决「复位由 clk driver 驱动」**（复位应由显示 SW 负责）⇒ **RFC 原形状作废**，落点改为 `msm_mdss_reset()`」 |
| `TASKS/README.md` §7 M2 行 | 「**★2026-10-28 厂商 QBG/battery 重新评估（lane，父复核）**：旧结论…**已推翻**…致命互斥已证…落点推荐 **B > C > A**」 |
| `patches/upstream/q28-dispcc-2026-10-22/README.md:3` | 「**状态**：✅ **已发送并归档（2026-10-22 22:08:10 +0800）**」——无 Taniya 否决与 RFC 作废记录（10-28 dispcc lane 自述「未改该 README 状态行」的欠账**至今未还**） |

**建议以哪处为准**：各 M 行内文（M8/M2 的 10-28 段已并入）为权威；`upstream-status-20261027.md` 需出 10-29 新页或在页首加「已过期，最新见 TASKS §7 各 M 行」横幅，§7 顶部指针同步改。**理由**：TASKS §7 顶部明说「当前一页」取代旧页，但该页 M4「未投」与 M4 行「已投递并复核（10-28）」直接矛盾、M8「等回包」与 M8 行「RFC 原形状作废」脱节；按指针去读一页状态的读者会拿到 10-27 的错误结论。`q28-dispcc README` 属补丁目录 README，非 SSOT，但它是「投递物自述状态」的唯一落点，滞后会让下游（如 b4/lore 检索）误判系列活跃。

### 2.6 ⑥（补充，S9 触发）§5 Q25 与 §4 N1 的 `0x402` 语义 —— 同仓自相矛盾 + 10-29 硬证据未入账

- `TASKS/README.md:301`（§5 Q25）：「① `0x402` = **运行期注册表条目类型字段**（不是 `PlatformConfigurationMapLib` 的 config tag…）解引用未映射 `0xD6ABB030`」。
- `TASKS/README.md` §4 N1（10-24 晚更正段）：「**★假设已被证伪**（2026-10-24 晚）…**根本不存在「运行期表」**，原「缺提供者」假设作废」。
- `reports/uefi-issue12-reply-final-draft-20261029.md`（10-29 定稿）：「0x402 语义…升为【**已证=请求上下文偏移 0 的 opcode（0x401..0x404 分派表）**】；崩溃点是 ctx+4 被当指针解引用（0xD6ABB030）；该路径全程 0 次查表」。

**建议以哪处为准**：10-29 定稿报告（llvm-objdump 反汇编硬证据，链路 `0x401..0x404 → 0x12e90 → 0x13120` 实测）。**理由**：Q25 行是 10-21 文案，先被 N1 的 10-24 更正（「不存在运行期表」）否定、再被 10-29 反汇编进一步精化（opcode 分派表）——同一份 SSOT 内 §4 与 §5 对同一事实给出两个矛盾答案，且 N1/Q25 均未记录「10-28 已发回帖（comment 6460500452）」与「10-29 新回帖定稿待批」。该矛盾 S9 会话已显式声明待并入（见 §1.11），属于**声明未执行**而非隐性漂移。

### 2.7 ⑦（补充，审计中发现）`reports/c5-u7-gralloc-layout-20261028.md` 停留在「E1/E2 未判别」中间态

- 该报告 §2 现状：「## §2 决定性设备侧检查（下一轮，唯一动作）：开 ALOGV 跑一次 preview，抓 `outLayout y/cb/cr` 那行…E1/E2 哪一条成立（§2 一次设备侧取证即可判别）」。
- 事实链：同日晚 lane L1c 已判别（E2 已证、E1 弱否证，`reports/c5-u7-gralloc-device-20261028.md` §3）、10-29 修法已上机有效（§8.1–§8.7）。S2 会话声明的「§2 的『ALOGV 打不开』结论需改（实测可开）」未落，且全文无「已被 L1c/10-29 超越」标注。
**建议以哪处为准**：`c5-u7-gralloc-device-20261028.md`（§3 + §8）为准；layout 报告页首加一行「⚠ 已被 L1c 判别与 10-29 修法超越，本文仅供过程考古」。**理由**：该报告的「唯一动作」早已执行完毕，留着未标废会诱导下一轮重复取证（正是 `#469`「对照上游必须取最新 revision」同型的过程坑）。


## §3 待办清单（当前真正待办）

> 两栏口径：**需要设备** = 判据需在 TB322FC 上取（含用户物理配合项）；**仅主机** = 判据可在主机闭环。
> 冻结/待批项如实标注，不算主动待办。

### 3.1 需要设备

| # | 待办 | 判据 | 文档指针 |
|---|---|---|---|
| D1 | 容器图形层卡点：surfaceflinger `SIGABRT: Unable to generate SkImage` 自杀 ⇒ `am start` 全 `DEAD_OBJECT` | App 启动后 `am start` 不再 `DEAD_OBJECT`、SF 存活、App 持续下 request（不止 12 帧） | `TASKS/README.md` §2 C5 行 10-29 段；`PROGRESS.md:219`；`reports/c5-u7-gralloc-device-20261028.md` §8 |
| D2 | 容器相机像素级正确性（Y/U/V 统计）与 App 端停帧根因 | 帧内容统计非空且合理；App 端 97/12 帧后停的定位 | 同上 §8.7 欠账段；`PITFALLS #460/#467` |
| D3 | camss v3 sashiko #4 [High]「多 RDI 累积位」修复效果判别 | `media-ctl` 把 `vfe0_rdi0+rdi1` 同接 `csid0` 并发取流，AUP/RUP 计数无累积漂移 | `reports/m4-camss-v3-20261029.md` §7 末段；`TASKS/README.md:623` |
| D4 | G3 Steam：登录界面真截图闭环 + 判据③（登录态） | `grim`（或 phosh D-Bus 路径）出非空登录截图；`SetLoginState` 过 WaitingForCredentials | `TASKS/README.md:16`（§0 G3 行）；`reports/g3-steam-screenshot-paths-20261029.md` §3/§5 |
| D5 | G3 captive portal / 登录出口（涉外部出口，需用户决策） | 设备侧 5 条定案命令跑通 + `/204` body 判读 | 同上 §5.4；会话 `2026-10-29-G3截图路径.md` §3 |
| D6 | Q33 WCD939X 冷起 20 s 读重试 | 调用栈定位 `soc_component_read_no_lock()` EBUSY 来源 | `TASKS/README.md:330`（§5 Q33） |
| D7 | G2 C3 身份/DRM：PI 检测 App 侧载（APK 推进容器，#467 路径） | PI Checker 三档回包到手 | `PROGRESS.md:219`；`TASKS/README.md` §5 Q1/C3 行 |
| D8 | wl2868c 驱动上机（LDO 电压/使能时序） | TB322FC 上 probe 成功 + 8 条 `*-supply` 电压实测 | `reports/wl2868c-driver-20261028.md` 缺口清单#5；`TASKS/README.md` §7 M4 行 wl2868c 段 |
| D9 | Q34 收尾：Debian 根补装新 `elden-firmware` deb + BT 配对实测 | 包内路径验证 + 耳机配对成功 | `TASKS/README.md:330`（Q34 行「未做」段）；`PITFALLS #454` |
| D10（冻结） | UEFI E0/E1 上机（N1 维持搁置；复启条件三条） | 解冻条件任一触发才排期 | `TASKS/README.md` §4 N1；`PITFALLS #468` |
| D11（冻结） | T9 suspend 掉电率（用户 10-28 裁决最低优先暂不排期） | 恢复时按本行历史口径 | `TASKS/README.md` §4 T9 行 |
| D12（冻结） | 相机/稳定性长跑（掉电率，用户既有口径最低优先） | — | `TASKS/sessions/2026-10-29-收官-容器相机与camss定调.md` 未证实段 |

### 3.2 仅主机

| # | 待办 | 判据 | 文档指针 |
|---|---|---|---|
| H1 | **SSOT 回填包**（本报告 §1/§2 全部缺口，一次归并）：① `DEVICE §1.1` 补 10-29 在机行（vk181-daily/#28/回滚）+ §2.2 补 vendor.img gralloc 补丁记录（sha `82769ed6…`+回退件路径）；② `TASKS §0` G2 行刷新（C8 已结项、去「需装 APK」、补 C5 两步推进）；③ `§5 Q25` ① 改 0x402 opcode 文案 + `§4 N1` 补「10-28 回帖已发 / 10-29 定稿待批」；④ `§7 M4` 行补 10-29 段并把 L623 错挂段归位；⑤ `§0` vk161 半句补「（已于 10-26 撤回）」；⑥ `PITFALLS` 补 6 条（S2 三条：VERBOSE tag 带@ / DEAD_OBJECT 前台抓 / cam-restart sudo；S5 两条：cover checkpatch create-mode 假阳性 / tmpfs worktree；S1 一条：IMapper V4 PlaneLayouts 零校验）；⑦ `INDEX` 报告清单补 `wl2868c-driver-20261028.md` | 本报告 §1 表格 S1–S9 全部转绿 | 本报告 §1.6/§1.7/§1.11、§2.1/§2.4/§2.6 |
| H2 | upstream 状态页出 10-29 新页（M4 已投/回信/放弃 6 枚、M8 RFC 形状作废、M2 QBG 重评估）+ `TASKS §7` 顶部「当前一页」指针改指新页；`patches/upstream/q28-dispcc-2026-10-22/README.md` 状态行补 Taniya 否决 | §7 顶部指针与新页时间戳一致；M4-2…4 状态行不再是「未投」 | 本报告 §2.3/§2.5 |
| H3 | UEFI issue #12 新回帖发送（**待用户点头**；撤回旧说法属外部可见动作） | `gh issue comment` 成功 + 回读 URL/作者 | `reports/uefi-issue12-reply-final-draft-20261029.md` §2/§5（114 行纯 ASCII 已定稿 + 13 项检查清单） |
| H4 | wl2868c driver 系列投递（**待用户批准**；前置 = `git format-patch -v2` 统一版本前缀重生成三枚） | 三枚 `[PATCH v2]` 前缀一致 + checkpatch 复跑绿 + 250/lore 归档 | `reports/wl2868c-driver-20261028.md` §6 缺口#1；`TASKS/README.md` §7 M4 行 |
| H5 | camss 后续：盯 v23 Kaanapali 线程与 10-29 回信回包；结合 mail-triage 对 Krzysztof 3 封「LLM slop」判定改回信策略（**短、贴 diff、git 产出**，不写散文） | 有回包即分诊；回信模板改造完成 | `PROGRESS.md:82`；`reports/mail-triage-20261029.md` §0/§3 |
| H6 | M2 A2 落点 B 补丁制作（扩展 `qcom_battmgr` + 厂商 DT profile；先补厂商 `*-batt.dtsi` 取证与 ADSP battmgr 协议上机前置假设核实） | 补丁过 checkpatch + linux-next 比对 | `reports/m2-a2-vendor-qbg-20261028.md` 遗留段；`TASKS/README.md` §7 M2 行 |
| H7 | 两份过程报告加「已超越」标注：`reports/c5-u7-gralloc-layout-20261028.md` 页首（已被 L1c/10-29 修法超越）；`reports/m2-a2-vendor-repo-check-20261026.md` §1 加指向 `m2-a2-vendor-qbg-20261028.md` 的交叉指针 | 两份报告页首有指针，无过时「唯一动作」 | 本报告 §2.7、§1.8 |
| H8 | G3 截图/登录离线物料（xwd 等 deb 清单已给，`apt-get -s --print-uris` 权威现算） | 清单入库，D4 可即取即用 | `reports/g3-steam-screenshot-paths-20261029.md` §4 |
| H9（无动作） | B5 上游化：用户 10-29 裁决**暂不启动**，备料封存 | — | `TASKS/README.md` §7 M6 行 10-29 段；`reports/b5-preflight-20261029.md` |

## §4 方法与局限

### 方法
1. **范围**：`TASKS/sessions/2026-10-28-*.md`（23 个）+ `2026-10-29-*.md`（11 个）全量 `grep -n '待并入\|★SSOT'` ⇒ **16 条目**（16 文件，其中 9 条声明「待并入」、7 条声明「已并入」）；对每条目回读全文确认声明目标，再逐条 grep/sed 目标文件（`TASKS/README.md` §0/§2/§4/§5/§7、`DEVICE/README.md` §1.1/§2.2、`PROGRESS.md`、`INDEX.md`、`PITFALLS/README.md`、`versions/` 三表、以及条目点名的 8 份 reports/README）。
2. **矛盾审计**：按任务指定的 5 个面（boot_b/uname、版本账本、camss、G2 C5/U7、邮件在途）逐面对账；另在核验过程中发现 2 个补充矛盾（Q25 vs N1 的 0x402、gralloc-layout 报告中间态），共 7 项（§2.1–§2.7）。
3. **只读纪律**：本 lane 唯一写 = 本报告；未跑任何 git 写操作、未碰设备、未派子代理；全部结论附命令 + 原始输出片段。
4. **判定口径**：「已并入」= 声明目标的实质内容可在目标文件命中（允许表述演化）；「部分并入」= 主落点已命中但声明的一部分（如 PITFALLS 条目、缓解项、交叉指针）缺失；「未并入」= 声明目标零命中。

### 局限
1. **无设备面**：在机 `boot_b` 真值无法独立核验（A2 无 ssh/fastboot 通道），只能以 `TASKS §0` 行首 + `versions/` 三表 + `m4-camss-v3 §7` 复原记录三角互证；若设备实际状态与此不符，§2.1 的「以哪处为准」结论需随之修正。
2. **out/ 不入库**：邮件投递的原始转录（`out/mail-*/`）多数不在 git，投递事实采信「会话 + 报告 + lore 记录」三角，未逐封回放。
3. **无标记会话文件仅快扫**：34 个会话中 18 个无 ★SSOT 标记，只做主题行/结论行扫描与 TASKS/PROGRESS 交叉验证，未逐字全读——不排除其中还有未声明的 SSOT 意图（但其结论均已在 TASKS/PROGRESS 有对应行，风险低）。
4. **reports/ 抽样**：130+ 份报告只深读与本审计直接相关的 12 份；`INDEX §2` 文档地图完整性、`PITFALLS/sessions/` 子目录逐条比对不在本 lane 范围。
5. **时点快照**：本报告基于 2026-10-29 15:26 前的文件状态（`TASKS/sessions/` 目录 mtime）；若并行 lane 在审计期间继续写 SSOT，命中行号可能漂移。

---

### 审计期间观察（并行写入）

- 本报告判定基于 **2026-10-29 15:26 前的文件快照**。审计尾段（`git status` 时刻）检测到 `TASKS/README.md` 出现**非本 lane 的未提交修改**（9 insertions / 8 deletions），方向与本报告 §3.2 H1 回填包一致：① `§5 Q25` ① 已改为「已两次修正：10-24 N1 证伪 + 10-29 反汇编定论 = opcode 分派表」；② `§5 Q28` 行已删去写死的「在机 boot_b = vk163」；③ `§7` 顶部「当前一页」已改为「各 M 行内文即权威，upstream-status-20261027.md 是 10-27 快照」；④ M4 行在重排。同时新出现 `reports/{c5-u7-sf-skimage,m8-dispcc-v2,mail-triage-20261029b,usb-dual-port-attribution,m4-camss-v3-plan}-20261029.md` 等本 lane 未读过的文件。
- **推论**：另一归并 lane 正在同步执行回填；H1/H2 的部分项可能已由其完成。后续执行者应**先 `git diff` 对账本报告 §1/§2 清单再做**，避免重复写入或冲突；本报告行号以 15:26 快照为准。

A2-DONE
