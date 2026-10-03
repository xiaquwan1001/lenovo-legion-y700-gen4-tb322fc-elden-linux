# 会话索引（SESSION-INDEX）

> 建立 2026-10-03。目的：把 45 个历史会话编成可检索台账，解决「轨迹复杂、AI 难以稳固推进」。
> 每行由子代理读有界摘要产出，编排者用确定性提取（直读 `.pi/sessions`）独立复核过关键条目。
> 机器可读副本：`archive/sessions-catalog-2026-10-03.jsonl`。**删除旧会话须先完成任务 #2（风险审核）并经用户确认**。

---

## 1. 统计

| 维度 | 分布 |
|---|---|
| 实机验证 | ✅ 实机 20 / ◐ 部分 2 / ✗ 未上机 23 |
| 状态 | active 23 / reference 15 / junk 5 / superseded 2 |
| 时间跨度 | 2026-09-29 → 2026-10-03（45 会话，36 在 flat、7 在 slug 目录、2 重复测试） |

---

## 2. 全量索引（按开始时间）

`实机`：✅ 有真实设备交互且给出结论 ｜ ◐ 部分 ｜ ✗ 未上机（纯文档/编译/主机侧）。
`kv`＝摘要中**提及**的内核版本（原始提及含噪声，**非已验证版本**；见 §5 时间线）。

