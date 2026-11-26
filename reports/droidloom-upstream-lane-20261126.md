# droidloom 附属仓库整理 + 上游缺陷/社区分叉评估（D24 常设 lane，首轮 2026-11-26）

> **来源**：lane D24（`researcher` / `custom.ustc-pool/ustc-dsf`）首轮产出；父代理已独立复核其最关键的两条外部事实（见文末「父代理复核」）。
> **性质**：只读（未改 `TASKS/`/`INDEX.md`/`PITFALLS/`、未 git 操作、未发 issue/PR、零设备写）。
> **维度登记** = `TASKS/dim/D24.md`；派发入口 = `TASKS/NEXT.md` §4.0。


> 性质：只读。未改 `TASKS/` `INDEX.md` `PITFALLS/`、未 git 操作、未发 issue/PR、未登设备写任何东西。
> 本文件是本次唯一产物（父代理如需落 `reports/`，请整段拷成 `reports/droidloom-upstream-lane-20261126.md`）。
> 上游抓取原文（GitHub API/HTML 摘要）未另存盘 —— 本机无 shell 工具，无法写 `reports/artifacts/`；文中每条结论都带可复取 URL。

## Summary

上游 `denialwm/droidloom` 的**缺陷面比我们记录的大得多**（54 条 issue，29 条 open），但它同时是**高活跃的**（release 49 于 2026-11-20 打包、周边 3 个 fork 各自带 8–41 个自有提交）。**我方 6 项核心缺陷中只有 2 项被一条既有 issue 覆盖（#48，虚拟 Wi-Fi 永久禁用 + DHCP DNS 硬编码）**；`unshare --forward-signals`、输入法状态机、冷启动显示尺寸三项**上游无 issue**，其中两项已在某个 fork 里被**代码修掉**：`EvilBorsch/droidloom`（`eb/main`，`0.1.0-49+eb7`）直接产出 Debian/Ubuntu `.deb`，并内含我们当前**本机规避手段**（`/usr/local/bin/unshare` shim、独立 nft DNS 重定向表）的正解 —— 这是本次最有价值的发现。**结论：继续投，但降级为「受控实验（只当实验）」，不作 G2 主线**；未来两周最小动作 = 给 #48 补数据、试 EvilBorsch 的 deb/三个 patch、给 IME 做一次「是否 phoc 缺可选扩展」的对照实验。

---

## Findings

### A. 附属仓库整理（本仓 face）

**A1. droidloom 相关资产清单（13 份报告 + 3 类非报告资产）**

| 路径 | 一句话作用 | 是否过期（按 `INDEX.md` §2 时间序） | 建议 |
|---|---|---|---|
| `reports/droidloom-deploy-20261126.md` | 0.1.0-49 三包正式摊装 + 小红书/Limbus 上机 + 三个部署期修复 | **部分过期**：§5 缺口-1「cell 无网（未解）」已解（同日晚）；§4 Limbus 判据已被 `limbus-appsealing` 细化 | 保留；加一行指针到 §5 的「已解」 |
| `reports/droidloom-cell-network-20261126.md` | 无网双根因（永久禁用 + DNS 硬编码），含源码级期望形态 | **主体有效，缺少"已修"段** —— 修法与实测结果只写在 `TASKS/G2.md` 的「★2026-11-26 晚」块里 | 保留 + 追加 §8「已修（探针改 vivo / 独立 nft 表 / connect-network）」 |
| `reports/droidloom-display-sizing-20261126.md` | 全屏真因 = task bounds 被原样当窗口尺寸 | **过期**：§3「未做的决定性实验」与 §4「不提供 per-app 全屏开关」都不再成立（per-app 覆写已生效） | 下沉为历史；结论并入新版或标 `⛔ 已被 11-26 晚的 per-app 覆写取代` |
| `reports/droidloom-ime-keyboard-20261126.md` | 键盘「输一个字符后缩回且唤不出」取证 + 四个处置选项 | **有效但口径需改**：把「上游状态机缺陷」降为「候选成因之一」，并加入「宿主合成器缺 `denial_text_input_panel_manager_v1`」假设（见 B/D） | 保留；§0 增补契约层依据（`docs/contracts/text-input-v1.md`） |
| `reports/limbus-appsealing-20261126.md` | AppSealing `Root_Detection=1` 明文证据 + 不投结论 | 有效 | 保留 |
| `reports/droidloom-app-compat-20261125.md` | J1/J2/J3 静态兼容判据（Limbus 现役装法起不来） | **J2 结论已被取代**（装得上、被安全层杀） | 保留；J2 行加指向 `limbus-appsealing-20261126.md` |
| `reports/droidloom-status-20261111.md` | L1–L4 判据定义 | 判据仍被引用，**状态事实全过期**（L4 早已过、含第三方 App） | 保留为「判据定义」；状态一律改指 `TASKS/G2.md` C12 |
| `reports/droidloom-feasibility-20261110.md` / `-20261108.md` | L1–L4 判据基线（2026-11-10 权威件） | 判据有效，实机事实过期（0.1.0-30 世代） | 保留（历史链） |
| `reports/droidloom-l2-phoc-syncobj-20261111.md` | phoc 补 `wlr_linux_drm_syncobj_manager_v1_create()`（L2 打通） | 有效，且**上游已自带 phoc 兼容**（见 C2 的 `b7ac285`） | 保留；加注「上游 0.1.0-49 已自带 graceful fallback」 |
| `reports/droidloom-notifications-abi-20261111.md` | 通知通道 ABI 错配假设与降级方案 | 部分被 `TASKS/G2.md` 收尾段推翻（self-heal） | 保留（历史取证） |
| `reports/artifacts/droidloom-deploy-20261126/`（8 文件） | doctor/applications/xhs/limbus 日志、tcpdump、快照 | 有效 —— **是回上游 issue 的唯一证据源** | 保留，勿下沉 |
| `reports/artifacts/c3-spic-20261115/` | SPIC 一次回包截图 | 有效（G2 C3 档案） | 保留 |
| `patches/fragment-droidloom-nftables.config` | 内核 `CONFIG_NF_TABLES` 片段 | 已不需要（在机内核算内置） | 保留（台账） |
| 设备侧（非本仓）：`/opt/dl-pkgs/*.zst`、`/usr/local/bin/unshare`、`/etc/sub{uid,gid}` 追加行、`~xuqianhui1001/.config/droidloom/{window-policy-v1,density-v1}.json(+.bak-20261126)`、`/etc/droidloom/{cell.json,runtime.env}` | 部署件与本地改动 | `unshare` shim **上游已有正解**（fork `5380af3`） | 见 D3（升级时怎么保） |

