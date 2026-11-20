# A1 — 阶段突破与卡点完整清单（只读审计）

审计代理: A1-phase-audit / 生成时间: 2026-11-19 22:11 / 只读
核验方式：INDEX.md §0 全文 + TASKS/README.md（§0/§1/§2/§4/§5/§7）+ PITFALLS/README.md 索引（#660–#693 段）+ `scripts/check-progress-counts.sh --tsv` + `scripts/recent-sessions.sh 3` + `git log --oneline -200`（HEAD `4542020e`）。所有指针均为文件:行位置或命令，未跑过的判据标「未取证」。

---

## (a) 时间轴：各阶段「真突破 / 被污染轮次 / 被推翻的旧结论」

> 「BCB 污染」定义（本项目 2026-11-19 立的口径）：`misc` 分区的 BCB 控制块残留（如 `boot-recovery`）会让启动进 recovery 而非正常 Android，这类失败样本**不算数**（INDEX.md §0 首条；`PITFALLS` #672/#677/#678 系同族「槽位属性污染实验」问题）。

| 阶段 | 真突破（判据 + 证据指针） | 卡点（现状 + 解除条件） | 被推翻的旧结论（作废日期） |
|---|---|---|---|
| **启动链（BL/EDL/GPT/槽位）** | ① BL 解锁走降级路一次成功（2026-10-03，`TASKS §1 G1-0`，判据 `unlocked:yes`）；② EDL 直写链完整闭环：`qdl` + 设备端 sha256 第二把尺子（`PITFALLS #669`），GPT-minimal 最小表 2026-11-18 生成并自检（`INDEX §0`「卡什么」第 1 条，`out/gpt-minimal-20261118/`）；③ 11-19 LUN0 手术表 + 最小根写入读回一致（sha `abf96ec4…`，`INDEX §0` 深夜条） | 「等送修/ABL 内存类硬件故障」**已被单变量证据作废**（真因=非原厂 GPT，2026-11-17 19:2x 定因；`reports/device-status-20261119.md`、`DEVICE/README.md §1.6`）。现无卡点，属「设备窗口」类动作 | ①「删条目≠删数据」回退口径（2026-11-18 作废，`PITFALLS #673`：写 6 GiB rootfs 会盖 `super`）；②「boot_b bit7=1 即 UNBOOTABLE」（2026-11-18 作废，`#678`：b 槽 0xf3 是出厂值）；③「送修单」（2026-11-19 作废，`DEVICE/service-repair-note-20261117.md` 顶部抬头） |
| **显示（DSI/DPU/DP/面板）** | ① bonded DSI 面板出图：Q31 定案 = 上游 `44784327815b` revert 掉 PLL init，我方净差异 1 行（2026-10-14，`TASKS §5 Q31`、`reports/m1-73-e1b-pllfix-20261014.md`）；② DP 外接输出（G1-9，2026-10-07，三步根因链：`dr_mode=otg` + `usb-role-switch`，内核提交 `6c1376907`）；③ **11-19 下午真突破：显示修复 = minbase 根缺 udev**（单变量证据：`apt install udev` + `enable systemd-udevd` ⇒ DPU aggregate + DSI×2 + DP + GPU 全 bound、fb0 1904×3040、屏幕有字；控制臂 = 持久 `boot_b` 内核/DTB 零改动；`TASKS/sessions/2026-11-19-显示修复=minbase缺udev.md`，git `d11afc16`） | 无卡点（显示链已通）；遗留小项 = RTC 冷起回 4-13（已由 time-sync.sh 处置，INDEX §0） | ① 11-19 上午/深夜的「nodp DTB 实验」与「显示挂死=DP 组件 defer」判读**不算突破**：都是缺 udev 的下游症状，nodp 件留档勿用（2026-11-19 下午推翻，`reports/d11afc16` 同提交、`TASKS §4` 2026-11-19 条）；② 11-18 两次 RAM 启动失败曾判「实验件坏」→ 改判 = cmdline 根标签 `linux17` vs `linux`（2026-11-19，`reports/475ebf78`）；③「60–70 s 硬件掉电」（2026-11-11 作废，`PITFALLS #620`：是 panic 下游症状） |
| **桌面（Phosh/输入法/日用）** | ① 11-19 13:20 **桌面端到端真突破**：greetd+phoc+phosh 三进程、锁屏截图有顶栏/中文、Mesa 26.1.6（backports）= Adreno 830 / GLES 3.2、`glmark2-es2` Score 2594（`TASKS/sessions/2026-11-19-EDL到桌面端到端重建.md`，git `57e915a6`）；② T20 电源键不熄屏闭环（根因 = `zwlr_output_power_v1` 单请求者，phoc+phosh 两枚自编件，2026-11-14，`TASKS §4 T20`）；③ T19 撕裂/抽搐修并固化（`MESA_EXTENSION_OVERRIDE` + `GSK_RENDERER=gl` + GPU devfreq，2026-11-14，同处） | ① G1-38 OSK 剩四类边角样本（GTK3/Qt/Alt+Tab/候选窗抖动），**需真人在解锁桌面做**（`TASKS §1 G1-38 行`）；② T19「打开 app 加载超时」未修（phosh 0.59 app-tracker 机制开放，`PITFALLS #657`）；③ **锁屏必须人手滑**（内核无 `CONFIG_INPUT_UINPUT`，INDEX §0 桌面条「卡点（需人）」） | ①「候选窗方案 A」（layer-shell 浮条）2026-11-13 真机撤下（`PITFALLS #646`：打断组字缓冲）；②「GTK_IM_MODULE=wayland → Visible=true」旧判据在 0.59 栈不成立（2026-11-13 夜，`TASKS §1 G1-38`） |
| **网络与时钟** | ① WiFi 候选榜塌缩根因 = NM 1.52 写死 bgscan + 周期扫描禁用 ⇒ `wifi-scan-refresh.service` 150 s 显式 RequestScan（G1-36，2026-10-19，`TASKS §1`）；② HTTPS 信任链根因 = 8 个 `/etc` 配置被清成 0 字节 + PMTU/MLKEM 黑洞缓解（G1-35，2026-10-18）；③ 11-19 新根上：主机 NAT（正确出口 = 手机热点 `enx027644563e50`，误加 eno1 由 tcpdump 定位）+ `chronyd -q` 冷起自愈 step 1.9e7 s（`INDEX §0` 13:20 条） | 无（usb0 自愈路由 + DNS 上游已固化进 `deploy-desktop-shell.sh`） | ① ath12k 早启 `-110` 曾判「驱动问题」→ 改判 = 时序问题，PCI rescan 即复活，固化 `ath12k-rescan.service`（2026-11-19，git `d11afc16`）；② Q26「WiFi 关联后周期掉线」2026-10-10 用户确认正常后关闭（`TASKS §5 Q26`） |
| **音频** | G1-4 真突破 = tplg MI2S **SD 线错**（SD0→SD1，`PITFALLS #90`）+ WCD939x 麦克风 bring-up；播放 2026-10-04 实测听声、`arecord/aplay -D default` rc=0（`TASKS §1 G1-4 行`） | R1 有线耳麦**硬件缺失**（无 3.5mm/转接头）冻结；R2 双麦低价值未做；Q33 WCD939X 冷起 20 s 读重试未修（`TASKS §5 Q33`） | 「GRAPH_START status=0 = 可听」类控制面假判据（`TASKS §5 勾销规则`明令） |
| **相机** | G1-5 真突破 = 2026-10-18 vk127：后摄 s5kjns 30.06 fps / 前摄 gc08a8 30.26 fps 满帧 + 三个 AE 独立 bug 修复（`reports/camera-linux-vk127-20261018-agc-rootcause.md`） | 剩两条**可选增强**：libcamera 不认 `MEDIA_ENT_F_FLASH` + flash LED NTC 温控（`TASKS §1 G1-5 行`，非阻塞） | ①「软 ISP 只写第 0 帧」「libcrypto 构建致黑帧」两旧结论被两臂同配方对照推翻（2026-10-18，同报告）；②「前置闪光灯」是误称——本机只有一颗后摄 LED（2026-11-13 口径更正，同处） |
| **传感器** | G1-34 真突破 = 根因是「修复从未进镜像」（`fastrpc.c:2599` 的 `qcom,non-secure-domain` 只存在于未提交工作区）；加一行后 `/dev/fastrpc-adsp` + SensorProxy 三项 true（2026-10-30，`TASKS §1 G1-34`；上游形态 = M10，2026-11-07 已投 1×250） | **11-19 新根上传感器回退**：`hexagonrpcd` attach ADSP sensor PD 会**硬崩整机**（无 Oops/无 pstore，`PITFALLS #692/#324`）；Debian 13 无 `libssc2`、iio-sensor-proxy 未链 libssc ⇒ 要做须自建。解除条件 = 取证通道（串口/ramoops 窗）+ 自建 libssc | M10 早期「PAS id 不匹配」假设被反汇编否证（2026-10-07，`TASKS §1 G1-11`） |
| **Waydroid（G2 主线）** | C1 治本 = 内核缺 `CONFIG_IPV6_MULTIPLE_TABLES`（2026-10-11 vk103，无 workaround 出网 `curl baidu=200`）；C2 GMS 登录成功（用户人工验证）；C4 UDP 传感器 HAL；C6 音频（codec 53，闹钟出声）；C10 马达透传；C11 中文输入法；C5 容器相机出真帧（10 Y mean 107）——各判据见 `TASKS §2 C1/C2/C4/C5/C6/C10/C11 行` | **C3 已实测收口（2026-11-15）**：SPIC 回包 `deviceRecognitionVerdict=[]` ⇒ BASIC/DEVICE/STRONG 三档全不满足，与书面判读一致；剩 C5 App 实开预览 / C8 书面结论未立项 / C9 打分表未出数（`TASKS §0` G2 行） | ①「uinput+UDP」传感器方案作废 → UDP HAL 真实现（2026-10-11，`TASKS §6` ①）；② C5「metadata is null」实为关闭路径噪声（2026-10-28 第二轮推翻，`TASKS §2 C5`）；③ droidloom「合成器缺口=内核/驱动问题」被翻转（2026-11-10：phoc 全树不调 syncobj create，`TASKS §2 C12`） |
| **安卓精简与共存（2026-11 新线）** | ① 11-18 最小包上机成功：清 `boot_a` UNBOOTABLE（`--set-active=a`）→ 自签 `vbmeta_a` Flags=1 → EDL 写 `super_min` 8.28 GiB 设备端 sha 一致 → **连续两发 `boot_completed=1`**、`/system` 11.43→5.0 GiB（git `ed8835a8`、`reports/android-super-format-20261118.md`）；② 11-19 **共存契约冻结**：Android `super 90504..5857671` + `userdata`，Linux `linux17 73277435..` + `boot_b`，16 条目不重叠 `coexist-check rc=0`，**实测刷安卓 3 次 Linux 全程可登**（`DEVICE/README.md §1.7`、`reports/android-slim-v3-20261119.md`） | **v3 精简镜像未进桌面（当前最大 Android 卡点）**：3 发均未进桌面，其中 2 发**被 BCB `boot-recovery` 污染不算数**；现场复核 ABL 清白（logfs 每条到 `Shutting Down UEFI Boot Services`、pstoredump 无 panic、电池 82%）。解除动作已定序 = S1 清 BCB→读回→reset → S2 原厂 metadata → S3 原厂 super 对照 → S4 二分 v2b → S5 `console=ttyGS0` 拿日志（`INDEX §0` 首条「下轮纪律」） | ①「试装最小包 3 发全败=镜像问题」→ 改判 = `boot_a` 被标 UNBOOTABLE（`#672`，2026-11-18 当天闭环）；②「设备恢复可用」待办改读 = 设备早已可用、遗留是软件面（`TASKS §4` 11-18 条）；③ v1 上机「同样 logo 后掉电」发**不算 Android 失败样本**（BCB confound，2026-11-19） |
| **UEFI（拓展，非主线）** | ① 2026-11-10 深夜两种形态都通，**flashed 三年全败真根因 = 原厂 `dtbo_a` 的 Android DTBO 被 ABL 合进我方 DTB**，清 `dtbo_a` 即通（`reports/uefi-dtbo-a-rootcause-20261110.md`）；② 2026-11-15 夜 GRUB 路径根因 = **Mu 把 initrd buffer 分配进 DTB `ramoops` 保留区**，内核 t=0.027 s 起把它当 printk 控制台写掉 initrd（`reports/uefi-grub-initrd-rootcause-20261115.md`、`#665`）；③ 2026-11-16 修法 ①（内核 pstore/ram 拒绝重叠 zone）**真机 A/B 对照通过** + 上游 3×250 已发（`reports/pstore-ram-initrd-guard-20261116.md`） | 「已收口、等上游回复」；剩余裁决项 = GRUB 先占位修法**登记触发条件不做**、GRUB 堆头清零**登记不追**（INDEX §0 第 4 条） | ①「vbmeta_a 是墙」（`#601` 否证）、「logfs 信标未变=没跑到」（`#602` 否证）、`#594/#597` 的判读——2026-11-10 作废；②「幻影页」「Conv 太小/落 4 GiB 以上」两假设 2026-11-15 五发定位作废（`TASKS §4 N1` 五发定位条）；③ LastFile2 v2 屏照待办撤销（2026-11-16，无信息增量） |
| **上游补丁（M 系列）** | **我方主线合入 = 0**，但在飞批次完整：mdss v5 / wl2868c v11→v12（补回 Rob R-b）/ dsi-phy v2 / pstore guard 3 枚 / Q28 证据回帖 / 板 DTS v7 + gamma v2 + haptics v2 + dwc3 v9 = 11-17 13:20 整批 17 封全 250；**在档未发件已清零**（INDEX §0 第 6 条） | ① **唯一收到人回 = wl2868c v11**（Rob：v11 漏带他的 R-b ⇒ v12 已补）；pstore v1/dsi-phy v2/mdss v5 零人回（`reports/upstream-replies-20261117.md`）；② **camss CSIPHY 2.4.0 delta 暂不投**：Qualcomm 11-14 SM8750 CAMSS v7（23 枚）做掉了我方 0001/0002 形状 ⇒ 等 v8 落地再定（`reports/upstream-delta-20261118.md` §2.1）；③ 前提变化两信：Bryan 称我方邮件「LLM output…难懂」（11-15）、`qcom,nsessions` 已被上游废弃合入（`641dd7dd0f68`） | ① M9 kexec LPI 认领**被 Marc Zyngier 整体否决并撤回**（2026-10-26，`TASKS §7 M9-收口`）；② M2 A1（DPU GC 块）撤稿 = 与上游 `3389406e6a03` 重复（2026-10-13）；③「patchwork commit_ref 空 = 未合入」口径不能外推（2026-11-18，`TASKS §7` 头三条限定） |
| **工具链与构建** | ① minbase rootfs 构建器（真 root + qemu-aarch64，proot 路线 6 连败后定案，`#676`）+ 15 项门禁；② 11-18 四板块脚本审查 **P0 28 条全修完** + 两道新静态门（§17 设备命令卫生 / §18 线刷包几何，git `e6f18c88` 系）；③ LTBox 评估 P0 六条全落地（§21 写前门，git `41619bdd`）；④ zero-to-desktop-check.sh（§22 桌面链路静态门，git `49f518ba`）；⑤ 磁盘 A 类清理两轮 15.25 GiB + 2026-11-19 二轮（build 内核树/geekidos-linux 删除，`reports/disk-cleanup-20261119-validation-impact.md`） | §5d 内核身份表 75 行「暂不可核」（源树已删，登记 `versions/kernel-src-archive.tsv`，恢复命令在 `versions/layout.tsv` 注释）——属**环境**类，重建即解；BACKLOG 剩余全部外部门（设备在线 / qdl 语义 / 人，`reports/script-audit-…` 系列） | 「构建产物丢 = 硬件位翻转」类判断一律走 hw-stability 通道，不在项目内深挖（11-19 `super` 构建脚本已加双 sha 硬门；11 字节翻转证据已落 `~/hw-stability/evidence/inbox/20261119-y700-elden-super-bitflip/`，见最近会话 `2026-11-19T11-20-17-246Z` 收尾） |

