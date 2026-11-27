# droidloom 上游缺陷聚类 + 社区分叉评估（D24 第二轮，主机侧，2026-11-27）

- **性质**：**纯主机侧**。未上设备（设备离线，任务书禁止）、未发任何 issue/评论、未 `git` 操作、除本文件外零改动。
- **取数**：`gh` CLI（已登录态账号，token 不落本文）走 GitHub REST/GraphQL，**取数窗口 2026-11-27T03:21:07Z–03:48:36Z**。与 11-26 首轮不同：本轮 `api.github.com` **返回 200**（首轮记录 403 rate limit），故本轮全部数字为 API 原值而非 HTML 抓取。
- **口径标签**：每条结论标 **实测**（API 原文/源码原文）/ **静态**（读源码或文档推断）/ **推断**（跨条组合，未直接取证）。
- **只读引用**：`TASKS/dim/D24.md`、`TASKS/G2.md`（11-26 三个增量块）、`reports/droidloom-{upstream-lane,cell-network,ime-keyboard,display-sizing,source-build,real-ime}-20261126.md`。
- **本轮唯一产物 = 本文件。**

---

## §0 一页结论（三个二值判断 + 硬数字）

| # | 二值判断 | 答 | 一句话依据（全部实测） |
|---|---|---|---|
| **J1** | 要不要给上游发东西（回复 / 新开）？ | **要，但只有 3 个动作**：回 `#48`、回 `#58`、新开 1 条 IME issue。其余全部「不碰」 | 33 条 open 里，我方四条缺陷**只有 1 条**有上游条目（`#48` = cell 无网双根因，逐项同构）；IME 的 `showSoftInput` 失败在**全部 62 条 issue（含 closed）正文里零命中**（本地全文 grep `showSoftInput`/`PHASE_IME`/`soft input` = 0 命中）；per-app 尺寸上游文档已有能力面（`docs/desktop-integration.md`：`window-mode` supports per-app preferences），提了即无效报告 |
| **J2** | 要不要整包跟某个 fork？ | **不要**。但**要 cherry-pick 两个 fork 的 4 处代码**（`gotakllc` 的 `WifiProvisioning` 自愈 = 我方无网主因的正解；`EvilBorsch` 的 host-resolver 进 lease / 不用 `--forward-signals` 停机 / `runuser` 路径） | 29 个 fork 中 **ahead>0 只有 10 个**，且**没有一个是「上游 + 少量」的干净形态**：`Reixo0` ahead 41 / **behind 81**、`oodzchen` `feat/fedora-desktop` ahead 16 / behind 48、`EvilBorsch` ahead 24 / behind 20（24 条里 9 条是 packaging/docs/tools）。整包跟 = 立刻背上一个 rebase 债 |
| **J3** | 现役 `0.1.0-49` 该不该升到 `0.1.0-51` 再判 IME？ | **该，且「先升再判」是硬前置**（不升，IME 主因实验无效） | 上游 `main` = `4df8af9 Package release 51`（2026-11-26T18:22:36Z），比 49 多 **20 个提交**；其中 release 50 有 **5 个提交直接改 IME/键盘路径**（`b04e72ad` Android apps lay out around Denial's on-screen keyboard、`2199b372` Negotiate the keyboard inset…、`4c2944b3`/`1656e4e3`/`08b1560c`/`723372aa4` 宿主键盘布局线），新增 `TaskAction::KeyboardInset` + framework `Type.ime()` insets 源 ⇒ 我方复现所依赖的「宿主挪窗 / IME 不显示窗口」语义已变 |

**硬数字（本轮实测，11-26 首轮值列在后作对账）**

| 项 | 本轮（11-27T03:2xZ） | 首轮（11-26） | 差 |
|---|---|---|---|
| 上游 `open_issues_count` | **33** | 29 | +4（`#55/#56/#57/#58/#60/#62/#63` 新进，`#59/#61` 已关） |
| issue 总数 / open / closed | **62 / 33 / 29**（编号 `#1–#63`，`#3` 不存在） | 54 / 29 / 25 | +8 |
| open 中**零评论** | **21 / 33**（含 `#48` `#34` `#43`） | 未统计 | — |
| fork 总数 | **29** | 27（API）/14（HTML） | +2；HTML/fork 折叠口径不再需要 |
| `ahead>0` 的 fork | **10 个**（+`oodzchen` main 0 ahead 但 5 个分支有码） | 判为 4 个 | 修正 |
| 上游 HEAD / 版本 | `4df8af9` = **0.1.0-51**（11-26T18:22Z） | `572e1c5` = 0.1.0-49 | **现役落后 2 个包版本 / 20 提交** |
| 我方四条缺陷被上游条目覆盖 | **1/4**（仅 cell 无网 = `#48`） | 2/6 | 口径改为「四条已定因」 |
| 「`denial_text_input_panel_manager_v1` 缺失」假说 | **被否证**（该接口不存在） | 列为候选主因 | 更正 |

---

## §1 与 11-26 首轮的对账：本轮作废 / 更正了什么

| # | 首轮结论 | 本轮证据 | 处置 |
|---|---|---|---|
| 1 | 候选主因「宿主合成器缺 `denial_text_input_panel_manager_v1`」（判据 = `wayland-info \| grep -c denial_text_input_panel`） | `docs/contracts/text-input-v1.md`（main，实测）首段：*"Droidloom uses the compositor's ordinary **`zwp_text_input_v3`** interface … **Denial needs no changes**."* 全仓无该 `denial_text_input_panel_manager_v1` 接口 | ⛔ **作废**。判据要换成 `wayland-info | grep -c zwp_text_input_v3` + 宿主 `droidloom-wayland` 的 presenter 侧日志；phoc/phosh 只要广告 text-input-v3 就在支持面内 |
| 2 | 「PR 面不可用（API 被限流），只有 `has_pull_requests:false` 单一依据」 | 本轮 `GET /repos/denialwm/droidloom` = 200，`has_pull_requests:false` 复现；`oodzchen`/`EvilBorsch`/`Sun-Monolog` 三条 issue 正文都写「**Pull requests are closed during the beta**」并给出 cherry-pick 分支 | ✅ 由「未证」升级为 **实测 + 三方口供一致**：贡献入口=issue/邮件，外部 PR 明确关闭 |
| 3 | 「`698e495` 到底在不在上游」矛盾（能在 denialwm 名下渲染但不在 main） | `compare/main...Reixo0:droidloom:main` 的 41 条 ahead 里含 `698e495 Phone-layout apps are fullscreen tasks`（作者 Reixo0，11-20T16:19Z） | ✅ **矛盾解除**：它是 `Reixo0` fork 的提交（GitHub 网络视图可在上游 URL 渲染）。表述仍为「**未进 main**」 |
| 4 | 「`oodzchen` 顶部 = release 42 ⇒ 0 自有提交」 | `oodzchen/droidloom` 有 5 个分支：`pr/host-selinux-kernel-config`(ahead 2)、`pr/fedora-rpm-packaging`(1)、`pr/wayland-toplevel-icon`(1)、`pr/camera-blob-write`(1)、**`feat/fedora-desktop`(ahead 16 / behind 48，pushed 11-26T05:27Z)**；`#25` 里他贴的两条分支已被 `enYao39`、`LuanVSO` 两人复现（后者报 `droidloom-base` 拆包导致起不来） | ⛔ **作废**。oodzchen 是**第二活跃**的外部代码源，此前漏判 |
| 5 | 「fork 总数 27 / forks 页只列 14，取 27」 | `forks_count`=`network_count`=**29**，`/forks?per_page=100` 返回 **29 条**（逐条 `ahead/behind` 已算） | ✅ 统一为 **29**，27 是当时的真值（两天里 +2） |
| 6 | 「跟 fork 前不能假设已被审过；上游 review 面极薄（#48/#34 零回复）」 | 现状：`#48` 打开 **5 天零回复**、`#34` 9 天零回复；但 `#21/#26/#35/#36` 有 `synthia-si[bot]` 长回复（= 维护者代持），`#22` 有 `doctorlogix` 本人回复；`#60/#62/#61` **由 bot 从 Discord 代开** | 修正为：**「回复有选择」**——能复现/能定层的会由 bot 在 1–4 天内长答；带大段源码取证但维护者无法复现的（`#48` `#34`）会沉默。这条直接决定 §4 草稿的写法 |
| 7 | 「最有价值外部事实 = `EvilBorsch` 命中我方 2 个本地规避」 | 仍成立（`5380af3`、`2712d37`、`201000a` 实测在 `eb/main`/`upstream-pr`，24 条 ahead）。但**被更强的事实超过**：见 §5.2 | 保留但降级 |
| 8 | 首轮行动 5「新 issue：unshare 2.41」 | `EvilBorsch` 已于 **11-26T13:17Z 用 `#58` 覆盖了同一条**（`runuser` + `--forward-signals`），且 `search/code repo:denialwm/droidloom "forward-signals"` 在 main 命中 `runtime/droidloom-supervisor/src/development.rs:493` ⇒ **上游至今仍需 util-linux ≥2.42** | ⛔ 改为 **回 `#58`**（补 Debian trixie 2.41.5 第二个发行版数据点），不再新开 |

