# droidloom vs Waydroid 路线裁决材料（Y700 四代 TB322FC，主线 Linux + Phosh）

- **★裁决落地（2026-11-28）**：用户已裁定「**Waydroid 路线收益低，不再当主力考虑**」⇒ 本报告 §5.1 推荐被采纳；SSOT 同轮改完（`TASKS/ANDROID-COMPAT.md §6`、`AGENTS.md` G2、`README.md` G2、`INDEX.md §0`、`TASKS/NEXT.md` T50）。下文保持提交时的原文（含「待拍板」字样），不追改。
- **基准日**：2026-11-28；在线取数窗口 **2026-11-28T09:37:32Z–09:45Z**（每条数字附复现命令）。
- **性质**：**主机侧只读**。零设备动作（未 ssh/adb/fastboot）、零 git 写、未发 issue。
- **唯一写入**：本文件。未改 `TASKS/`、`INDEX.md`、`PITFALLS/`、`DEVICE/`、`RESOURCES/`。
- **证据口径**：每条标 **实测**（命令输出/在线 API 原文）/ **静态**（读源码或文档）/ **未取证**（无本仓证据，不得当结论）。
  先例一律引用不重推：`reports/droidloom-*.md`（27 份）、`PITFALLS/README.md`+`PITFALLS/sessions/`（14 份含 droidloom）、
  `TASKS/G2.md`（C1–C12 + 11-26/11-27/11-28 增量）、`TASKS/NEXT.md`（T1–T47）、`TASKS/ANDROID-COMPAT.md` §6。

---

## 0. 一页结论

| # | 判断 | 结论 | 一句话依据（都可在本机复跑） |
|---|---|---|---|
| **J1** | 缺陷结构上，哪条路线的「我们自己的层」更薄？ | **droidloom 显著更薄** | 我方 droidloom 层 = **6 个 patch / 31 hunk / +366 −121 行**（`patches/local/droidloom-local-2026112{7,8}/`，`grep -c '^@@'` 复算）；Waydroid 层 = **约 2 700 行 C/AIDL（3 套自编 HAL）+ 约 1 070 行 shell（11 个 `scripts/waydroid-*.sh`+`cam-loopback.sh`）+ 11 项固化配置**（`patches-userland/waydroid-*/`、`TASKS/ANDROID-COMPAT.md` §5「维护性=高（已固化 11 项）」） |
| **J2** | 「要重编 AOSP」是不是 droidloom 的持续成本？ | **不是（至少现在不是）**：上游 **release 52（2026-11-27T11:51Z）已经把我们两条 image 侧缺陷修掉**，方式 = 上游发包，不是我们编 AOSP | `b30e8d8 "The keyboard opens after an app restarts its text field"`（新增 `EditorTask.java`，正是我方 `#763` 的 `task=0` 丢弃）；`6fe1878`（宿主键盘 insets 可见性）；`3bd905b`（重开 App 保住窗口尺寸）。见 §2.3 |
| **J3** | Waydroid 现在能不能「立刻顶上」？ | **不能**：设备上的 Waydroid **未初始化**，恢复要 60–90 min（`A7` 重装 + `waydroid init` + 回刷 `vendor.img` + 三套 HAL/脚本重部署） | `waydroid status` → `Waydroid is not initialized`（`reports/d16-unit-deploy-classify-20261127.md:163`，2026-11-27 实测）；`reports/best-state-and-gap-20261122.md:111` A7 行 |
| **J4** | 身份/完整性上限，两条路线差多少？ | **不差**：Waydroid 实测 `deviceRecognitionVerdict = []`（BASIC/DEVICE/STRONG 全不满足）、Widevine **不存在**（只有 ClearKey）；droidloom 上游明文免责同一项 | `reports/c3-spic-verdict-20261115.md`、`reports/c3-pi-tiers-closeout-20261110.md`、`reports/droidloom-app-compat-20261125.md` §1.1（`threat-model-v2.md:116-119`） |
| **J5** | 推荐 | **单主路线 = droidloom（跟上游 main + `patches/local/` 补丁集）；Waydroid 降为「冷备」**（资产留仓、不常驻、不追加固化开发）。**双轨只做冷双轨**：边际成本 ≈ **2–4 h/年维护 + 每次 rootfs 重装 60–90 min 恢复窗**。理由与推翻条件见 §5 | §1–§4 |

**一句话**：droidloom 的「缺陷多」主要在**宿主用户态可修层**且**上游 2 天一个包版本、image 侧缺陷在 24 h 内被上游修掉**；Waydroid 的「缺陷少」是因为它**已经冻结**（5.5 个月 9 个 commit），但它解决不了同一批身份天花板，还要我们长期背着 ~3.8 k 行自编 HAL 与 11 项固化配置。

---

## 1. 缺陷台账（逐条归类 + 计数）

### 1.1 归类口径

- **(a) 纯宿主用户态可修**：Rust/Java-free/脚本/配置/宿主合同（含需要**重编宿主 `runtime` 或 phoc**，但**不碰 AOSP**）。
- **(b) 需重编 Android/AOSP 镜像**：改动落在 `image`/`base` 包（frameworks/systemui/ime/task backend）。
- **(c) 需上游 droidloom 改架构**（或形态固有、本地不可修）。
- **(d) 环境/一次性**：实验装置 vs 契约、构建机、操作纪律、一次性部署。

### 1.2 台账（按证据出处分组；编号 = `PITFALLS` ID 或报告定位）