---

## (b) 现在真正卡什么（一张表）

| 项 | 阻塞类型 | 解除动作 | 价值排序 |
|---|---|---|---|
| 安卓 v3 精简镜像进桌面（3 发未进、2 发 BCB 污染） | 设备窗口 + 流程纪律（清 BCB→读回→reset） | 按已定序 S1–S5 做（清 BCB → 原厂 metadata → 原厂 super 对照 → 二分 v2b → ttyGS0 拿日志） | **1**（G2 共存线的当前主卡点，S1 起每步都是设备动作） |
| 桌面内验证不能自动化：锁屏必须人手滑 | 环境（内核缺 `CONFIG_INPUT_UINPUT`） | 重编内核开 uinput（需走 build-kernel.sh 整套 + 模块树部署） | 2（决定 agent 能否独立做桌面回归） |
| camss CSIPHY 2.4.0 投递 | 上游（等 Qualcomm CAMSS v8 落地）+ 设备（上机出流回归未做前不发） | 盯 v8 → 删/收敛 binding 枚 → 上机 s5kjns/gc08a8 30 fps 回归（需用户裁决「无实测声明」） | 3（G1 上游化唯一成体系待投系列） |
| 在飞上游系列等回复（mdss v5 / dsi-phy v2 / pstore v1 / wl2868c v12 等） | 上游（无阻塞，被动等待） | 定期 `read-mail-ustc.py --replies-only`（该判据本身失效待修，`reports/mail-inbox-20261118.md`） | 4（等待类，不占人力） |
| 传感器在新根回归（hexagonrpcd attach 硬崩 + 缺 libssc2） | 环境 + 设备窗口（需取证通道） | 先建串口/ramoops 取证通道；自建 libssc + `-Dssc=true` | 5 |
| T9 待机功耗判读 | 人（要 1–2 天待机窗数据，取数是人的动作） | 造待机窗（`suspend-resource-sample.sh cycles` 或临时开 suspend）→ scp 取数 | 6 |
| G1-38 OSK 四类边角样本 + IME 候选窗重做 | 人（需解锁桌面真人操作） | 人在桌面会话取 GTK3/Qt/Alt+Tab/抖动样本；候选窗按 `#646` 前置条件重做 | 7 |
| T14 hapticd 可重建性口径 | **口径冲突，未取证**：INDEX §0 写「唯一缺口 = hapticd 二进制不可重建」vs `TASKS §4 T14 行` 写 `verify.sh --rebuildable = ok=7 missing=0`（2026-11-11）。两说并存，审计不裁决 | 按时间序裁决规则跑 `packaging/elden-userland/tools/verify.sh --rebuildable` 现查一次 | 8 |
| §5d 内核身份表 75 行不可核 | 环境（build 内核树已清理） | 按 `versions/layout.tsv` 注释重建树 → 重跑 vk-identity | 9 |
| T19「打开 app 加载超时」 | 上游（phosh 0.59 app-tracker 机制开放） | 盯 phosh 上游 / 降级复测（0.58 已证无效） | 10 |
| 脚本审查 P2 余项 / partlun 三个调用点接闸 | 设备窗口 | 设备在线各验一次（`reports/script-audit-*` + BACKLOG） | 11 |