---

## §2 上游 open issue 内容级聚类（33 条 → 8 簇）

> 聚类口径 = **正文里的失效层与失效机制**（读过 33 条全文正文，非标题匹配）。簇和 = 33 ✅

| 簇 | 条数 | issue | 内容共性（不是标题罗列） | 我方相关性 |
|---|---|---|---|---|
| **C1 图形后端 / 缓冲池** | 8 | `#63` `#62` `#55` `#54` `#49` `#44` `#40` `#20` | 三条独立机制：① **minigbm 无对应后端**（Mali/panfrost `#40/#54`，`#62` 要求按宿主 GPU 选后端）⇒ SurfaceFlinger 起不来或退化；② **缓冲池容量与 BLAST 队列不匹配**（`#55`：面板 `3048×2032`@144 Hz，patch `0029` 给 `getMaxAcquiredBufferCountForRefreshRate` +1 ⇒ **5 缓冲**，而 `0018 import-retention` 的 `kSparesPerLayer=3`/`kSpareBytes=96 MiB` 只有 4 槽 ⇒ **每帧 100% miss**）；③ 转发层句柄/格式错（`#49` 用错 `VkInstance`、`#63` AMD GFX10+ YV12 chroma stride） | Adreno 不命中 ①③；**`#55` 值得盯**：我方刚把小红书拉到 `configure=1902x3039` 全屏，面板同为高分辨率 ⇒ 同一条 5-vs-4 判据的适用面**可能**已成立（**推断**，未取证：需要 `droidloomctl logs` 里的 import miss 计数）。我方 Adreno 无任何 perf 基线 |
| **C2 打包 / 发行版 / 工具链** | 11 | `#58` `#51` `#52` `#25` `#18` `#14` `#21` `#6` `#47` `#22` `#50` | 唯一真问题 = **上游只发 Arch pacman、且所有版本挤在同一个 release entry**（`#52`）：于是每条发行版线都得自己造打包层（Nix `#6/#21`、Fedora RPM `#25`、Ubuntu deb `#58`、immutable `#51`、appimage `#14`、Tiny GUI `#47`），而 `#22` 是硬形态限制（Google Cuttlefish 镜像为 Silvermont 编译 ⇒ 无 MOVBE 的 x86_64 CPU 永远起不来；维护者已答「自建 plain x86-64 系统半，但未排期」） | **强相关**：我方 = Debian/Mobian aarch64，正是 `#25/#58` 的人群；`#58` 与本机几乎同构（arm64 平板 + 非 Arch + 上游包）。`#50`/`#22` 与 arm64 原生无关 |
| **C3 输入法 / 键盘** | 3 | `#34` `#43` `#53` | 共同前提 = **Android 侧不画键盘**（`#34`：「make android keyboard an empty spacer so apps fit to actual OSK」），派生三类后果：**让位**（`#34`，release 50 已用 `Type.ime()` insets 源解决）、**布局漂移**（`#43` AZERTY→QWERTY，release 50 的 subtype/`0010-…host-keyboard-notification.patch` 线已解决）、**设置入口**（`#53`：点通知后 5 分钟无输出 + 机器变响 = CPU 满载，CachyOS，正文无日志） | **我方那条（`showSoftInput` 失败后唤不回）在这 3 条里不存在**。全 62 条 issue 正文 grep `showSoftInput` / `PHASE_IME` / `soft input` = **0 命中** ⇒ 空缺成立（实测）。`#43` 与 `#34` 已被 release 50 覆盖 = 我方「先升 51 再判」的依据（J3） |
| **C4 网络 / 存储持久态** | 2 | `#48` `#57` | 共性 = **cell 的单点状态一旦落盘错误就跨重启**：`#48` = `WifiConfigManager` 把 SSID 判成 `NO_INTERNET_PERMANENT` 并写进 `WifiConfigStore`，而 `WifiProvisioning` 用一次性 `wifi_provisioned` 位、复查永不发生；`#57` = `share_user_folders` 的 5 个 idmapped submount 让 `installd mStorageMounts` 被覆盖 ⇒ 卸载残留 34.45 GiB | **`#48` = 我方无网主因的同构原件**（逐项同因，见 §3）。`#57` 我方未开 `share_user_folders`（未取证） |
| **C5 起停 / 宿主兼容** | 1 | `#56` | `ip failed (exit status: 1)` + `droidloom.service` control process 退出（Arch i915）；**报告者自己 11-26 回「Got itself corrected on a restart」** ⇒ 无根因、已失焦 | 不同因（我方起停问题的正解在 `#58`/`EvilBorsch`） |
| **C6 应用兼容** | 5 | `#26` `#12` `#46` `#35` `#37` | 共性 = **App 对形态的假设与 cell 不符**：Unity 6 URP 的 D24_S8/MSAA（`#26`，bot 已给 `-force-gles` 与 Unity 6000.1.0a5 修法）、爱加密 IJM 解出 x86_64 库（`#12`）、Camera2 BLOB 走 minigbm 被 16384 宽度界挡（`#46`）、通知/闹钟（`#35`，bot 反问后报告者未回）、键鼠映射器（`#37`，第二人附议并要求对齐 waydroid-helper/XtMapper） | `#46`/`#35` 与小红书/相机线相邻；`#12` 与 Limbus 的加壳层是**同一族**（但我们的杀手是 AppSealing `Root_Detection=1`，另一层） |
| **C7 桌面集成 / 窗口标识** | 2 | `#45` `#36` | 共性 = **窗口身份与命中区**：`#45` 要求 `app_id` 对齐 `.desktop` + `xdg_toplevel_icon_v1`（oodzchen 已给 `845c268`）；`#36` 权限弹窗点击落点比按钮低 10–20% 屏高（报告者自陈改过 Android 字号缩放 + Denial App 尺寸缩放；维护者多 DPI/字号**无法复现**，要版本/DE/截图） | 与「弹窗被裁」**不是同一现象**（我方是 freeform 1440x2400 把弹窗裁掉，不是点击错位）。**不合并**；`#36` 里的 DPI/字号线索与我方 `dpi 213→690` 有交集 ⇒ 若要提尺寸类问题，必须把「configure 尺寸」与「命中偏移」分开写 |
| **C8 外设直通** | 1 | `#60` | bot 从 Discord 代开：有人本地做了手柄直通，缺机型/版本/日志 | 无关 |

**簇级二值判断（内容级）**：33 条里**属于我方四条缺陷射程的只有 `#48`（+ `#34` 作为设计前提）**；其余 31 条与四条无因果交集（Adreno GPU 簇、发行版打包簇、外设簇、应用兼容簇）。⇒ 「上游 bug 多」不等于「上游 bug 都是我们的」，第一轮把 6 项摊成对照的做法在本轮收敛为 4 项。

---