| # | 缺陷（现象 → 机制） | 类 | 出处（可复跑/可引） |
|---|---|---|---|
| 1 | cell 拿不到 `10.177.0.2`：`WifiConfigManager` 把 SSID "Droidloom" 落盘成 `NETWORK_SELECTION_PERMANENTLY_DISABLED`，`WifiProvisioning` 一次性位不复查 | **b** | `reports/droidloom-cell-network-20261126.md` §0-1；上游 `#48`同构；`patches/local/.../001-wifi-provisioning-self-healing.patch`（+59/−23，需 image） |
| 2 | cell 无 DNS：`DhcpResponder` 硬编码 `1.1.1.1/8.8.8.8`，本校园网封校外 UDP/53 | **a** | 同上 §0-3；`003-host-resolvers-in-lease.patch`（+154/−90，runtime）；2026-11-27 上机绿（`reports/droidloom-t2-patches-t5-ime-20261127.md` 判据③） |
| 3 | `unshare --forward-signals` 需 util-linux ≥2.42（本机 2.41.5） | **a** | `002-remove-forward-signals.patch`（+75/−2）；上游 issue `#58`；PITFALLS 无独立号（见 `TASKS/NEXT.md:105`） |
| 4 | `runuser` 硬编码 `/usr/bin` | **a** | `004-runuser-sbin-path.patch`（+13/−2） |
| 5 | 宿主键盘唤不出（首次）：`text_input.rs` 要求 `Some(editor.task)==focused_task`，而宿主 OSK 是 layer 表面吃住键盘焦点 ⇒ 死锁 | **a** | **#762**（`PITFALLS/sessions/601-…`）；`0002-enable-text-input-without-keyboard-focus.patch`（+7/−3，已装并真手指验收） |
| 6 | 键盘提交后自隐且再不唤出：IMMS 收起 → `droidloom-wayland` 忠实 `disable()` → `needs_enable()` 不再 enable | **a** | **#761/#763 的宿主半边**；`0001-t38-text-input-keep-enabled.patch`（+58/−1，7 hunk）；`reports/t38-keypad-rootcause-20261128.md` |
| 7 | 「只能输一个字」：应用每键 `setText` → `restartInput` → `HostInputMethod.apply()` 因 `state.active=false`（restart 时 `task=0`）丢弃 | **b**（**上游 52 已修**） | **#763**（`sessions/602-…`）；上游 `b30e8d8` 新增 `EditorTask.java`（+18 行）"keeps the task of the editor being restarted" |
| 8 | `showSoftInput` 恒 `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`（`onShowInputRequested()` 恒 `false`） | **b** | `reports/droidloom-ime-keyboard-20261126.md`、`reports/droidloom-upgrade-51-ime-20261127.md` §0-2；issue **#65**；根治需重编（用户 11-28 已把该需求下移） |
| 9 | 图形 Android IME（Trime/Fossify）窗口永不投到宿主（架构明文「headless IME never shows a window」） | **c** | **#753**（`sessions/592-…`）、`reports/trime-droidloom-keyboard-20261128.md`、issue **#69** |
| 10 | 宿主键盘「看得见按不动」/ insets 判定随 boot 变（`WindowInsets` 取最后来源） | **b**（**上游 52 已修**） | 上游 `6fe1878`（+40/−7，`0001-droidloom-bottom-navigation-insets.patch`） |
| 11 | 手机档 App 被塞 1440×2400 freeform 任务、Wayland 窗口原样照搬 ⇒ 内容占 75.6%×78.9%、弹窗被裁 | **a**（配置）+ 上游 52 部分 | `reports/droidloom-display-sizing-20261126.md` §1；解 = `~1001/.config/droidloom/window-policy-v1.json` per-app 覆写（`TASKS/G2.md:72`）；app 重开回原尺寸 = 上游 `3bd905b` |
| 12 | dpi 213（=1430 dp，被当平板） | **a**（配置） | 同上；`TASKS/G2.md:65`（`dpi 690`，必须 `sudo -u xuqianhui1001`） |
| 13 | 通知通道 `invalid Android frame` 紧循环（1919 次 / 2 s），已自愈；热补丁降级被否证（sret+drop 析构 ⇒ UB） | **a**（重编宿主 runtime 方能根治） | **#616**（`sessions/270-…`）、`reports/droidloom-warn-20261111.md` §0-2/§0-4 |
| 14 | 换 phoc / `restart greetd` 后 `droidloom.service` 不回来自启（`graphical-session.target` 仍 `inactive(static)`） | **a**（unit/autostart） | **#759**（`sessions/598-…`）；待办 `T46`（`TASKS/NEXT.md:121`） |
| 15 | 合成器缺 `wp_linux_drm_syncobj_manager_v1` ⇒ `droidloom-wayland` global bind 失败 | **a**（已解，phoc 补一行，重编宿主合成器） | **#604/#609/#610/#612/#613**、`reports/droidloom-l2-phoc-syncobj-20261111.md`；`out/phoc-syncobj-arm64-20261111/` |
| 16 | 启动四道门（subuid 给 root / `data_dir/{data,metadata}` / 9 个 `/usr/bin/droidloom-*` 软链 / 祖先属主） | **d** | **#614**（`sessions/269-…`）、**#608**（`PITFALLS/README.md:306`） |
| 17 | `droidloom-package-helper prepare` 要求 `/etc` 为 `root:root 0755`（本机不符） | **d** | `reports/droidloom-status-20261111.md` §3.2 |
| 18 | 跨发行版构建假 FAIL：相对 `--sysroot` 传给 cargo（cwd=源码仓） | **d**（构建机） | **#730**（`PITFALLS/README.md:404`、`sessions/363-…`） |
| 19 | 内核 `CONFIG_NF_TABLES` 缺 ⇒ cell 起不来（gate 已解，`patches/fragment-droidloom-nftables.config`） | **d** | `TASKS/G2.md` C12 行；**#605**（`olddefconfig` 验证口径） |
| 20 | `LOCALVERSION` 一变整棵模块树「消失」，伪装成 GPU/显示坏 | **d** | **#607**（`PITFALLS/README.md:305`） |
| 21 | 自动化验键盘的假阴性/假绿：`adb input tap` 不给宿主焦点（#761）、`adb screencap` 看的是 Android 合成（#753）、`uinput-touch` 到不了 OSK 层表面（#755）、能点不能挥（#760） | **d**（工具/纪律） | **#755/#760/#761**；`sessions/594-…`、`599-…`、`600-…` |
| 22 | `pkill -x phosh-osk-stub` ⇒ 「画得出按不动」，只能重开会话 | **d**（纪律） | **#756**（`sessions/595-…`） |
| 23 | 上游无 PR 通道（`pulls` API 404），只有 `main` 一条线；贡献只能 issue + compare | **c**（流程） | **#757**（`sessions/596-…`）、`reports/droidloom-fork-survey-20261128.md` §1 |
| 24 | 无 Android SELinux LSM ⇒ 安全边界退化为宿主沙箱 ⇒ PI/Widevine 结构性不可达（上游明文免责） | **c** | `reports/waydroid-droidloom-userland-interface-20261026.md` X2；`reports/droidloom-app-compat-20261125.md` §1.1 |
| 25 | 相机 broker 要宿主 **braun**、定位 broker 要宿主 **dmail**（本机都没有） | **a**（缺宿主栈，无现成件） | `reports/droidloom-app-compat-20261125.md` §3.2（"缺组件"）；`reports/droidloom-deploy-20261126.md:91`（未测） |
| 26 | Limbus Company 启动即被杀：AppSealing `Root_Detection=1`（cell 按设计 permissive + 可写系统） | **c**（形态固有） | `reports/limbus-appsealing-20261126.md`；`TASKS/G2.md:52` |
| 27 | 侧滑返回：`lisgd` 只旁听 evdev 不 `EVIOCGRAB` ⇒ 同一次触摸照送应用 | **a**（工具层，或走上游 MR） | `reports/droidloom-osk-keypad-hide-20261128.md` §A；`T35` |
| 28 | GApps add-on 首次激活要求**全新** `data_dir`（现役数据不作数） | **d** | `reports/droidloom-app-compat-20261125.md` §1.2/§1.3 |
| 29 | 性能（缓冲池 5 vs `kSparesPerLayer=3`、import miss）——上游 `#55` 判据**是否适用于我方未测** | **未取证** | `reports/droidloom-upstream-cluster-20261127.md` §3 缺陷 4（明确「本仓无定因件」） |