- 硬数字：本仓 droidloom 相关**报告 13 份**（`droidloom-*` 11 + `limbus-appsealing-*` 1 + `droidloom-feasibility-20261108` 计入 11 中其一），**artifacts 目录 2 个**，**内核片段 1 个**，**设备侧配置件 5 类**。
- 附带发现：`reports/README.md`（机器生成索引）把 `droidloom` 组记为 **8 篇**，与实际 ≥12 不符 ⇒ 索引已过时，需重跑 `scripts/reports-index.py`（本次不改）。

**A2. 重复与漂移（同一事实多处写、口径不一致）→ 具体改指向清单（不要自己改）**

| # | 事实 | 现状冲突 | 应改成 |
|---|---|---|---|
| 1 | cell 无网 | `droidloom-deploy §5①②`＝「未解/最大缺口」 vs `TASKS/G2.md ★11-26 晚`＝「已修好，adb 出 device」 | `deploy §5` 首行加「⛔ 已于 2026-11-26 晚修复，见 `cell-network` §8 / TASKS 晚块」 |
| 2 | 首个 cell 联网的判据 | `status-20261111 §1.2` 判据集 vs `deploy §2` doctor 13/1/0 vs `cell-network §7` 五条 | 判据唯一定义留在 `status-20261111`；其余只引用，不复制 |
| 3 | 小红书全屏 | `display-sizing §1`（dpi 213→690 + `task resize` 临时生效） vs `TASKS 晚块`（真修法 = `window-policy-v1.json` per-app 覆写，configure=1902x3039） | `display-sizing` 全文标「⛔ 修法已被 per-app 覆写取代」，唯一现役记录指向 TASKS 晚块（或本轮新版） |
| 4 | per-app 窗口能力 | `display-sizing §4`＝「不提供 per-app 全屏开关」 vs 上游 `docs/desktop-integration.md`＝`window-mode` 支持 per-app + `droidloomctl start --mode mobile` + `window-mode --package` | 我方结论作废（**这是文档误判，不是上游缺口**）；见 Contradictions #2 |
| 5 | IME 键键盘 | `ime-keyboard §0`＝「上游状态机缺陷」 vs 上游 `text-input-v1.md`（宿主缺可选扩展时"cannot report manual host dismissal"） | `ime-keyboard §0` 改为「三分支待判：① IME↔presenter JSON 桥 ② 宿主 phoc 缺 `denial_text_input_panel_manager_v1` ③ Android 侧 IME 会话」 |
| 6 | Limbus 起不来 | `app-compat-20261125`（J2：split 装不上/静态不可起） vs `deploy §4`（装得上、AppSealing 杀） vs `limbus-appsealing §9`（Root_Detection=1，非 emulator） | `app-compat` J2 行改为「见 limbus-appsealing-20261126」；「结构性不可过（emulator）」字样全删 |
| 7 | droidloom 现役版本 | `feasibility/status`（0.1.0-30 世代） vs `deploy`（0.1.0-49） | 版本号只写一处（`TASKS/G2.md` C12 行的增量子块），历史报告保留版本字样但标日期 |

**A3. 常设入口建议：`RESOURCES/droidloom-upstream.md`（稳定页）+ `reports/droidloom-upstream-lane-YYYYMMDD.md`（滚动轮次）**

- 理由：`INDEX.md` 是唯一入口且规定「7 个角度文件夹 + `sessions/`」，**没有 `reference/` 目录**（`INDEX.md` 抬头明列 7 夹）⇒ 新建 `reference/droidloom/README.md` 会破坏布局。
- 建议形态：① **稳定事实页**（上游 issue/fork 地图、我方缺陷↔issue 对照、升/降级判据）放 `RESOURCES/droidloom-upstream.md`（`RESOURCES/README.md` 已是外部资源 SSOT，正好挂 §1.x）；② **每轮分析**留 `reports/droidloom-upstream-lane-<date>.md`，只写增量与「本轮作废了哪句」；③ 两个都只在 `INDEX.md §0` 留**一行**指针（保持单入口）。

### B. 上游缺陷面（denialwm/droidloom）

**B1. 硬数字与主题聚类**

- **issue 总数 = 54**（编号 #4–#57；#1–#3 不存在）：**open 29 / closed 25**（`open_issues_count: 29` 与 open 列表两页 25+4 逐条吻合）。
- **PR 面：不可用** —— 仓库元数据 `has_pull_requests: false`（贡献入口关闭），issue 编号里也没有夹 PR 号；`/pulls` API 本次被限流（13.250.3.65 rate limit），未 100% 反证（见 Missing evidence）。
- **我方可复用的信号源**：仓库只有 `main` 一个分支，HEAD = `572e1c5`「Package release 49」（2026-11-20T14:21Z，`pushed_at` 同）；`docs/KNOWN_ISSUES.md` 仍在树内且极长（主要写 x86_64 Teto 翻译与 GApps 支线，**不含我方三项**：IME、per-app 尺寸、util-linux）。

