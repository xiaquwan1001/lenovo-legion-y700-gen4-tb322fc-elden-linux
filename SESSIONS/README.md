# SESSIONS — 会话角度（逐会话索引与档案）

> ## ⚠ 本目录 = **已冻结的历史快照**（2026-10-15 标注）
>
> **新会话不进入本目录。** 本目录与 `sessions/*.md` 是 2026-10-14 从 `RESOURCES.md` §4
> 机械迁出的**一次性快照**，此后不再增补（§1/§2/§3 三张表永久停在快照值）。
>
> - **要检索会话** → 一律用 **pi 原生会话**：`.pi/sessions/*.jsonl`（`session_search` / `/resume`）。
>   这是**唯一权威**，也**不要求**任何人手抄索引表（口径见 `INDEX.md` §2 / `.pi/AGENT-OPS.md` §4）。
> - **要知道任务状态** → `../TASKS/README.md` §0。
> - **要看逐提交史** → `../HISTORY/`（由 `scripts/gen-history.sh` 再生）。
> - **本目录为何还留着**：它是 `scripts/check-sessions.sh` 的逐字节校验基准（对
>   `git show d8ae437:RESOURCES.md`），并有 `HISTORY/days/*` 的反向链接；**保留 = 零风险**，
>   退役反而要同步改角度清单与交叉链接。故**冻结保留**，不再维护、不再新增。
>
> 读到本目录时请把它当**档案**，不要当「当前会话列表」。

> **角度**：本项目（TB322FC / elden）**逐会话的索引与档案**。
> **SSOT 声明**：本目录（`README.md` + `sessions/*.md`）是**会话视角的快照视图**；
> 提交视角（谁在什么时候提交了什么）见 [`../HISTORY/`](../HISTORY/README.md)，两者互补、不互相覆盖。
> 任务状态 / 完成度 / 未解项**不在此维护**，以 `../TASKS/README.md` §0 为准。
> 生成：`scripts/gen-sessions.py`；源快照：`git show d8ae437:RESOURCES.md` §4 会话索引。

---

## 0. 会话身份与检索（**权威不在本目录**）

- **会话身份 + 全文 = pi 原生项目会话**：磁盘 `.pi/sessions/*.jsonl`（项目级 `sessionDir`）。
  检索 = **`session_search`**（hermes 记忆检索）或 pi 会话选择器 **`/resume`**；会话内容**不手抄、不复制进本目录**。
- **§1/§2/§3 是快照**（2026-10-14 从 `RESOURCES.md` §4 会话索引迁出时冻结），此后新增会话不在表内。
- **逐会话档案**：`sessions/YYYY-MM-DD-<名称>.md`（共 171 个），与 §3 表**一行一文件**；
  文件名 = 日期 + 「名称（建议）」slug 化；同日重名加 `-2` 或 `-<短id>`。
- **磁盘匹配**：用 `.pi/sessions/*<短id>*.jsonl` 定位；最早 9 条（2026-09-29 → 09-30）因早期目录布局
  存放在 `.pi/sessions/--home-xuqianhui1001-y700-elden--/`（各档案文件内已逐条列出真实路径）。
- **历史子节处置**：源 §4.4「删除候选」（junk 已删/其余待批）与 §4.5「建议重命名」（已执行）**不再保留正文**，
  见本文件 §5。
- **⚠ 快照统计未随 v2 重核（2026-10-14）**：§1「9 条墓碑行」实为 9 条**重复 id 行**（同会话多主题/子代理，非删除/迁移）；
  「reference 34」实测 **35**；§1「主会话 jsonl 162」为快照值，磁盘顶层现 **168** 个 jsonl（快照后新增 6 个）。会话数字以 pi 原生会话（`.pi/sessions/*.jsonl`）为准。
- **缺口**：2026-10-13 的 **Waydroid 马达透传 C10** 无 §3 行/档案（快照冻结后新增），其内容见 `../PITFALLS/README.md` §29/§30；
  已完成子功能合并账见 `COMPLETED-FEATURES.md`。

---

## 1. 统计（逐字搬自源 §4.1，块内标题保持源样）

### 1. 统计

| 维度 | 分布 |
|---|---|
| 实机验证 | ✅ 实机 77 / ◐ 部分 14 / ✗ 未上机 79 |
| 状态 | active 119 / reference 34 / junk 12 / superseded 5 |
| 时间跨度 | 2026-09-29 → 2026-10-14（磁盘**主会话** jsonl **162**；本索引 **171 行**（含 9 条已删除/迁移会话的墓碑行）；子代理会话文件（深度≥2，136 个）不入本表；无产出/冒烟行标 `junk`，可整行忽略；**会话数字 SSOT = 本表**） |

---

## 2. 内核版本时间线与「实机验证边界」（逐字搬自源 §4.3）

### 3. 内核版本时间线与「实机验证边界」（任务 #2 的界）

**关键缺陷（vk7–vk41）**：早期 vkNN 构建共用同一 `uname -r` = `7.2.0-debug-gba28ec16f01f-dirty`（localversion 未改）
→ 设备上无法从内核自报分辨在跑哪个 vk；版本只能靠**镜像文件名 + 刷入命令**追溯。
**vk42 起已分离**：vk42=`geb432f18a0d1`、vk45=`g26cc186e9485`（不再是同一 uname）。

构建时间线（`out/boot-elden-vk*.img`）：

| vk | 构建时间 | 关键改动（据补丁/配置落地时间） | 会话实机确认 |
|---|---|---|---|
| vk7–vk13 | 09-28 23:43 → 09-29 23:39 | 0001 ath12k；初始 bringup | 09-29/30 会话 ✅（vk11–13） |
| vk14–vk19 | 09-30 19:08 → 19:54 | 0002 dspp-gc-gamma、0003 aw86927 haptics | 09-30 ✅（触觉修复，vk19 干净基线） |
| vk20–vk26 | 09-30 21:21 → 23:36 | 0004 wcn7861；audio SMMU/kprobe；binderfs | 09-30 ✅（vk25/26 WiFi-BT/充电） |
| vk27–vk34 | 10-01 10:55 → 23:12 | 0005 q6apm-gpr、0006–0009（DSI/面板165Hz/APM header） | 10-01 ✅（vk32/33/34，**vk34 有明确「在跑」确认**） |
| vk35 | 10-02 01:40 | 温控限频会话前后 | 10-02 ⚠️ 仅 ssh 读数，未见明确 vk35 确认 |
| vk36–vk39 | 10-02 10:48 → 12:01 | 0010 thermal-graded-trips、0011 q6apm-mi2s、config-vk40-bringup | ⚠️ INDEX 称『最后在机基线 vk39』但**无会话级确认** |
| vk40 / vk40-ram | 10-02 19:43 / 20:02 | vk39 之后 + 10-03 initramfs 持久化改动 | 10-03 ✅ 上机（U2 持久 Phosh），**但曝熄屏即重启等新 bug** |
| vk40re / vk41-psci | 10-03 19:51 / 22:46 | vk40 热区重落；`psci.c` vendor reset（→fastboot） | 10-03 ✅ `eldroid-bootctl reboot bootloader` 真进 fastboot（G1-24 S2） |
| vk42 | 10-04 00:04 | vk34-recon 基础上干净重落音频/温控增量 | 10-04 ✅ 上机 |
| vk43 / vk44 / vk45 | 10-04 00:20 / 00:42 / 00:49 | vk43：tplg MI2S SD0→SD1（出声）；vk44：VA DMIC 采集尝试；vk45：DMIC 偏置 | 10-04 ✅ **vk43 出声**；vk44/45 采集图全绿但录音恒 0（本机无 DMIC，方向证伪） |
| vk46 / vk47 / vk47a | 10-04 09:00 / 09:20 / 09:31 | vk46：持久根内核↔模块对齐；vk47：持久根基线；vk47a：BT A/B | 10-04 ✅ 模块对齐后相机/音频在持久根复现；vk47a BT 零写盘 A/B。⚠️ **镜像内核命名漂移**（2026-10-06 两法抽取 UTS）：`vk46`/`vk46-ram` 实为 **vk45**、`vk47`/`vk47-ram`/`vk47-dtb42` 实为 **vk46**；真 vk47 仅见 `vk47clean` |
| vk48 / vk49 / vk50 | 10-04 日间 → 17:45 | vk48：R1 有线耳麦 tplg RX 播放子图；vk49：相机模块冷启自动加载；**vk50：相机出流 + `LOCALVERSION=-vk50` + kexec 首测** | ✅ vk49 20 模块全载；**vk50 前后摄连续出帧**；❌ vk50 kexec `-e` 硬挂 |
| vk47clean | 10-04 23:52 | Q24 对照：干净重建内核（清除 `-dirty`） | 10-05 ✅ 持久在跑；但**熄屏→关机仍复现** ⇒ Q24 根因排除 |
| vk51 / vk52 | 10-04 晚 | vk51：bootchain（G1-29 机制/路线）；vk52：slim initramfs（G1-30） | 均主机侧；vk52 slim=20.8 MiB，E5 上机待定 |
| vk53 | 10-05 19:09 | NFC（ST21NFCA）+ CDSP + `TYPEC_MUX_FSA4480=y` | ❌ **作废**：`&i2c0`（NFC 总线）使能致硬关机，且本机无 NFC 硬件（#108）；**CDSP 部分经 vkD2 复现通过** |
| vk54 | 10-05 20:19 | kexec H4 对照（trans_pgd fix）+ DP 单变量 DTB + ramoops 取证 DT | ❌ kexec 仍失败；ram 版反复掉电→用户停手 |
| vk55 | 10-05 | 会话 overhaul（greetd `initial_session` + 用户/系统服务包） | ✅ 上机 + 重启验证（真 logind 会话、亮度 API 修复） |
| vk56 / vk57 / vk58 / vk58c | 10-05 22:18 → 23:11 | kexec R2 ad-hoc slim；vk58=带 trans_pgd fix 的运行内核；vk58c=可用 slim | ✅ vk58c `fastboot boot` 启动；❌ 从 vk58 发起 kexec 仍失败（fix 不充分） |
| vk59 | 10-05 23:58 | 驱动验证：vk53 内核（NFC+CDSP+FSA4480=y）重打 slim | ⚠️ **旧矩阵作废**：真因 = `&i2c0` 使能（#108）；**vkD1/D2/B1 单变量已定案**；CDSP-only 可启动 |
| vk60 | 10-06 | init 固化（唯一真源 + 日志 + `/persist` 竞态）+ 最小 initramfs slim 候选 | ❌ **slim 弃用**：无 `/lib/firmware` ⇒ 驱动全废（#113）；能进桌面但触屏/电池/WiFi/声音全无 |
| vk61 | 10-06 | boot_b 复刻 = 原完整 ramdisk 仅换修好 `/init`（内核/固件/模块零回归，83.3 MB < 96 MiB） | ✅ `fastboot boot` 零写盘验收（触屏/WiFi/电池/BT 正常）；**待刷 boot_b** |
| vkD1/D1a/D1b/D2 · vkB1–B4 · vkX/vkY | 10-06 | vk53 单变量二分载具（vk61 full initramfs + vk53 内核，零写盘；非 vk 号命名，不进 registry） | ✅ **定案**：仅 `&i2c0{status="okay"}` 即挂（vkB1）；nfc-pinctrl-only 起（vkD1a）、nfcdev 挂（vkD1b）、CDSP-only 起（vkD2）；vkX(dtb53) 挂 / vkY(kern53) 起。vkB2–B4 有 manifest 无结论留档 |