### 1.3 计数

| 类 | 条数 | 代表编号 |
|---|---|---|
| **(a) 纯宿主用户态可修** | **13** | #2/3/4/5/6/11/12/13/14/15/25/27（+#762 同型） |
| **(b) 需重编 Android/AOSP 镜像** | **4** | #1（WifiProvisioning）、#7（#763，**上游 52 已修**）、#8（`onShowInputRequested`）、#10（insets，**上游 52 已修**） |
| **(c) 需上游改架构 / 形态固有** | **4** | #9（#753/#69）、#23（#757）、#24（SELinux/PI/Widevine 天花板）、#26（AppSealing） |
| **(d) 环境 / 一次性 / 纪律** | **7** | #16（#614）、#17、#18（#730）、#19（#605）、#20（#607）、#21（#755/#760/#761）、#22（#756） |
| 未取证 | **1** | #29 性能 |
| **合计** | **29** | 另：#607/#613 等诊断口径条目未单列（属方法论，不属缺陷） |

**口径提醒（重要）**：
1. **(b) 类 4 条里已有 2 条被上游 release 52 修掉**，且交付方式 = **上游发包（image 67 MB + runtime 11 MB，base 仍是 49 不动）**，不是我们编 AOSP。所以「缺陷台账里 (b) 类条数」≠「我们要重编 AOSP 的次数」。
2. 用户 2026-11-28 的裁决（AOSP/Android 镜像重编**不是主线待办、需求下移**）下，**#1 与 #8 两条按「不做」记账**，本机可用性由宿主侧补丁 + 上游发版承接：`reports/build-env-podman-eval-20261128.md` §2-C 行（该活已出列）、`TASKS/NEXT.md:105`（T2 残留）、`TASKS/NEXT.md:135`（T38 残留）。

---

## 2. 上游健康度（现查，2026-11-28T09:37:32Z–09:45Z UTC）

> 复现前缀（`gh` 必须摘代理，`curl` 才走本机代理）：
> `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY gh api <path>`，每条套 `timeout -k 5 60`。

### 2.1 denialwm/droidloom（实测）

| 指标 | 值 | 复现命令 |
|---|---|---|
| `open_issues_count` / issue 总数 / open / closed | **38** / **68** / **38** / **30** | `gh api repos/denialwm/droidloom --jq .open_issues_count`；`gh api "repos/denialwm/droidloom/issues?state=all&per_page=100" --jq '[.[]\|select(.pull_request\|not)]\|group_by(.state)\|map("\(.[0].state)=\(length)")'`（`has_pull_requests:false` ⇒ 无 PR 混入） |
| open 中零评论 | **24 / 38** | 同上 `select(.state=="open") \| map(select(.comments==0)) \| length` |
| stars / forks / watchers | **612 / 33 / 3** | `gh api repos/denialwm/droidloom --jq '{stargazers_count,forks_count,subscribers_count}'` |
| 仓库创建 | **2026-09-06**（≈ 2.7 个月） | 同上 `created_at` |
| `pushed_at` / `main` tip | **2026-11-27T11:45:05Z** / `e6f18c4` = **0.1.0-52** | 同上；`gh api "repos/denialwm/droidloom/commits?per_page=1"` |
| 发布形态 | **单 tag `packages`**，**153 个资产**；无独立 release note | `gh api repos/denialwm/droidloom/releases --jq '.[0]\|{tag_name,assets:(.assets\|length)}'` |
| 包版本节奏（实测提交史） | 45→46→47→48→49(11-20)→50(11-26T13:56Z)→**51(11-26T18:22Z)**→**52(11-27T11:44Z)** ⇒ **11-26/27 两天连发 3 版**；**最近一版距今 ≈ 22 h** | `gh api "repos/denialwm/droidloom/commits?per_page=30"` |
| commit 量 | 自 2026-11-21 起 **20 条**；自 2026-11-01 起 **≥100 条**（单页上限 100，未翻页 ⇒ 取「≥」） | `gh api "repos/denialwm/droidloom/commits?since=2026-11-21T00:00:00Z&per_page=100" --jq length` |
| aarch64 资产 | 有（`image/runtime/source-0.1.0-5{0,1,2}-aarch64`）；**`base` 仍只有 `0.1.0-49`（903,293,629 B）** ⇒ 升级只下 78 MB | `gh api releases/tags/packages --jq '.assets[]\|"\(.name) \(.size)"' \| grep -E 'base\|0\.1\.0-5'` |