## §3 我方四条已定因缺陷 ↔ 上游条目对照表

> 「同因」判据 = **失效层 + 机制**是否一致，不是现象像。「最近活动」= `updated_at`（实测）。三态建议**只草拟，不清发**。

### 缺陷 1 — cell 无网（SSID 永久禁用 + DHCP 硬编码 DNS）〔我方 §`cell-network-20261126` 已定因〕

| 上游条目 | 标题（正文摘要） | 状态 / 最近活动 | 与我方同因？ | 三态建议 |
|---|---|---|---|---|
| **`#48`** wt-5783 | *Virtual Wi-Fi "Droidloom" gets permanently disabled on captive-portal validation failure…*（根因 1 = `WifiProvisioning` 一次性位；根因 2 = AOSP 默认 `www.google.com` 探针；**secondary note = `DhcpResponder` 硬编码 `dns:[1.1.1.1,8.8.8.8]`，报告者也在校园网遇到 UDP/53 被丢**） | open，**0 评论**，`updated 2026-11-22T12:33:38Z`（沉默 5 天） | **同因（主因 ①）**：同一条 `NETWORK_SELECTION_DISABLED_NO_INTERNET_PERMANENT` 落盘 + 同一段 `Ignoring network selection disabled SSID`；**部分同因（②）**：他也命中校园网 53 封锁，但**没有 DoT/DoH 与「只有校内 resolver 可达」这一层量化** | **值得回复**（最高性价比；草稿 §4-C1） |
| **`#58`** EvilBorsch | *Droidloom on Ubuntu 26.04 arm64 (OnePlus Pad 3): findings and fixes*（正文含「**the host's DNS resolvers are passed into the lease**」+ cherry-pick 分支 `upstream-pr`） | open，0 评论，`updated 2026-11-26T13:17:27Z` | **同因（次因 ②）**，且**已给出可编译的实现**（`eb/main` 的 `dhcp_responder.rs` 里 `Resolvers` 结构 + DHCP OPTION_DNS 变长，实测读到源码） | **值得回复**（把我的修复结果挂到「lease 带宿主 resolver」这条实现上，草稿 §4-C2） |
| `#57` | 共享文件夹 submount 覆盖 `installd mStorageMounts` | open 0 评论 | 否 | 不碰 |
| `#56` | `ip failed (exit status: 1)` | open，报告者自答「重启自愈」 | 否 | 不碰 |

**本轮新增的关键外部事实（实测，对 J1/J2 影响最大）**：`gotakllc/droidloom@4e995f2ae`「Add native windowing and robust ATAK integration」中，**`WifiProvisioning.java` +64/−23** 把一次性 `wifi_provisioned` 位**整段删掉**，改成 `NETWORK_STATE_CHANGED`/`WIFI_STATE_CHANGED` 监听 + `enableNetwork(networkId, **true**)` + `reconnect()` + 「已 COMPLETED 则不重做」，注释原文：*"a one-shot 'provisioned' bit is not sufficient"* / *"Passing false merely marks it enabled and can leave a restored cell disconnected forever"*。该提交 **author = `doctorlogix`（doctor.logix@gmail.com）= 上游维护者本人**，committer = `mdelsalto`，日期 **2026-11-26T20:07:17Z**，**晚于上游 HEAD（18:22Z）⇒ `#48` 的主因修法已存在于 fork，但尚未进 `main`**（`main` 的 `WP49` 版仍 `if (preferences.getBoolean(DONE,false)) return;` + `enableNetwork(networkId,false)`，实测）。
⇒ 含义：我方 `#48` 评论**不必再论证「该怎么修」**（维护者显然已经动手），价值改在**「同一失效在第 3 类网络（校园网：探针可达但仅校内 resolver 可用）也成立 + 已验证 workaround 的持久性」**。

### 缺陷 2 — per-app 窗口覆写 / 手机 App 不满屏（task bounds 被原样当 Wayland 窗口尺寸）〔我方 §`display-sizing-20261126` + 11-26 晚 per-app 覆写〕

| 上游条目 | 内容 | 状态 / 最近活动 | 同因？ | 三态建议 |
|---|---|---|---|---|
| `#36` Gibbz | 权限弹窗**点击落点**低于按钮 10–20% 屏高（自陈改过 Android 字号缩放 + Denial App 尺寸缩放） | open，1 评论（11-20 bot：**无法复现**，要 `pacman -Qs droidloom`/DE/设备/桌面或移动模式/截图） | **否**（我方是 `configure=1 size=480x800 → configure=2 size=1440x2400` 的**几何裁剪**，命中区没有偏） | **不碰**（合并会污染两条线索；若要提，按 bot 要的 4 项格式单独成条） |
| `#45` oodzchen | `app_id` 用包名 + 缺 `xdg_toplevel_icon_v1` ⇒ 任务栏匹配不上 | open 0 评论（分支 `845c268` 已备） | 否 | 不碰 |
| `#61`（closed 11-26） | XWayland 全屏请求被顶栏压住（bot 代开，报告者有本地全屏 patch） | **closed 2026-11-26T15:42Z** | 否（XWayland 层，不是 Android task 层） | 不碰（可作为「维护者会接受外部本地 patch 并当轮关闭」的先例引用） |
| `#55` wt-5783 | 144 Hz 高分辨率下 **5 缓冲 vs `kSparesPerLayer=3` ⇒ 每帧 100% import miss** | open 0 评论（11-24） | **可能是「全屏修好之后」的新因**（同一判据公式，面板不同）——**未取证** | **暂不碰**；先按 §6-A5 的判据测我方是否有 import miss，命中再回（第二条候选回复） |
| **无条目** | 「手机档 App 默认被给 1440x2400 的 freeform 窗口、`window-policy-v1.json` 的 per-app 覆写是设计内能力」 | `docs/desktop-integration.md`（main，实测）：*"`window-mode` supports per-app preferences"*、`droidloomctl start --mode mobile`；`Reixo0` 另有 `698e495 Phone-layout apps are fullscreen tasks`（**未进 main**，含 framework patch `0010-…fullscreen-tasks`） | — | **不碰**（能力已文档化 ⇒ 提「缺失」必被打回；`Reixo0` 那条是**策略改动**而非缺陷，跟随成本 > 我方一条 JSON 覆写） |

### 缺陷 3 — 占位 IME `showSoftInput` 失败（输一个字符后键盘缩回、再也唤不出）〔我方 §`ime-keyboard-20261126`，已用 Fossify 绕行〕

| 上游条目 | 内容 | 状态 / 最近活动 | 同因？ | 三态建议 |
|---|---|---|---|---|
| `#34` Gibbz | *Make android keyboard empty spacer so apps fit to actual OSK*（**设计前提**：Android 不出键盘窗、App 不随键盘 resize） | open **0 评论**，`updated 2026-11-18`（沉默 9 天） | **部分是**：同一条前提（`onEvaluateInputViewShown=false`、无 IME 窗口），但**他要的是 resize**，我方坏的是 **show 会话不可恢复**。release 50 已用 `Type.ime()` insets 源满足 `#34` 的诉求 | **不碰 `#34`**（会让两条诉求混在一条）；只在 IME 新 issue 里引用它作为设计依据 |
| `#43` TessertRavery | AZERTY→QWERTY 漂移 | open 0 评论（11-20） | 否（布局 ≠ 会话） | 不碰（**已被 release 50 的 subtype 线处理**，升级后可验证） |
| `#53` charbguy | *Not Opening Keyboard Settings*：点通知后电脑变响、5 分钟无输出（CachyOS） | open 0 评论（11-24） | **不确定**（正文只有 2 句、无日志/无版本；我方无同类现象） | 不碰（信息量不足） |
| **无条目** | `showSoftInput` 永远 `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` + `RemoteInputConnectionImpl: Session id mismatch` | **全 62 条 issue 零命中**（实测 grep） | 我方独有复现 | **应新开 issue**（草稿 §4-C3）——但**必须先把版本升到 51 再复现一次**（J3），否则维护者一句「reproduce on release 51」就打回，`#36` 是现成的反例 |