**边界判定**：最后**持久在机**的版本 = **`vk47clean`（b 槽，2026-10-05 至今）**；
**经 `fastboot boot` 确认启动**的版本 = vk58 / vk58c / vk59-vk47DTB；**经重刷确认在机**的含 vk55 会话 overhaul。
播放出声在 **vk43** 确认，温控四级在 **vk42** 确认，**DP 三闸根因在 vk53 内核侧实机证**（FSA4480 模块 insmod）。
「熄屏→重启/关机」（Q24）在 `vk47clean` 上仍复现（用户口述，`idle-delay=0` 规避），**根因未证实、间歇性未解**；
vk53/vk54 启动失败**已单变量定案 = 使能 `&i2c0`（本机无 NFC 硬件，#108）**：**G1-10 NFC 取消**，**G1-11 CDSP 设备侧已启动**（`vkD2-cdsponly`，待 `remoteproc1` 取证），**G1-9 DP 的 role-switch/`mdss_dp0` DTB 待做**。**相机仅 `v4l2-ctl` 出帧、缺 App 实测**；**WiFi 到可用（Q26）✅ 已关闭（2026-10-10 用户实机确认关联即可用）**；**BT 配对+TWS 已用户实测可用**。

**版本账目机读校验 + 不可复现号登记（2026-10-06）**：`archive/topics/VK-LEDGER-AUDIT-2026-10-06.md`——
`vk43` = 全账唯一零证据号（无源/镜像/manifest）；`vk52/vk54/vk56/vk57` slim 镜像**错包内核**（陈旧 `Image.gz`，
与 vk52-slim 同 bug 类）；`scripts/check-doctor.sh` §5 现已硬校验「registry 单调唯一 / registry 号必有 manifest /
树自称内核 ≡ 镜像内 UTS」，历史项经 `versions/vk-ledger-known-issues.tsv` 降 WARN。**`vk53` 已定案（2026-10-06，#108）**：实机失败真因 = 使能 `&i2c0`（与 NFC 驱动/pinctrl 无关），且本机无 NFC 硬件 ⇒ G1-10 取消；内核已补 annotated tag `vk53`@`2b5badef0`，registry 更正见 `versions/vk-registry.tsv` 注释块。**版本处置台账**（按「有成果未上机→补测、无成果→跳过、有 bug 无排查→待调查、bug 已由后续修复→闭环」）见 **`versions/vk-triage.tsv`**（54 行：补测 0 / 已知未解 3 / 待刷 1 / 跳过 7 / 闭环 43；另末尾附补测结论 + DTB 静态判定依据）。

**号与内核解耦（2026-10-08 全量对账，PITFALLS #135/#136）**：对 `out/` 76 镜像 × 61 manifest × 内核仓 33 ref 逐项比对得：**76 个带内核载荷的镜像只含 26 个不同内核二进制**（2026-10-08 快照；2026-10-10 复算 = 40 镜像/18 内核）；`7.2.0-debug-vk47clean-gbd114ca335e1` 一个 UTS 串对应 **5 个不同二进制**；**24 个镜像的 vk 号 ≠ 其内核提交所属号**（vk60/61/62/63 共用同一 vk47clean 内核；vk54 系列内核实为 vk53 提交+dirty，tag `vk54` 的 vabits fix 只在未登记的 `vk54f` 跑过；vk46/47 系列同差一号）。因此口径定为：**`vkN` = 构建/载具流水号**（2026-10-06 已如此理解 vk61，本次写成规则），**内核身份只看镜像内核载荷解压后的 sha256 + 源提交**。工具：`scripts/vk-identity.py`（生成/门禁）、`versions/vk-kernel-identity.tsv`（逐镜像对齐表，兼欠账账本）、`check-doctor` §5d（新构建硬拦，存量降 WARN）；manifest 新增 `kernel_payload_sha256`/`kernel_release_matches_image`/`kernel_packed_*`（#131 根治）。同时找回被删的 `vk43` 诚实留白 tag（现为 `archive/vk43-honest-gap`）；内核仓 pack 局部损坏已修复（#137）。

---

## 3. 全量索引（按开始时间；逐字搬自源 §4.2）

> 下表**逐字搬自** `git show d8ae437:RESOURCES.md` 的 §4.2，仅把「ID」列改为指向本目录 `sessions/` 档案文件的链接。
> `实机`/`kv` 列口径见源节说明（`kv` ＝摘要中**提及**的内核版本，**非已验证版本**）。