### 2.2 四条线程的维护者响应（实测，逐条）

| 条目 | 状态 | 创建 | 最近更新 | 评论 | 评论者 |
|---|---|---|---|---|---|
| **#34**（Android 键盘做空占位器，让 App 让位宿主 OSK） | open | 2026-11-18T10:40Z | 2026-11-18（**10 天零回复**） | 0 | — |
| **#48**（虚拟 Wi-Fi 永久禁用 + DHCP DNS 硬编码） | open | 2026-11-22T12:33Z | 2026-11-27T14:45Z | **1** | 仅 `xiaquwan1001`（我方）⇒ **维护者 6 天零回复** |
| **#65**（占位 IME `showSoftInput` 恒失败，49/51 双版本） | open | 2026-11-27T14:01Z | 2026-11-28T03:41Z | **2** | 两条均 `xiaquwan1001`（我方，含协议 trace）⇒ **维护者 0 回复** |
| **#69**（图形 Android IME 不投影到宿主） | open | 2026-11-28T01:52Z | 2026-11-28T01:55Z | 0 | — |

复现：`gh api repos/denialwm/droidloom/issues/{34,48,65,69} --jq '"#\(.number) \(.state) \(.created_at) \(.updated_at) c=\(.comments)"'`；
`gh api repos/denialwm/droidloom/issues/65/comments --jq '.[]\|"\(.created_at) \(.user.login)"'`。

**读法（静态 + 实测组合）**：维护者确实在**改代码**（52 里三条正是我方痛点域），但**不在 issue 里对话**；
`reports/droidloom-fork-survey-20261128.md` §1 记录实际 triage 由 `synthia-si[bot]`（Discord↔issue 桥）做，
`denialwm`/`doctorlogix` 本人在抽样的 6 条线程里**未见回帖**。⇒ **规划假设必须是「上游会修，但不会回你」**：
能等的等发包，不能等的自己打 patch（我方 6 条 patch 就是这条假设的产物）。

### 2.3 关键新事实：release 52 已覆盖我方两条 image 侧缺陷（实测 commit 级）

| 上游 commit | 标题 | 触及文件（API 原文） | 对应我方缺陷 |
|---|---|---|---|
| `b30e8d8`（2026-11-27T11:25Z） | *The keyboard opens after an app restarts its text field* | `+ android/framework/droidloom-ime/.../EditorTask.java`、`HostInputMethod.java (+9/−2)`、测试、`docs/contracts/text-input-v1.md` | **#763**（"The input method keeps the task of the editor being restarted" = 我方 `task=0` 丢弃的根因） |
| `6fe1878`（11-27T11:06Z） | *Apps see the host keyboard as visible in every boot* | `android/framework/0001-droidloom-bottom-navigation-insets.patch (+40/−7)` | #10（insets 可见性随 boot 变化；App 自己收键盘） |
| `3bd905b`（11-27T11:33Z） | *An app opened again keeps its window's size* | `android/framework/droidloom-window-policy/.../DroidloomTaskBackend.java (+31)` | #11 的「重开回到 manifest 尺寸」半边 |

复现：`gh api repos/denialwm/droidloom/commits/b30e8d8 --jq '.commit.message, (.files[]|"\(.status) \(.additions)+ \(.filename)")'`（`6fe1878`/`3bd905b` 同法）。

**成本含义（这是本报告对既有口径的最大修正）**：我方在机版本是 **51**（`TASKS/NEXT.md:139` T15 行），
而 **52 的 image 包 66,873,071 B + runtime 11,131,885 B 于 2026-11-27T11:51Z 已在 release 上**、
`base` 无需重下 ⇒ **「升级到 52 再复判 IME」是一次 ~78 MB / 10 min 的动作，不是一次 AOSP 重编**。
（判据：升级后 `adb logcat -d -s DroidloomIME | grep -c restarting=true` 与「号段框连输 10 位」；
若 #763 仍未解，再回到本地 patch 路线。**本条为静态推断 + 未上机，故不计入已解决。**）

### 2.4 Waydroid 上游（实测，对照）

| 指标 | 值 | 复现命令 |
|---|---|---|
| stars / forks / open issues | **12 612 / 568 / 995** | `gh api repos/waydroid/waydroid --jq '{stargazers_count,forks_count,open_issues_count}'` |
| `pushed_at` | **2026-11-15T23:09:57Z**（≈13 天前有提交） | 同上 |
| release 节奏 | **1.6.0 2025-11-21 → 1.6.1 2025-12-29 → 1.6.2 2026-02-22 → 1.6.3 2026-05-28（最近一版距今 ≈ 6 个月）** | `gh api "repos/waydroid/waydroid/releases?per_page=8" --jq '.[]\|"\(.published_at) \(.tag_name)"'` |
| commit 量 | 自 2026-06-01 起 **9 条**（≈1.6 条/月）；最近 10 条最早到 2026-05-28 ⇒ 提交稀疏、以修边角为主 | `gh api "repos/waydroid/waydroid/commits?since=2026-06-01T00:00:00Z&per_page=100" --jq length` |

