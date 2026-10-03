# 查漏补缺（GAPS）— 未解问题 · 待验证 · 待调查 · 风险

> 六视角文档集之一（`DEVICE.md` / `TASKS.md` / `RESOURCES.md` / `ANDROID-COMPAT.md` / `INDEX.md`）。
> **规则**：任何"不确定/未验证/暂不下结论"的事只在这里登记，写清「未知什么 + 怎么测 + 谁做 + 何时」；
> 一旦有结论，写进 `DEVICE.md`（设备事实）或 `ANDROID-COMPAT.md`（兼容方案），并从本表勾销。

---

## 1. 待调查（Open questions，按优先级）

| ID | 未知 | 为什么要知道 | 怎么测（最小实验） | 关联任务 |
|---|---|---|---|---|
| **Q22** | **vk34（2026-10-01）之后未逐版验证的内核增量**：5 文件（DTS 分级热 trip、q6apm.c/q6prm.c/audioreach.c/q6apm-lpass-dais.c 音频）+ `config-vk40-bringup`，全部只在 vk40 叠加体上上过机，与「vk40 新 bug（含熄屏→重启）」可能因果相关 | 决定 G1 基线是否可信；是「AI 难以稳固推进」的核心 | 已做静态取证（`archive/topics/AUDIT-since-vk34-2026-10-03.md`）。**待做**：① 确认边界 vk34/vk39；② 以 vk34 为基线分批加回增量或反向移除音频改动，逐批上机隔离回归源 | **G1-1/G1-22**；见审核文档 |
| **Q21** | **桌面空闲熄屏（DPMS blank）→ 整机重启**（2026-10-03 U2 实测；`idle-delay=10` 必触发）。重启前串口最后 3 行为 `ucsi_glink … timeout waiting for UCSI read response / failed to reset PPM / PPM init failed`，**无 kernel panic** | 直接阻塞持久系统的日常使用；且与 DP/altmode（G1-9）疑似同源 | 已做：串口日志 `logs/serial-20261003-192121.log`；复现 2 次。**待做**：① 先禁止空闲熄屏（`idle-delay=0`/caffeine）→ 看是否不再重启；② 抓 `dpms-watch.sh` 日志 + 必要时抓 ADSP/PDR 日志定位 UCSI PPM；③ 试在熄屏前 `echo 1 > /sys/class/drm/card0/card0-DSI-1/...` 逐步隔离 | **G1-22** |
| **Q1** | **容器内的 GMS 身份/Play Integrity/Widevine 能做到哪一级**（不作废猜测，先取证） | 决定 G2 兼容上限与是否需要 VM/换路线 | 复现社区三条做法各一次，只变一个变量：① Waydroid + GApps（OpenGApps/MindTheGapps）；② 未认证设备注册流程（Android ID → `google.com/android/uncertified` → 清 GMS 缓存）；③ Widevine L3 库注入。记录 `getprop` 关键项 + `drminfo` + Play 状态。**社区侧已补证（2026-10-02）**：WayDroid-ATV 有 arm64 GAPPS 镜像（2026-01 SourceForge）但 **L3 仍仅 x86-64**（release notes 原文）；官方 licensing 页明确 GApps/Widevine 受许可限制、建议开源替代；PlayIntegrityFork(pif.json) 仍是主流过 PI 手段（v18 在手）；L1 需芯片商+GMS 认证（L3 是默认必测项，不需额外申请） | **C3** |
| Q2 | Waydroid 在 **vk40** 上是否不再需要旧 workaround（vk40 已开 iptables/NAT：`IP_NF_FILTER/NAT`、`NF_NAT_MASQ`、`XT_MATCH_COMMENT` ✅；`CONFIG_IP_ADVANCED_ROUTER` 仍 not set，若需策略路由再补） | 少一处 bind-mount 脆弱点 | 起容器看 `ip route` 是否自动有默认路由；不通再启用 workaround 并记因 | **C1** |
| Q3 | **droidloom**（Linux 原生跑 Android 应用，Wayland 直出窗口）在 arm64 宿主是否可用 | 形态优于容器（无需 Android 镜像） | **已查（2026-10-02）**：`denialwm/droidloom`（251★，Rust，活跃）repo 声称支持 arm64+x86_64 平台，但**预览包只发 x86_64 Arch**（pacman+ship.yml）；INSTALL 的 "experimental ARM64" 指 x86 宿主跑 ARM64 APK（Digitalis/Berberis 翻译层）；arm64 宿主 = 官方目标但无公开包。自构建一条命令 `cargo run --locked -p droidloom-package -- build`（需 rootless podman+AOSP pin，免宿主 sudo），产物 pacman 格式需适配本 rootfs。**剩两点未知**：① arm64 自构建是否干净；② freedreno+Phosh 下 GPU/输入路径 | 观察（R1 受阻再试） |
| Q4 | **无 KVM 前提下 VM 路线值不值得投**（**书面评估已完成 2026-10-02**，结论见 TASKS C8） | 决定要不要开第二条腿 | 结论：**维持低优先**。① 设备侧 KVM 不可达（XBL 在 secure-boot 链内加载 hyp，主线 `-el2.dtb` overlay 只适用 Qualcomm dev kit，ABL 重签救不了——hyp 加载点在 ABL 上一级）；② 独立 gunyah 驱动（v17）未进主线（本地 7.2 树 `drivers/virt/` 无 gunyah 目录）；③ 唯一新路线 = KVM-in-EL1+Gunyah backend（RFC 00/34，Linaro，2025-04，配 `qemu-for-gunyah`），WIP（pinned pages/无 guest_memfd/禁 swap）。**决定性上机实验**：vk40 起机后 `dmesg \| grep -i gunyah`（本地 qcom_scm 已带 gunyah UUID 探测）——通则路线第一步成立，败则归档 | **C8**（🟡 书面结论已出） |
| **Q5** | **真 Android 对照基线**（一旦覆盖 a 槽就不可复得）：GMS 属性 8 段、Widevine 级别、7 颗传感器读数曲线、目标 App 行为 | 兼容层的"标准答案"，也是判定容器是否等价的尺子 | 在 U1（当前仍 stock+root）一次采完：`getprop` 全量、`dumpsys media.drm`、传感器 30 s 采样 CSV、5 个目标 App 关键流程录屏 | **建议立刻插入（覆盖 a 槽前）** |
| Q6 | 兼容层验收的**量化判据**——**已定稿（2026-10-02，A15）**：10 条用例+阈值见 `ANDROID-COMPAT.md` §5 | 避免"看起来能用"的自欺 | 上机后按用例表逐条实测打分（打分模板同处） | **C9**（模板就绪） |
| Q7 | Linux 分区到底要多大（**本轮已定"按项目体量决定"**） | 决定 GPT 手术一次给多少，避免二次缩容 | 按 `DEVICE.md` §3.1 估算表，上机后 `du` 实测各组成 → 回填表 → 定 `--linux-gib` | G1-2 前完成 |
| Q8 | 音频是否真的可听 + 有无录音通路（`GRAPH_START status=0` 只是控制面） | G1 硬验收 #4 | 上机 `amixer cset numid=8 on; speaker-test -c2`；录音需另找 ADC 通路 | G1-4 |
| Q9 | 相机能否真正出流（graph ENABLED ≠ 有帧） | G1 硬验收 #5 | `qcam`/`gst-launch-1.0 v4l2src` 取 10 帧存盘 | G1-5 |
| **Q15** | **解锁 U2 的两个不可逆代价**：① Widevine **L1→L3**（现 `sys.lenovo.widevine_security_level=L1`，属 TEE 内密钥，社区主流案例为永久降级）——它正是 Q1/Q5 容器侧 DRM 上限的「标准答案」；② 保修 + FOTA。**两台单元现均已解锁**（U1 2026-08-16 / U2 2026-10-03；U2 实机现 `flash.locked=0`） | 先拍基线再解锁，否则事后无法对照；且影响 G2 的 U5 用例上限 | ✅ **已执行（2026-10-03）**：`scripts/bl-preunlock-evidence.sh HA2EXB0E` → `backup/HA2EXB0E-16+512/pre-unlock/`（getprop 全量/by-name/传感器清单/settings/Widevine=L1 + SHA256SUMS）；解锁后重测同一项做对照 | **G1-0**、Q1/Q5 |
| ~~**Q16**~~ | ~~三代「模板改 SN 自造解锁 blob」在四代 259 上是否有效~~ **已结（2026-10-03）：无效。** 四代 1.5.x ABL 换内嵌 key，**任何** sn.img（官网/三代免签模板/第三方签名）都过不了；且 **1.1.11.120 / 1.5.x 本身就不开放解锁命令**（版本门）。正解 = 降级 1.1.11.073 后 `fastboot oem unlock`（U2 已实测一次成功，无需 sn.img） | 不影响 G1（EDL 路不受 lock 位限制） | 已验证；`PITFALLS` #86、`RUNBOOK` §0.5 ★权威顺序、复盘 `archive/topics/复盘-2026-10-03-BL解锁.md` | 已结 |
| ~~**Q18**~~ | ~~第三方签名四代 blob（356 B）能否过 259 的 ABL 验签~~ **已结（2026-10-03）：不通过**——`flash unlock` OKAY（伪分区，不算数）但 `oem unlock-go` 失败；离线 18 组合验签全败 ⇒ 四代 ABL 换 key。**结论：买/求签名文件对 1.5.x 无用**；blob 与取证保留作证据（`backup/HA2EXB0E-16+512/sn-neko-zuxos.img`、`sn-neko` 取证 §5） | 已关：G1-0 靠降级解决 | `PITFALLS` #84/#86 | 已结 |
| ~~**Q17**~~ | ~~locked 态下「EDL 直写 + testkey 自签链」能否把 b 槽引导起来~~ **不再阻塞（2026-10-03）**：U2 已解锁 → 本实验从「必需」降为「可选」；`scripts/build-locked-chain.sh` 离线验证全绿，**真机未验**（无 locked 单元） | 若将来拿到 locked 新单元且想保住 Widevine L1/保修，本实验仍可取代解锁 | 照旧：`qdl` 写 `boot_b`/`dtbo_b`/`vbmeta_b` 后从 b 槽引导；失败留屏幕状态/日志 | G1-1（可选） |
| Q10 | TF 卡间歇写丢失是卡、还是 `sdhci-msm` flush/cache | G1 硬验收 #8 | 换卡 A/B + `fio verify` 长跑 | G1-6 |
| Q11 | DP 输出被 `disabled` 的 ADSP altmode/UCSI 能否修好 | 外接显示能力 | 先只读勘察 `pmic_glink`/`ucsi` 日志与 DT 依赖 | G1-9 |
| Q12 | 温控缺 OEM 层（`lenovo,sys-temp`/BCL）会不会在长期负载下露短板 | 安全边界 | 长时压测（≥2 h）+ `thermal-watch` 采样，看壳温与限频层级 | G1-8 附带 |
| **Q13** | **AVF 资产（crosvm/vm/microdroid_kernel/u-boot.bin）主机上找不到**：文档曾记"已提取"，2026-10-02 全盘核验（`~` + `/mnt/Samsung`）无任何产物（仅 AOSP 树内无 Gunyah 的 crosvm 源码）——要么已丢要么没拷回 | C8/R2 VM 路线的地基资产 | U1 仍 stock+root 时重提取：`pm path com.android.virt` 定位 APEX → 解包 `apex_payload.img`（debugfs）→ 取 crosvm/vm/microdroid_kernel/u-boot.bin → scp 回主机，路径登记 `RESOURCES.md` §2.2 | 随 C0 同批（覆盖 a 槽前，不可复得） |
| **Q14** | **C4 UDP HAL 上机三未知**：① 容器 UDP 52012 从 waydroid0 网桥是否可达（容器防火墙）；② overlay 的 .rc/.so SELinux context；③ Termux 转发器实际传感器名与映射 | C4 验收前置 | 部署后逐项：`deploy-sensors-hal.sh --restart` → `dumpsys sensorservice`（5 个 elden 传感器?）→ 宿主 `sensord --send 容器IP --fake` → `dumpsys sensorservice` 事件计数增长；不通则查 `waydroid shell iptables -L` 与 logcat HAL 日志 | **C4**（代码/编译全就绪） |
| ~~**Q19**~~ | ~~locked b 槽实验三未知~~ **已结（2026-10-03）**：U2 走降级路解锁成功（`fastboot oem unlock`），locked 实验不再需要；三未知答案归档：① U2(259) vbmeta_b 顶层=8fcb864f；② 1.1 与 259 的 vbmeta 顶层/boot chain key 均为 **AOSP testkey 2597c218**（私钥在手），rollback 均 1738713600/0；③ dtbo 无 hash 校验需求由自造 vbmeta 控制。路 C 管线保留作资产 | — | — | 已结 |
| **Q20** | **流程病：引导链问题先外部取证/自研、后本地检索** ⇒ 把 7、8 月已定的结论（版本门、.120 trap、失败特征串、**U1 已于 2026-08-16 用降级路解成功一次**）在 10-03 重新发现一遍，多花一轮必败实验。根因：`references/*.md` 正文不入上下文，**不 grep 等于不存在**（`PITFALLS` #87） | 上不设防就会再犯（下次是新 ROM 版本 / 新单元 / AVB 参数） | 已落：① `AGENTS.md` 新增「本地优先」规则；② `RUNBOOK` §0.5 ★权威顺序置顶（含版本门与停手串）；③ 本文末一条 grep 命令作开场强制动作；④ 引用旧成功记录先查单元+固件态 | 流程（无单元依赖） |