| 2026-09-29 | [`01a0ed5b`](sessions/2026-09-29-分区-安卓gpt缩容与游戏备份.md) | 分区：安卓GPT缩容与游戏备份 | gpt-slot | ✅ | superseded | TWRP(adb recovery)成功启动并验证；探索GPT缩容/f2fs；定位TF卡写丢失真相；Limbus/HollowKnight加密存 | vk11 | 缩容方案(65G)被后续持久化方案取代；f2fs须clean卸载；游戏存档加密未解密 |
| 2026-09-29 | [`01a0edac`](sessions/2026-09-29-文档-flashing资料打包与索引.md) | 文档：flashing资料打包与索引 | docs-reorg | ✗ | reference | 生成 flashing-bundle(257文件/15MB)+tar.gz(4.1MB,tar tzf校验)+MANIFEST.sha256+s | - | 有意排除 auth.json/models.json 等敏感文件；大二进制品留在原位 |
| 2026-09-29 | [`01a0edaf`](sessions/2026-09-29-持久根-b槽直启+gpt手术+睡眠.md) | 持久根:b槽直启+GPT手术+睡眠 | persistence | ✅ | active | b槽直启mainline(/dev/sda17)打通,GPT缩userdata加linux分区,定位睡死=进deep挂死;AVB/KSU侦察就绪 | vk12,vk13 | 睡死根因未完全闭环(deep休眠挂死);a槽AVB/KSU刷写序列未在本会话执行;会话结束时设备在fastboot |
| 2026-09-30 | [`01a0eff8`](sessions/2026-09-30-解锁-a槽ksu收尾+电源键唤醒.md) | 解锁:a槽KSU收尾+电源键唤醒 | unlock-avb | ✅ | active | a槽刷dtbo/init_boot/vbmeta/recovery后zuxos首启boot_completed=1;电源键由只能熄屏修到可正常唤 | vk12 | a槽KSU/重签AVB刷写;唤醒依赖dbus/gsd-power旁路,触屏唤醒仍不可用 |
| 2026-09-30 | [`01a0f067`](sessions/2026-09-30-槽位-gpt-a-b-槽元数据逆向.md) | 槽位：GPT A/B 槽元数据逆向 | gpt-slot | ✅ | active | 确认槽状态不在 misc 而在 boot LUN GPT：set_active 交换分区 type GUID 并翻转属性 bit，冷/热重启使  | - | 实验涉及临时改 slot successful 位与多次重启；若写错可能致槽不可启动。 |
| 2026-09-30 | [`01a0f0c7`](sessions/2026-09-30-显示-桌面对齐与缩放.md) | 显示: 桌面对齐与缩放 | display | ✅ | active | chrony修复1970→2026；foot终端装好；NetworkManager接管wlan0；缩放定位phoc.ini与phosh moni | - | 睡眠挂死未实测收口；Displays面板缩放不持久化；PMIC RTC只读只能NTP校时 |
| 2026-09-30 | [`01a0f14f`](sessions/2026-09-30-显示-缩放深色夜灯与刷新率.md) | 显示：缩放深色夜灯与刷新率 | display | ✅ | active | 定位 colord/dbus 激活与 gamma 链路问题并部分修复；发现面板固件仅适配120Hz，切60Hz会黑屏；缩放数值显示不动 | - | 60Hz模式切换黑屏未解决；缩放百分比显示与夜灯阈值仍需内核/面板线跟进 |
| 2026-09-30 | [`01a0f1ee`](sessions/2026-09-30-触觉-aw86937-马达-sram-修复.md) | 触觉：AW86937 马达 SRAM 修复 | touch-haptic | ✅ | active | 定位 AW86937 固件超 4KB 被驱动写死窗口拒绝，按型号区分 SRAM 窗口后震动成功，出 vk19 干净基线并盘点各子系统缺口。 | vk14,vk15,vk16,vk17,vk | 音频 tplg FE→BE 路由未通；USB-C alt mode、传感器、fsa4480 未绑定等缺口仍在。 |
| 2026-09-30 | [`01a0f22e`](sessions/2026-09-30-会话-pi资产内聚迁移.md) | 会话: pi资产内聚迁移 | session-meta | ✗ | reference | profile/技能/会话迁入~/y700-elden/.pi/；新增项目settings.json与trust.json；用pi SDK实测技 | - | 迁移需重启profile才生效；旧会话软链待删；android-screen-streaming留在全局 |
| 2026-09-30 | [`01a0f23c`](sessions/2026-09-30-音频-audioreach共享内存根因.md) | 音频：AudioReach共享内存根因 | audio | ✅ | active | 用 kprobe 定位 SHARED_MEM_MAP 失败根因：PCM 缓冲地址 bit32 与 AudioReach 的 SMMU sid 约 | vk19,vk20,vk21,vk22,vk | 音频修复未收口（DMA掩码/地址约定改动未生效）；多次改内核刷机；TF卡SDR104静默写坏仅记录未解决 |
| 2026-09-30 | [`01a0f292`](sessions/2026-09-30-存储-tf卡uhs与a2支持评估.md) | 存储：TF卡UHS与A2支持评估 | other | ✗ | reference | 控制器仅UHS-I(上限SDR104)、无UHS-II；主线/厂商内核都会启用A2 cache特性；现被3.3V降速workaround压到约1 | - | 结论基于既有 dmesg 与静态分析；白牌卡是否真A2无保证；SDR104静态写坏未解 |
| 2026-09-30 | [`01a0f29e`](sessions/2026-09-30-wifi-bt-驱动支持与充电旁路.md) | WiFi-BT: 驱动支持与充电旁路 | wifi-bt | ✅ | active | vk26上机验证binderfs可用；BT频繁断连定位为QCA WCN7861 IBS深度睡眠；充电'净掉电'为USB输入限流100mA；Way | vk19,vk25,vk26 | Waydroid系统镜像未下成、容器未跑通；BT IBS睡眠调参未收口；充电限制依赖ADSP |
| 2026-09-30 | [`01a0f2be`](sessions/2026-09-30-虚拟化-el2与安卓模拟器调研.md) | 虚拟化:EL2与安卓模拟器调研 | virtualization | ✗ | reference | 结论：SM8850 efisp漏洞不适用SM8750、hyp由XBL验签加载不可绕；EL2仍不可达，建议Waydroid容器+Alpine有包( | - | EL2/KVM判定为不可达属静态分析；Alpine包可用性未上机验证 |
| 2026-10-01 | [`01a0f537`](sessions/2026-10-01-容器-waydroid-编译与-mesa-卡点.md) | 容器：Waydroid 编译与 Mesa 卡点 | waydroid | ✅ | active | 系统/vendor 镜像下载校验完成、waydroid init 成功，容器进到 Android 系统层；SurfaceFlinger 因 Me | vk27 | 8 字节补丁绕过 GPU 查表后引发 gpu hangcheck lockup；AOSP 树 sync 未完成，容器尚不可用。 |
| 2026-10-01 | [`01a0f5a0`](sessions/2026-10-01-音频-主线vs厂商audioreach分析.md) | 音频:主线vs厂商AudioReach分析 | audio | ✗ | active | 发现厂商Android内核本身自带q6apm/audioreach(AudioReach SPF路径),正在diff厂商与主线APM协议实现,未 | - | 结论未闭环;主线apr按protection-domain门控/GPR_SVC_ADSP_CORE值待确认;tplg I2S子图未注册根因改动未 |
| 2026-10-01 | [`01a0f61c`](sessions/2026-10-01-下载-盘符纠正与sync续传.md) | 下载:盘符纠正与sync续传 | download-mirror | ✗ | active | 纠正NVMe盘符漂移(系统盘/新盘互换),改用by-id定位;定位sync失败=Clash代理整体挂,直连恢复,下载续传 | - | 1T盘被fio全盘覆写且累计写扇区超7%,建议回读校验;盘符漂移易误擦系统盘 |
| 2026-10-01 | [`01a0f71b`](sessions/2026-10-01-下载-教育网出口矩阵+aosp迁移.md) | 下载:教育网出口矩阵+AOSP迁移 | download-mirror | ◐ | active | 修正http_proxy污染后实测出口矩阵:USTC镜像IPv6约100MB/s,GitHub只能走代理1.3-1.9MB/s;AOSP.git | - | GitHub仅代理1.3-1.9MB/s为瓶颈;CERNET路由未持久化;代理时好时坏致误判 |
| 2026-10-01 | [`01a0f779`](sessions/2026-10-01-审计-waydroid-sync-进度与前置.md) | 审计：Waydroid sync 进度与前置 | probe-audit | ✗ | reference | sync 未完成约 48%，为真进度非卡死；构建依赖树约一半未检出故不能开工；发现看门狗停与 23G 废弃 repo。 | - | 在途 tmp_pack 129G，重启会丢失；盘空间看门狗未运行。 |
| 2026-10-01 | [`01a0f7b4`](sessions/2026-10-01-显示-面板-165hz-刷新率支线.md) | 显示：面板 165Hz 刷新率支线 | display | ✅ | active | 把 165Hz 档移到 mode table 首位，冷启即 165Hz 且 DSI 无报错；音频走 kprobe 定位 GPR/APM 问题；并 | vk28,vk29,vk30,vk31 | 165Hz 稳定性与功耗未长期验证；音频 FE→BE 仅静态推进。 |
| 2026-10-01 | [`01a0f7cd`](sessions/2026-10-01-审计-waydroid-卡点与自编-mesa.md) | 审计：Waydroid 卡点与自编 Mesa | probe-audit | ✗ | reference | 卡点=SurfaceFlinger 需 bionic Mesa≥26.1；成品不存在→树内定向编可行但全量 sync 属过度下载，可用 free | vk27 | 「升 Mesa 26.1 即不 hang」为推断非实测，存在 Glymur 反例；sync 未收敛。 |
| 2026-10-01 | [`01a0f7f0`](sessions/2026-10-01-音频-tplg-dapm出声排查.md) | 音频: tplg/DAPM出声排查 | audio | ✅ | active | 构建vk32-34上机；音频定位到'no backend DAIs enabled/found 0 new BE paths'的DAPM/tpl | vk31,vk32,vk33,vk34 | 音频BE通路未打通；面板165Hz默认是否最终验收不明；多次reboot验证 |
| 2026-10-01 | [`01a0f802`](sessions/2026-10-01-文档-补写waydroid-aosp审计.md) | 文档:补写Waydroid AOSP审计 | waydroid | ✗ | reference | 新建WAYDROID-AOSP-AUDIT-2026-10-01.md(~7KB)，含535GB树/1070+11工程/从未构建、卡点链、三路径 | - | 审计后freedreno-only最小构建尚未执行 |
| 2026-10-01 | [`01a0f80f`](sessions/2026-10-01-元-回顾近期会话确认方向.md) | 元：回顾近期会话确认方向 | session-meta | ✅ | reference | 汇总音频 GPR 根因修复(vk34)与 165Hz(vk32)成果，现场复核 vk34 在跑；锁定音频 tplg I2S 子图为主攻方向。 | vk32,vk34 | 音频 aplay 仍 EINVAL；Waydroid sync 出现 bad object 引用损坏。 |
| 2026-10-01 | [`01a0f821`](sessions/2026-10-01-waydroid-黑屏修复+mesa实测.md) | Waydroid:黑屏修复+Mesa实测 | waydroid | ✅ | active | 黑屏真因=pulse挂载非optional致LXC起不来,改lxc.py后Session/Container RUNNING;Mesa 26.1 | - | Waydroid最终由用户点图标验证;ramoops DT节点未加;容器网络未测 |
| 2026-10-01 | [`01a0f845`](sessions/2026-10-01-文档-资源就绪盘点.md) | 文档:资源就绪盘点(Mesa/设备) | probe-audit | ✗ | reference | Mesa 26.1.8已构建并部署到设备(含A830表项),AOSP树550G;设备SSH在线内核7.2.0;新Mesa尚未上机验证 | - | 残留sync进程仍在跑;新Mesa未实测;内核树11文件未提交 |
| 2026-10-01 | [`01a0f868`](sessions/2026-10-01-会话-swarm规划与子代理派遣.md) | 会话:swarm规划与子代理派遣 | session-meta | ◐ | active | 规划并发并派出多worker;抢修harness宕机;修复项目分桶被劫持到lobcorp;回收EL2与Play报告 | - | harness曾掉线;分桶劫持靠父PID修复可能复发;子代理产出未独立验证 |
| 2026-10-02 | [`01a0fa45`](sessions/2026-10-02-温控-过热限频与并发限流.md) | 温控:过热限频与并发限流 | thermal-charge | ✅ | active | ssh 47；CPU热区93–103°C而passive trip=105°C几乎不降温，负载52；执行限频后降至42–44°C；记录ustc_ | vk39,vk38 | 温控passive trip贴SoC上限、无有效cdev绑定，未固化降温策略 |
| 2026-10-02 | [`01a0fa6f`](sessions/2026-10-02-审计-未进主线驱动盘点.md) | 审计：未进主线驱动盘点 | probe-audit | ✗ | reference | 对比厂商529 compatible/297 ko，SoC层已越过；缺SLPI传感器栈(架构性放弃)、OEM私有、FM/SE；温控/旁路/DP实 | - | DP 被 DT disabled 因缺 ADSP altmode/UCSI 会 defer；相机差 config 是最高性价比下一步 |
| 2026-10-02 | [`01a0fadc`](sessions/2026-10-02-环境-过检测env-pass与sukisu.md) | 环境:过检测env-pass与SukiSU | other | ✅ | active | adb 583/fastboot 614；装SukiSU 4.2.0与envpass_props模块、隐藏KSU管理器包名后Native Det | vk39 | 刷入第三方SUSFS boot_a后ABL拒启已回刷原厂；后门模块经用户决定不装；收尾未完成（设备仍在fastboot） |
| 2026-10-02 | [`01a0fc02`](sessions/2026-10-02-文档-aosp资料迁移校验.md) | 文档: AOSP资料迁移校验 | other | ✗ | reference | 1219裸库fsck全OK、1254项目齐全、24仓库抽检干净，数据零损失；清理23G冗余与4.1G tmp_pack；fstab加固需sudo | - | gcc-4.9仓库损坏(repo sync唯一失败源)已用remove-project规避；fstab nofail需用户sudo收尾 |
| 2026-10-02 | [`01a0fc50`](sessions/2026-10-02-路线-两轨分机决定与vk40准备.md) | 路线：两轨分机决定与vk40准备 | bringup | ✗ | active | 落盘 ROUTE-DECISION：新机跑mainline/Waydroid、旧机做Android+AVF D轨；定全程不碰a槽、b槽纯RAM根 | vk40,vk39,vk38 | 仅有准备与结论，vk40 未上机；GPT手术未执行；D轨(旧机)未开工 |
| 2026-10-02 | [`01a0fc63`](sessions/2026-10-02-虚拟化-droidvm-avf路线调研.md) | 虚拟化: DroidVM/AVF路线调研 | virtualization | ✗ | reference | 报告落盘ARM-VIRT-RESEARCH-2026-10-02.md；拆两条线；发现本机stock已含com.android.virt.ape | vk40,vk39,vk38 | 判断基于文档与离线APEX提取，未真机跑VM；host AOSP树无Gunyah |
| 2026-10-02 | [`01a0fcbf`](sessions/2026-10-02-文档-六视角重构与设备等价.md) | 文档：六视角重构与设备等价 | docs-reorg | ✗ | reference | 新建 MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN，改写入口与 AGENTS，合并为六视角文档集（12 文 | vk40 | G2 的 Play DEVICE 级/Widevine L1 边界、LINUX_GIB 容量、a 槽去留均待用户拍板。 |
| 2026-10-02 | [`01a0fcee`](sessions/2026-10-02-解锁-降级1.1解锁bl成功.md) | 解锁:降级1.1解锁BL成功 | unlock-avb | ✅ | active | fastboot 523；实测U2出厂259下oem unlock-go失败，线刷1.1.11.073后oem unlock直接成功；核出boo | vk40,vk39 | 降级路径擦数据不可逆；EL2/KVM仍不可达，仅容器路线 |
| 2026-10-02 | [`01a0fd4e`](sessions/2026-10-02-引导-uefi启动链调研.md) | 引导:UEFI启动链调研 | bringup | ✗ | reference | 结论：启动链PBL→XBL(EDK II)→ABL(UEFI app)，无ESP/Boot####/ACPI；G1驱动固件走remoteproc | vk40,vk39 | 无；仅文档结论 |
| 2026-10-03 | [`01a10060`](sessions/2026-10-03-解锁-bl解锁取证与自制sn.img.md) | 解锁: BL解锁取证与自制sn.img | unlock-avb | ✅ | active | 证实AVB镜像链用AOSP testkey确实可自签；BL解锁blob为Lenovo自签证书(serial 804940DE…)，机制是免签模板 | vk40,vk39 | 1.5.10.259可能屏蔽解锁指令；Widevine L1解锁后不可逆；本轮未实际执行解锁 |
| 2026-10-03 | [`01a100d9`](sessions/2026-10-03-解锁-sn.img解密blob取证.md) | 解锁:sn.img解密blob取证 | unlock-avb | ✅ | superseded | fastboot 189；blob 356B、magic 1a2blenovo3c4d5e、Bootloader_SN与本机逐字节一致、RSA- | vk40 | 该blob路径最终未采用；真正的解锁由降级1.1路线达成 |
| 2026-10-03 | [`01a10110`](sessions/2026-10-03-解锁-bl解锁经验整理定稿.md) | 解锁：BL解锁经验整理定稿 | unlock-avb | ✗ | reference | 出复盘-2026-10-03-BL解锁.md并统一11处口径：流程=降073→oem unlock→unlock_critical；关闭G1-0 | - | 流程依赖固件≤1.1.11.073 版本门；判定行易误读(flash unlock OKAY 非判定) |
| 2026-10-03 | [`01a10158`](sessions/2026-10-03-持久根-u2上机与gpt手术.md) | 持久根:U2上机与GPT手术 | persistence | ✅ | active | ssh 247；userdata 449.7→256.7GiB、新增linux17=193GiB写后CRC OK；vk40持久b槽直启Phosh | vk40,vk39,vk38 | 熄屏/睡眠→整机重启未解（G1-22/Q21）；改idle-delay复现致重启环、SSH窗口过短，设备一度不可达 |
| 2026-10-03 | [`01a10185`](sessions/2026-10-03-会话-项目整理与git纳管.md) | 会话: 项目整理与git纳管 | session-meta | ✗ | active | git init纳管293文件；导出权威内核补丁；建RESOURCES.md §3台账；发现patches 0001-011不能完整重建内核树；发起swarm | vk40,vk39,vk38 | vk40引入未上机验证的历史新bug；旧会话归档与清理未执行；patch回导边界依赖单份导出 |
| 2026-10-03 | [`01a101bf`](sessions/2026-10-03-审计-vk34后增量第二遍.md) | 审计：vk34后增量第二遍（AUDIT2） | kernel-audit | ✅ | active | 逐hunk分类N1–N4；建V1/V2二分镜像；取得可量化回归 vk40re vblank=6/PPM=1 vs vk34recon 0/0；落盘AUDIT2 | vk40,vk34 | 静默复位间歇；V1/V2未取有效样本；取证钩子有观察者效应已回退 |
| 2026-10-03 | [`01a101ee`](sessions/2026-10-03-审计-vk34后增量第三遍.md) | 审计：vk34后增量第三遍（AUDIT3） | kernel-audit | ✅ | active | 审计前序工具调用；排除「副作用在轮询内」(0条)；查明boot_b实为vk40内核致版本归属污染；备vk34recon基线 | vk40,vk34 | reboot与轮询同命令被harness杀死(4/10)；跨版本复位比较作废 |
| 2026-10-03 | [`01a101f3`](sessions/2026-10-03-引导-linux-fastboot能力核实.md) | 引导：Linux→fastboot能力核实 | flashctl | ◐ | superseded | 本地检索确认BCB bootonce不被采纳、ABL无明文串；给出flash-b.sh免fastboot做A/B | vk40,vk34 | 「能力不存在」结论后被PSCI vendor reset推翻（见01a1021c） |
| 2026-10-03 | [`01a1021c`](sessions/2026-10-03-刷机控制+桌面-psci-reboot与elogind.md) | 刷机控制+桌面：PSCI reboot与elogind | flashctl-power | ✅ | active | 实机确认 PSCI SYSTEM_RESET2 vendor reset 生效：`eldroid-bootctl reboot bootloader` 真进fastboot；另修elogind关机（HandlePowerKey占位致shutdown inhibitor卡in-progress） | vk41,vk40 | EDL/recovery的vendor reset未测；长按关机待实测；配置重启持久性待复核 |
| 2026-10-03 | [`01a10224`](sessions/2026-10-03-会话-项目架构整理与文档分层.md) | 会话：项目架构整理与文档分层 | docs-reorg | ✗ | active | 审查12份根文档；定三层架构(领域/元/证据)+SSOT规则；新增scripts/check-doctor.sh；启动全面收敛到6份 | - | 收敛重构进行中；db/LESSONS拟删除 |
| 2026-10-03 | [`01a10264`](sessions/2026-10-03-复盘-logind-关机-+-音频-温控重落与出声.md) | 复盘：logind 关机 + 音频/温控重落与出声 | power-audio | ✅ | active | ①logind 关机假成功真根因=busybox helper 不带 `-f` 只 `kill(1)`，PID1 是 shell→假成功；落 `fix-logind-poweroff.sh`。②建 `devlogs.sh` 运行日志采集。③vk39 两增量（音频 0009/0011 + 温控 0010）被 vk34-recon 回退→新分支 vk42 干净重落（uname `geb432f18a0d1`）。④音频无声根因=tplg MI2S **SD 线错**（SD0→SD1，功放接 `i2s1_data1`）→ tplg 修正 + ramdisk 字节替换 → **vk43 出声** ✅ | vk43,vk42,vk41 | 熄屏→重启仍未解；**输入端❌**（实测本机麦克风=模拟麦接 WCD939x，非 DMIC；需 WCD939x bring-up）；温控四级 trip ✅
| 2026-10-04 | [`01a10440`](sessions/2026-10-04-会话-进度盘点与下一步规划.md) | 会话：进度盘点与下一步规划 | session-meta | ✗ | active | 实测 U2=vk45 持久根 up 7h20m；发现 INDEX §3/TASKS §0 文档漂移；定优先级 P0 收口→P1（U1 C0 取证）→P2（WCD939x / 熄屏重启） | - | P1 需 U1 接入；WCD939x 与 G1-22 未开工 |
| 2026-10-04 | [`01a104a2`](sessions/2026-10-04-会话-并发版本协作任务规划.md) | 会话：并发版本协作任务规划（swarm→subagent） | session-meta | ✗ | active | 确认可并发的版本协作任务，定主 agent 编排 + 子 agent 执行形态，给下一步建议（未执行） | - | 仅规划 |
| 2026-10-04 | [`01a104e1`](sessions/2026-10-04-会话-音频剩余问题专攻.md) | 会话：音频剩余问题专攻 | audio | ✅ | active | 主任务线收官转入残余（R1 耳麦/R2 双麦）；证据 `archive/topics/AUDIO-*`、`WCD939X-2026-10-04.md` | vk44–vk48 | R1 受硬件限制挂起 |
| 2026-10-04 | [`01a104e2`](sessions/2026-10-04-会话-tf-卡-+-相机并行.md) | 会话：TF 卡 + 相机并行（vk47 基线，三子代理） | tfcard-camera | ✅ | active | 派相机/存储/蓝牙三子代理并行；产出见 `*-2026-10-04-subagent.md` | vk47–vk49 | — |
| 2026-10-04 | [`01a104f1`](sessions/2026-10-04-会话-测试环境约束修正.md) | 会话：测试环境约束修正（RAM vs 持久变体） | docs-reorg | ◐ | active | 修正「RAM 启动缺桌面服务被误判功能故障」→ PITFALLS #93 + AGENTS 测试环境选择条款 | vk47 | — |
| 2026-10-04 | [`01a10500`](sessions/2026-10-04-会话-音频收尾.md) | 会话：音频收尾（R2 双麦/R3 裸 ALSA） | audio | ✅ | active | R2 定位 AMIC1+AMIC4 双麦；R3 `audio-alsa-init.sh` 裸 ALSA 开箱可用（保守增益 400） | vk47,vk48 | 双路采集未做（低价值） |
| 2026-10-04 | [`01a10504`](sessions/2026-10-04-会话-pi-启动入口差异说明.md) | 会话：pi 启动入口差异说明 | session-meta | ✗ | superseded | 两种入口差异解释；后续旧 cd 包装已移除 | - | PITFALLS §15.1 |
| 2026-10-04 | [`01a10527`](sessions/2026-10-04-子代理-相机-vk49-基线-+-冷启加载.md) | 子代理：相机 vk49 基线 + 冷启加载 | camera | ✅ | active | 20 模块全载、graph ENABLED、出流 -EPIPE 待续；`CAMERA-2026-10-04-subagent.md` | vk49 | 子会话 |
| 2026-10-04 | [`01a10527`](sessions/2026-10-04-子代理-tf-卡根因定性-+-5-候选补丁.md) | 子代理：TF 卡根因定性 + 5 候选补丁 | tfcard | ✅ | active | 卡本身 70–80%；`max-sd-hz` 等价厂商 shifter；`TF卡-2026-10-04-subagent.md` | vk47 | 子会话；待换卡 A/B |
| 2026-10-04 | [`01a10527`](sessions/2026-10-04-子代理-bt-根因重定位-+-keepalive-a-b.md) | 子代理：BT 根因重定位 + KEEPALIVE A/B | bt | ✅ | active | H4 不成立、H3 排除，剩 H1/H2 单变量待测；`BT-2026-10-04-subagent.md` | vk47a | 子会话 |
| 2026-10-04 | [`01a1056c`](sessions/2026-10-04-审查-上游化全量-diff-分级.md) | 审查：上游化全量 diff 分级（M 系列） | upstream | ✗ | reference | 内核树 vs 主线 v7.2 全量 diff，A/B/C/D 分级 → `UPSTREAM-REVIEW-2026-10-04.md` + TASKS §7 | - | — |
| 2026-10-04 | [`01a1058b`](sessions/2026-10-04-迭代快环工具链-+-双仓异地备份.md) | 迭代快环工具链 + 双仓异地备份 | vcs-iterate | ✗ | active | `iterate.sh` 四档环、`device-lock.sh`、kexec/to-fastboot、模块化片段、GitLab 双仓 | vk49,vk50 | 实机首测见 `01a105d1` |
| 2026-10-04 | [`01a1058e`](sessions/2026-10-04-git-历史回填-vk1-vk40.md) | git 历史回填 vk1–vk40（史记官编排） | vcs | ✗ | active | 分支 `history/pre-vk34` 49 提交 + 49 tag + graft；`archive/2026-10-04-git-backfill/` | 回填 | mtime 归因局限（见 README） |
| 2026-10-04 | [`01a10596`](sessions/2026-10-04-子代理-史记官-vk1-vk13-史料.md) | 子代理：史记官 vk1–vk13 史料 | vcs | ✗ | reference | 为回填供版本史料（base1–vk13） | - | 子会话 |
| 2026-10-04 | [`01a10596`](sessions/2026-10-04-子代理-史记官-vk14-vk34-史料.md) | 子代理：史记官 vk14–vk34 史料 | vcs | ✗ | reference | 为回填供版本史料（vk14–vk34） | - | 子会话 |
| 2026-10-04 | [`01a105d1`](sessions/2026-10-04-会话-重构复核三维度-+-p0-p1-落地-+-快环接通.md) | 会话：重构复核三维度 + P0/P1 落地 + 快环接通 | docs-reorg | ✅ | active | 复核（子代理过期/锁旁路/manifest 断链）→ agents+missions 重写、flash-b/cycle 补锁、`!out/*.manifest`、fragment 应用、vk50 构建+kexec 首测 | vk50 | 本会话 |
| 2026-10-04 | [`01a105f5`](sessions/2026-10-04-会话-精简审计执行.md) | 会话：精简审计执行（产物 -6G） | cleanup | ✗ | reference | 执行 E1/E2/E4/E5/S1/C1/C2：out 旧镜像/中间物/死脚本/junk 会话清理；**补回 `extract-avfpubkey.py`**（自测 PASS）；check-doctor FAIL=0；提交 `76c444c` | vk50 | E3/E6/S2-S4 未批；`archive/topics/清理清单-2026-10-04-精简审计.md` |
| 2026-10-04 | [`01a105fb`](sessions/2026-10-04-子代理-只读审计-1-01a105fb.md) | 子代理：只读审计（会话清理候选） | audit | ✗ | reference | 会话/复盘覆盖归属审计，产出可删候选清单（未删） | - | 子会话；被 01a105f5 采纳 |
| 2026-10-04 | [`01a105fb`](sessions/2026-10-04-子代理-只读审计-2-01a105fb.md) | 子代理：只读审计（文档精简） | audit | ✗ | reference | 6 份文档全读：过时数字（51/59/68 会话数、33/57 镜像数）、死链（`extract-avfpubkey.py`、`config-vk-modular`、`net-up-manual.sh`、flashing-bundle 路径）、SSOT 违规 | - | 子会话；多数已修 |
| 2026-10-04 | [`01a105fb`](sessions/2026-10-04-子代理-只读审计-3-01a105fb.md) | 子代理：只读审计（.pi 配置） | audit | ✗ | reference | agents/missions/skills/settings 审计：93 处路径引用 0 真死链（missions/agents）、**2 处 SKILL 死链**（已修）、HINDSIGHT +5 行值得提交 | - | 子会话；check-doctor 已扩覆盖 SKILL |
| 2026-10-04 | [`01a10635`](sessions/2026-10-04-会话-相机出流-+-kexec-定论-+-g1-22-初判.md) | 会话：相机出流 + kexec 定论 + G1-22 初判 | camera-kernel | ✅ | active | **G1-5 前后摄连续出帧**（根因=csiphy/vfe 默认格式与 sensor raw 不匹配+链路未使能）；**kexec 定论硬挂不可用**；vk50 `LOCALVERSION=-vk50` 重建 1513 模块对齐；G1-22 初判=vk40 音频插桩+热区（**2026-10-05 反转：未证实，见 Q24**） | vk50 | `CAMERA-2026-10-05.md`、`G1-22-2026-10-05.md` |
| 2026-10-04 | [`01a1068c`](sessions/2026-10-04-会话-并发任务基线+fork-工作流.md) | 会话：并发任务基线+fork 工作流 | vcs | ✗ | reference | `lane.sh`/`.githooks/commit-msg`/`versions/vk-registry.tsv`/`.pi/CONCURRENCY.md` 落地（提交 `bfe0002`）；修「扫 out 猜版本号」撞车根因 | - | 冒烟验证通过 |
| 2026-10-04 | [`01a106b9`](sessions/2026-10-04-会话-持久根模块对齐-+-干净内核判定.md) | 会话：持久根模块对齐 + 干净内核判定 | kmod-clean | ✅ | active | 25 模块部署到运行内核 → 相机/音频在持久根复现；确认 **boot_b=vk47 `-dirty` 镜像**；出 `bootslot-b/boot_b-clean.img` 并刷入（Q24）。⚠️ **后续反转**：刷后仍复位 ⇒「dirty 镜像为根因」**未证实**，转间歇性未解 | vk47 | `KMOD-ALIGN-2026-10-05.md`；结论见 Q24/REBOOT-5MIN §7.9 |
| 2026-10-04 | [`01a1071b`](sessions/2026-10-04-会话.md) | 会话：（空「可以继续了」） | session-meta | ✗ | junk | 仅一句用户消息，无助手产出 | - | - |
| 2026-10-04 | [`01a1072e`](sessions/2026-10-04-会话-编排桌面四问+bootchain.md) | 会话：编排桌面四问+bootchain（内联侦察） | desktop-bootchain | ◐ | active | 编排 G1-26/27/28（dt-ui）+ G1-29（bootchain）；内联定位：dconf 未落错 HOME、**无 logind 会话**、gsd-power 在 **session bus**、elogind SetBrightness 任意 name 均 EISDIR | - | 子代理受预算墙；转内联 |
| 2026-10-04 | [`01a10736`](sessions/2026-10-04-子代理-bootchain.md) | 子代理：bootchain（G1-29 间接引导层） | bootchain | ✗ | reference | 四代 UEFI **被拆成 `uefi_a`/`imagefv_a`/`abl_a` 由 XBL 加载**、ABL 自身不扫 FAT；路线 C（min initramfs）现在可做、A（自建可自举 UEFI 壳）有原型；交付 `scripts/grubfat-*.sh`；`BOOTCHAIN-2026-10-05.md`；vk51 | vk51 | lane 已 merge；E1/E3→E4→E5 待排期 |
| 2026-10-04 | [`01a10736`](sessions/2026-10-04-子代理-dt-ui.md) | 子代理：dt-ui（G1-26/27/28 桌面用户态） | desktop-ui | ✅ | reference | **GTK3 无头探针证实 `Adwaita-dark`→回退浅色**（应 `Adwaita`+prefer-dark）；accent 被 phosh guard 拦（同名问题）；亮度=elogind 无 session/VT；gsettings 须 `dbus-run-session`。**lane 未提交、会话中断** → 证据父代落 `DT-UI-2026-10-05.md` | - | lane `dt-ui` 仍 open（无改动） |
| 2026-10-04 | [`01a10744`](sessions/2026-10-04-会话-dt-ui-重派-1.md) | 会话：dt-ui 重派（空） | session-meta | ✗ | junk | 仅派发词，0 助手消息（预算墙/模型解析失败） | - | - |
| 2026-10-04 | [`01a1074a`](sessions/2026-10-04-会话-dt-ui-重派-2.md) | 会话：dt-ui 重派（空） | session-meta | ✗ | junk | 仅派发词，0 助手消息 | - | - |
| 2026-10-04 | [`01a10759`](sessions/2026-10-04-会话-编排.md) | 会话：编排（预算墙中断） | session-meta | ✗ | junk | 编排被 `ustc-ai-3` 预算墙打断；结论被 01a1072e 取代 | - | - |
| 2026-10-04 | [`01a10789`](sessions/2026-10-04-会话-进度整理-+-卡点-+-会话成果汇总.md) | 会话：进度整理 + 卡点 + 会话成果汇总 | session-meta | ✗ | active | 汇总 12 个未收录会话的成果；补 `DT-UI-2026-10-05.md`、PITFALLS #103、TASKS G1-26/27/28、登记 3 份 EDK2-Gunyah 参考 | - | - |
| 2026-10-04 | [`01a107a2`](sessions/2026-10-04-会话-edk2-gunyah-三仓资产分析.md) | 会话：EDK2-Gunyah 三仓资产分析 | uefi-gunyah | ✗ | reference | 通读 `edk2-gunyah`/`edk2-gunyah-qemu`/`edk2-aarch64-gunyah` 三仓；结论：**均为 guest 侧 ArmVirt UEFI，无 SM8750 裸机平台代码** → G1≈0、G1-29 只提供「打包/瘦身」技巧（缺环不变）、C8 Gunyah VM 有现成 guest 固件；登记 `RESOURCES.md` §1.5 | - | 纯主机侧文档；未上机 |
| 2026-10-05 | [`01a10996`](sessions/2026-10-05-资源-sm8750-uefi-资源收集-+-中文社区检索.md) | 资源：SM8750 UEFI 资源收集 + 中文社区检索 | uefi-resources | ✗ | reference | 定位 TB322FC 设备包**已现成**（`mu_wide_platforms` → `lenovo-y700g4`）+ 原厂 DXE 备份（`UEFIFirmwareBackup`）；证实 `build_uefi.py` 原生产出 `boot.img`（BootShim + FD）；中文社区无 UEFI/WoA/U-Boot 产出；落 `UEFI-RESOURCES-2026-10-05.md`、`RESOURCES.md` §1.6 | - | 未 clone/未构建/未上机；本设备无验证记录、容量档差异待核 |
| 2026-10-05 | [`01a109e7`](sessions/2026-10-05-会话-memory_search-冒烟-1.md) | 会话：memory_search 冒烟（project/kexec） | session-meta | ✗ | junk | 单条检索指令，输出「条目数：1」（hermes 记忆迁移后冒烟） | - | 冒烟测试 |
| 2026-10-05 | [`01a109e8`](sessions/2026-10-05-会话-冒烟-1-01a109e8.md) | 会话：冒烟（只回 OK） | session-meta | ✗ | junk | 空测试，0 工具调用 | - | 冒烟测试 |
| 2026-10-05 | [`01a109e8`](sessions/2026-10-05-会话-memory_search-冒烟-2.md) | 会话：memory_search 冒烟（failure/project 计数） | session-meta | ✗ | junk | 输出 `failure:1` / `project:1` | - | 冒烟测试 |
| 2026-10-05 | [`01a109ec`](sessions/2026-10-05-会话-standing-instructions-条数冒烟.md) | 会话：standing-instructions 条数冒烟 | session-meta | ✗ | junk | 输出 7（校验 STANDING.md 注入） | - | 冒烟测试 |
| 2026-10-05 | [`01a109ec`](sessions/2026-10-05-会话-冒烟-2-01a109ec.md) | 会话：冒烟（只回 OK） | session-meta | ✗ | junk | 空测试 | - | 冒烟测试 |
| 2026-10-05 | [`01a109ed`](sessions/2026-10-05-会话-冒烟-3-01a109ed.md) | 会话：冒烟（只回 OK） | session-meta | ✗ | junk | 空测试 | - | 冒烟测试 |
| 2026-10-05 | [`01a109f5`](sessions/2026-10-05-会话-uefi-路线-a-本地编译链前置.md) | 会话：UEFI 路线 A 本地编译链前置（依赖/网络） | uefi-build | ◐ | active | ① 定位本地构建依赖走 **Azure DevOps 内网 feed**（mono TLS 过不去）、代理对大文件**静默截断**（解释了 GitHub artifact 下不完）⇒ curl 直抓 nupkg + 断点续传；② 从 GitHub artifact 取到 `uefi-images-lenovo-y700g4-DEBUG.zip` 并**首次上机**（U7–U9 同步异常刷屏，无结论）。后半在 `01a10aab` 完成 | - | 本会话无设备侧结论；`UEFI-UFS-BRINGUP-2026-10-05.md` 含合并结论 |
| 2026-10-05 | [`01a10aab`](sessions/2026-10-05-会话-uefi-路线-a-上机-a-g-矩阵-+-上游-issue.md) | 会话：UEFI 路线 A 上机 A–G 矩阵 + 上游 issue | uefi-bringup | ✅ | active | 本地编译链打通；壳机制成立、**能进 BDS**；A–G 实验定位硬墙 = **UFS 初始化**（UFSDxe ASSERT / `Sync Exception` + SCM mailbox/QBSS/CPU_Vectors 缺失）⇒ Mu Pakala 移植层系统性缺口，非单点补丁可解；发上游 issue `sunflower2333/mu_wide_platforms#12`；最佳基线 `out/local-exp/expB-ufs-unpatched.img`；落 `UEFI-UFS-BRINGUP`/`UEFI-UFS-UPSTREAM-ASK` | - | 路线 A 搁置，待上游回复（Q25） |
| 2026-10-05 | [`01a10b60`](sessions/2026-10-05-会话-硬件驱动覆盖.md) | 会话：硬件驱动覆盖（G1-9/10/11，vk53） | hw-drivers | ✅ | active | **G1-9 DP 根因链三闸**实机定位（① FSA4480 mux 未部署→altmode 永久 defer，insmod 后**立即绑定已证**；② `usb-role-switch` 删除→UCSI defer；③ `mdss_dp0 disabled`）；G1-10 NFC / G1-11 CDSP 实现并构建 vk53（**仅主机侧**）；UEFI 搁置 + 本轮范围定为主线硬件驱动；提交 `5f1dcf0`/`69edbbd`/`86665ec` | vk53 | vk53 未上机；**2026-10-06 定案：其 DTB 启动失败根因 = 使能 `&i2c0`（本机无 NFC 硬件，#108）；NFC 项取消、CDSP 通过** |
| 2026-10-05 | [`01a10ba5`](sessions/2026-10-05-会话-kexec-热重载失败.md) | 会话：kexec 热重载失败（R1 取证 + R2 上机） | kexec | ✅ | active | R1 主机侧：`--dtb` 空操作、缺上游 `1537e55728ec`；R2 上机：带 trans_pgd fix 的 **vk58 仍失败 ⇒ fix 不充分**；`kexec -e` = **直接掉电**（非死挂），落盘 kmsg 无里程碑（疑 B1）；**附带修真 bug** = slim initramfs 缺 `/bin/sh`（#107）；`vk54-ram` 反复掉电→用户停手；提交 `7cc6407` | vk54,vk58 | kexec 分支点仍未定位；快环放弃 |
| 2026-10-05 | [`01a10ba8`](sessions/2026-10-05-会话-发行版-用户态选型-+-会话-overhaul.md) | 会话：发行版/用户态选型 + 会话 overhaul | userland-session | ✅ | active | ① 选型：**不整体换发行版**（~14 个用户态 bug 中 ~7 个是会话/PAM/logind 类，现 Alpine 加 `greetd+phrog+elogind` 会话可一次清）；② 补 28+ 包（portal/gvfs/rtkit/BT 音频/PAM）；③ **路径 A 上机 + 重启验证**：`greetd initial_session` → 真 logind 会话 c1/root/tty7 + 24 个会话服务，**亮度 `SetBrightness` 511→1800 解 EISDIR**；lane `userland-session` → `ee72844`/`03b4777`，VK=vk55 | vk55 | 落 `USERLAND-STACK`/`USERLAND-PKGS`；`/tmp` 不可写致 `phrog-dbg.log` 权限坑 |
| 2026-10-05 | [`01a10bd0`](sessions/2026-10-05-会话-三调查合并-+-驱动上机验证-+-q24-更正.md) | 会话：三调查合并 + 驱动上机验证 + Q24 更正 | merge-verify | ✅ | active | 合并 kexec/发行版/驱动（优先级裁决）；Phase1 上机：**vk53/vk54「DTS 改动致启动失败」结论已撤回**（用户 2026-10-06 更正：当时坏 init+用户态干扰，#108）⇒ 回落为未上机验证；提交 `de59ebd`/`84899ba` | vk59,vk58,vk47clean | ramoops-only/NFC-only/CDSP-only 二分未完成；init 稳固化未开工 |
| 2026-10-06 | [`01a10ebb`](sessions/2026-10-06-会话-近三日进度整理.md) | 会话：近三日进度整理（索引补齐 + 记录更正） | session-meta | ✗ | active | 补 RESOURCES §4 缺失 13 行、更新统计/时间线；更正 TASKS §0「DP/NFC/CDSP 已实现待上机」口径。本会话（进行中） | - | 进行中 |
| 2026-10-06 | [`01a10ee1`](sessions/2026-10-06-init-固化-唯一真源-+-开机刷屏真因-+-vk60-vk61.md) | init 固化：唯一真源 + 开机刷屏真因 + vk60/vk61 | init/boot | ✅ | active | 定位开机刷屏=`switch_root`×后台 `/persist` 竞态（突然 vcs 取证）；init 合为唯一真源+日志/自检/回退；发现真机 busybox 有 findfs、无 blkid/mountpoint（名单手写错误）；slim（vk60）无固件驱动全废→蛮弃；**vk61**（原 ramdisk 仅换 /init）零写盘验收通过（触屏/WiFi/电池/BT 均正常），待刷 boot_b | vk61 | boot_b 待刷；BT 「恢复正常」机制未证，需旧/新 RAM init 单变量 A/B |
| 2026-10-06 | [`01a10f2c`](sessions/2026-10-06-会话-近四天会话审查.md) | 会话：近四天会话审查（失败方向/排查思路/文档精简） | session-audit | ✗ | active | 审查 10-02→10-06 会话：成功 ~30 / 失败卡墙 ~8 / 未解 ~6 / 中断 ~14；提炼错误方向 F1–F9（检索顺序、主机侧假阳性、观察者效应、小样本定论、混淆变量、基础设施误判…）；落地文档瘦身（TASKS §1/§4、INDEX §3、PITFALLS §0 纪律 4） | - | `archive/topics/SESSION-AUDIT-2026-10-06.md` |
| 2026-10-06 | [`01a10f5e`](sessions/2026-10-06-initramfs-载具固化-+-可复现打包.md) | initramfs：载具固化 + 可复现打包 | init/boot | ◐ | active | 修 `cpio --reproducible`/`sort -z`/`gzip -n` 使打包可复现；定 slim/full 两载具；真机 `inittest-veh` 进桌面、init 日志干净 | vk61 | WiFi 慢归 Q26 |
| 2026-10-06 | [`01a10fdd`](sessions/2026-10-06-设备-bt-pan-不可用-+-cdsp-验证准备.md) | 设备：BT PAN 不可用 + CDSP 验证准备 | device-net | ◐ | active | 平板无 PAN/NAP 服务 ⇒ SSH 不能走蓝牙；U1/U2 均离线；给出 CDSP 上机验证命令（NCM/串口两路） | - | 待用户接 USB |
| 2026-10-06 | [`01a10ff8`](sessions/2026-10-06-版本-vk40-61-号审查-+-tag-补录.md) | 版本：vk40–61 号审查 + tag 补录 | vk-ledger | ✗ | active | 补 `vk54`@`26cd13b1c`；vk43/49/50 无源不伪造 tag；`check-doctor` 新增 §5 机读校验（FAIL=0） | vk40-61 | vk53 全程排除 |
| 2026-10-06 | [`01a11012`](sessions/2026-10-06-版本-vk1-40-审查-+-fastboot-侦察.md) | 版本：vk1–40 审查 + fastboot 侦察 | vk-ledger | ✅ | active | 审 vk1–40 功能/日志/上机；fastboot 侦察：current-slot=b、unlocked、max-download 768 MiB；该 ABL 不支持 `fastboot fetch` | vk1-40 | 无 |
| 2026-10-06 | [`01a1106e`](sessions/2026-10-06-文档-语义漂移审查.md) | 文档：语义漂移审查 | docs-audit | ✗ | active | 排查「偏好→规则升格 / 来源不明 / 前后翻转」共 7 项；落 `archive/topics/SEMANTIC-DRIFT-AUDIT-2026-10-06.md` | - | 待处置 |
| 2026-10-06 | [`01a11074`](sessions/2026-10-06-版本-vk61-刷入-报错-澄清.md) | 版本：vk61 刷入“报错”澄清 | vk-ledger | ✅ | active | 非故障：vk61 是 initramfs 载具号，`uname` 仍 `vk47clean` 是正确签名；kernel/dtb 与 `boot_b-live` 逐字节同 | vk61 | 无 |
| 2026-10-06 | [`01a11100`](sessions/2026-10-06-内核-reboot-edl-刷机控制取证.md) | 内核：reboot edl / 刷机控制取证 | flashctl | ✅ | active | `reboot edl`/recovery 路径取证：vk41 钩子映射 bootloader/edl → PSCI RESTART2；recovery 落 nvmem-reboot-mode 未覆盖 | - | reboot edl 实测待做 |
| 2026-10-06 | [`01a11132`](sessions/2026-10-06-用户态-g1-31-gnu-工具-+-g1-32-openrc.md) | 用户态：G1-31 GNU 工具 + G1-32 OpenRC | userland | ✅ | active | GNU 工具补装（735→760 包，重启回归 ×2）；OpenRC 交接打通（PID1=/sbin/init，rc-status 全 started，loginctl reboot 干净重启） | - | 提交 G1-31/32 收口 |
| 2026-10-06 | [`01a111ad`](sessions/2026-10-06-排查-q22-q26-下一步方法手册.md) | 排查：Q22/Q26 下一步方法手册 | method-plan | ◐ | active | Q26 三条修复未通 → 下一步方法落 `plan`/专题 §13；提交两仓 | - | 方法未执行 |
| 2026-10-06 | [`01a111cd`](sessions/2026-10-06-文档-resources-资产口径更正.md) | 文档：RESOURCES 资产口径更正 | docs | ✗ | active | §1.2 Mesa 宿主=Alpine 等 4 处口径更正，只动文档 | - | 无 |
| 2026-10-07 | [`01a11407`](sessions/2026-10-07-审计-widevine-g2-口径核实.md) | 审计：Widevine/G2 口径核实 | widevine-audit | ✗ | active | PITFALLS #126 + §15.6、TASKS §6/§5 Widevine 口径更正，提交 `2ce1cf3` | - | 无 |
| 2026-10-07 | [`01a11466`](sessions/2026-10-07-内核-cdsp-修复-+-boot_b-持久化-+-dp0-回归.md) | 内核：CDSP 修复 + boot_b 持久化 + DP0 回归 | cdsp/boot | ✅ | active | CDSP 起（split 固件+initramfs，提交 `c132a1bc7`）；boot_b 持久化 `cdsp-vk47clean`；发现并回退 DP0 黑屏回归（#128）；boot_b 内核改回 vk47clean 对齐模块 | vk47clean | 尾段 stopReason:aborted（方案 A：bd114ca33 worktree 构建 Module.symvers 未执行；dma-buf 后由 `01a11518` 别路解决，无损失） |
| 2026-10-07 | [`01a11518`](sessions/2026-10-07-相机-g1-5-完整收口.md) | 相机：G1-5 完整收口（dma-buf→软件 ISP→App） | camera | ✅ | active | dma-buf 补齐 → libcamera 软件 ISP → Snapshot 预览/拍照/录像全通，180° 朝向修正，App 实测通过 | - | 剩 C5 容器共享（非阻塞） |
| 2026-10-07 | [`01a115a8`](sessions/2026-10-07-收盘-g1-9-dp-打通-+-q21-q24-根因.md) | 收盘：G1-9 DP 打通 + Q21/Q24 根因 | dp/sleep | ✅ | active | DP 打通（`dr_mode=otg`+`usb-role-switch`+`mdss_dp0` 同批，提交 `6c1376907`，外接实测出画面）；Q24 根因实锤=相机模块链（dp5/dp6/dp7 控制变量 A/B） | - | DP 放缩/横竖屏残余（桌面侧，非阻塞） |
| 2026-10-07 | [`01a11650`](sessions/2026-10-07-会话-测试接续.md) | 会话：测试接续（中断，无产出） | stress-prep | ◐ | junk | 任务=继续未验证项（linux→安卓→x86）；止于温控/基准压测准备（读 charge-ctl.sh），**无终报无提交**；温控/基准压测**确认未执行**（全仓无运行记录） | - | 遗留未提交：`scripts/bench-run.sh`、`scripts/thermal-stress.sh`（压测脚本就绪待跑）；.pi/settings.json 为 settings 精简正常残留 |
| 2026-10-07 | [`01a11667`](sessions/2026-10-07-审计-近两天会话一致性审计.md) | 审计：近两天会话一致性审计 | session-audit | ✗ | active | 修死链误报（check-doctor 正则把 adsp.mdt 截成 adsp.md）；INDEX 88%→90%；TASKS §0 DP/Q24 状态对齐；RESOURCES §4 补 9 行（另：§2 有重复行段，待后续去重） | - | 本会话 |
| 2026-10-07 | [`01a1167d`](sessions/2026-10-07-稳定基线-vk62-收尾.md) | 稳定基线 vk62 收尾 | q28/base | ✅ | superseded | **vk62** = vk47clean 内核 + dp5 DTB H1 变体 + 完整 ramdisk + split CDSP + cmdline；已登记 registry | vk62 | vk62 后经 #131 判 tree_drift（打包内核非本树字节） |
| 2026-10-07 | [`01a11702`](sessions/2026-10-07-相机-熄屏矛盾-+-上游-patch-发送.md) | 相机×熄屏矛盾 + 上游 patch 发送 | camera/upstream | ✅ | active | 已向 linux-arm-msm@vger 发送报告；patch 转纯 ASCII、重做 commit 链（171de3ae0→c5…） | - | 网页代填，无凭据落盘 |
| 2026-10-08 | [`01a11919`](sessions/2026-10-08-待办盘点与-vk63-烧录.md) | 待办盘点与 vk63 烧录 | tasks/boot | ✅ | active | 4 提交收尾、check-doctor FAIL=0；**boot_b=vk63 已烧录读回校验**；Q26 口径撤销 | vk63 | - |
| 2026-10-08 | [`01a11a40`](sessions/2026-10-08-reboot-进-bootloader-钩子固化.md) | reboot 进 bootloader 钩子固化 | boot | ✅ | active | G1-24 `reboot edl` 实测推迟；gitlab 镜像线含逐字节相同钩子 e7453f538 | - | edl 实测未做 |
| 2026-10-08 | [`01a11a70`](sessions/2026-10-08-vk64-定版.md) | vk64 定版（相机/熄屏/桌面） | q24/camera | ✅ | active | 相机、熄屏电源、桌面三问题修复；HEAD=d02658e63（H2 DTS be79b256d + panel retry），tag vk64 转 annotated | vk64 | - |
| 2026-10-08 | [`01a11aa0`](sessions/2026-10-08-未解决问题只读盘点.md) | 未解决问题只读盘点 | docs/tasks | ✗ | reference | 2 提交 5 文档，状态复述改指针；Q24 改回 🟡 重开；check-doctor WARN 11→10 | - | - |
| 2026-10-08 | [`01a11ab5`](sessions/2026-10-08-版本号混乱核查-+-vk64-tag-修正.md) | 版本号混乱核查 + vk64 tag 修正 | vk-ledger | ✅ | active | vk64 tag lightweight→annotated（目标 d02658e63）；在途豁免 2→0、`--gate`=OK | vk64 | GitLab 服务端点击需人工 |
| 2026-10-08 | [`01a11b0a`](sessions/2026-10-08-文档入口精简-+-版本账审查.md) | 文档入口精简 + 版本账审查 | docs/vk-ledger | ✅ | active | 移走白名单负向验证 FAIL=8→恢复绿；80 镜像/26 内核二进制逐类审查 | - | - |
| 2026-10-08 | [`01a11b24`](sessions/2026-10-08-kexec-失败调查进度整理.md) | kexec 失败调查进度整理 | kexec | ✅ | active | 落盘 archive/topics/KEXEC-DIAG-TEST-PLAN-2026-10-08.md §8；设备停 boot_b vk64 | vk64 | crash kernel 未证实 |
| 2026-10-08 | [`01a11b69`](sessions/2026-10-08-内核版本号只读复核.md) | 内核版本号只读复核 | vk-ledger | ✗ | reference | 门禁 FAIL=2→0，提交 f8897dc；vk65–69 在途产物零改动 | - | - |
| 2026-10-08 | [`01a11bee`](sessions/2026-10-08-待测问题整理与内核树恢复.md) | 待测问题整理与内核树恢复 | tasks/hardware | ✅ | active | 内核树恢复 clean、.config 恢复、设备回 Linux（boot_b=vk64） | vk64 | - |
| 2026-10-08 | [`01a11bfc`](sessions/2026-10-08-kexec-取证技术总结导出.md) | kexec 取证技术总结导出 | kexec/docs | ✗ | reference | 写 `~/文档/kexec-取证与技术总结.md`（311 行，纯 Markdown） | - | 输出在项目外 |
| 2026-10-09 | [`01a11fe1`](sessions/2026-10-09-会话-10-09-中断项目接续与多线编排.md) | 会话：10-09 中断项目接续与多线编排 | session-meta | ◐ | active | 「继续之前中断的项目」→编排子代理推进文档口径/GPU·相机/旋转/kexec/UEFI/模块化多线；对齐 10-09 午后 Q28 密集复现（vk74/75/76）、GUI 死挂取证两件套、持久装弹常驻等提交（`d35088e`→`0915c4a`） | vk74,vk75,vk76 | 与 01a12093/01a120fe 多线并行、边界待厘清；主题待据正文核定 |
| 2026-10-09 | [`01a12093`](sessions/2026-10-09-会话-子代理派发.md) | 会话：子代理派发（文档/GPU·相机/旋转/kexec/UEFI/模块化） | session-meta | ◐ | active | 首条指令=分派 6 类子代理（文档进度口径审核、GPU 驱动与相机、重力旋转用户级开关、kexec 可行性、UEFI 启动、驱动模块化），高难任务用高上下文模型 | vk* | 编排会话，实机结论归各子线；主题据首条指令 |
| 2026-10-09 | [`01a120fe`](sessions/2026-10-09-会话-接手上一轮并处理待办.md) | 会话：接手上一轮并处理待办 | session-meta | ◐ | active | 首条=接手上次会话（设备在 linux）逐项处理待办 | - | 多线接续，主题待据正文核定 |
| 2026-10-09 | [`01a12140`](sessions/2026-10-09-相机-模块驱动收尾-+-camera-not-found-根因.md) | 相机：模块驱动收尾 + "camera not found" 根因 | camera | ✅ | active | 收尾相机模块驱动 + 查「模块已装仍报 camera not found」→ 根因=现役 cmdline `elden_nocamera=1` 使模块根本没加载（配置态非驱动坏，`c377ac2`/`d8ba26d`；PITFALLS #157 类误判） | vk64 | 相机⇄熄屏互斥（Q24）为已知约束；主题据首条指令+提交标题 |
| 2026-10-09 | [`01a12157`](sessions/2026-10-09-审计-当前版本基线与可安全烧录集合.md) | 审计：当前版本基线与可安全烧录集合 | version-audit | ◐ | active | 首条=「现在版本基线是多少？哪些是安全的」→盘点在机/在途 vk 基线与可安全烧录集 | vk64,vk71,vk74 | 口径与 §4.3 时间线 / `versions/` 账本一致；短会话（315 行） |
| 2026-10-09 | [`01a12302`](sessions/2026-10-09-q28-密集取证-寄存器差分-+-好-坏基线.md) | Q28 密集取证：寄存器差分 + 好/坏基线（vk74–76） | display/q28 | ✅ | active | **Q28 密集取证 / vk74–76**：首个好/坏寄存器差分到手（否掉 dsi1vco/dsi1_isr/byte-clk 三个假差异）、模块化线在机验收通过、U2 A/B 槽位险情处置；判据更正（dsi_isr **增量**不可判屏幕死活→改累计值+dmesg，`b4616d5`/`372dda8`） | vk74,vk75,vk76 | 会话跨 10-09 深夜→10-10 12:37；Q28 根因终定在后续 01a1241b |
| 2026-10-09 | [`01a11e06`](sessions/2026-10-09-设备侧工具链安装.md) | 设备侧工具链安装 | device-setup | ✅ | active | 装 30 包含依赖 ~100MB：vim/bat/fzf 等，EDITOR→vim | - | - |
| 2026-10-09 | [`01a11f5d`](sessions/2026-10-09-g1-34-重力与自动旋转.md) | G1-34 重力与自动旋转 | sensors/rotation | ✅ | active | 重力 180° mount-matrix 修正；自动旋转根因=开机时序（iio-proxy 抢 QRTR svc400 前起→phosh MODE_OFF），现场修复实测能转 | - | 持久化待办 |
| 2026-10-10 | [`01a1241b`](sessions/2026-10-10-q28-定案-死内核事故修复-+-vk84-单变量-a-b.md) | Q28 定案：死内核事故修复 + vk84 单变量 A/B | q28/build | ✅ | active | **死内核事故 + vk84 + Q28 定案**：`make olddefconfig` 误删 ARCH_QCOM 致 vk81/82/83 无 QCOM 驱动死内核（作废，PITFALLS #162），build/apply 脚本加符号守卫+回钉；vk84-q28delay-{base,exp} 单变量对（唯一差 cmdline）；Q28 根因=bonded 双 DSI 首条 DCS 命令 DMA hang（冷起 ~60%，L2 DPU ctl reset 为下游，#164）；上游正解 `2028280686f4` 逐字移植对本树无效 | vk84 | 冷 A/B 未跑完（T1 vk84-exp=NOCARD，n=1）；vk84 实验镜像在途未收口 |
| 2026-10-10 | [`01a12529`](sessions/2026-10-10-会话-新一轮项目整理.md) | 会话：新一轮项目整理（文档/参考/规划/工作史） | session-meta | ✗ | active | **本轮整理**：发起项目整理（进度文档/参考资料/下一步规划/git 工作史），派 T1/T2/T3 子代理；本行即 T2 资产台账同步所在会话 | - | 本会话；T1/T2/T3 提案待 integrator 落领域层文档 |
| 2026-10-10 | [`01a125f2`](sessions/2026-10-10-分界线-clean-base-+-模块化-vk89-+-q28-按内核二进制确定性-复核.md) | 分界线 clean/base + 模块化 vk89 + Q28「按内核二进制确定性」复核 | q28/modular | ✅ | active | **分界线**：立 `clean/base`（=vk64 源 `d02658e63`，tag `baseline/clean-base`）+ `baseline/feature-only`；删「镜像与描述对不上」10 个 img（保留 vk62/63 回退资产）；工作树切到 clean/base。**模块化**：fragment-modular → `vk89`（82.1 MiB，自包含模块化 ramdisk；补 `CONFIG_PCI_PWRCTRL_PWRSEQ=y` 修无 WiFi，#125）。**Q28 复核**：固定路径连测 21 发 ⇒ `vk64.img` GOOD×7 / 所有新编 NOCARD×14，路径·ramdisk·config·工具链·clean 全量逐个排除 ⇒ **按内核二进制确定性**（非冷/暖、非~60%随机，#171）。修 `assert-kernel-sane.sh` 对显式 `KERNEL_IMG=` 的误伤；清 /tmp 配额（~7 G 死内核 scratch）。 | vk89 | 追因 A（dump 两侧 kallsyms 定位位移区）/ B（单因素构建推 GOOD）待裁决 |
| 2026-10-10 | [`01a12542`](sessions/2026-10-10-q28-日常失败定性.md) | Q28 日常失败定性（STORM） | q28 | ✅ | active | 用户真实日常失败=**STORM（L1 cmd-DMA hang）**；NOCARD 全为伪影（reboot2 粘态或诊断链 ca813…） | - | - |
| 2026-10-10 | [`01a1259d`](sessions/2026-10-10-项目巡检与-skill-收敛.md) | 项目巡检与 skill 收敛 | docs/skills | ✗ | active | 给不常用 skill 加 `disable-model-invocation`：60→31 可见/29 隐藏，注入块 16.9K 起 | - | 浏览器相关 skill 未动 |
| 2026-10-10 | [`01a125c4`](sessions/2026-10-10-高效迭代流程与-mod-loop.md) | 高效迭代流程与 mod-loop | dev-workflow | ✅ | active | mod-loop KV 解耦 + `--bootstrap`（零写盘 fastboot boot → 推全模块）；提交 4945805 | - | - |
| 2026-10-10 | [`01a12645`](sessions/2026-10-10-q28-内核二进制确定性-溯源审计.md) | Q28「内核二进制确定性」溯源审计 | q28/audit | ✅ | active | 提交 daa858a，本地/origin(USTC)/github 三处 HEAD 一致并推送；结论次日被降级 | - | - |
| 2026-10-10 | [`01a12836`](sessions/2026-10-10-卡-fastboot-根因与修复.md) | 卡 fastboot 根因与修复 | boot/ab | ✅ | active | 刷写正确 vk64（逐字节同）；卡 fastboot=独立 rootfs provisioning bug，已修 | vk64 | - |
| 2026-10-11 | [`01a128bf`](sessions/2026-10-11-刷新率与缩放用户态修复.md) | 刷新率与缩放用户态修复 | display/userland | ✅ | active | 修 phoc 恒 165Hz（只认 preferred mode）+ 非整数比例显 100%；测中两次遇 Q28 坏 boot，循环重启撞好 boot（上限 4 次） | - | 受 Q28 挡 |
| 2026-10-11 | [`01a12965`](sessions/2026-10-11-android-侧采集准备.md) | Android 侧采集准备 | android/c0 | ✗ | reference | 流程确定：`adb reboot bootloader`→切 a 槽→刷 dtbo_a→重启采集 | - | - |
| 2026-10-11 | [`01a12973`](sessions/2026-10-11-waydroid-传感器上游路线否证.md) | Waydroid 传感器上游路线否证 | waydroid/sensors | ✅ | active | 上游 `waydroid-sensors` 在本机不能注册 HAL，反而关 stub 致容器起不来（images.py:155）；已恢复容器 | - | - |
| 2026-10-11 | [`01a129eb`](sessions/2026-10-11-三支线调查与推送.md) | 三支线调查与推送 | waydroid/sidequest | ✅ | active | 支线：waydroid 传感器、openrc→systemd、musl→glibc；推送 github+origin daa858a..fbd01d6 | - | - |
| 2026-10-11 | [`01a12a3a`](sessions/2026-10-11-容器音频与-emulated-storage.md) | 容器音频与 emulated storage | waydroid/audio | ✅ | active | 容器 emulated storage 修复（缺 `/dev/fuse`）；录音/闹钟出声；提交推送 | - | - |
| 2026-10-11 | [`01a12a67`](sessions/2026-10-11-init-glibc-选型调研.md) | init / glibc 选型调研 | research | ✗ | reference | 报告写 `~/文档/arm平板-systemd-vs-openrc-glibc-vs-musl-调研-2026-10-11.md`；systemd 更适合（DE 绑定 `systemd --user`） | - | 独立于项目 |
| 2026-10-11 | [`01a12ab4`](sessions/2026-10-11-三项架构裁决与-q28-收尾.md) | 三项架构裁决与 Q28 收尾 | decisions | ✅ | active | openrc→systemd/musl→glibc/UEFI 三项裁决；6 提交收尾，check-doctor 全绿（a0e9976…b9c25ae） | - | - |
| 2026-10-11 | [`01a12b7a`](sessions/2026-10-11-q24-q28-关系辨析.md) | Q24↔Q28 关系辨析 | q24/q28 | ✗ | active | 机制层：Q28 STORM=命令 DMA 超时（面板未 init、系统存活）；Q24=熄屏 RPMh `mxc.lvl`→0 硬复位（无痕）；共享成分小 | - | - |
| 2026-10-11 | [`01a12d5a`](sessions/2026-10-11-q28-storm-现象整理.md) | Q28 STORM 现象整理 | q28 | ✅ | active | STORM 真复现，坏发在 `msm_dsi … timing` 后 ~0.22s；落盘 `reports/q28-storm-bias-audit-20261011.md §7`（550742f） | - | - |
| 2026-10-11 | [`01a12d5a`](sessions/2026-10-11-q28-构建身份伪影定案.md) | Q28 构建身份伪影定案（续/分支） | q28 | ✅ | active | 收尾 FAIL=0：NOCARD=UTS 版本串内容、STORM=`#60` 2 位号 4坏/2好（~67%）vs 3 位号 0坏/12+ | - | - |
| 2026-10-12 | [`01a12d85`](sessions/2026-10-12-进展分析与文档收口.md) | 进展分析与文档收口（本会话） | docs/analysis | ✗ | active | 修 G2 50→60 漂移、vk 版本账收口（在途 8→0、补登 vk90–93、清死脚本/unversioned）、补会话索引 | - | - |
| 2026-10-12 | [`01a12ef1`](sessions/2026-10-12-上游邮件通道定案-+-v3-回归报告投递.md) | 上游邮件通道定案 + v3 回归报告投递 | upstream/mail | ✅ | active | 通道三选一实测：Outlook basic auth 已禁、QQ 改写 Message-ID 断线程、**USTC 保真**；v3 于 08:22Z 投递，5 个归档（arm-msm/clk/linux-devicetree/lkml/regressions）收录、正文 sha256 一致；新增 `~/.local/bin/send-mail-ustc.py`、`lore-query.py`（过 Anubis PoW） | - | Taniya `quic_tdas` 邮箱满退信 → 已用上游 yaml 登记的备用地址 `taniya.das@oss.qualcomm.com` 单独重投（无退信）；列表信被 Coremail 标 `[SPAM]` 已加白名单 |
| 2026-10-12 | [`01a12d9c`](sessions/2026-10-12-空会话.md) | 空会话（冒烟） | meta | ✗ | junk | （仅“你好”，无实质操作） | - | - |
| 2026-10-12 | [`01a12de9`](sessions/2026-10-12-pi-subagents-fabric-迁移检查.md) | pi-subagents→fabric 迁移检查 | infra/fabric | ✗ | active | 确认 pi-subagents 卸载后 agents/missions 仍可手动拼装；fabric 派发路径验证 | - | - |
| 2026-10-12 | [`01a12df8`](sessions/2026-10-12-q24-九轮静态复核与实验计划.md) | Q24 九轮静态复核与实验计划 | q24 | ✗ | active | 续接 C 系列后收敛：{camcc}单不致死、H1 DT 否证、GPU runtime-PM 否定、NoC/BCM 否证、PMIC PON 无差异；收敛到电气/时序级 | - | 下一步=外部电压测量(需人手) |
| 2026-10-12 | [`01a12ef9`](sessions/2026-10-12-项目整理与子代理分派.md) | 项目整理与子代理分派 | docs/orchestration | ✗ | active | 文档收口+死脚本清理+vk 版本账收口 | - | - |
| 2026-10-12 | [`01a12f22`](sessions/2026-10-12-q24-q28-进度确认.md) | Q24/Q28 进度确认 | docs/analysis | ✗ | active | 汇总 Q24/Q28 未解状态与下一步 | - | - |
| 2026-10-12 | [`01a12f56`](sessions/2026-10-12-linux-7.2.x-7.3-上游补丁调研.md) | Linux 7.2.x/7.3 上游补丁调研 | research/upstream | ✗ | reference | 搜索 7.2 高版本与 7.3 中与本地开发相关的补丁更新 | - | - |
| 2026-10-12 | [`01a12f8e`](sessions/2026-10-12-q28-七臂否证.md) | Q28 七臂否证（vk116–vk122+vk123） | q28 | ✅ | active | 驱动内自恢复七臂全部否证；DYN pclk 域闩住⇒故障态不在 DSI 控制器内部；恢复只能整机复位 | vk116–vk123 | 主靶 dispcc/INTF 静态对照后削弱 |
| 2026-10-12 | [`01a13056`](sessions/2026-10-12-进度整理与方向思考.md) | 进度整理与方向思考 | docs/analysis | ✗ | active | 阅读当日文档、整理 Q24/Q28 进度、评估同 SoC 板型驱动参考价值 | - | - |
| 2026-10-12 | [`01a130aa`](sessions/2026-10-12-q24-q28-本地进度核查.md) | Q24/Q28 本地进度核查 | docs/analysis | ✗ | active | 查本地进度文档与报告完整性 | - | - |
| 2026-10-12 | [`01a1327e`](sessions/2026-10-12-q24-q28-实验进展整理与报告审核.md) | Q24/Q28 实验进展整理与报告审核 | q24/q28 | ✗ | active | 整理全部实验记录，审核待发上游报告 | - | - |
| 2026-10-13 | [`01a13327`](sessions/2026-10-13-上游邮件订阅有效性审查.md) | 上游邮件订阅有效性审查 | upstream/mail | ✗ | active | 审计已订阅邮件列表哪些仍有用 | - | - |
| 2026-10-13 | [`01a1334d`](sessions/2026-10-13-locale-中文支持调研.md) | locale 中文支持调研 | research/locale | ✗ | reference | 分析设备中文 locale 是否依赖 glibc（目前设备不支持中文） | - | 纯调查未落盘 |
| 2026-10-13 | [`01a13379`](sessions/2026-10-13-上游-下游改动分布审计.md) | 上游/下游改动分布审计 | audit/upstream | ✗ | active | 检查 phosh/内核/Waydroid/LineageOS 本地改动在上游内占比 | - | - |
| 2026-10-13 | [`01a133ec`](sessions/2026-10-13-文档整理.md) | 文档整理（本会话） | docs/cleanup | ✗ | active | 补会话索引、清 tmp 文件、归档旧 plans | - | - |
| 2026-10-13 | [`01a13403`](sessions/2026-10-13-项目并行审计与文档精简.md) | 项目并行审计与文档精简 | audit/docs | ✗ | active | 五路并行审计：三层入口 + 完成度单源 + 一致性修正 + 入口精简 | - | P0–P3，`reports/audit-overview-20261013.md` |
| 2026-10-13 | [`01a13453`](sessions/2026-10-13-待办盘点.md) | 待办盘点 | docs/status | ✗ | reference | 盘点当前开放待办与卡点 | - | - |
| 2026-10-13 | [`01a134c3`](sessions/2026-10-13-上游化统筹与分片备料.md) | 上游化统筹与分片备料 | upstream/plan | ✗ | active | M1 重基 + M3-3/M3-4/M3-6/M4-camss/M5/B5 备料封存 | - | 投递冻结；`reports/m3-*`、`m4-camss-project`、`b5-dsi-resoc` |
| 2026-10-13 | [`01a1356a`](sessions/2026-10-13-m1-7.3-重基树上机-bringup.md) | M1-7.3 重基树上机 bringup | m1 | ✅ | active | 7.3-rc7 重基树零写盘 bringup；外设全废=缺 `=m` 模块（fsa4480→DP→DRM、fastrpc→传感器），非回归 | - | `reports/m1-73-port-bringup-20261013.md`、`PITFALLS #248–#250` |
| 2026-10-13 | [`01a13598`](sessions/2026-10-13-上游显示栈对照.md) | 上游显示栈对照（P1–P2c） | q28/display | ✅ | active | 纯上游 DSI 点不亮(-22)→+vendor PHY 面板 DCS 成功→**P2b 1 发 GOOD 无 Q28 签名**；P2c 合成器 GOOD 但面板无内容 ⇒ 判据须面板实测 | p1–p2c | `reports/p1-upstream-dsi-20261013.md` |
| 2026-10-14 | [`01a13795`](sessions/2026-10-14-m1-显示回归定位与根因分析.md) | M1 显示回归定位与根因分析 | m1/display | ✅ | active | 同窗口对照：日常 vk94 出桌面 / M1 7.3-rc7 树 m1-73j 只有背光 ⇒ **M1 树显示回归**（非 Q28/非粘态）；DIAG 证明 enable 路径被调用、DSC1.2 否证；强候选 H1 = 上游 revert 了 bonded PLL 初始化修复（`93c97bc8d85d`/`44784327815b`）；4 条子代理 lane（3 成 1 编排者接管） | - | Q31 未收口，E1（恢复 bonded PLL 语义 + 同内核探针）待上机；面板判据=实测；`reports/m1-display-rootcause-analysis-20261014.md` |
| 2026-10-13 | [`01a1378a`](sessions/2026-10-13-整理昨日进度-更新过时文档.md) | 整理昨日进度、更新过时文档 | docs/cleanup | ✗ | active | 收口 10-13 深夜 P1–P2c 未提交工作并同步 INDEX/TASKS/PITFALLS/q28-INDEX | - | 本会话 |

---

## 4. 逐会话档案（`sessions/`）

`sessions/` 一个文件 = 一个会话（与 §3 表顺序一一对应）：

| 字段 | 说明 |
|---|---|
| pi 会话 id | 短 id；磁盘匹配 `.pi/sessions/*<短id>*.jsonl` |
| 日期 / 名称（建议）/ 主题 / 实机 / 状态 / kv(提及) | 取自 §3 快照表，逐字 |
| 结论（原文） | §3 表「结论」列，逐字 |
| 风险 / 未收口 | §3 表「风险/未收口」列，逐字 |
| 相关提交 | 指向 `../../HISTORY/days/<日期>.md`，并注明当日提交条数 |

**生成与校验（机械，勿手抄）**：

```bash
scripts/gen-sessions.py            # 重新生成 SESSIONS/README.md + sessions/*.md
scripts/gen-sessions.py --check    # ① 文件数 == 快照表行数 ② §1/§2/§3 逐字节等于源块 ③ 字段抽检
```

---

## 5. 已执行完毕的历史子节（源 §4.4 / §4.5，不保留正文）

- **源 §4.4 删除候选**：S1 的 6 条 junk/空会话已于 2026-10-04 删除
  （见 `../archive/topics/清理清单-2026-10-04-精简审计.md`）；其余「已被取代 / junk 冒烟」项仍在 §3 表内
  （`状态` 列 = `superseded` / `junk`），处置仍为**待批**。
- **源 §4.5 建议重命名**：以 `session_info` append 方式执行、**可逆**，**已全部完成**；
  执行结果即 §3 表与 `sessions/` 文件名所用的「名称（建议）」列。
- 需要两节原始全文时查历史版本：`git show d8ae437:RESOURCES.md`。

---

## 6. 已完成子功能合并账

见 [`COMPLETED-FEATURES.md`](COMPLETED-FEATURES.md)：按子系统把「结论 ↔ 会话档案 ↔ 关键提交」并成一张账，
收敛同一完成功能的分散描述并标出缺口（本目录 §3 为 2026-10-14 冻结快照；该账为本轮整理产物，随新完成项增补）。

---

> 会话全文/检索 = pi 原生 `.pi/sessions/*.jsonl`（`session_search` / `/resume`）；本目录只存**快照索引 + 逐会话档案**。