**对照读法**：Waydroid = **成熟但冻结**（容器栈稳定、镜像由社区 OTA，问题密度高但增量小）；
droidloom = **高速但未定形**（2.7 个月 68 条 issue、两天一发包、单一维护者 + bot）。
⇒ 「上游等待时长」应写成：**droidloom 的修复会自己来但不会通知你（要盯 release）；Waydroid 的修复基本不会来（要自己背）。**

---

## 3. 功能面逐项对照（每项标证据文件 / 缺证据写「未取证」）

| 功能 | droidloom（本机实证） | Waydroid（本机实证） | 差距判读 |
|---|---|---|---|
| **相机** | **不能**：`droidloom-devices` 的 `camera.sock` 客户端要宿主 **braun** 的相机与 session，本机无 braun；现役 0.1.0-51 **未测**相机（`reports/droidloom-app-compat-20261125.md` §3.2 末、`reports/droidloom-deploy-20261126.md:91`） | **部分可用**：容器 `dumpsys media.camera` = 1 设备（`Device 0 maps to "200"`）、端到端真帧 10 帧/Y mean 107、前后「切换」= 换 loopback 生产者（`TASKS/G2.md` C5 行、`reports/c5-u7-container-camera-20261028.md`）；**App 内预览 U7 仍差 2 步** | **Waydroid 优（差距真实）** |
| **音频** | **未取证**：`droidloom-audio` per-user PipeWire broker 未跑过（`reports/droidloom-feasibility-20261110.md` §…「未测」、`reports/droidloom-app-compat-20261125.md` §3.2 麦克风行） | **播放 + 录音通路均实测通**（闹钟出声、`TestRecord` rms≈457/peak≈1815）、**延迟未量化**（`reports/container-audio-20261011.md`、`TASKS/ANDROID-COMPAT.md` §5 U8） | **Waydroid 优（未取证 ≠ 不可用）** |
| **传感器** | **不能/未取证**：droidloom 侧无传感器 broker 记录 | **可用但降级**：UDP HAL 6 传感器 running、数据流实测（`TASKS/G2.md` C4、`reports/research-waydroid-sensors-hal-20261011.md`）；真值源依赖 `ssc-udp-relay`+`hexagonrpcd`（`PITFALLS #692` 硬崩 ⇒ 现以 `--fake` 兜底，`TASKS/ANDROID-COMPAT.md` §2-①） | **Waydroid 优** |
| **GMS 登录** | **上游已验证（非我方实测）**："Account sign-in and opening Play Store have been verified on the Moto ARM64 cell"；本机**未取证**（需 LiteGapps + 全新 data_dir，`reports/droidloom-app-compat-20261125.md` §1.1/§1.3） | **本机实测通**：Play Store 登录成功 + GMS 服务可用（用户人工确认，`TASKS/G2.md` C2 行，经宿主 Clash 代理） | **Waydroid 优（本机实证）** |
| **Play Integrity** | 上游明文「not supported claims」；我方**未诉求** | **实测 `deviceRecognitionVerdict = []`**（BASIC/DEVICE/STRONG 全不满足，`reports/c3-spic-verdict-20261115.md`） | **平（都不达标）** |
| **Widevine** | 无（同栈天花板，`reports/droidloom-app-compat-20261125.md` §1.1） | **不存在**（vendor `mediadrm/` 只有 `libdrmclearkeyplugin.so`，`reports/android-compat-20261026.md` §2.1） | **平（都无）** |
| **输入法** | **勉强可用**：headless IME + 宿主 phosh OSK；真手指可出数字键盘（`#762` 补丁后）、**连输仍受 #763 限制**（上游 52 修）；图形 IME 不可用（`#753`/#69）；宿主 OSK 的 RIME 中文已能落进 Android 框（`TASKS/NEXT.md:129` 残留①已解决） | **可用（宿主侧）**：squeekboard + fcitx5/Rime 上屏中文已验收，`elden-ime-focusd` 自写；**容器内 IME 未验**（`TASKS/G2.md` C11 行 + `reports/android-compat-20261026.md` §1 输入「容器内 IME 未验」） | **Waydroid 略优（中文链路成熟）；droidloom 的宿主 OSK 方案已打通同一需求** |
| **剪贴板** | **可用**：presenter 绑定期实测 `clipboard=ext-data-control`（`reports/droidloom-status-20261111.md:66`、`reports/droidloom-feasibility-20261110.md:269`） | **未取证**（本仓无 Waydroid 剪贴板实测记录） | **droidloom 优（唯一 Side 有实测）** |
| **通知** | **端到端可用**：adb 实发通知宿主接收并落 `notifications.state`（`reports/droidloom-warn-20261111.md` §0-2）；历史紧循环已自愈 | **未取证** | **droidloom 优** |
| **文件共享** | **可用（静态）**：`share_user_folders` 把宿主 Pictures/Download/Movies 映成 Android 集合（`reports/droidloom-app-compat-20261125.md` §3.2）；**本机未开**（上游 `#57` 有 idmap 副作用） | **可用（历史）**：`/dev/fuse` + emulated storage（`PITFALLS #191`）；**当前未部署，未取证** | **平（都有机制，均未在本 rootfs 现测）** |
| **窗口与 dpi** | **per-task 独立 Wayland 窗口**（这是它的核心价值）；per-app 尺寸靠 `window-policy-v1.json`（`TASKS/G2.md:72` 实测 `configure=1902x3039`）；dpi 可调（213→690 实测）；**多 app 并存 = 设计内能力**（每 task 一 `xdg_toplevel`），本机实测到 2 个窗口并列的场景**未取证** | **单窗口**：`show-full-ui` 把整个 Android 塞进一个 Phosh 窗口，**不满足多窗口**（`TASKS/ANDROID-COMPAT.md` §5 U9 未做、`reports/c9-cases-20261013.md:25`） | **droidloom 结构性强（这是路线选择的核心理由）** |
| **多 app 并存** | 同上（每个 App 独立窗口，可并排；`session mode: desktop` 实测） | 只能在一个 Android 桌面内切 App | **droidloom 优** |
| **性能** | **未取证**（本仓零 perf 基线；上游 `#55` 缓冲池公式是否适用未测，`reports/droidloom-upstream-cluster-20261127.md` §3-4） | **未取证**（U6 30 fps 未测；已知 freedreno/Adreno 830 GLES 3.2 + 宿主 165 Hz 在跑，`reports/android-compat-20261026.md` §1 图形） | **平（都未取证，谁都不许拿性能当论据）** |
| **可靠性/起停** | `droidloom-doctor` = 13 PASS / 1 WARN(`host_lsm`) / 0 BLOCK；**#759：会话重建后不自启**（待办 T46） | 会话**不随桌面自启**（`Session: STOPPED`）；**当前未初始化**（J3） | **droidloom 优（至少已在机运行）** |