---

## 2. 已知缺口的补救路径（G1 侧，简表；细节见 `DEVICE.md` §1.3）

| 缺口 | 类别 | 补救 | 状态 |
|---|---|---|---|
| 相机出流 | config/部署 | 开 `CONFIG_V4L2_FLASH_LED_CLASS` 之类逐项补齐 + 部署 `.ko` | 🟡 到 graph 就绪 |
| 音频出声/录音 | tplg + 驱动时序 | 已修 BE graph 时序（`patches/0011`）；录音通路待查 | 🟡 Q8 |
| TF 卡 | 驱动 bug 或卡 | 换卡 A/B 定性后再决定补丁方向 | ⛔ Q10 |
| DP 输出 | bring-up（非缺驱动） | 修 `pmic_glink` UCSI/altmode | ⬜ Q11 |
| NFC | DT compatible 不匹配 | 改 compatible + config | ⬜ 低优先 |
| SLPI 7 传感器 | **架构性不可做** | 不救硬件，救接口（容器内虚拟传感器） | → `ANDROID-COMPAT` §2① |
| TEE/SPU/hw-fence/Gunyah/PMIH010x/BCL/FM/ST54 | 私有或无源码 | 明确不投入 | ✗ 结案 |

---

## 3. 环境与流程类待办（不属功能，但会咬人）