| 主题簇 | open 条数 | issue 号 |
|---|---|---|
| 显示 / 窗口 / 输入映射 | 6 | #36（权限弹窗点击错位）、#37（键鼠映射器）、#45（app_id + `xdg_toplevel_icon_v1`）、#55（144Hz 高分辨率 direct-layer import 抖动）、#54（minigbm panfrost 后端）、#40（Mali：minigbm 无后端 ⇒ 每 5 s 重启） |
| 输入法 / 键盘 | 3 | #34（Android 键盘改空占位以适配宿主 OSK）、#43（AZERTY→QWERTY 布局漂移）、#53（点通知后 Keyboard Settings 打不开/机器风扇狂转） |
| 网络 / ADB | 2 | **#48**（虚拟 Wi-Fi 永久禁用 + DHCP DNS 硬编码）、#56（`ip failed (exit status: 1)`，i915 x86_64 起 cell 失败） |
| 应用兼容 / 运行 | 5 | #26（Hearthstone/Unity 起不来）、#12（IJM 打包 ARM 解出 x86_64 库）、#46（camera JPEG BLOB 16384 px 宽度界）、#35（闹钟/通知不触发）、#50（gapps 拒收 Build Tools 37 的 apksigner 输出） |
| GPU | 3 | #20（Mali 支持）、#44（nvidia-prolapse 内核态）、#49（NVIDIA forwarding 用错 VkInstance） |
| 打包 / 发行版 | 9 | #51（immutable 发行版安装）、#52（release 条目拆分）、#25（Fedora/Ubuntu）、#21（NixOS flake）、#18（其他发行版包）、#14（通用包格式）、#6（NixOS）、#47（Tiny GUI）、#22（无 MOVBE 的 CPU tracker） |
| 存储 | 1 | #57（shared user folder submount 覆盖 `installd mStorageMounts` ⇒ 卸载残留 34.45 GiB） |
| 音频 / 相机（其他） | 0 | —（#46 归应用兼容） |

（合计 6+3+2+5+3+9+1 = 29 ✅）

**B2. 我方现象 ↔ 上游 issue 对照表**

| # | 我方现象（本仓证据） | 上游是否已有 | 状态/日期 | 上游是否已知修法 |
|---|---|---|---|---|
| 1 | SSID `"Droidloom"` 被 `NETWORK_SELECTION_PERMANENTLY_DISABLED` 永久禁用 | **有 = #48** | open，2026-11-22，**0 评论** | **有**：`WifiProvisioning` 设 `noInternetAccessExpected=true` + 开机复查解禁；workaround（改 captive-portal URL + 手动 connect）报告者已实测 |
| 2 | `DhcpResponder` 硬编码 DNS `1.1.1.1/8.8.8.8`，校园网封校外 UDP/53 | **有 = #48 的 secondary note**（同 issue 第 3 条根因） | 同上 | **有方向**（DNS 可配/从宿主带出），且 **fork 已实现**（`EvilBorsch` `2712d37` "host resolvers in the lease"） |
| 3 | `unshare: 未识别的选项 "--forward-signals"`（Debian trixie util-linux 2.41）导致 cell 起不来 | **无 issue** | — | **fork 有代码**：`EvilBorsch` `5380af3`（"stop Android without `unshare --forward-signals`"） |
| 4 | 手机 App 只占 1440x2400，同意弹窗被截断 | **无专属 issue**；最接近 = #36（弹窗**点击错位**，非裁剪）、closed #39（默认生成 `density-v1.json`） | #36 open（2026-11-18，维护者回「无法复现，请补版本/桌面/截图」） | **代码已在动**：上游 49 含 `5ca6487`（隐藏状态栏的 App 走全屏）；**未进 main 的 `698e495`「Phone-layout apps are fullscreen tasks」**（+105/−4，5 文件，见 Contradictions #1） |
| 5 | 输入第一个字符后宿主 OSK 缩回、再也唤不出（`onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`） | **无**；#34 是这条设计的本体（"空占位 spacer"）、#43/#53 相邻 | #34 open（2026-11-18，0 评论） | **无修法**；契约层解释见 `docs/contracts/text-input-v1.md`（宿主缺 `denial_text_input_panel_manager_v1` ⇒ 无法回报 manual dismissal，但"ordinary text input 仍可用"） |
| 6 | Limbus 被 AppSealing 判 `Root_Detection=1` | **半覆盖 = closed #33**（`/system/xbin/su` 误报，release 44 起用空目录覆盖 `/system/xbin`） | closed 2026-11-18（bot 回复 + 关闭） | **已有修法且我们已在 49 上**（`a99318d` "Hide su from Android"）⇒ 我方命中项是**另一个 root 信号**（permissive SELinux / 可写系统 / `ro.debuggable`？未证），属**新信息** |

- 硬数字：**已有 issue 覆盖的我方缺陷 = 2/6**（两项都归 #48）；**fork 代码覆盖但无 issue = 1/6**（unshare）；**完全无覆盖 = 3/6**（IME、显示尺寸的一项、Limbus 的新 root 信号）。

**B3. 我们能提供的新信息 ⇒「值得回复 / 新开 issue」候选清单（只草拟，未发）**