**静态补充（读 release 51 源码，不是猜测）**：`HostInputMethod.onShowInputRequested()` 在 **49 与 51 都 `return false`**（实测两版原文），且 `onEvaluateInputViewShown()` 恒 `false` ⇒ 「IME 无窗口 → 无法把 shown 报回 IMMS」是**设计后果**；51 相对 49 的 IME 增量全在**布局跟随**与 **inset 协商**（`compare` 里 `droidloom-ime` 仅 `HostInputMethod.java +64/−0`，全是 subtype/layout），**没有任何一行改 show/dismiss 状态机** ⇒ 「升级到 51 就能修好键盘」= **不成立（静态）**，但「升级后 `Type.ime()` 源生效会改变 App 的 resize 行为，从而改变复现形态」= 需要重测（实测待做）。

### 缺陷 4 — 性能〔**我方未定因、未取证**〕

| 上游条目 | 内容 | 状态 | 同因？ | 三态建议 |
|---|---|---|---|---|
| `#55` | 5 缓冲 vs 4 槽 LRU ⇒ **每帧 100% import miss**（含可复算的 24.6 MiB/缓冲、96 MiB 上限） | open 0 评论 | **未知**：我方零 perf 基线。仓库内唯一沾边的量化是 11-11 那次通知通道紧循环（1919 次 / 2 s，后自愈）与 `doctor` 的 WARN，**都不构成性能定因** | **不碰**；先按 §6-A5 建基线（半天，需设备）|
| `#44` `#49` `#40` `#20` `#54` `#63` `#62` | GPU 侧（NVIDIA 内核态转发 / 错 VkInstance / Mali 无 minigbm 后端 / AMD YV12 stride） | open | **否**（我方 Adreno + Freedreno/原生 Mesa，`droidloomctl start` 已报 `graphics: native Drm`） | 不碰 |

> **诚实标注**：任务书把「性能」列为我方四条已定因之一，但**本仓可查证据里它没有定因件**（`reports/droidloom-*` 全文 grep `性能|帧率|fps|卡顿|发热|功耗` 只命中 AppSealing 那条无关行）。故本行按「**未取证**」处理，不引用社区传言，也不提 issue。

---

## §4 对上游的文字（**只草拟，不清发**；未建 issue、未发评论）

> 写法依据 §1-6 的实测口径：**维护者只回「能复现 / 能定层」的条目**（`#21/#26/#35/#36` 的 bot 长答 vs `#48/#34` 的沉默）⇒ 每条都以「可复制的判据 + 版本/设备/日志」开头，不写情绪、不写「请尽快」。

**C-1 追加到 `#48`（优先级最高）**
> Third independent report — and a network where the probe URLs **do** answer, so `noInternetAccessExpected` alone is not the whole story.
> Device `Lenovo Legion Y700 Gen4` (aarch64, Debian/Mobian, phoc 0.58 + my own syncobj patch), `droidloom-{runtime,image,base} 0.1.0-49`.
> 1. Same persisted state: `dumpsys wifi` → `- DSBLE ID: 0 SSID: "Droidloom"`, `firstL2ConnectionAttempt=null`, every scan logs `Ignoring network selection disabled SSID: "Droidloom"`; `/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml` → `SelectionStatus=NETWORK_SELECTION_PERMANENTLY_DISABLED`, `DisableReason=NETWORK_SELECTION_DISABLED_NO_INTERNET_PERMANENT`, `CreatorUid=10072(systemui)`, `hasEverConnected:true / hasEverValidatedInternetAccess:false`.
> 2. Here the host reaches **all three** AOSP probes fine **today** (`connectivitycheck.gstatic.com`, `www.google.com`, `wifi.vivo.com.cn` all return 204) — the disable was captured in an earlier session and survives reboot, so the cell can be permanently offline while the host is perfectly online. This matches your root cause 1 exactly: nothing ever re-checks.
> 3. Root cause 2 is worse here than "1.1.1.1 is intercepted": this campus network forwards UDP/53 **only to the on-campus resolver**. Measured from the host: `busybox nslookup <domain> 202.38.64.18` → OK; `1.1.1.1 / 8.8.8.8 / 223.5.5.5 / 114.114.114.114` → `connection timed out`; TCP `8.8.8.8:853`, `223.5.5.5:853/443` → blocked. So even with the SSID re-enabled and `noInternetAccessExpected=true`, the lease's hardcoded DNS makes every app-side lookup fail.
> 4. What restored it, in your order (DNS first, then re-enable), all reversible: (a) point the probes at a reachable 204 (`cmd settings put global captive_portal_{http,https,fallback}_url http(s)://wifi.vivo.com.cn/generate_204` — note `connect.rom.miui.com` answers 200 here and is treated as a portal); (b) a **separate** nft table (`ip dl_dns_redirect`, prerouting `iifname dlh1001 ip saddr 10.177.0.2 udp dport 53 dnat to <campus resolver>`) — separate, because rules added to `droidloom_u1001*` are deleted by the supervisor on cell stop; (c) `cmd wifi connect-network "Droidloom" open`. Result: `wlan0 10.177.0.2/30`, `dumpsys connectivity` → `Active default network: 100 … IS_VALIDATED`, host `adb devices -l` → `10.177.0.2:5555 device … device:droidloom`, and the +79 s re-disable did not recur.
> 5. **Both fixes are already written and I did not need to invent anything** — `EvilBorsch/droidloom@2712d37` puts the host's resolvers in the lease (which makes (b) unnecessary), and I saw the Wi-Fi half reworked as a self-healing watcher in `gotakllc/droidloom@4e995f2`. Two asks: make the lease carry host resolvers (or make it configurable in `cell.json`), and have `WifiProvisioning` re-enable a saved-but-disabled `"Droidloom"` on `NETWORK_STATE_CHANGED`.
> 6. Caveat worth documenting: **none of (a)–(c) survives a reboot of the host** — the nft table is gone and `graphical-session.target` may not pull `droidloom.service` up at all. Measured after a reboot: `nft list ruleset | grep -c dl_dns_redirect` = 0, `journalctl -b | grep -c droidloom` = 0.

**C-2 追加到 `#58`**
> Second distro with the same two blockers, on the same class of hardware (Lenovo Y700 Gen4 tablet, aarch64, **Debian 13/trixie**, phoc compositor): `unshare: unrecognized option "--forward-signals"` from util-linux **2.41.5** — `unshare --forward-signals true` reproduces it standalone, and `search/code "forward-signals"` still points at `runtime/droidloom-supervisor/src/development.rs:493` on `main` (`0.1.0-51`). We worked around it with a `/usr/local/bin/unshare` shim, which is exactly the kind of long-lived shadow we'd rather delete; a feature-detect (`--help | grep forward-signals`) would let us. `runuser` in `/usr/sbin` bit us the same way. Also confirming your host-resolver-in-lease point from a network where hardcoded `1.1.1.1` is not merely intercepted but unroutable — details in my `#48` comment; `2712d37` is the shape we'd ship.

**C-3 新开 issue（升级后再发）**
> Title: *Headless IME: `showSoftInput` never completes — `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`, panel does not come back after the first commit*
> Body must contain（缺一不可，按 `#36` 被打回的原因补齐）：版本（**release 51** 重跑；若 49 也复现则两个版本都列）、设备（Y700 Gen4 / phoc 0.58 / phosh-osk-stub）、桌面或移动模式、`logcat -b all` 片段（`start input restarting=true`、`RemoteInputConnectionImpl: Session id mismatch header.sessionId: 0 currentSessionId: 1`、`ImeTracker onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`）、`dumpsys input_method` 里 `mViewVisibility=GONE / mHasSurface=false / frame 高 0` 与宿主 `sm.puri.OSK0` 的 `Visible=false` 同时成立、以及**无人复现脚本**：`adb -s device:droidloom shell input tap <x y>` → `input text 3` → 再 tap → `exec-out screencap -p`。
> Framing（静态依据）：`onShowInputRequested()` returns `false` on purpose and `onEvaluateInputViewShown()` is `false`, so Android can never report "shown"; `text-input-v1.md` says show requests should refresh editor state *with a Wayland commit, not another `enable`*, and dismissal must survive a `restartInput`. Here the **second** show request on the *same still-focused editor* fails, and `session` has already been bumped ⇒ question for you: which side is expected to re-arm `EditorVisibility` when the compositor's `zwp_text_input_v3` session is still alive but Android bumped `session` in `onStartInput(restarting=true)`?
> **注意**：`zwp_text_input_v3` 是契约里写明的普通接口（*"Denial needs no changes"*），**不要**写成「缺 `denial_text_input_panel_manager_v1`」（该接口不存在，会当场失分）。