| 日期 | ID | 名称（建议） | 主题 | 实机 | 状态 | 结论 | kv(提及) | 风险/未收口 |
|---|---|---|---|---|---|---|---|---|
| 2026-09-29 | `01a0ed5b` | 分区：安卓GPT缩容与游戏备份 | gpt-slot | ✅ | superseded | TWRP(adb recovery)成功启动并验证；探索GPT缩容/f2fs；定位TF卡写丢失真相；Limbus/HollowKnight加密存 | vk11 | 缩容方案(65G)被后续持久化方案取代；f2fs须clean卸载；游戏存档加密未解密 |
| 2026-09-29 | `01a0edac` | 文档：flashing资料打包与索引 | docs-reorg | ✗ | reference | 生成 flashing-bundle(257文件/15MB)+tar.gz(4.1MB,tar tzf校验)+MANIFEST.sha256+s | - | 有意排除 auth.json/models.json 等敏感文件；大二进制品留在原位 |
| 2026-09-29 | `01a0edaf` | 持久根:b槽直启+GPT手术+睡眠 | persistence | ✅ | active | b槽直启mainline(/dev/sda17)打通,GPT缩userdata加linux分区,定位睡死=进deep挂死;AVB/KSU侦察就绪 | vk12,vk13 | 睡死根因未完全闭环(deep休眠挂死);a槽AVB/KSU刷写序列未在本会话执行;会话结束时设备在fastboot |
| 2026-09-30 | `01a0eff8` | 解锁:a槽KSU收尾+电源键唤醒 | unlock-avb | ✅ | active | a槽刷dtbo/init_boot/vbmeta/recovery后zuxos首启boot_completed=1;电源键由只能熄屏修到可正常唤 | vk12 | a槽KSU/重签AVB刷写;唤醒依赖dbus/gsd-power旁路,触屏唤醒仍不可用 |
| 2026-09-30 | `01a0f067` | 槽位：GPT A/B 槽元数据逆向 | gpt-slot | ✅ | active | 确认槽状态不在 misc 而在 boot LUN GPT：set_active 交换分区 type GUID 并翻转属性 bit，冷/热重启使  | - | 实验涉及临时改 slot successful 位与多次重启；若写错可能致槽不可启动。 |
| 2026-09-30 | `01a0f0c7` | 显示: 桌面对齐与缩放 | display | ✅ | active | chrony修复1970→2026；foot终端装好；NetworkManager接管wlan0；缩放定位phoc.ini与phosh moni | - | 睡眠挂死未实测收口；Displays面板缩放不持久化；PMIC RTC只读只能NTP校时 |
| 2026-09-30 | `01a0f14f` | 显示：缩放深色夜灯与刷新率 | display | ✅ | active | 定位 colord/dbus 激活与 gamma 链路问题并部分修复；发现面板固件仅适配120Hz，切60Hz会黑屏；缩放数值显示不动 | - | 60Hz模式切换黑屏未解决；缩放百分比显示与夜灯阈值仍需内核/面板线跟进 |
| 2026-09-30 | `01a0f1ee` | 触觉：AW86937 马达 SRAM 修复 | touch-haptic | ✅ | active | 定位 AW86937 固件超 4KB 被驱动写死窗口拒绝，按型号区分 SRAM 窗口后震动成功，出 vk19 干净基线并盘点各子系统缺口。 | vk14,vk15,vk16,vk17,vk | 音频 tplg FE→BE 路由未通；USB-C alt mode、传感器、fsa4480 未绑定等缺口仍在。 |
| 2026-09-30 | `01a0f22e` | 会话: pi资产内聚迁移 | session-meta | ✗ | reference | profile/技能/会话迁入~/y700-elden/.pi/；新增项目settings.json与trust.json；用pi SDK实测技 | - | 迁移需重启profile才生效；旧会话软链待删；android-screen-streaming留在全局 |
| 2026-09-30 | `01a0f23c` | 音频：AudioReach共享内存根因 | audio | ✅ | active | 用 kprobe 定位 SHARED_MEM_MAP 失败根因：PCM 缓冲地址 bit32 与 AudioReach 的 SMMU sid 约 | vk19,vk20,vk21,vk22,vk | 音频修复未收口（DMA掩码/地址约定改动未生效）；多次改内核刷机；TF卡SDR104静默写坏仅记录未解决 |
| 2026-09-30 | `01a0f292` | 存储：TF卡UHS与A2支持评估 | other | ✗ | reference | 控制器仅UHS-I(上限SDR104)、无UHS-II；主线/厂商内核都会启用A2 cache特性；现被3.3V降速workaround压到约1 | - | 结论基于既有 dmesg 与静态分析；白牌卡是否真A2无保证；SDR104静态写坏未解 |
| 2026-09-30 | `01a0f29e` | WiFi-BT: 驱动支持与充电旁路 | wifi-bt | ✅ | active | vk26上机验证binderfs可用；BT频繁断连定位为QCA WCN7861 IBS深度睡眠；充电'净掉电'为USB输入限流100mA；Way | vk19,vk25,vk26 | Waydroid系统镜像未下成、容器未跑通；BT IBS睡眠调参未收口；充电限制依赖ADSP |
| 2026-09-30 | `01a0f2be` | 虚拟化:EL2与安卓模拟器调研 | virtualization | ✗ | reference | 结论：SM8850 efisp漏洞不适用SM8750、hyp由XBL验签加载不可绕；EL2仍不可达，建议Waydroid容器+Alpine有包( | - | EL2/KVM判定为不可达属静态分析；Alpine包可用性未上机验证 |
| 2026-10-01 | `01a0f533` | 会话：微信端汇报进度(空) | session-meta | ✗ | junk | 会话空，无实质助手结论 | - | - |
| 2026-10-01 | `01a0f537` | 容器：Waydroid 编译与 Mesa 卡点 | waydroid | ✅ | active | 系统/vendor 镜像下载校验完成、waydroid init 成功，容器进到 Android 系统层；SurfaceFlinger 因 Me | vk27 | 8 字节补丁绕过 GPU 查表后引发 gpu hangcheck lockup；AOSP 树 sync 未完成，容器尚不可用。 |
| 2026-10-01 | `01a0f5a0` | 音频:主线vs厂商AudioReach分析 | audio | ✗ | active | 发现厂商Android内核本身自带q6apm/audioreach(AudioReach SPF路径),正在diff厂商与主线APM协议实现,未 | - | 结论未闭环;主线apr按protection-domain门控/GPR_SVC_ADSP_CORE值待确认;tplg I2S子图未注册根因改动未 |
| 2026-10-01 | `01a0f608` | 下载:续传(1T盘暂缓) | download-mirror | ✗ | junk | 会话无助手结论输出,任务未收口(1T盘测试中) | - | 1T盘仍在测试勿用;下载进度未报告 |
| 2026-10-01 | `01a0f61c` | 下载:盘符纠正与sync续传 | download-mirror | ✗ | active | 纠正NVMe盘符漂移(系统盘/新盘互换),改用by-id定位;定位sync失败=Clash代理整体挂,直连恢复,下载续传 | - | 1T盘被fio全盘覆写且累计写扇区超7%,建议回读校验;盘符漂移易误擦系统盘 |
| 2026-10-01 | `01a0f71b` | 下载:教育网出口矩阵+AOSP迁移 | download-mirror | ◐ | active | 修正http_proxy污染后实测出口矩阵:USTC镜像IPv6约100MB/s,GitHub只能走代理1.3-1.9MB/s;AOSP.git | - | GitHub仅代理1.3-1.9MB/s为瓶颈;CERNET路由未持久化;代理时好时坏致误判 |
| 2026-10-01 | `01a0f779` | 审计：Waydroid sync 进度与前置 | probe-audit | ✗ | reference | sync 未完成约 48%，为真进度非卡死；构建依赖树约一半未检出故不能开工；发现看门狗停与 23G 废弃 repo。 | - | 在途 tmp_pack 129G，重启会丢失；盘空间看门狗未运行。 |
| 2026-10-01 | `01a0f7b4` | 显示：面板 165Hz 刷新率支线 | display | ✅ | active | 把 165Hz 档移到 mode table 首位，冷启即 165Hz 且 DSI 无报错；音频走 kprobe 定位 GPR/APM 问题；并 | vk28,vk29,vk30,vk31 | 165Hz 稳定性与功耗未长期验证；音频 FE→BE 仅静态推进。 |
| 2026-10-01 | `01a0f7cd` | 审计：Waydroid 卡点与自编 Mesa | probe-audit | ✗ | reference | 卡点=SurfaceFlinger 需 bionic Mesa≥26.1；成品不存在→树内定向编可行但全量 sync 属过度下载，可用 free | vk27 | 「升 Mesa 26.1 即不 hang」为推断非实测，存在 Glymur 反例；sync 未收敛。 |
| 2026-10-01 | `01a0f7f0` | 音频: tplg/DAPM出声排查 | audio | ✅ | active | 构建vk32-34上机；音频定位到'no backend DAIs enabled/found 0 new BE paths'的DAPM/tpl | vk31,vk32,vk33,vk34 | 音频BE通路未打通；面板165Hz默认是否最终验收不明；多次reboot验证 |
| 2026-10-01 | `01a0f802` | 文档:补写Waydroid AOSP审计 | waydroid | ✗ | reference | 新建WAYDROID-AOSP-AUDIT-2026-10-01.md(~7KB)，含535GB树/1070+11工程/从未构建、卡点链、三路径 | - | 审计后freedreno-only最小构建尚未执行 |
| 2026-10-01 | `01a0f80f` | 元：回顾近期会话确认方向 | session-meta | ✅ | reference | 汇总音频 GPR 根因修复(vk34)与 165Hz(vk32)成果，现场复核 vk34 在跑；锁定音频 tplg I2S 子图为主攻方向。 | vk32,vk34 | 音频 aplay 仍 EINVAL；Waydroid sync 出现 bad object 引用损坏。 |
| 2026-10-01 | `01a0f821` | Waydroid:黑屏修复+Mesa实测 | waydroid | ✅ | active | 黑屏真因=pulse挂载非optional致LXC起不来,改lxc.py后Session/Container RUNNING;Mesa 26.1 | - | Waydroid最终由用户点图标验证;ramoops DT节点未加;容器网络未测 |
| 2026-10-01 | `01a0f845` | 文档:资源就绪盘点(Mesa/设备) | probe-audit | ✗ | reference | Mesa 26.1.8已构建并部署到设备(含A830表项),AOSP树550G;设备SSH在线内核7.2.0;新Mesa尚未上机验证 | - | 残留sync进程仍在跑;新Mesa未实测;内核树11文件未提交 |
| 2026-10-01 | `01a0f868` | 会话:swarm规划与子代理派遣 | session-meta | ◐ | active | 规划并发并派出多worker;抢修harness宕机;修复项目分桶被劫持到lobcorp;回收EL2与Play报告 | - | harness曾掉线;分桶劫持靠父PID修复可能复发;子代理产出未独立验证 |
| 2026-10-02 | `01a0fa45` | 温控:过热限频与并发限流 | thermal-charge | ✅ | active | ssh 47；CPU热区93–103°C而passive trip=105°C几乎不降温，负载52；执行限频后降至42–44°C；记录ustc_ | vk39,vk38 | 温控passive trip贴SoC上限、无有效cdev绑定，未固化降温策略 |
| 2026-10-02 | `01a0fa4b` | 会话:OK测试 | session-meta | ✗ | junk | 6条消息，助手回复OK，无实质内容 | - | - |
| 2026-10-02 | `01a0fa4b` | 测试：仅回 OK | session-meta | ✗ | junk | 仅回复 OK，无实质内容。 | - | - |
| 2026-10-02 | `01a0fa6f` | 审计：未进主线驱动盘点 | probe-audit | ✗ | reference | 对比厂商529 compatible/297 ko，SoC层已越过；缺SLPI传感器栈(架构性放弃)、OEM私有、FM/SE；温控/旁路/DP实 | - | DP 被 DT disabled 因缺 ADSP altmode/UCSI 会 defer；相机差 config 是最高性价比下一步 |
| 2026-10-02 | `01a0fabe` | 会话: 测试OK | session-meta | ✗ | junk | 返回OK，无实际工作 | - | - |
| 2026-10-02 | `01a0fadc` | 环境:过检测env-pass与SukiSU | other | ✅ | active | adb 583/fastboot 614；装SukiSU 4.2.0与envpass_props模块、隐藏KSU管理器包名后Native Det | vk39 | 刷入第三方SUSFS boot_a后ABL拒启已回刷原厂；后门模块经用户决定不装；收尾未完成（设备仍在fastboot） |
| 2026-10-02 | `01a0fc02` | 文档: AOSP资料迁移校验 | other | ✗ | reference | 1219裸库fsck全OK、1254项目齐全、24仓库抽检干净，数据零损失；清理23G冗余与4.1G tmp_pack；fstab加固需sudo | - | gcc-4.9仓库损坏(repo sync唯一失败源)已用remove-project规避；fstab nofail需用户sudo收尾 |
| 2026-10-02 | `01a0fc50` | 路线：两轨分机决定与vk40准备 | bringup | ✗ | active | 落盘 ROUTE-DECISION：新机跑mainline/Waydroid、旧机做Android+AVF D轨；定全程不碰a槽、b槽纯RAM根 | vk40,vk39,vk38 | 仅有准备与结论，vk40 未上机；GPT手术未执行；D轨(旧机)未开工 |
| 2026-10-02 | `01a0fc63` | 虚拟化: DroidVM/AVF路线调研 | virtualization | ✗ | reference | 报告落盘ARM-VIRT-RESEARCH-2026-10-02.md；拆两条线；发现本机stock已含com.android.virt.ape | vk40,vk39,vk38 | 判断基于文档与离线APEX提取，未真机跑VM；host AOSP树无Gunyah |
| 2026-10-02 | `01a0fcbf` | 文档：六视角重构与设备等价 | docs-reorg | ✗ | reference | 新建 MISSION-SCOPE/DEVICES/ANDROID-COMPAT-PLAN，改写入口与 AGENTS，合并为六视角文档集（12 文 | vk40 | G2 的 Play DEVICE 级/Widevine L1 边界、LINUX_GIB 容量、a 槽去留均待用户拍板。 |
| 2026-10-02 | `01a0fcee` | 解锁:降级1.1解锁BL成功 | unlock-avb | ✅ | active | fastboot 523；实测U2出厂259下oem unlock-go失败，线刷1.1.11.073后oem unlock直接成功；核出boo | vk40,vk39 | 降级路径擦数据不可逆；EL2/KVM仍不可达，仅容器路线 |
| 2026-10-02 | `01a0fd4e` | 引导:UEFI启动链调研 | bringup | ✗ | reference | 结论：启动链PBL→XBL(EDK II)→ABL(UEFI app)，无ESP/Boot####/ACPI；G1驱动固件走remoteproc | vk40,vk39 | 无；仅文档结论 |
| 2026-10-03 | `01a10060` | 解锁: BL解锁取证与自制sn.img | unlock-avb | ✅ | active | 证实AVB镜像链用AOSP testkey确实可自签；BL解锁blob为Lenovo自签证书(serial 804940DE…)，机制是免签模板 | vk40,vk39 | 1.5.10.259可能屏蔽解锁指令；Widevine L1解锁后不可逆；本轮未实际执行解锁 |
| 2026-10-03 | `01a100d9` | 解锁:sn.img解密blob取证 | unlock-avb | ✅ | superseded | fastboot 189；blob 356B、magic 1a2blenovo3c4d5e、Bootloader_SN与本机逐字节一致、RSA- | vk40 | 该blob路径最终未采用；真正的解锁由降级1.1路线达成 |
| 2026-10-03 | `01a10110` | 解锁：BL解锁经验整理定稿 | unlock-avb | ✗ | reference | 出复盘-2026-10-03-BL解锁.md并统一11处口径：流程=降073→oem unlock→unlock_critical；关闭G1-0 | - | 流程依赖固件≤1.1.11.073 版本门；判定行易误读(flash unlock OKAY 非判定) |
| 2026-10-03 | `01a10158` | 持久根:U2上机与GPT手术 | persistence | ✅ | active | ssh 247；userdata 449.7→256.7GiB、新增linux17=193GiB写后CRC OK；vk40持久b槽直启Phosh | vk40,vk39,vk38 | 熄屏/睡眠→整机重启未解（G1-22/Q21）；改idle-delay复现致重启环、SSH窗口过短，设备一度不可达 |
| 2026-10-03 | `01a10185` | 会话: 项目整理与git纳管 | session-meta | ✗ | active | git init纳管293文件；导出权威内核补丁；建FILES.md台账；发现patches 0001-011不能完整重建内核树；发起swarm | vk40,vk39,vk38 | vk40引入未上机验证的历史新bug；旧会话归档与清理未执行；patch回导边界依赖单份导出 |

---

## 3. 内核版本时间线与「实机验证边界」（任务 #2 的界）

**关键缺陷**：所有 vkNN 构建共用同一 `uname -r` = `7.2.0-debug-gba28ec16f01f-dirty`（localversion 未改）
→ 设备上无法从内核自报分辨在跑哪个 vk；版本只能靠**镜像文件名 + 刷入命令**追溯。

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

**边界判定（待你确认）**：最后一个**有明确实机确认**的版本 = **vk34（2026-10-01 23:12）**；
vk35–vk40 的改动（尤其 0010/0011 与 10-03 initramfs/持久化）**未逐版单独上机验证**，
vk40 是把它们叠加后的结果 → 这是「以前没有的新 bug」的最可能来源。

---

## 4. 删除候选（**等任务 #2 完成后再执行**，需你确认）

| 类型 | ID | 日期 | 现名 | 处置建议 |
|---|---|---|---|---|
| junk/空 | `01a0f533` | 2026-10-01 | summarize: 微信端汇报进度 | 删除（无内容） |
| junk/空 | `01a0f608` | 2026-10-01 | analyze: 继续下载数据任务 | 删除（无内容） |
| junk/空 | `01a0fa4b` | 2026-10-02 | - | 删除（无内容） |
| junk/空 | `01a0fa4b` | 2026-10-02 | - | 删除（无内容） |
| junk/空 | `01a0fabe` | 2026-10-02 | - | 删除（无内容） |
| 已被取代 | `01a0ed5b` | 2026-09-29 | 分区：安卓GPT缩容与游戏备份 | 归档（结论已进更晚文档） |
| 已被取代 | `01a100d9` | 2026-10-03 | 解锁:sn.img解密blob取证 | 归档（结论已进更晚文档） |

> `01a0fa4b` 有两个文件（`-7536…`/`-6dec…`）均为 OK 测试；`01a0f868`/`01a0fd4e` 短会话可归并。

---

## 5. 建议重命名（append `session_info`，可逆；待确认后批量执行）

| ID | 现名 | → 建议名 |
|---|---|---|
| `01a0ed5b` | troubleshoot: 平板连接后续工作 | **分区：安卓GPT缩容与游戏备份** |
| `01a0edac` | chore(workspace): 整理 flashing profil | **文档：flashing资料打包与索引** |
| `01a0edaf` | troubleshoot: fastboot 设备后续刷机步骤 | **持久根:b槽直启+GPT手术+睡眠** |
| `01a0eff8` | 2026-09-30T10:04+08:00 | **解锁:a槽KSU收尾+电源键唤醒** |
| `01a0f067` | feat(flashing): 继续下一个任务 | **槽位：GPT A/B 槽元数据逆向** |
| `01a0f0c7` | analyze(sessions): 检查未完成的 agent 分析 | **显示: 桌面对齐与缩放** |
| `01a0f14f` | 2026-09-30T18:22+08:00 | **显示：缩放深色夜灯与刷新率** |
| `01a0f1ee` | plan(desktop): 全局进度与待办依赖层级 | **触觉：AW86937 马达 SRAM 修复** |
| `01a0f22e` | chore(workspace): 移动 skill、sessions  | **会话: pi资产内聚迁移** |
| `01a0f23c` | analyze: 检查当前进度 | **音频：AudioReach共享内存根因** |
| `01a0f292` | analyze(tf): 平板固件对 TF 卡 UHS/A2 支持 | **存储：TF卡UHS与A2支持评估** |
| `01a0f29e` | feat(wifi): 添加 WiFi 和蓝牙支持 | **WiFi-BT: 驱动支持与充电旁路** |
| `01a0f2be` | research: 芯片平板运行安卓模拟器可行性 | **虚拟化:EL2与安卓模拟器调研** |
| `01a0f537` | analyze: 检查昨晚进度 | **容器：Waydroid 编译与 Mesa 卡点** |
| `01a0f5a0` | 2026-10-01T12:25+08:00 | **音频:主线vs厂商AudioReach分析** |
| `01a0f61c` | analyze: 继续下载任务 | **下载:盘符纠正与sync续传** |
| `01a0f71b` | migrate: 移动 AOSP 数据包到新盘 | **下载:教育网出口矩阵+AOSP迁移** |
| `01a0f779` | audit: 审计 waydroid 下载任务与下一阶段 | **审计：Waydroid sync 进度与前置** |
| `01a0f7b4` | plan: 整理待办、资源与未来规划 | **显示：面板 165Hz 刷新率支线** |
| `01a0f7cd` | audit(waydroid): 卡点与本地编译 AOSP 必要性 | **审计：Waydroid 卡点与自编 Mesa** |
| `01a0f7f0` | analyze(aosp): 下载进度与面板音频验收 | **音频: tplg/DAPM出声排查** |
| `01a0f802` | docs(waydroid): 补写 AOSP 审计技术文档 | **文档:补写Waydroid AOSP审计** |
| `01a0f80f` | summarize: 回顾近期 sessions 确认方向 | **元：回顾近期会话确认方向** |
| `01a0f821` | (无) | **Waydroid:黑屏修复+Mesa实测** |
| `01a0f845` | (无) | **文档:资源就绪盘点(Mesa/设备)** |
| `01a0f868` | 加载一下最近的进度。我们新加入了插件swarm，现在可以真正意义上的派出 | **会话:swarm规划与子代理派遣** |
| `01a0fa45` | (无) | **温控:过热限频与并发限流** |
| `01a0fa6f` | (无) | **审计：未进主线驱动盘点** |
| `01a0fadc` | (无) | **环境:过检测env-pass与SukiSU** |
| `01a0fc02` | (无) | **文档: AOSP资料迁移校验** |
| `01a0fc50` | 我们需要继续主线。新的平板明日到，同型号，16+512g，现在我们要整理 | **路线：两轨分机决定与vk40准备** |
| `01a0fc63` | (无) | **虚拟化: DroidVM/AVF路线调研** |
| `01a0fcbf` | (无) | **文档：六视角重构与设备等价** |
| `01a0fcee` | (无) | **解锁:降级1.1解锁BL成功** |
| `01a0fd4e` | (无) | **引导:UEFI启动链调研** |
| `01a10060` | (无) | **解锁: BL解锁取证与自制sn.img** |
| `01a100d9` | (无) | **解锁:sn.img解密blob取证** |
| `01a10110` | (无) | **解锁：BL解锁经验整理定稿** |
| `01a10158` | (无) | **持久根:U2上机与GPT手术** |
| `01a10185` | (无) | **会话: 项目整理与git纳管** |