| 候选 | 标题（草稿） | 要贴的证据 | 预期维护者关心点 |
|---|---|---|---|
| **C-1 回 #48（最高性价比）** | 追加评论：*Second independent report + a network where every off-subnet UDP/53 is dropped* | ① `dumpsys wifi` 的 `DSBLE/PERMANENTLY_DISABLED` + `firstL2ConnectionAttempt=null`；② `WifiConfigStore.xml` 的 `DisableReason`；③ `busybox nslookup`：`202.38.64.18` ✓ / `1.1.1.1 8.8.8.8 223.5.5.5 114.114.114.114` 全 timeout + TCP 853/443 BLOCKED；④ 修复后 `dumpsys connectivity` = `IS_VALIDATED` + `adb devices` = `device:droidloom`（证明 workaround 在第三张网也成立）；⑤ 79 s 复禁未再发生 | 「不是只有中国大陆 Google 被墙，**校园网把校外 53 全封**是更普遍的一类」；`noInternetAccessExpected=true` 是否仍能 VALIDATED；DNS 从宿主带出的实现形态 |
| **C-2 新 issue** | *Cell fails to start on util-linux 2.41 (Debian 13 / Ubuntu 26.04): `unshare: unrecognized option '--forward-signals'`* | ① `journalctl --user -u droidloom.service` 原文；② `unshare --version` = 2.41.5；③ 判据：`unshare --forward-signals true` 直接报错；④ 指向 `EvilBorsch` `5380af3` 的做法（不提"我们的 shim"作为解法） | 发行版兼容成本；是否愿意改为 feature-detect 而不是依赖 2.42 |
| **C-3 新 issue** | *phoc/phosh: `showSoftInput` never completes — `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`, keyboard does not return after the first commit* | ① 我方 `logcat -b all` 片段（`start input restarting=true`、`RemoteInputConnectionImpl: Session id mismatch`、`ImeTracker onFailed`）；② IME 窗口 `mViewVisibility=GONE/mHasSurface=false/frame 高 0`；③ 宿主 `phoc 0.58 + phosh-osk-stub`，`wayland-info` **无** `denial_text_input_panel_manager_v1`；④ 复现脚本 `adb shell input tap/text` + `screencap` | 是否要求在"无该扩展的合成器"下降级为"每次 show 都重新 `enable`"；`restartInput` 与 dismissal 的契约边界（`text-input-v1.md` 已写 but 未覆盖 fail 分支） |
| **C-4 回 #36（可选）** | 追加：裁剪而非错位的第二形态 | 1440x2400 freeform task 下同意弹窗被裁的截图 + `configure=2 size=1440x2400`；说明与"点击错位"不同 | 可能是同一个 per-app 尺寸问题的两种表现，帮他收敛 |
| 不建议 | 单独提「per-app 全屏缺失」 | —— | 该能力**上游文档里已有**（`window-mode --package`、`start --mode mobile`），提了会被当无效报告 |

### C. 社区分叉分析

**C1. 硬数字**

- **fork 总数 = 27**（API `forks_count`/`network_count`；注意 `github.com/.../forks` HTML 只列 **14** 个，两处不一致 → Contradictions #3）。
- **有自有提交的 fork = 3 个代码 fork + 1 个打包 fork**（其余 23 个 = 与上游同点的镜像/快照）：

| fork | 默认分支 / 分支 | 最后 push | 自有提交量 | 改了什么（top commits） |
|---|---|---|---|---|
| **`EvilBorsch/droidloom`** | `eb/main`（+`eb/ubuntu-packaging`、`eb/unshare-util-linux-2.41`、`eb/host-resolvers-clean-stop`、`eb/launch-starts-android`） | 2026-11-25T03:39Z | ≈20 提交，版本已到 `0.1.0-49+eb7` | **Debian/Ubuntu `.deb` 三包流水线**（`eb-arm64-sysroot`/`eb-build-runtime`/`eb-build-debs`，`upstream.lock` + `.MTREE` 逐文件校验，可复现）；**`unshare` 2.41 修复**；**宿主 resolver 进 DHCP lease**；`runuser` 路径修复；ready = user 0 `RUNNING_UNLOCKED`；160 dpi/scale 单位；loop 设备 udev 规则；APK 双击安装 desktop entry |
| **`Reixo0/droidloom`** | `main` | 2026-11-25T19:33Z | **41 提交**（doctorlogix 147 为基础） | 窗口策略线：**`698e495` "Phone-layout apps are fullscreen tasks"（+105/−4，含新 patch `0010-droidloom-host-turns-fullscreen-tasks.patch`）**、`946df41` "keep tasks in the host's windowing mode"、`bbf4daf` 关窗先停 App；视频线（Codec2 V4L2、direct video layer、60 Hz 让 Android 选）；通知 MPRIS/media artwork；ADB 每 30 s 检查 transport；相机 camera 0 + JPEG；NFC |
| **`dev-kenn/droidloom`** | `main` | 2026-11-19T11:18Z | ≈9 提交（且有 `Merge upstream release 47`） | 键位映射器（键鼠→触摸、鼠标视角、摇杆滚轮、profile 位置精确）＋后来**又移除**该映射器；媒体传输键映射；`droidloomctl app` + 桌面 action；launcher 排除 Terminate |
| `yigexuanmu/droidloom-nix` | `main` | 2026-11-21T14:34Z | nix flake 打包 | NixOS 支持（对应 issue #6/#21） |
| 其余 23 个（`yaxiaiyuting`、`oodzchen`、`pharra`、`clansty`、`bintis`、`starfoxdot64`、`FFT-infra`、`8749236`、`richardfrk`、`q757571446`、`Ujhhgtg`、`alderman-norta92`(droidloom-apk)…） | — | 多数 = 上游同点或早于 49 | **0** | 只读快照（`oodzchen` 顶部仍是 release 42，虽然他提了 #45/#46；`yaxiaiyuting` 顶部 = release 31） |

- 「近 3 个月有提交」= 上述 3+1 个；仓库本身 2026-09-06 才建，所以时间窗内全部 fork 都在 3 个月内，须用「是否有自有提交 + `pushed_at` 晚于上游 `572e1c5`(11-20)」来筛 —— 满足者仍是这 4 个。

**C2. 值不值得跟某个 fork：值得，**二值 = 跟（`EvilBorsch` 为主，`Reixo0` 为补）**

- **跟 `EvilBorsch`（强理由）**：它就是「我们的发行版形态」—— Debian/Ubuntu arm64 `.deb`、util-linux 2.41、宿主 DNS、ready 语义、loop 设备噪音，**逐条命中我方 3 个已踩坑中的 2 个**（shim、DNS 重定向），且工程纪律异常好（上游包 SHA-256 锁、逐文件 `.MTREE` 比对、构建可复现、程序与上游 ELF `NEEDED` 对齐）。
- **跟 `Reixo0`（中理由）**：唯一在动**窗口尺寸/全屏**这条线，正好是我方「手机 App 只占 75%」的上游对应修法；但它是宽改动（framework patch 0010），跟随成本高于我们的 per-app 配置覆写。
- **不跟 `dev-kenn`（弱理由）**：键鼠映射器与我们「平板当手机用」的目标相反（要的是触摸，不是映射）；其余 23 个 0 提交。
- **反向提醒**：两个活跃 fork 都是 "X and claude committed"（LLM 协作提交）。这既解释了 41 提交/4 天的速度，也意味着**上游 review 面极薄**（29 open issue、0 人类回复在 #48/#34 上），跟 fork 前必须自己跑判据，不能假设"已被审过"。