| 项 | 现象 | 处理 |
|---|---|---|
| 代理 `127.0.0.1:7897` 整体故障 | `web_search`/`web_fetch` 全灭（curl 35 TLS eof）；**直连反而可用** | 需你修代理；期间外部资料用 `curl --noproxy '*'` + GitHub API（本轮已如此取证） |
| `/mnt/Samsung` 无 `nofail` | 掉盘卡开机 | ✅ 已修（A18，2026-10-02） |
| `qemu-utils` 缺失 | 不能造/转 guest 磁盘 | ✅ 已装（`/usr/bin/qemu-img`、`qemu-nbd` 在位，A13 勾销） |
| API 双重限流（20 req/窗口 + $30/3h） | worker"干净退出"像崩溃 | 用 provider `deepseek`；并发 ≤3；见 `archive/topics/复盘-2026-10-02-swarm.md` |
| vermagic 耦合 | 改 `CONFIG_LOCALVERSION` → 相机 `.ko` 全废 | 改内核版本必须整套重编 `.ko` |
| 备份目录命名 | 历史 `backup/new-tablet/` 语义已废 | 新操作一律 `backup/<SN>-<容量档>/`；脚本默认值参数化（A16） |

---

## 4. 风险登记（高影响，需你决策或知悉）

| 风险 | 概率/影响 | 缓解 |
|---|---|---|
| 解锁 U2 = 永久失去 Widevine L1 / 保修 / FOTA（全项目唯一 locked 单元） | 高概率 / 中 | 解锁前 locked 基线已入库（`backup/HA2EXB0E-16+512/pre-unlock/`，Widevine=L1 已记）；G2 的 U5 用例按 L3 上限做预期 |
| 1.5.10.259 屏蔽解锁指令导致白跑一轮 | ~~低/低~~ **已发生（2026-10-03）** | 已由全量降级 1.1.11.073 解决（G1-0 已关闭）；**以后新单元直接判版本门→降级，不再在 1.5.x 上试解锁**（`RUNBOOK` §0.5）。注：U2 现态已回 **259 + unlocked**（2026-10-03 实机核验） |
| 覆盖 a 槽后强检测/银行类 App 完全不可用 | 中 / 中 | Q5 先取证；保留 stock + EDL 恢复；容器不行就换路线而不是硬扛 |
| GPT 手术/回收分区写坏 LUN0 | 低 / **高** | 手术前 `fastboot fetch` + GPT 双表 dump + EDL 包在手；只写主/备表两处；写后读回校验 |
| 设备热失控（曾 103 °C） | 低 / 高 | 分级 trips 已在线；压测必带 `thermal-watch`，超 90 °C 自动降级 |
| **空闲熄屏→重启（U2 实测）** | **已发生 / 高** | 禁止空闲熄屏（`idle-delay=0` 或 phosh caffeine 常开）作为临时规避，并把它写进 `start-desktop.sh`/rootfs 归档；根治前 **不要**在不可回滚的持久系统上做熄屏实验（详见 `archive/topics/复盘-2026-10-03-持久化与睡眠.md`） |
| **未验证内核增量（vk34 之后）** | 已发生 / 高 | 见 `Q22` + `archive/topics/AUDIT-since-vk34-2026-10-03.md`；vk40 是把 10-02 音频/DTS 增量与 10-03 持久化 initramfs 叠加的结果 |
| 边充边跑掉电（PMIC 默认 100 mA） | 中 / 中 | 上机前 `charge-ctl.sh` 拉满输入电流；长任务挂充电器并监控 |
| 单一路线依赖（只押 Waydroid） | 中 / 中 | 保留 redroid 作 R1' 备胎（`ANDROID-COMPAT` §0） |

---

## 5. 勾销规则

- 勾销一条 Q ⇒ 必须给出：命令、原始输出片段、结论一句话、生效文档链接（`DEVICE.md` / `ANDROID-COMPAT.md`）。
- 不允许"口头已确认"：控制面 OK ≠ 数据面 OK（`GRAPH_START status=0` ≠ 可听；graph ENABLED ≠ 出帧）。