**C-4 明确不提（三条）**
1. 不提「per-app 全屏/尺寸缺失」——`docs/desktop-integration.md` 已写 `window-mode` per-app + `start --mode mobile`，我方已用 `window-policy-v1.json` 解掉。
2. 不提「unshare 2.41 新 issue」——`#58` 已占，改为 C-2 追加。
3. 不提性能——无本地数据（§3 缺陷 4）。

---

## §5 forks 现查 + 「跟不跟」裁决 + 最小可维护形态

### 5.1 全量（29 个 fork，`compare` 逐条算 ahead/behind，实测）

| fork | 默认/关键分支 | pushed | ahead / behind（vs `main`=rel51） | 改了什么（正文级，不是标题） | 跟不跟 |
|---|---|---|---|---|---|
| **`EvilBorsch/droidloom`** | `eb/main`（+ `upstream-pr`、`eb/ubuntu-packaging`、`eb/unshare-util-linux-2.41`、`eb/host-resolvers-clean-stop`、`eb/launch-starts-android`、`eb/android-setup`、`eb/one-scale`） | **11-26T13:15Z** | **24 / 20**（`upstream-pr` 与 `eb/main` **同一组 24 条**） | 24 条里 **9 条是 packaging/docs/tools**（`packaging/eb-ubuntu/**` 617 行、`tools/eb-{arm64-sysroot,build-runtime,build-debs}` 512 行、`docs/EB-BUILD.md` 358 行）；真代码 = `dhcp_responder.rs +57/−22`（**宿主 resolver 进 lease**，`Resolvers` + 变长 OPTION_DNS）、`development.rs`（不用 `--forward-signals`、poweroff 停机、launch 按需启动、ready=user0 unlocked）、`droidloomctl.rs +300/−38`、`control.rs +179/−7`、**新增 `on_demand.rs` 398 行**、`density.rs`（160 dpi/单位 scale）、`applications/lib.rs +138/−1`。**无 release/无已发布 `.deb` 资产**（实测 `releases` 为空） | **跟（cherry-pick 级）** |
| **`gotakllc/droidloom`** | `main` | **11-26T20:17Z** | **1 / 0** | 单条 `4e995f2 Add native windowing and robust ATAK integration`（26 文件），**author = `doctorlogix` 本人**：`WifiProvisioning.java +64/−23`（**`#48` 主因的正解**，见 §3）、`libdecor.rs +267`（SSD）、`titles.rs +86/−7`、`multicast_relay.rs +164`（新）、`development_network.rs +107/−1`、`window-policy/src/lib.rs +111/−5`、`packaging/debian/*`（9 个文件 = 有人在做 Debian 化）、`droidloom-doctor +86` | **跟（只取 `WifiProvisioning` 与 `development_network`/`multicast_relay` 作参考）** |
| `oodzchen/droidloom` | `main`(0/48) + 5 分支 | 11-26T05:27Z | 分支 `pr/host-selinux-kernel-config` **2/20**、`pr/fedora-rpm-packaging` **1/20**、`pr/wayland-toplevel-icon` **1/20**、`pr/camera-blob-write` **1/48**、**`feat/fedora-desktop` 16/48** | 小分支＝SELinux `bpffs` 放宽 + `/proc/config.gz` 缺失回落、Fedora RPM、`xdg_toplevel_icon_v1`、Camera BLOB 绕过 2D 尺寸校验；大分支＝服务端装饰/滚动/鼠标导航 + **`host/bridge/offline` 三种网络模式 + `hostnet_shim.c` 582 行 + identity + dhcp 改动（≈2 000 行）** + 桌面设置 GUI + Plasma 修复 | **暂不跟**（`feat/fedora-desktop` 形态太宽；`pr/camera-blob-write` 等相机阶段再取；`pr/host-selinux-kernel-config` 我方 11-25 已实测判定「本机不需要」） |
| `Reixo0/droidloom` | `main` | 11-25T19:33Z | **41 / 81** | 视频线（Codec2 V4L2、direct video layer、60 Hz 交给 Android）、相机/NFC/传感器/定位/麦克风、通知→MPRIS/媒体封面、窗口线（**`698e495` 手机档 App 走全屏 task**、`946df41` 保持宿主窗口模式、`bbf4daf` 关窗先停 App）、ADB 30 s 探活 | **不跟**（behind 81；与上游 rel50/51 有 **19/123** 文件重叠 ⇒ rebase 债最重；且其 `698e495` 是策略改动，我方一条 per-app JSON 已覆盖同需求） |
| `yigexuanmu/droidloom-nix` | `main` / `nvidia-video-nvk` | 11-21T14:34Z | **7 / 20** · **13 / 20** | Nix flake + NOS 模块（含 `system_heap` 加载、Vulkan loader 注入）；另一支做 NVIDIA Vulkan Video（NVK over RM、H.264 Codec2 引擎，仍停在 GPU fault 调试） | 不跟（非我方发行版、非 Adreno） |
| `dev-kenn/droidloom` | `main`（+ `keymapper-kenn` 等 4 支） | 11-19T11:18Z | **13 / 29** | 键鼠→触摸映射器（含摇杆/鼠标视角/随机偏移）后**又整体移除**（`f5a2472 Remove the keyboard and mouse to touch mapper`）；留下 `droidloomctl app` + 桌面 action、媒体键、launcher 排除 Terminate | 不跟（与「平板当手机用」相反；`#37` 另有其人） |
| `Ujhhgtg/droidloom` | `main` | 09-13 | **39 / 215** | 9 月一天的 V4L2 外置相机 provider 反复试错（含 3 次 revert） | 不跟（停摆 2.5 个月，且已被上游 `#46`/oodzchen 分支覆盖同一问题域） |
| `bintis` / `pharra` / `starfoxdot64` / `alghiffaryfa19` | `main` | 10-17 / 11-12 / 10-26 / 11-26 | 4/209 · 2/115 · 1/185 · **2/0** | Nix flake（两次，`bintis` 早于 `pharra`）、CI API 修正、`feat: add gapps` + `ship.yml`（第三方 GApps 打包） | 不跟（体量小或与目标无关） |
| 其余 18 个（`gotakllc` 之外的 0-ahead 群：`richardfrk` `8749236` `tdk000` `Perpuskita` `gweffect` `yaxiaiyuting` `bojogon7` `FFT-infra` `BinaryAtoms` `birkmann` `clansty` `david-xyz-abc/droidloom-fedora` `yezxx` `snowzlmbot` `alderman-norta92/droidloom-apk` `LiveAlieen` `q757571446` `RoombaMaster`） | `main` | 09-06…11-20 | **0 / behind**（`richardfrk`、`8749236` 停在 `572e1c5`=49） | 与上游同点的快照，零自有提交 | 不跟 |

**活跃度口径（仓库 09-06 才建 ⇒ 「近 3 个月」= 全量，必须改用「有自有提交 + 最近推送」）**：`ahead>0` 者 **10 个**（+`oodzchen` 分支群 = 11 个代码源）；`pushed_at ≥ 11-20`（= 上游 release 49 当天）**且 ahead>0** 者 **6 个**：`gotakllc`、`alghiffaryfa19`、`EvilBorsch`、`oodzchen`、`Reixo0`、`yigexuanmu`。