**C3. 我们若打补丁，最小可维护形态**

| 形态 | 评估 | 结论 |
|---|---|---|
| **A. fork 整包（`EvilBorsch`）** | 成本最低（现成 `.deb`，`upstream.lock` 锁定 49）、升级路径清晰（+ebN 递增）、能一次性消灭我方的 `unshare` shim 与 nft DNS 表 | **推荐做"候选基线"**，但先验证 Debian trixie 依赖（见 Missing） |
| **B. `patches/local/*.patch` 集合** | 我方只有一条真补丁候选（per-app 尺寸已有配置面，无需补丁）；`runtime` 包的程序要重编才能上补丁（见下） | **只在 A 不可行时用**；形态 = 3 条小 patch（unshare/runuser/host-resolvers）+ `dpkg-divert` 卫生 |
| **C. 只提交上游** | 上游**关 PR**（`has_pull_requests: false`），只能 issue/邮件；release 节奏 ~2 天/次，但 issue 回复极慢（#48/#34 零回复） | **只做 issue（B3 的 C-1/C-2）**，不指望修法落地 |

- **runtime 包重编成本（源码可得性）**：**可得且便宜**。`runtime` 只是 9 个 Rust 宿主程序 + 1 个 package-helper，`cargo build --locked --release --target aarch64-unknown-linux-gnu` 即可；`EvilBorsch` 实测 **57 s（10 job，空 target，crate 已下载）**、**第二次全清重建位相同**。`image`/`base`（AOSP：`system/system_ext/product`，~850 MiB×2）**不需要重编**（fork 原文：不经 AOSP 数 GB/数小时的构建）。
- **Arch 专用性程度 = 中等，且已被证明可绕**：① 包格式 pacman（`.pkg.tar.zst` + hooks）→ `EvilBorsch` 用 maintainer scripts 取代 hooks；② `runuser` 在 `/usr/bin` vs Debian `/usr/sbin`；③ `unshare --forward-signals` 要 2.42；④ 无 adb 依赖、无 `libwayland-server0` 声明（我方 `PITFALLS #730` 已实证）。这些**都是打包/依赖层问题，不是代码层 portability 问题** —— 这也解释了为什么 fork 只需重编 runtime 就能在 Ubuntu 26.04 跑。

### D. 结论

**D1. 「droidloom 值不值得继续投」= 只当实验（受控投入），不作 G2 主线**

| 三态 | 判据 | 我方现状 |
|---|---|---|
| 主线可用 | 输入法可用 + 常用 App 能装能跑 + 网络自助恢复 + 升级不丢本地改动 | ❌ 输入法未修；Limbus 结构性被拒；本地改动 3 处 |
| **只当实验** ✅ | 上述任一不满足，但**上游活跃 + 我方缺陷有条目化上游对应物 + 维护成本 ≤ 每轮半天** | ✅ 三条全中（release 49、3 fork、本轮缺陷 2/6 有条目） |
| 停 | 上游停摆 or 我方缺陷全为结构不可修（要改形态） | ❌ 未到（Limbus 一项接近，但 Steam 版能跑） |

- 明确**不做**的投入：不碰 AppSealing 对抗（反向工程安全层越过边界）；不为 droidloom 装 GApps 去救 Limbus（AppSealing 与 GMS 无关，`deploy §4` 已判）；不为它再改内核。
- 与 Waydroid 的关系不变：Waydroid 仍是 G2 主线（C1/C2/C3 已收口），droidloom 只提供「独立窗口 + 原生性能」这一条 Waydroid 给不了的体验。

**D2. 未来 2 周最小行动清单（每条 ≤ 半天，含验收判据）**

| # | 动作 | 验收判据 | 预算 |
|---|---|---|---|
| 1 | **回 #48**（B3 C-1 草稿 + 我方日志片段） | 评论发出（含 4 项证据），且我方 `reports/droidloom-cell-network-20261126.md` §8 记上 issue URL | 2 h |
| 2 | **试 `EvilBorsch` `0.1.0-49+eb7` deb**（或仅取其 3 patch 重编 runtime） | `dpkg -i` 后：`droidloomctl status` = Android is ready；**`/usr/local/bin/unshare` 可删且 cell 仍能起**；DHCP lease 里 DNS = 宿主 resolver（`nft list ruleset` 无 `dl_dns_redirect`） | 4 h |
| 3 | **IME 分支判定实验**（不改设备配置，只读+一次 `restart`） | 判据三选一：① `wayland-info | grep -c denial_text_input_panel` = 0 且宿主换 sway/headless 后 `showSoftInput` 成功 ⇒ 宿主扩展缺失；② 换 sway 仍失败 ⇒ 桥/IME 缺陷；③ 失败点随 `droidloomctl logs` 里 JSON 桥第一条错误变化 ⇒ presenter 侧 | 4 h |
| 4 | **把显示结论写成"配置即解"**（`window-policy-v1.json` per-app 覆写模板 + `--package` 用法） | 本仓出现一份 ≤1 页的 `reports/droidloom-display-sizing-20261126.md` 追加节或新版，含可复制的 JSON + 回退命令 | 2 h |
| 5 | 新 issue C-2（unshare 2.41） | issue 打开（附 `EvilBorsch` `5380af3` 指针，不附我方 shim 作为解） | 1 h |

（不建议本轮做：跟 `Reixo0` 的 framework patch 0010 —— 我们的 per-app 配置已解决同一问题，跟随成本 > 收益。）

**D3. 风险：本地改动在上游升级时怎么丢 / 怎么保**