**对照结论**：Waydroid 赢在**外设与账号面**（相机/音频/传感器/GMS 登录 = 4 项，全是「我们已写好的自编 HAL」）；
droidloom 赢在**桌面形态与已实测的桥**（多窗口/剪贴板/通知/起停 4 项），其余 6 项两者都没证据或都不可达。

---

## 4. 成本模型（按「我们实际要维护的层」估 1 年人力）

### 4.1 事实底座（先量，再估）

| 量 | droidloom | Waydroid | 取证 |
|---|---|---|---|
| 我们的源代码层 | **6 patch / 31 hunk / +366 −121 行**（Rust 5 处 + Java 1 处） | **C/AIDL 三套 HAL ≈ 2 702 行**（sensord 1 948 + haptics 552 + camera-provider 202）+ **shell ≈ 1 067 行**（11 个脚本）+ 11 项固化配置 | `grep -c '^@@'`/`grep -c '^+'` 逐个 patch 复算；`find patches-userland/waydroid-* patches/waydroid-camera-64bit-20261018 -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.aidl' \| xargs cat \| wc -l`；`wc -l scripts/waydroid-*.sh scripts/cam-loopback.sh` |
| 单件构建耗时（实测） | runtime 9 个 Rust 程序：**18 s**（我方 `scripts/build-droidloom-userland-crates.sh`，4 个 C 依赖件）／EB 口径 57 s 交叉编 | Mesa 定向重编 **~5.5 min（ccache 热 ~10 min）**；相机 provider 需 **AOSP tag（VNDK33）头 + `dl-cam/gen-aidl.sh`** 才能重编（重活） | `TASKS/NEXT.md:117`（T44 行：18 s / 4 件 / `ldd` missing=0）；`TASKS/ANDROID-COMPAT.md` §6-C；`reports/waydroid-camera-provider-64bit-20261018.md` §头 |
| 上游发版频率 | **1–3 天/包版本**（11-26 两天 3 版，实测） | **≈6 个月/版**（1.6.1→1.6.3） | §2.1/§2.4 |
| 我方可直接消费的修复 | **高**：52 里 3 条命中我方痛点域（§2.3） | **低**：5.5 个月 9 条外部 commit，与我们的 11 项固化无交集 | §2.4 |
| 一次「全量重来」成本 | 摊装 3 包（base 903 MB 一次性 + image 67 MB + runtime 11 MB）+ 4 道门（#614）；AOSP 全编 ~ **120 GiB + 数小时**（**已出列、不排期**） | `A7`：装 `waydroid`+`lxc` → `waydroid init` → 回刷 `vendor.img`（相机 gralloc + vibrator HAL + RRO）→ 三套 HAL/脚本部署 = **60–90 min 设备窗** | `TASKS/NEXT.md:105`（120 GiB 口径）；`reports/best-state-and-gap-20261122.md:111` |
| 当前在机状态 | **在跑**（cell `Android is ready`、adb `10.177.0.2:5555` 在线、小红书可上屏） | **未初始化**（`waydroid status` → not initialized） | `TASKS/G2.md:51`、`reports/d16-unit-deploy-classify-20261127.md:163` |

### 4.2 假设（写死，便于将来推翻）

- **H1**：跟上游 main、**每月升 1–2 次包**（不追每 2 天一个版本）。每次 = 78 MB + `droidloom-doctor` + 3 条冒烟（cell ready / adb / 一次 launch）。
- **H2**：`patches/local/` 保持 **6 条上限**；升级时重贴（`git log -- <4 文件>` 判邻域，`reports/droidloom-upstream-cluster-20261127.md` §5.3 的退役判据）。
- **H3**：**不做 AOSP 重编**（用户 2026-11-28 裁决）。若将来被迫做，按 **1 次 = 120 GiB + 数小时 + 一次镜像回归** 计。
- **H4**：宿主侧新增功能（相机/定位 broker 宿主栈）**只做被需求拉动的**，按每次 ≤ 1 周估。
- **H5**：Waydroid 冷备状态下**不主动升级**；只在「要用」时恢复 + 恢复后跑 A7 判据。

### 4.3 一年人力