### 5.2 「跟不跟」二值 = **跟（cherry-pick 级），整包跟 = 否**

**跟的三条硬理由（全部实测）**
1. **`#48` 主因的正解已经写好了，而且在两个不同 fork 里**：`gotakllc@4e995f2`（维护者本人的自愈版 `WifiProvisioning`）与 `EvilBorsch`（`launch` 按需启动 + ready 语义）。我方现在靠「手工 `cmd wifi connect-network`」续命，**重启即失效已被实测判 FAIL**（`cell-network §9`）⇒ 不跟就等于把一个已解问题挂在自己名下。
2. **`EvilBorsch` 逐条命中我方两个长期本地规避**（`/usr/local/bin/unshare` shim、独立 nft DNS 表），并且**工程纪律可核**：`upstream.lock` 钉上游发布、拒绝在 `Cargo.lock`/`rust-toolchain.toml` 漂移时构建、`git archive` 导出源码（未提交内容不进包）、路径重映射消掉构建机路径、sysroot 只 **342 MB**（`mmdebstrap` extract 模式不跑 maintainer script）；runtime 交叉构建 **57 s / 10 jobs**（`docs/EB-BUILD.md` 实测原文，与我方 11-25 本机 12.5 s 的宿主工具链编译量级一致）。
3. **冲突面可控（量化）**：`eb/main` 的 38 个文件与上游 rel50/51 的 60 个文件**只重叠 3 个**（2 个 docs + `development.rs`，后者上游仅 +9/−2）；`gotakllc` 只重叠 **2/26**。对照 `Reixo0` 19/123、`oodzchen feat/fedora-desktop` 4/120 且 behind 更深。

**不整包跟的三条理由**
1. 三个候选都**已经在还 rebase 债**（behind 20 / 48 / 81），上游节奏是 **~2 天一个包版本**（45→46→47→48→49→50→51，见提交史），整包跟意味着每两天重签一次。
2. `EvilBorsch` 的 24 条里 **9 条是我们不需要的 Ubuntu 打包胶水**，而它的 `.deb` **没有发布资产** ⇒ 真要用得自己 `mmdebstrap` 造 342 MB resolute rootfs + 903 MB `droidloom-base`，**踩任务书「不下载 >1 GiB」红线**。
3. 两个活跃 fork 的提交署名大量带 `Co-Authored-By: Claude`（`#58` 正文自带 `🤖 Generated with Claude Code`），**无人复核**（`#48`/`#34` 5–9 天零回复；`#58` 0 回复）⇒ 跟进去的每一行都得自己跑判据，「已被审过」不成立。

### 5.3 最小可维护形态：三选一裁决 = **`patches/local/`  cherry-pick 集**

| 形态 | 本轮证据下的评估 | 裁决 |
|---|---|---|
| **A. 整包 fork**（跟 `eb/main` 或 `feat/fedora-desktop`） | 需要 342 MB sysroot + 903 MB base 下载（红线）；24 条里 9 条无用；behind 20 起跳，两天一变 | ❌ |
| **B. `patches/local/*.patch`（我方目录约定）** | 需要维护的只有 **4 条**：① `WifiProvisioning` 自愈（取 `gotakllc`，Java，**在 image/base 包里** ⇒ 需 AOSP 侧重编或由上游发版带来）② 宿主 resolver 进 lease（取 `2712d37`，Rust，**只需重编 runtime**）③ 停机不用 `--forward-signals`（取 `5380af3`，runtime）④ `runuser` 路径（取 `201000a`，runtime）。②③④ 全在 `runtime` 的 9 个 Rust 程序内，**我方可交叉重编**（11-25 已证：宿主工具链 12.5 s 编过；aarch64 只缺 `libwayland-server:arm64` 开发包）；`base/image`（AOSP ~850 MiB×2）**不动** | ✅ **裁决 = B** |
| **C. 只提上游** | 上游只收 issue/邮件（外部 PR 关闭），且对「带大段源码取证但对方无法复现」的条目会沉默（`#48` 5 天、`#34` 9 天）；`#48` 的正解虽已在维护者手里，**但要等下一次他把它推上 main 并发包** | ⚠️ 作为 **B 的并行动作**（§4 三条），**不作为唯一形态** |

**形态 B 的两条附加判据（避免 B 退化成"永远背补丁"）**
- **每条 patch 必须带"退役判据"**，写进 patch 头注释：① `unshare` shim 退役 = `strings /usr/bin/droidloom-supervisor | grep -c forward-signals` = 0；② nft DNS 表退役 = cell 内 `dumpsys connectivity` 的 DNS ≠ `1.1.1.1/8.8.8.8`；③ `WifiProvisioning` patch 退役 = 上游包里 `grep -q wifi_provisioned WifiProvisioning.java` 失败（自愈版落地）。
- **上游升级时对表**：升包前先跑 `git -C ~/src/droidloom log --oneline <上次基线>..HEAD -- runtime/droidloom-supervisor/src/{development.rs,development_network.rs,dhcp_responder.rs} android/framework/droidloom-systemui/src/com/android/systemui/wifi/WifiProvisioning.java`，非空即说明补丁邻域被动过 ⇒ 先重贴再升级（本轮实测：rel50/51 动了 `development.rs` 9 行，**未动 `development_network.rs`/`dhcp_responder.rs`/`WifiProvisioning.java`** ⇒ 现在是重贴成本最低的窗口）。

---

## §6 两周最小行动清单（每条 ≤ 半天；每条带判据；标注是否需设备 / 需发帖）

| # | 动作 | 判据（可判定的通过条件） | 需设备 | 需发帖 | 预算 |
|---|---|---|---|---|---|
| **A1** | 把上游基线从 `572e1c5`(49) 推到 `4df8af9`(51)：本地 `~/src/droidloom` fetch + `git log` 出「动了我们补丁邻域吗」的判定（§5.3） | `git rev-parse origin/main` = `4df8af9…`；且 §5.3 的那条 `git log -- <4 文件>` 输出为空或仅 `development.rs` ⇒ 记录「重贴成本 = 低/中/高」三态结论 | 否 | 否 | 1 h |
| **A2** | 起草并**冻结** `patches/local/` 四条（含退役判据头注释），从 `gotakllc@4e995f2` / `EvilBorsch@{2712d37,5380af3,201000a}` 生成 `.patch` 文件 | 4 个文件存在且 `git apply --check` 在 `main@4df8af9` 上通过（Rust 三条应过；Java 一条允许标 `applies-to=android/framework/droidloom-systemui`，等 image 重编时用） | 否 | 否 | 3 h |
| **A3** | 把 §4-C1/C2/C3 三段文字定稿入仓（`reports/droidloom-upstream-cluster-20261127.md` 已含草稿；定稿 = 补上我方最新日志原文与截图编号），**等用户点头再发** | 三段各自的「证据槽位」非空：C1 有 4 项（dumpsys/settings/nft/结果行），C2 有 `unshare --version` + `development.rs:493` 指针，C3 有 release **51** 的 logcat + `dumpsys input_method` + 截图（若 51 未复现则**整条撤掉**） | 部分（C3 的 51 复现需设备） | **是（需用户点头）** | 2 h（C1/C2 部分） |
| **A4** | 读 `gotakllc@4e995f2` 的 `multicast_relay.rs`/`development_network.rs`/`window-policy` 三处，判定「维护者的 `#48` 修法是否会把我们的 `dl_dns_redirect` 需求一并消掉」 | 产出 1 张「字段级对照」：`dns` 是否仍在 lease 里硬编码（实测：**gotakllc 仍硬编码 1.1.1.1/8.8.8.8**）⇒ 结论「`#48` 主因与次因在两个 fork 里各修一半」写死，避免将来误判「上游全修好了」 | 否 | 否 | 2 h |
| **A5** | **性能基线（为缺陷 4 补证据）**：同一 App（小红书）在全屏 `1902x3039` 下抓 `droidloomctl logs` 的 import miss/evict 计数 + `simpleperf`/`dumpsys gfxinfo` 一帧时间分布，并按 `#55` 的公式（5 缓冲 vs `kSparesPerLayer=3`）代入我方面板算一遍 | 有数字（≥3 次采样）且能回答两问：① 我方是否 100% miss；② 若是，`kSpareBytes` 我方该是多少。**只有 ①=是** 才把 `#55` 从「不碰」改「值得回复」 | **是（只读）** | 否 | 4 h |
| **A6** | IME 判定实验（J3 前置：先升到 51）：`wayland-info | grep -c zwp_text_input_v3` + 升级后重跑 tap/text/screencap 三轮 | 三态之一：① 51 上 `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE` = 0 ⇒ 我方那条已被 release 50/51 顺带解掉，**C3 撤销**；② 仍失败且 `zwp_text_input_v3` 在位 ⇒ 会话状态机缺陷成立，**发 C3**；③ 失败点变了 ⇒ 换 presenter 侧日志再判（旧判据「缺 denial_text_input_panel」已作废） | **是** | 否 | 4 h |
| **A7** | 把「现役 49 → 51 的本地改动保命表」补两行（新增：`WifiProvisioning` patch、`dhcp_responder` patch），落到 `patches/local/README` 级别的一页表 | 表内每行有「升级时行为 / 保法 / 退役判据」三列非空 | 否 | 否 | 1 h |
| **A8** | 下轮 D24 复现的**取数脚本化**：把本轮的 issue/fork/compare 查询写成一个 `scripts/` 级只读脚本的建议（本轮**不改仓库**，只在本报告留命令清单） | 报告 §8 的 URL 清单可直接复制执行；任何人能在 5 分钟内重跑并得到同一组数字（fork 数、open 数、ahead/behind 表） | 否 | 否 | 0.5 h |