| 本地改动 | 存放位置 | 升级（pacman 摊装 / deb）时的行为 | 保法 |
|---|---|---|---|
| **per-app 窗口覆写** `window-policy-v1.json` | `~xuqianhui1001/.config/droidloom/` | **不丢**（不在包内，属用户配置）；但 **root 跑 `droidloomctl` 会写 `/root/.config`**，等于静默失效 | 只用 `sudo -u xuqianhui1001` + `XDG_RUNTIME_DIR=/run/user/1001`；把该文件纳入 `deploy-desktop-shell.sh --check` 一类幂等装置 |
| **nft DNS 重定向**（`ip dl_dns_redirect` + 未来 unit） | 独立 nft 表 + `/etc/systemd/system/droidloom-dns-redirect.service` | **表本身随宿主重启消失**；若上游 fork 已实现 "host resolvers in the lease"，该 unit 可**整件删除**；若写进 `droidloom_u1001*` 表则 cell stop 时被 supervisor 删掉（必踩） | 升级前先判「lease DNS 是否已是宿主 resolver」；是 ⇒ 删 unit；否 ⇒ 保留独立表（**永不写进 supervisor 拥有的两表**） |
| **captive-portal 探针**（`settings put global captive_portal_*`） | cell 内 `/data/system/users/0/settings_global.xml` | **不丢**（在 Android data 里，包升级不动 data）；但 **`cell.json` 里若换 data 目录 / 重建 cell 就全丢** | 纳入「新 cell 首启 checklist」；用 #48 的 `noInternetAccessExpected` 落地后可撤 |
| `/usr/local/bin/unshare`（2.42 shim） | `/usr/local/bin` | **不丢**（非包文件），但会**长期遮蔽**系统 `unshare` 造成排障误判 | `EvilBorsch` 的 runtime 上来后**立即删**；删前判据：`strings /usr/bin/droidloom-supervisor | grep -c forward-signals` = 0 |
| `subuid` 追加行 300000:100000 | `/etc/sub{uid,gid}` | 不丢；`droidloom-doctor` 已不查 subuid（上游 `9e2cc27`） | 无需动作 |

---

## Contradictions

1. **`698e495` 到底在不在上游**：`https://github.com/denialwm/droidloom/commit/698e495` 能渲染（Title = "Phone-layout apps are fullscreen tasks"，Author = **Reixo0**，2026-11-20T16:19Z，+105/−4，Co-Authored-By: Claude），但 `denialwm/droidloom/branches/all` **只有 `main`**，而 `main` HEAD = `572e1c5`（11-20T14:21Z，早于该提交）⇒ 对象存在于该仓、但不在任何可见分支上。可能的解释：① Reixo0 有推送权并推过随后删除的分支；② 抓取器把 fork 页归到了 upstream 名下。**未解决**，因此本报告一律表述为「未进 release 49 / 未在 main 上」，不表述为「上游已修」。
2. **per-app 窗口能力是否存在**：我方 `droidloom-display-sizing-20261126.md §4` 写「`window-mode` 只有 fit-output / windowed 两档，无 per-app 全屏」；上游 `docs/desktop-integration.md` 写 `window-mode` **supports per-app preferences**，README 给出 `droidloomctl window-mode windowed --width 900 --height 1200 --package org.mozilla.firefox` 与 `droidloomctl start --mode mobile`。**判：我方文字错**（把"需要 `--package`"读成"没有"），但未见 49 的 `--help` 原文 ⇒ 置信度中等（见 Missing）。
3. **fork 总数**：API 元数据 `forks_count`/`network_count` = **27**，`github.com/denialwm/droidloom/forks?sort=newest` 只列 **14** 个（可能被 GitHub 的 fork 列表折叠/过滤）。本报告采用 27 为「总数」、14 为「可见集合」。
4. **弹窗问题的形态**：#36 是「点击位置与按钮错开 10–20% 屏高」（维护者无法复现），我方是「freeform 1440x2400 把同意弹窗**裁掉**」。两者不是同一现象，**不要合并**；#36 里的 DPI/字号线索与我方 dpi 213→690 的改动有交集，值得在 C-4 评论中点明但不宣称同因。

## Missing evidence

1. **PR 面未证**：`/pulls` API 本次被限流；只有仓库元数据 `has_pull_requests: false` 作为「PR 关闭」的依据。若要 100% 证，需换出口 IP 重取（或 `gh api` 带 token）。
2. **本仓文件清单不完整**：本会话无 shell（仅 read/write/web），无法 `ls reports/ scripts/ patches/`，故 A1 的清单由「任务书 + `INDEX.md` + `TASKS/G2.md` + `reports/README.md`」拼成；`patches/local/`、`scripts/` 下是否有其它 droidloom 件**未核**。`reports/README.md`（机器生成）本身也过时（`droidloom` 组记 8 篇 vs 实际 ≥12）。
3. **设备侧只读核对未做**：未登设备，因此「`/system/xbin/su` 是否已被空目录覆盖（release 44 的 `a99318d`）」「AppSealing 的具体 root 信号是哪一个」「`droidloomctl window-mode --help` 是否含 `--package`」三项**均为未验证假设**。
4. **`EvilBorsch` deb 与 Debian trixie 的兼容性未验**：其 sysroot 是 Ubuntu `resolute`（glibc 2.43、`libgbm1 26.0.8`、`libpipewire 1.6.2`、`libwayland-server0 1.24.0`），而 trixie 的这些库版本更低（glibc 2.41 满足 `GLIBC_2.39` 需求，但 `Depends` 的库版本/`libpipewire-0.3-0t64` 之类的包名差异**必须实机 `dpkg --dry-run -i` 验证**）。
5. **`Reixo0` 41 提交里是否有 IME 相关**：只读了 top ~30 条标题，未见 IME/OSK 条目；未逐条穷尽，故「无 fork 修 IME」这一结论是**基于可见标题的推断**，非穷举证明。
6. **`docs/KNOWN_ISSUES.md` 只读到前 1/3**（约 34 KB 之后被截断），除已引的「force-resizable/revision 7」「standalone APK only」「App services」外，后段（x86_64 Teto 翻译细节）未全文核。