---

## (c) 已结项勿重推（从 INDEX §0 与 TASKS §4 摘出，带指针）

| 项 | 结项口径 | 指针 |
|---|---|---|
| Q28 面板 init 间歇失败 | 「已规避」结项（2026-10-24 用户裁决）：运营线 8/8 无坏发；根因**仍未解释**（运营判断结项）；0154/0155 是唯一有效修法（Fisher p=0.003） | `TASKS §5 Q28 行`、`reports/q28-DOSSIER.md` |
| Q32 暖起 vs 冷起 | 并入 Q28，五发判据表已成 | `TASKS §5 Q32 行` |
| Q24 熄屏→整机复位 | 根因指名 = 上游 `skip retention by default`（7.3 线免疫），停止采样，**不值得取证**（2026-10-24 用户裁决） | `TASKS §5 Q24 行`、M7 = 🟢 |
| Q26 WiFi 周期掉线 | 2026-10-10 用户实机确认正常，关闭 | `TASKS §5 Q26 行` |
| Q35 双口「长边数据+短边快充」 | 2026-10-29 判定物理可行、被 ADSP 选口策略挡住，**不再投入** | `TASKS §5 Q35 行`、`DEVICE/README.md §1.4` |
| Gunyah（C8/N2） | 10-25「不做」被 11-11 复核改「有条件重启」；驱动已移植编译（`out/gunyah-73/`）；**当前 = 等统一内核基线才上机**，不要按旧口径重推「终局不做」 | `TASKS §4 N2`、`reports/gunyah-restart-assessment-20261111.md` |
| M9 kexec LPI 认领 | 被维护者否决、已撤回；kexec 定位 = 不需显示/网络的调试快环 | `TASKS §7 M9-收口` |
| G1-10 NFC | 本机无 NFC 硬件（2026-10-06 取证），取消 | `TASKS §1 G1-10 行` |
| G1-30 slim initramfs | 归因 = initramfs 打包（缺 `/lib/firmware`），slim 不作日常启动 | `TASKS §1 G1-30 行`、`PITFALLS #113/#115` |
| G1-6 TF 卡 | 新卡收口（3 轮 0 不一致 + fsck clean）；旧卡废置不追 | `TASKS §1 G1-6 行` |
| G1-26/27/28 深色/图标/亮度 | 已出列结项（2026-10-11） | `TASKS §1` 三行 |
| droidloom（C12/Q3） | L1–L4 全绿结项；维持「只跟踪」，复启判据 = R1 受阻或需无镜像形态 | `TASKS §2 C12 行`、`§5 Q3 行` |
| LastFile2 打印版 v2 屏照 | 撤销（无信息增量） | `INDEX §0` 第 6 条 |
| BL 解锁 / sn.img / testkey 链 | 已定稿关闭：四代 1.5.x 换 ABL key，任何 sn.img 无效；正解=降级 1.1.11.073 | `RUNBOOK §0.5`、`TASKS §5 Q16/Q18/Q17 行` |
| Waydroid Q29 Mesa bind / Q30 emulated storage | 已核对并简化 / 已修 | `TASKS §5 Q29/Q30 行` |
| 「等送修」设备口径 | 2026-11-19 整体作废，设备不需送修 | `DEVICE/service-repair-note-20261117.md` 顶部、`reports/device-status-20261119.md` |
| 文档精简第一刀 C1–C8 | 已于 2026-11-19 执行完（C9 判「收益<风险」不做） | `INDEX §0` 下一步第 10 条、`reports/doc-slim-plan-20261118.md` |
| 磁盘 A 类清理 | 两轮 15.25 GiB 已执行完；三项评估有明确结论（可压不可删/无可删/建议保留） | `INDEX §0` 下一步第 8 条、`reports/disk-cleanup-20261115.md` §2 |