**分组**：**不需设备 + 不需发帖 = A1 / A2 / A4 / A7 / A8**（合计 ~7.5 h，可立刻做）；**需设备只读 = A5 / A6**；**需发帖（需用户点头）= A3**。

---

## §7 未取证 / 残余风险

1. **未上设备** ⇒ 本报告所有设备侧数字都直接引用 11-26 的实测件（`cell-network §2/§8/§9`、`ime-keyboard §1`、`display-sizing §1`），未重新现查；A5/A6 未做前，「性能」与「IME 主因」两条**维持未定因**。
2. **fork 的"改了什么"基于 commit 标题 + 文件级 stat + 抽样 diff**（`EvilBorsch`/`gotakllc` 读了关键 diff 原文；`Reixo0`/`oodzchen` 只读了标题与文件清单）⇒ `Reixo0` 41 条里**是否藏有 IME 相关改动 = 仍未穷举**；「无 fork 修 IME」是**推断**。
3. **`gotakllc/droidloom` 的性质未证**：author=维护者邮箱、committer=`mdelsalto`、仓库属一个公司名（`gotakllc`）、内容是 "ATAK integration" ⇒ 最可能是**商业合作分支/上游作者的另一个落脚点**（推断）。若它其实是维护者未来的主发布线，本报告 §5 的「不整包跟」结论需要重估（触发条件：`gotakllc` 开始领先 `denialwm` 多个提交，或上游 README 指向它）。
4. **`.deb` 可行性未验**：EB 的 sysroot 是 Ubuntu `resolute`（glibc 2.43、`libgbm1 26.0.8`、`libpipewire 1.6.2`、`libwayland-server0 1.24.0`），Debian trixie 的对应版本更低 ⇒ 即便走形态 B，`runtime` 重编时的**依赖符号**仍需实测（11-26 首轮的 Missing#4 至今未解）。
5. **上游节奏与贡献入口**：`has_pull_requests:false` 是仓库元数据 + 三方 issue 正文一致口径，但**没有官方 CONTRIBUTING 明文**⇒「只能靠 issue/邮件」是强证据推断。
6. **`#22`（无 MOVBE）类硬限制**与 arm64 无关，但说明一条纪律：**上游的"未排期"回答会写得非常详细**（bot 长答里给了原因、方案、为什么现在不做、以及 release 41 起已有前置检查）⇒ 我方提问要按同样标准给数据，否则沉默概率高。
7. **本轮唯一产物 = 本文件**；未建 issue、未发评论、未改任何既有文件、未执行 git 写操作（`git status` 里其他 lane 的改动与本任务无关）。

---

## §8 Sources（URL + 取数时间；全部 2026-11-27T03:21:07Z–03:48:36Z，`gh`/REST API 实测）

**上游仓库与提交**
- 元数据（open 33 / forks 29 / stars 601 / `has_pull_requests:false` / `pushed_at` 2026-11-26T18:22:59Z）：https://api.github.com/repos/denialwm/droidloom
- 提交史（HEAD `4df8af9 Package release 51`；`da89eed` release 50；`572e1c5` release 49；IME/键盘 5 条 `b04e72ad`/`4c2944b3`/`2199b372`/`1656e4e3`/`08b1560c`/`723372aa4`）：https://github.com/denialwm/droidloom/commits/main
- 49→51 的差异（20 提交 / 60 文件；IME inset 与 `TaskAction::KeyboardInset`、`0010-…host-keyboard-notification.patch`、`0011-…no-boot-brightness-override.patch`、`runtime-layout-v1.md` 新增音量/亮度节）：https://api.github.com/repos/denialwm/droidloom/compare/572e1c51c5caf75183efe25ad811f98c1268bf56...main
- releases（单 tag `packages`，148 资产，含 `0.1.0-50/51` 的 aarch64+x86_64）：https://api.github.com/repos/denialwm/droidloom/releases
- 源码原文：`runtime/droidloom-supervisor/src/development.rs`（`--forward-signals` 第 493 行）https://github.com/denialwm/droidloom/blob/main/runtime/droidloom-supervisor/src/development.rs#L487-L499 ；`development_network.rs:33`（**DNS 仍硬编码 1.1.1.1/8.8.8.8**）；`android/framework/droidloom-ime/src/com/android/droidloom/ime/HostInputMethod.java`（49 与 51 两版逐行对比）；`android/framework/droidloom-systemui/src/com/android/systemui/wifi/WifiProvisioning.java`（main 仍是 `DONE` 位 + `enableNetwork(id,false)`）
- 文档：`docs/contracts/text-input-v1.md`（**"ordinary `zwp_text_input_v3"` / "Denial needs no changes"**）https://github.com/denialwm/droidloom/blob/main/docs/contracts/text-input-v1.md ；`docs/desktop-integration.md`（`window-mode` per-app、`start --mode mobile`）；`docs/INSTALL.md`

**issue（open 33 / closed 29，含正文与评论全文）**
- open 列表 + 正文：https://github.com/denialwm/droidloom/issues?q=is%3Aissue+is%3Aopen （33 条正文已本地全文 grep：`showSoftInput`/`PHASE_IME`/`soft input`/`OSK`/`freeform`/`1440`）
- closed 列表 + 正文：https://github.com/denialwm/droidloom/issues?q=is%3Aissue+is%3Aclosed （`#61` `#59` `#38` `#39` `#33` `#31` `#17` `#10` `#24` `#7` 等）
- 关键条目：`#48`（我方无网主因同构件）https://github.com/denialwm/droidloom/issues/48 ；`#58`（Ubuntu 26.04 arm64 + cherry-pick 分支 `upstream-pr`）https://github.com/denialwm/droidloom/issues/58 ；`#25`（Fedora 复现 + `droidloom-base` 拆包副作用）；`#55`（5 缓冲 vs `kSparesPerLayer=3`）；`#34`/`#43`/`#53`（IME 簇）；`#36`/`#45`（窗口簇）；`#22`（MOVBE，维护者长答）；`#26`/`#21`/`#35`（bot 长答样本 = 回复风格依据）；`#60`/`#62`/`#61`（bot 从 Discord 代开）