## Sources

- **Kept**
  - `denialwm/droidloom` 仓库元数据（`/repos` JSON）— forks_count 27、open_issues 29、`has_pull_requests:false`、HEAD `572e1c5`：https://api.github.com/repos/denialwm/droidloom
  - open issues 两页（29 条逐条标题/作者/日期/评论数）：https://github.com/denialwm/droidloom/issues?q=is%3Aissue+is%3Aopen （+ `&page=2`）
  - closed issues（25 条，含 #33 与 #39）：https://github.com/denialwm/droidloom/issues?q=is%3Aissue+is%3Aclosed
  - **#48 全文**（我方无网双缺陷的同构原件 + 两条 suggested fixes + workaround 实测）：https://github.com/denialwm/droidloom/issues/48
  - **#33 全文 + bot 回复**（`/system/xbin/su` 误报 → release 44 起空目录覆盖）：https://github.com/denialwm/droidloom/issues/33
  - #36（弹窗点击错位，维护者要证据）：https://github.com/denialwm/droidloom/issues/36 ；#34（空占位键盘的设计意图）：https://github.com/denialwm/droidloom/issues/34
  - `docs/KNOWN_ISSUES.md`（main）：https://raw.githubusercontent.com/denialwm/droidloom/main/docs/KNOWN_ISSUES.md
  - `docs/desktop-integration.md`（**per-app window-mode / `--mode mobile` / `--package`**）：https://raw.githubusercontent.com/denialwm/droidloom/main/docs/desktop-integration.md
  - `docs/contracts/text-input-v1.md`（宿主 OSK 契约 + 「缺扩展则无法回报 manual dismissal」）：https://raw.githubusercontent.com/denialwm/droidloom/main/docs/contracts/text-input-v1.md
  - `docs/BUILDING.md`（打包产物、runtime vs image 重建边界、GitHub Actions 发布链）：https://raw.githubusercontent.com/denialwm/droidloom/main/docs/BUILDING.md
  - main 提交史（release 36→49、`a99318d` Hide su、`5ca6487` 全屏、`78f1c56` dpi 改窗）：https://github.com/denialwm/droidloom/commits/main
  - **`EvilBorsch/droidloom` `docs/EB-BUILD.md`**（Debian/Ubuntu `.deb` 全套、unshare 2.41 修复、host resolvers、57 s 可复现重建、`+eb7`）：https://raw.githubusercontent.com/EvilBorsch/droidloom/eb/main/docs/EB-BUILD.md
  - `EvilBorsch` 提交史（`5380af3`/`2712d37`/`201000a`/`66ef5ac`…）：https://github.com/EvilBorsch/droidloom/commits/eb/main
  - `Reixo0` 提交史（`698e495` 全屏任务、`946df41` 窗口模式、视频/通知/ADB）：https://github.com/Reixo0/droidloom/commits/main ；README（能力清单 + 命令示例）：https://github.com/Reixo0/droidloom
  - `dev-kenn` 提交史（键位映射器增删）：https://github.com/dev-kenn/droidloom/commits/main
  - forks 列表：https://github.com/denialwm/droidloom/forks?sort=newest ；`/forks` API（`pushed_at` 抽样）：https://api.github.com/repos/denialwm/droidloom/forks?sort=newest&per_page=50
  - 本仓：`reports/droidloom-deploy-20261126.md`、`reports/droidloom-cell-network-20261126.md`、`reports/droidloom-display-sizing-20261126.md`、`reports/droidloom-ime-keyboard-20261126.md`、`TASKS/G2.md`（C12 + 三个增量块）、`INDEX.md §0`、`reports/README.md`
- **Rejected/deprioritized**
  - `api.github.com/.../pulls` — 被限流，无数据（记为 Missing）
  - `denialwm/droidloom` README（main）— 与 Reixo0 fork README 内容同源，只作交叉印证，未单独引用
  - `yaxiaiyuting` / `oodzchen` / `pharra` / `clansty` 等 23 个 fork 提交页 — 顶部提交即 release 31/42 的上游提交，判「0 自有提交」，未逐页取证（记录为抽查）
  - `#53`（Keyboard Settings 通知）— 与 IME 桥无关（CachyOS 上点通知卡死），只用于确认「IME 簇里没有我方这条」
  - `docs/KNOWN_ISSUES.md` 后 2/3（Teto/ARM64 翻译 TR-001…）— 与 arm64 原生运行无关，跳过

## Next steps