---

## (d) 完成度数字现查（并注明与 INDEX §0 是否一致）

现查命令：`bash scripts/check-progress-counts.sh --tsv`（2026-11-19 22:0x 实跑，输出见会话）。

| 目标 | 脚本现查 | INDEX §0 记载 | 一致性 |
|---|---|---|---|
| **G1** | `G1_complete=36`，`G1_detail = ✅33 🟢3 🟡1 ❌2`，分母 37（❌2 = G1-10 无 NFC、G1-30 同路线；🟡1 = G1-38 OSK） | 「G1 = 36/37」（INDEX §0 第 1 条，2026-11-17 口径） | ✅ **一致**（36/37，且行内明细同样指向 G1-38 为唯一 🟡） |
| **G2** | `G2_complete=10 / G2_in_scope=13`，`G2_detail = ✅7 🟢2 🎯1 🟡2 ⬜1`（🟡 = C5 App 预览、C8；⬜ = C9 打分表） | 「G2 = 10/13」 | ✅ **一致**（未完成 3 项 = C5 App 实开预览 / C8 立项 / C9 打分表，与 INDEX §0 第 2 条同） |
| **G3** | 无脚本计数（TASKS §0 表：PoC ✅ + Steam 登录界面 ✅，游戏端到端未做） | 「G3 = Steam 登录界面 ✅（2026-10-28 设备实测 3/3），游戏端到端未做」 | ✅ **一致**（证据 `reports/g3-steam-20261028.md`；脚本不覆盖 G3，数字无漂移） |
| 拓展（UEFI/Gunyah） | 非主线不进分母 | 两种形态都通 / 有条件重启 | ✅ 一致 |

补充核验：`scripts/recent-sessions.sh 3` 最新两条会话（`2026-11-19T04-08-05Z`、`2026-11-19T11-20-17Z`）的收尾结论与 INDEX §0 首条（共存契约 + v3 + BCB 污染）**逐条对得上**，无文档滞后信号；`git log` 头部（`4542020e`…`d11afc16`）与 §0 各条目的收口提交号一致。

---

### 审计局限声明

- 本轮未连接设备，所有「设备侧现态」均转引自 INDEX §0 / sessions 报告（最近实测窗 = 2026-11-19 21:5x，BCB 已在 11-19 深夜从 Linux 侧清 0、备份于设备 `/tmp/misc.bcb.bak` 与主机 `diag/misc-*.bin`，见会话 `2026-11-19T11-20-17-246Z`）。
- T14「hapticd 不可重建」两说并存，本轮按「未取证」处理，未跑 verify.sh 裁决（见 (b) 表第 8 行）。
- 时间预算内未逐篇读 TASKS/sessions 12 篇全文，以 `recent-sessions.sh 3` + INDEX §0 + 各 README 行内指针交叉覆盖；结论均带可回溯指针。