**fork（29 个，逐个 `compare`）**
- forks 列表：https://api.github.com/repos/denialwm/droidloom/forks?sort=newest&per_page=100
- `EvilBorsch/droidloom`：https://github.com/denialwm/droidloom/compare/main...EvilBorsch:droidloom:eb/main （24/20）；`upstream-pr` 同集合 https://github.com/EvilBorsch/droidloom/tree/upstream-pr ；`docs/EB-BUILD.md`（sysroot **342 MB**、57 s、`upstream.lock` 三重拒建）https://github.com/EvilBorsch/droidloom/blob/eb/main/docs/EB-BUILD.md ；`dhcp_responder.rs`（`Resolvers` + OPTION_DNS）
- `gotakllc/droidloom@4e995f2`：https://github.com/gotakllc/droidloom/commit/4e995f2ae33ec8689c862b9f5e79c91fecb02bad （`WifiProvisioning +64/−23`、`libdecor.rs`、`multicast_relay.rs`、`packaging/debian/`；author=doctorlogix / committer=mdelsalto）
- `oodzchen/droidloom` 分支：`feat/fedora-desktop`（16/48）https://github.com/oodzchen/droidloom/tree/feat/fedora-desktop ；`pr/host-selinux-kernel-config`（2/20）、`pr/fedora-rpm-packaging`（1/20）、`pr/wayland-toplevel-icon`（1/20）、`pr/camera-blob-write`（1/48）
- `Reixo0/droidloom`（41/81，含 `698e495`）https://github.com/denialwm/droidloom/compare/main...Reixo0:droidloom:main ；`dev-kenn`（13/29）；`yigexuanmu/droidloom-nix`（7/20、`nvidia-video-nvk` 13/20）；`Ujhhgtg`（39/215）

**本仓引用**：`TASKS/dim/D24.md`、`TASKS/G2.md`（11-26 三个增量块 + 收尾 8 待办）、`reports/droidloom-upstream-lane-20261126.md`（对账基线）、`reports/droidloom-cell-network-20261126.md`（§2 实测 / §8 已修 / §9 重启回归）、`reports/droidloom-ime-keyboard-20261126.md` + `reports/droidloom-real-ime-20261126.md`（Fossify 绕行件）、`reports/droidloom-display-sizing-20261126.md`（含 D24 首轮对账节）、`reports/droidloom-source-build-20261125.md`（本机编译能力与 oodzchen 分支已抓成本地分支）

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "open issue 内容级聚类 33→8 簇（簇和=33，正文级共性而非标题）；四条已定因缺陷逐条对照表（上游 issue 号+标题+updated_at+同因判定+三态建议，含 3 份只草拟不清发的回复/新 issue 文稿）；forks 现查 29 个逐个 compare 出 ahead/behind 与改动摘要（重点 EvilBorsch eb/main 24/20、gotakllc 1/0 的维护者 WifiProvisioning 修法）；「跟=cherry-pick 级 / 整包跟=否」二值裁决 + 三选一形态裁决（patches/local/，含 4 条 patch 与退役判据）；两周最小行动 A1–A8（每条 ≤半天、带可判定判据、按需设备/需发帖分组）；全部结论标实测/静态/推断并附 URL 与取数时间窗 2026-11-27T03:21–03:48Z。"
    }
  ],
  "changedFiles": [
    "reports/droidloom-upstream-cluster-20261127.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "gh api repos/denialwm/droidloom (+ /issues?state=open|closed|all + /issues/N/comments + /releases + /forks + /commits?path=…)",
      "result": "passed",
      "summary": "REST 本轮返 200（11-26 记 403 rate limit）：open 33 / closed 29 / 总 62、21 条零评论、forks 29、HEAD=4df8af9 release 51、releases 148 资产"
    },
    {
      "command": "gh api repos/denialwm/droidloom/compare/main...<fork>:<repo>:<branch> × 29 fork + 11 分支",
      "result": "passed",
      "summary": "逐个算 ahead/behind：ahead>0 共 10 个（EvilBorsch 24/20、Reixo0 41/81、oodzchen 分支 16/48 等），EB 与上游 rel50/51 文件重叠 3/38、gotakllc 2/26、Reixo0 19/123"
    },
    {
      "command": "gh api compare 572e1c5...main（逐文件 patch）+ HostInputMethod/WifiProvisioning 49 vs main 双版本文本对比",
      "result": "passed",
      "summary": "证实 release 50 改 IME inset 协商（TaskAction::KeyboardInset + Type.ime() insets 源）而未改 show/dismiss 状态机；main 仍硬编码 DNS 1.1.1.1/8.8.8.8 且 WifiProvisioning 仍是一次性位"
    },
    {
      "command": "本地全文 grep（open/closed 62 条正文）showSoftInput|PHASE_IME|soft input|OSK|freeform|per-app",
      "result": "passed",
      "summary": "我方 IME 缺陷在上游全量 issue 中零命中 ⇒ 空缺成立，应新开 issue"
    },
    {
      "command": "curl raw.githubusercontent.com（development_network.rs / text_input.rs / INSTALL.md / desktop-integration.md）",
      "result": "passed",
      "summary": "部分超时（raw 偶发 28 号错），已改用 gh api contents 端点取到全文；无结论损失"
    }
  ],
  "validationOutput": [
    "簇和校验：8+11+3+2+1+5+2+1 = 33 = open 总数",
    "issue 计数：编号 #1–#63、count=62（#3 不存在）、open 33 + closed 29 = 62 自洽；21 条 open 零评论",
    "forks：forks_count=network_count=29 且 /forks 分页返回 29 条（11-26 的 27 已过期）",
    "二值判断均给出可复核反证位：main 的 development.rs:493 仍有 --forward-signals；main 的 WifiProvisioning 仍 if(getBoolean(DONE)); EB releases 资产为空（故 .deb 需自建 = 触 1 GiB 红线）",
    "对 11-26 首轮落 8 条更正（含 denial_text_input_panel_manager_v1 假说作废、oodzchen 漏判、698e495 归属矛盾解除）"
  ],
  "residualRisks": [
    "未上设备：性能与 IME 主因两条维持未定因，A5/A6 是前置（分别 4h、需只读设备）",
    "Reixo0 41 条只读标题+文件清单，'无 fork 修 IME' 仍是推断而非穷举",
    "gotakllc/droidloom 的性质（商业合作分支 / 作者另一落脚点）未证，若它开始领先上游则 §5 的'不整包跟'需重估",
    "EB 的 .deb 与 Debian trixie 依赖兼容性仍未实测（sysroot 是 Ubuntu resolute，glibc 2.43/libpipewire 1.6.2 高于 trixie）",
    "上游贡献入口=issue/邮件 是元数据+三方正文一致口径的强推断，无 CONTRIBUTING 明文",
    "本报告只草拟未发任何 issue/评论；若用户批准发布，C3 必须先有 release 51 的复现数据，否则大概率被'无法复现'打回（#36 是现成反例）"
  ],
  "noStagedFiles": true,
  "diffSummary": "新增 1 份报告 reports/droidloom-upstream-cluster-20261127.md；未改任何既有文件，未做 git 写操作（git status 中其他 lane 的改动与本任务无关）",
  "reviewFindings": [
    "no blockers",
    "note: 本轮否证了 11-26 首轮写进 D24 的候选主因（宿主缺 denial_text_input_panel_manager_v1 接口不存在，契约写明用普通 zwp_text_input_v3），并作废'新提 unshare 2.41 issue'（已被 EvilBorsch #58 覆盖）——是否据此回改 reports/droidloom-upstream-lane-20261126.md / TASKS/dim/D24.md 由父代理决定，本次未改",
    "note: 现役 droidloom 停在 0.1.0-49，上游已到 0.1.0-51（+20 提交，含键盘 inset 协商与宿主键盘布局线），IME 判定实验在未升级前提下无效"
  ],
  "manualNotes": "取数用的是已登录 gh 令牌（账号 xiaquwan1001），未在任何产物里写出令牌内容；GitHub 搜索 API 对本仓返回 422（权限口径），因此改用「拉全量 issue 正文本地 grep」，结论不受影响。全程未调用 grow_loop。"
}
```

■