1. **先做 B3-C1（回 #48）**：成本 2 h、收益最高（唯一「上游已认账 + 我方有第二张网证据」的条目）。
2. **再验 `EvilBorsch` deb**（Missing #4 的 `dpkg --dry-run -i` 前置）：若 trixie 依赖不可解，就退化为「只取 3 条 patch 重编 runtime」，并把 `/usr/local/bin/unshare` 与 nft DNS 表退役 —— 这一步直接减少我方 2 处长期本地改动。
3. **IME 三分支实验**（D2-3）：这是唯一「可能不是上游 bug 而是宿主缺扩展」的条目，结论会决定 C-3 该不该开 issue（避免像 #36 那样被"无法复现"打回）。
4. （可选）给 `INDEX.md` 的滚动入口定案：`RESOURCES/droidloom-upstream.md`（稳定事实）+ `reports/droidloom-upstream-lane-YYYYMMDD.md`（轮次）。

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "报告四个交付块齐备且逐块给硬数字：A 13 份报告/2 个 artifacts 目录 + 7 条漂移改指向清单 + 入口建议；B 上游 issue 54 条（open 29 / closed 25）+ 7 簇聚类 + 6 项我方缺陷对照（覆盖 2/6）+ 4 条 issue 候选草稿；C fork 总数 27 / 有自有提交 4 个 + 值不值得跟的二值结论 + 3 种补丁形态与 runtime 重编实测成本（57 s）；D 三态判断 + 5 条 ≤半天的行动清单（含验收判据）+ 5 类本地改动的升级风险与保法。"
    }
  ],
  "changedFiles": [
    ".pi/sessions/subagent-artifacts/outputs/de9f4bf3-9286-439d-aeb2-295969be55e3/research.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "web_fetch api.github.com/repos/denialwm/droidloom{/issues,/forks,/contents,/pulls}",
      "result": "passed",
      "summary": "仓库元数据、29 条 open issue、25 条 closed issue、docs 清单、forks 抽样取到；/pulls 被 GitHub 限流（记入 Missing）"
    },
    {
      "command": "web_fetch raw.githubusercontent.com/denialwm/droidloom/main/docs/{KNOWN_ISSUES,BUILDING,desktop-integration,contracts/text-input-v1}.md",
      "result": "passed",
      "summary": "四份上游文档原文取到；KNOWN_ISSUES 截断于约 1/3 处（已记录）"
    },
    {
      "command": "web_fetch github.com/{EvilBorsch,Reixo0,dev-kenn,yaxiaiyuting,oodzchen}/commits/<branch> + docs/EB-BUILD.md",
      "result": "passed",
      "summary": "4 个活跃 fork 的自有提交与改动面取到，其余 fork 抽查为 0 自有提交"
    }
  ],
  "validationOutput": [
    "issue 计数交叉核对：open 列表 25+4=29 与 API open_issues_count=29 一致；序号 #4–#57 共 54 条（#1–#3 不存在），closed=25 ⇒ 总 54 自洽",
    "主题簇求和校验：6+3+2+5+3+9+1 = 29 = open 总数",
    "我方缺陷覆盖数校验：6 项中 #48 覆盖 2 项（网络/DNS 为其同一 issue 的两条根因）、fork 代码覆盖 1 项（unshare）、无覆盖 3 项",
    "fork 计数双源不一致已如实并列（API 27 vs forks 页 14），未强行统一"
  ],
  "residualRisks": [
    "无 shell 工具 ⇒ 本仓 reports/scripts/patches 未能全量枚举，A1 清单可能漏项；reports/README.md 索引本身已过时（droidloom 组记 8 篇 vs 实际 ≥12）",
    "未登设备 ⇒ 「/system/xbin/su 是否已被遮蔽」「AppSealing 具体 root 信号」「droidloomctl window-mode 是否支持 --package（49 版实测）」三项为未验证假设",
    "GitHub /pulls 被限流 ⇒ 「PR 关闭」只有仓库元数据 has_pull_requests:false 单一依据",
    "commit 698e495 的归属存在未解决矛盾（能渲染在 denialwm 名下但不在 main 上），报告已按保守口径表述",
    "EvilBorsch 的 .deb 未在 Debian trixie 上验证依赖（其 sysroot 为 Ubuntu resolute），D2-2 的第一步必须先 dpkg --dry-run",
    "Reixo0 fork 41 提交仅读 top ~30 条标题 ⇒ 「无 fork 修 IME」是推断而非穷举"
  ],
  "noStagedFiles": true,
  "diffSummary": "仅新增一份研究会话产物文件（research.md），仓库既有文件零改动",
  "reviewFindings": [
    "no blockers",
    "note: 报告明确标注了「我方 display-sizing §4『无 per-app 全屏开关』为误判」——这是对本仓既有结论的纠正，需父代理决定是否据此改那份报告（本次未改）"
  ],
  "manualNotes": "本会话无 shell，故未把上游抓取原文落到 reports/artifacts/droidloom-upstream-20261126/（任务书允许但工具不具备）；文中每条结论都带可复取 URL，父代理若需原文固化可按 Sources 列表批量抓。另：若要把本文件转成 reports/droidloom-upstream-lane-20261126.md，建议直接整段拷贝（本文件即按报告体裁写）。"
}
```


---

## 父代理复核（2026-11-26T11:0xZ，独立重跑，不采信自报）

| lane 自报 | 父代理现跑（`--noproxy '*'` 直连 GitHub API） | 结论 |
|---|---|---|
| 上游 54 issue / 29 open | `GET /repos/denialwm/droidloom` ⇒ `open_issues_count=29`、`pushed_at=2026-11-20T14:21:43Z` | 一致（注意 `open_issues_count` 含 PR） |
| 27 个 fork，`EvilBorsch/droidloom` 最新活跃 | `/forks?sort=newest` 返回 **27** 条，`EvilBorsch/droidloom` `pushed_at=2026-11-25T03:39:11Z`、默认分支 **`eb/main`** | 一致 |
| EvilBorsch 自带 8–41 个自有提交、含我们两个坑的正解 | `compare/main...eb/main` ⇒ **ahead_by=24 / behind_by=0**，提交标题里逐条命中：`supervisor: stop Android without unshare --forward-signals`（= 我们 lane D 临时装 `/usr/local/bin/unshare` shim 的那个坑）、`supervisor: host resolvers in the lease, stop Android by powering it off`（= 我们 nft DNS 重定向/DHCP 硬编码 DNS 的那个坑）、`packaging: import the Ubuntu repack of release 49`（`.deb` 线） | **一致，且是最有价值的外部事实** |

**父代理裁定（同轮）**：接受 lane 的三态结论 = **继续投、但降级为「受控实验」，不作 G2 主线**。
**下一步（待用户点头再动设备）**：① 给上游 `#48` 补我方复现数据（校园网 UDP/53 全封 + 探针 204 实测）；② 评估 `EvilBorsch` 的 `.deb` 与三个 patch（`--forward-signals` / host resolvers / quick stop）能否替换我们现有的本地规避（可回退）；③ IME 那条「是否 phoc 缺 `denial_text_input_panel_manager_v1`」的对照实验。
**纪律**：本文件只出结论与清单，不改既有报告；漂移清单（§A2）由父代理按 `INDEX.md` §2 时间序逐条落地。