| 项 | droidloom（主路线） | Waydroid（冷备） | 说明 |
|---|---|---|---|
| 日常维护（升级 + 重贴 patch + 冒烟） | **12–18 h/年**（12–24 次 × 30–45 min） | **0**（不升级）/ 若热备则 **6–10 h/年**（2 次恢复 × 60–90 min + 判据） | H1/H2/H5 |
| 新缺陷处置（按 2026-11 的实际速率外推） | **20–40 h/年**（11 月共处置 ≈ 10 条宿主侧缺陷，多在 1–4 h/条；含一次真手指验收） | **4–8 h/年**（冻结栈，主要来自宿主内核/桌面变化导致的回归） | 台账 §1.2 的 (a) 类 |
| 需要重编镜像/系统的次数 | **0–1 次/年**（已被上游 52 消掉 2 条；残余风险见 §5.4） | **0–1 次/年**（仅当 LOS 镜像换代才需重编 camera-provider；`TASKS/ANDROID-COMPAT.md` §6-A 已裁决「维持 LOS 20 不追新」） | H3 |
| 上游等待 | **「会修但不回」**：修复随发包到（52 距 51 仅 17 h）；issue 回复按 0 计 | **≈不等待**（栈冻结），但也意味着**要自己背** | §2.2/§2.4 |
| 设备窗口占用 | 每次升级 ~15 min + 验机 15 min | 恢复 60–90 min；回归验收 ~30 min | — |
| **合计（保守）** | **32–58 h/年** | **冷备 4–8 h/年**；热备 **10–18 h/年** | — |

**双轨的边际成本**：把 Waydroid 保持在**冷备**（资产留仓、不常驻、每次 rootfs 重装后不主动恢复）= **4–8 h/年**；
保持在**热备**（每次 rootfs/内核/桌面变更后都恢复并跑 C1–C11 判据）= **10–18 h/年**，且要额外承担
「两套容器后端共存」的配置漂移（`reports/waydroid-droidloom-userland-interface-20261026.md` §3 已裁「只抽象 3 个点」，其余不抽象）。

---

## 5. 结论

### 5.1 推荐（明确）

1. **主路线锁定 droidloom**，形态 = **跟上游 `main` 发版 + 我们只维护 `patches/local/`（6 条上限 + 退役判据）**。
   不做整包 fork（`reports/droidloom-fork-survey-20261128.md` §6 选项 A/B；`eb/main` 三条与我方 `00{2,3,4}` **diff 字节等同**，无照抄价值）。
2. **Waydroid 降为冷备**：保留仓内全部资产（3 套 HAL 源、11 个脚本、`vendor.img` 回刷配方、`A7` 步骤），
   **不追加固化开发、不追上游版本、不在每次重装后主动恢复**。触发「转正」时才恢复（60–90 min）。
3. **双轨 = 冷双轨，不做热双轨**：热双轨的边际成本（10–18 h/年 + 配置漂移）买不到东西 —— 因为两条路线的
   **身份天花板完全相同**（PI 全不满足、Widevine 无），而 Waydroid 的形态（单全屏 Android 窗口）与「Android 应用进 Phosh 桌面」的项目目标相反。
4. **下一步唯一的高性价比动作**（≤ 半天，需设备窗一次）：
   **升到 release 52 → 复判 #763**（`gh api releases/tags/packages` 取 `image/runtime-52-aarch64`，`tar --zstd -xf -C /`，判据 =
   号段框连输 10 位 + `adb logcat -d -s DroidloomIME | grep -c restarting=true` + 宿主 `grim` 看键盘）。
   **若 52 修好 ⇒ 我方 `0001`/`0002` 两条宿主补丁的 `#763` 相关性归零，缺陷台账 (b) 类只剩 #1/#8 两条已出列的项。**

### 5.2 为什么不是「Waydroid 转正」

- 它现在**不可运行**（未初始化，J3），转正要先付 60–90 min 恢复 + 一套 HAL 回归；
- 它的 4 项优势（相机/音频/传感器/GMS 登录）**都来自我们自编的 ~3.8 k 行**，属于「继续背」而不是「白拿」；
- 它是**单窗口**形态，等于把我们花在桌面（Phosh/phoc）上的工作降级为「Android 里套一个全屏」；
- 它的上游**冻结**（6 个月一版、5.5 个月 9 条提交），遇到 arm64 相关问题时**没有上游可等**；
- 它不能改善身份天花板（J4），而身份是这个项目唯一「花钱也买不到」的缺口。

### 5.3 为什么不是「现在就砍掉 Waydroid」

- 相机/音频/传感器三项**只有 Waydroid 有本机实证**；一旦需求转成「用平板发布照片/视频/直播」，
  droidloom 侧要从零写 braun/dmail 宿主栈（≥ 2–4 周量级），Waydroid 只要 60–90 min 恢复。
- 冷备成本极低（4–8 h/年），且资产已全在仓内 ⇒ **保底价值 > 维护成本**。

### 5.4 哪些证据会推翻该推荐（逐条给判据）

| # | 出现即推翻/改写推荐 | 判据（可复现） |
|---|---|---|
| **F1** | **必须重编 AOSP 才能推进**（例：某必需 App 依赖图形 IME 投影、或 `onShowInputRequested` 必须在 Android 侧改） | 需出现的现象：`#753`/`#69` 变成阻塞「每天要用的 App」的同因缺陷，且上游 30 天未修 ⇒ 转「Waydroid 主 + droidloom 观察」 |
| **F2** | **上游停更或质量回退** | `gh api repos/denialwm/droidloom --jq .pushed_at` **> 30 天无更新**，或连续 2 个包版本引入我方补丁邻域冲突且判据回归（cell/adb/launch 任一 FAIL） |
| **F3** | **release 52 也没修 #763** 且宿主侧已无手段（`#762` 补丁后仍只能输 1 位） | 52 上 `grep -c restarting=true` 仍每键一条 + 号段框第 2 位起无响应 ⇒ IME 需求被迫回到 (b) 类 ⇒ 立 F1 流程（Waydroid 转正候选） |
| **F4** | **性能不可接受且不可修** | 我方 `droidloomctl logs` 出现 `#55` 判据（5 缓冲 vs `kSparesPerLayer=3` ⇒ 每帧 import miss）+ 帧率/发热实测低于 Waydroid 同 App 基线（需先建基线，当前**双未取证**） |
| **F5** | **需求转向「手机替代」**（拍照发布、直播、GMS 全家桶、银行类 App） | 用户需求明确要求相机/麦克风/传感器/GMS 商店任一成为日常 ⇒ Waydroid 转正（唯一有本机实证的外设栈） |
| **F6** | **arm64 出现带 Widevine L3/L1 的新镜像** | WayDroid-ATV / LOS 22+ 的 arm64 镜像 `vendor/lib64/mediadrm/` 出现除 `libdrmclearkeyplugin.so` 之外的插件 ⇒ 身份维度重估（当前平局被打破） |
| **F7** | **宿主栈变化打断 droidloom 前置** | phoc/phosh 升级后 `wayland-info \| grep -c linux_drm_syncobj_manager_v1` = 0 或 `droidloom-wayland` 出现 bind failure（`#604/#613` 判据）⇒ 需重新评估「是否值得为了它钉住合成器」 |
| **F8** | **Waydroid 恢复成本被证明远低于估计** | `A7` 实测 < 30 min 且 C1/C5/C6/C10 判据一次全绿 ⇒ 冷备可升级为「可热切的热备」，双轨结论改写 |

---

## 6. 未取证清单（不得当结论用）

1. **release 52 是否真修好 #763**（静态推断 + commit 语义；需一次 78 MB 升级 + adb 复现）。
2. **droidloom 的音频/相机/传感器/性能**：四项均无本机实测（音频 broker 未跑、braun/dmail 缺、零 perf 基线）。
3. **Waydroid 当前形态的剪贴板/通知/文件共享**：本仓无实测记录（`/dev/fuse`、`config_nodes` 有历史修复，但本 rootfs 未恢复）。
4. **多 app 并存的实测**：droidloom 设计内支持、本机只验过单 App + 2 应用目录；Waydroid `U9` 从未做过。
5. **升级 droidloom 52 对我方 6 条 patch 的冲突面**：`base` 仍 49、image/runtime 改动未与我方 hunk 逐行对表（需 30 min：`git apply --check` on source-52）。
6. **本报告的 Waydroid 侧数字多数来自 2026-10/11 的实测**；设备当前未初始化，未重跑。

---

## 7. 复现命令汇总（本报告所有在线数字）

```sh
# 上游元数据 + issue 结构（gh 必须摘代理）
P='env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY'
timeout -k 5 60 $P gh api repos/denialwm/droidloom \
  --jq '{open_issues_count,forks_count,stargazers_count,pushed_at,has_pull_requests,created_at}'
timeout -k 5 60 $P gh api "repos/denialwm/droidloom/issues?state=all&per_page=100" \
  --jq '[.[]|select(.pull_request|not)]|group_by(.state)|map("\(.[0].state)=\(length)")'
timeout -k 5 60 $P gh api "repos/denialwm/droidloom/issues?state=all&per_page=100" \
  --jq '[.[]|select(.pull_request|not)|select(.state=="open")]|"zero=\([.[]|select(.comments==0)]|length)/\(length)"'
for n in 34 48 65 69; do timeout -k 5 40 $P gh api repos/denialwm/droidloom/issues/$n \
  --jq '"#\(.number) \(.state) \(.created_at) \(.updated_at) c=\(.comments)"'; done
# release 52 的三条关键 commit
for s in b30e8d8 6fe1878 3bd905b; do timeout -k 5 60 $P gh api repos/denialwm/droidloom/commits/$s \
  --jq '.commit.message, (.files[]|"\(.status) \(.additions)+ \(.filename)")'; done
# 包资产（base 仍 49 ⇒ 升级只 78 MB）
timeout -k 5 60 $P gh api repos/denialwm/droidloom/releases/tags/packages \
  --jq '.assets[]|"\(.name) \(.size)"' | grep -E 'base|0\.1\.0-5'
# Waydroid 上游
timeout -k 5 60 $P gh api repos/waydroid/waydroid --jq '{open_issues_count,pushed_at,stargazers_count}'
timeout -k 5 60 $P gh api "repos/waydroid/waydroid/releases?per_page=8" --jq '.[]|"\(.published_at) \(.tag_name)"'
timeout -k 5 60 $P gh api "repos/waydroid/waydroid/commits?since=2026-06-01T00:00:00Z&per_page=100" --jq length
```

```sh
# 我方「要维护的层」量化（本机只读）
cd patches/local
for f in droidloom-local-20261127/00*.patch droidloom-local-20261128/00*.patch; do
  echo "$f hunks=$(grep -c '^@@' $f) +$(grep -c '^+[^+]' $f) -$(grep -c '^-[^-]' $f)"; done
find ../patches-userland/waydroid-sensord-udp ../patches-userland/waydroid-haptics-aidl \
     ../patches/waydroid-camera-64bit-20261018 -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.aidl' \) \
  | xargs cat | wc -l
wc -l ../scripts/waydroid-*.sh ../scripts/cam-loopback.sh | tail -1
```

---

## 8. 边界

- **做**：读 `PITFALLS/README.md` + `PITFALLS/sessions/`（14 份含 droidloom）、27 份 `reports/droidloom-*.md`、
  `TASKS/G2.md`、`TASKS/NEXT.md`、`TASKS/ANDROID-COMPAT.md` §6、`patches/local/*`；`gh api` 只读取数 6 组。
- **没做**：设备 `ssh`/`adb`/`fastboot`（0）、装包/升级（0）、改 `TASKS/`/`INDEX.md`/`PITFALLS/`（0）、
  发 issue/评论（0）、`git commit`（0）、下载 release 资产（0）。
- **唯一写入**：本文件。
