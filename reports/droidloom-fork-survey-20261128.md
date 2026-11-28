<!-- 来源：researcher lane 产出 .pi/sessions/subagent-artifacts/outputs/a061b3f4-.../research.md，父代理 2026-11-28 11:2x 独立复核关键数字后提升入 reports/ -->

# droidloom 社区分支/分叉生态调查（2026-11-28）

> 只读调查：全部数据来自 GitHub 公开 API/HTML 页面与 raw 文档，**未 clone、未编译、未发 issue/评论**。
> 我方背景沿用 `reports/droidloom-release-download-verify-20261127.md` 与
> `patches/local/droidloom-local-20261127/BUILD.md`（现役 0.1.0-51、4 条本地 patch、整包 fork 已裁决不做）。
> `gh` 在本轮不可用（无 shell 工具），改用 `web_fetch` 直取 `api.github.com` 与 `github.com` HTML；中途命中过一次
> 未认证限流（`API rate limit exceeded for 47.129.113.164`），其后一律走 HTML/raw，故下文每条都标了取证方式。

---

## 0. 一句话结论

**没有「社区分支生态」，只有 8 条散落的个人分支线；其中唯一与我们同构（Debian 系 + ARM 平板 + 非 Arch 打包）的是
`EvilBorsch/droidloom` 的 `eb/*` 系列（`eb/main` = 相对上游 **ahead 25 / behind 0**）。它把我们 4 条 patch 中的 3 条
（`--forward-signals`、`runuser`、宿主 resolver）已经做成上游风格的 commit，外加 `.deb` 打包与「不用 podman 的交叉编译/重打包」工具链。**
上游 `main` 现为 **release 52**（`e6f18c4`），并且**外部 PR 在 beta 期被关闭**，所以「向上游要东西」只能走 issue + compare 链接这一条通道。

---

## 1. 上游现状（判据基线）

| 字段 | 值 | 取证 |
|---|---|---|
| `full_name` | `denialwm/droidloom`（Organization 账号） | `GET /repos/denialwm/droidloom` |
| `stargazers_count` / `forks_count` / `subscribers_count` | **611 / 32 / 3** | 同上 |
| `open_issues_count` | 38（含 PR 计数，但见下条） | 同上 |
| 默认分支 / `pushed_at` | `main` / `2026-11-27T11:45:05Z` | 同上 |
| `main` tip | `e6f18c47cb4fc8fbd160a128cd55f1c47ba048da`，commit message = **`Package release 52`**（author `doctorlogix`，2026-11-27T11:44:48Z） | compare API 的 `base_commit` 字段 |
| 分支数 | **1**（只有 `main`；无 `next`/`staging`/`release-*` 线） | `GET /branches?per_page=100` |
| **PR 通道** | **关闭**。`github.com/denialwm/droidloom/pulls?q=is:apr` → **“No pull requests matched your search”**；issue #58/#66 均写明 “Pull requests are closed during the beta / external PRs are disabled on this repository” | HTML PRs 页 + #58/#66 正文 |
| 社区通道（README 内） | **无**任何 Matrix/Discord/论坛链接；README 只有 docs 与 releases | `raw README.md` |
| 实际社区通道 | **Denial Discord 的 `#droidloom` 频道**（证据：issue #68 由 `synthia-si[bot]` 从 `discord.com/channels/1531377176551620608/1546854605491806278/...` 自动开单） | #68 正文 footer |
| 维护者在 issue 里的实际回应形态 | 由 **`synthia-si[bot]`**（Discord↔issue 桥）做结构化 triage：#35 中 30 h 内回帖问「哪类通知/何时/版本/日志」，并索要 `droidloomctl logs`+`journalctl` 输出 | #35 timeline |
| 我抽样 4 个线程（#25 #35 #58 #65 #66 #63）里 `denialwm`/`doctorlogix` 本人 | **未见本人回帖**（#63 由报告者自己修完自关） | HTML issue 页 |

> **对本项目的直接影响**：`TASKS`/`PITFALLS` 里「向上游提 PR」的口径要改写成**提 issue（带 compare 链接）**，
> 因为 repo 层面没有开 PR 的地方 —— 这是本轮最硬的一条新事实。

---

## 2. 分叉枚举（32 个，逐条判活）

**总量与取证**：`forks_count = 32`；`github.com/.../forks?include=active,inactive,network,archived` 两页共列出
**33 个条目**（第一页 26 + 第二页 7，其中含 network-fork-of-fork，故比 32 多 1）。
**判活方法**：先用 `GET /repos/<owner>/droidloom/git/refs/heads/main`（约 300 B，省配额）比对 tip 与上游 `e6f18c4`；
不同者再取 `github.com/denialwm/droidloom/compare/main...<owner>:<branch>` 的 HTML 页（直接给出 `Ahead by / Behind by / Files changed`
和 commit 列表）与 `github.com/<owner>/droidloom/commits/<branch>`（commit message 供子系统归类）。

### 2.1 有效分叉（有自有 commit）——共 8 条

| # | fork | stars | 默认分支 tip / 最后 push | **ahead / behind**（vs `denialwm:main` = `e6f18c4`） | 相关分支 | 改了哪些子系统（按 commit message 归类） |
|---|---|---|---|---|---|---|
| 1 | **EvilBorsch/droidloom** | 1 | `eb/main` = `a0dd66c`；`2026-11-27T17:39` | **25 / 0** | `main`(=`e6f18c4`), `eb/main`, `eb/android-setup`, `eb/host-resolvers-clean-stop`, `eb/launch-starts-android`, `eb/one-scale`, `eb/ubuntu-packaging`, `eb/ubuntu-runuser`, `eb/unshare-util-linux-2.41`, `upstream-pr`(`7fa1eea`, **24 / 26**) | **宿主打包（.deb）+ supervisor（停机/resolver/按需启动/ready 语义）+ 应用目录 + droidloom-wayland 密度 + 交叉编译工具 + 文档**；Android 侧不改 |
| 2 | **Reixo0/droidloom** | 1 | `a470b56`；`2026-11-25T19:33` | **41 / 87** | `main` | 通知/MPRIS、Codec2 V4L2 与 SurfaceFlinger 视频直通、window policy、NFC/GNSS/sensors/camera HAL、`droidloom-update` lib64 sysroot（**无打包、无 Debian 相关**） |
| 3 | **dev-kenn/droidloom** | 0 | `f5a2472`；`2026-11-19T11:18` | **13 / 35** | `main` | 键鼠→触摸 keymapper（`input_keys.rs`）、`droidloomctl` 子命令与桌面动作、媒体键映射（5 文件） |
| 4 | **FFT-infra/droidloom** | 0 | `main`=`ffccef6`（= 上游 10-24 tip，**main 无自有 commit**） | main **0 / 落后**；分支见右 | `fedora-rpm`(`94bca59`, **5 / 6**), `stylus-tablet-v2`(`1a09d9b`), `integration/r52-sheng`(`5dff86b`) | **Fedora RPM 打包 + SELinux/firewalld + `build-rpm`**、笔输入（`zwp_tablet_v2`，input ABI→9）、r52 集成；并发布 `r51-fedora44-1` / `r52-fedora44-1` RPM |
| 5 | **oodzchen/droidloom** | 0 | `main`=`df72bc9`（release 42 镜像，0 自有） | main **0 / 落后** | `pr/host-selinux-kernel-config`, `pr/fedora-rpm-packaging`, `feat/fedora-desktop`（见 #25 自述） | Fedora 兼容（`/sys/fs/bpf` SELinux context、缺 `/proc/config.gz` 时的 `/boot/config-*` 兜底）+ RPM specs + 控制中心 GUI |
| 6 | **yigexuanmu/droidloom-nix** | 0 | `476a74d`；`2026-11-21T14:34` | 自有 **7 条**（基于 release 49） | `main` | **Nix flake + NixOS module**（PATH、Vulkan loader、`system_heap` dma-heap、desktop entry 链接）；含 `mioha` 的 commit |
| 7 | **pharra/droidloom** | 0 | `06f755d`；`2026-11-12T15:43` | 自有 **2 条**（基于 release 33，**已旧**） | `main` | NixOS 实验性 flake（Copilot 参与） |
| 8 | **bit-shift-io/droidloom** | 0 | repo created `2026-11-27T22:48` | 未取 compare（工作线在分支） | `barbet-health-hal-interface`（见 #35 评论） | Pixel 5a(`barbet`) 移植：`vendor.health-default` rc 的 `interface aidl` 行缺失导致 boot hang |

### 2.2 无效分叉（0 自有 commit：纯镜像 / 占名 / 从没推过）

- **镜像且落后**：`yaxiaiyuting/droidloom`（tip `ec87a93` = 上游 release 31）、`FFT-infra/droidloom@main`、`oodzchen/droidloom@main`（release 42）、`Ujhhgtg`、`q757571446`、`starfoxdot64`、`clansty`、`bintis`、`alderman-norta92/droidloom-apk`（改名 fork）、`Gibbz`（11-27 建，等价于 bit-shift-io 的镜像）、`duy150905`、`gotakllc`、`alghiffaryfa19`、`bit-shift-io@main`。
- **从未 push**：`richardfrk`、`8749236`、`tdk000`、`Perpuskita`、`gweffect`、`bojogon7`、`BinaryAtoms`、`birkmann`、`yezxx`、`snowzlmbot`、`LiveAlieen`、`RoombaMaster`、**`david-xyz-abc/droidloom-fedora`**（名字很诱人，但 “Never updated” ⇒ 空壳，勿追）。

> 分类口径：「有效」= 默认分支或可识别工作分支上存在**非 doctorlogix 作者的 commit**；两个 Nix 线（#6 #7）按此计有效，
> 但 `#7` 的基线停在 release 33，实际不可用。

---

## 3. 社区通道实况（30 天内参与者）

**通道清单**

| 通道 | 状态 | 证据 |
|---|---|---|
| GitHub PR | **关闭**（beta 期，repo 层面 disable） | PRs 页 “No pull requests matched”；#58/#66 自述 |
| GitHub issue | **唯一的正式入口**，且约定俗成 = 「兼容性报告 + 我方 fork 分支 compare 链接」 | #58（EvilBorsch）、#66（FFT-infra）都是这个形状 |
| Discord | **Denial server → `#droidloom`**（issue 由 bot 反向开单） | #68 footer |
| Matrix / 论坛 / 邮件列表 | **未发现** | README、docs/README 无相关链接 |
| CI | **无公开 CI**；发布链是自建 runner（`/mnt/puck/logix/droidloom`，见我们 11-27 报告 §4 引 `docs/BUILDING.md`） | 同左 |
| 官网 | `denialwm.org/droidloom.html`（README 引 “Why not Waydroid?”） | README |

**近 30 天 issue 参与者**（作者 + 评论者，取自 `github.com/denialwm/droidloom/issues?q=sort:updated-desc` 与前 6 个线程正文）

| 人 | 身份线索 | 出现处 |
|---|---|---|
| `synthia-si[bot]` | 维护方 triage bot（Discord 桥），**事实上的第一响应人** | #35 #61 #62 #68 |
| `xiaquwan1001` | 我方（Debian 13 + phosh 0.46 + Y700） | #65 #69 |
| `EvilBorsch` | Ubuntu 26.04 arm64 OnePlus Pad 3，`eb/*` 分支作者 | #58 |
| `FFT-infra` | Fedora 44 arm64 Xiaomi Pad 6S Pro，RPM + 笔输入 | #66（并引用 #25） |
| `oodzchen` | Fedora 45（aarch64 Adreno 830 / x86_64 Iris Xe），`pr/*` 分支 | #25 |
| `Gibbz` / `bit-shift-io` | Pixel 5a(`barbet`) 移植、health HAL 修复 | #35 #67 |
| `enYao39` / `LuanVSO` | 消费者/测试者（LuanVSO 指出 base 拆包后 fork 缺 `.img` 致启动失败） | #25 |
| `wt-5783` | 高质量 bug 报告者（captive portal 永久禁用 Wi-Fi、installd submount、144 Hz 直通抖动） | #48 #55 #57 |
| 其它 | `coffeecode3d`(#64 KeyMint/RKP)、`limegreen99`(#63 自修关单)、`AndusDEV`(#54 Panfrost)、`subby2006`(#25 发起人)、`realahmed7777`(#51 #52)、`maki40681`(#56)、`charbguy`(#53)、`KittenPro`(#37)、`Sun-Monolog`(#50)、`adas0x`(#59) | 同上 |

**结论**：有**活跃第三方**（≥6 个能改代码/能打包的人），但**没有第三方维护者**（除 bot 外，没有第二个人能关 issue/合并代码）。
我们不是孤例 —— 至少在 Debian 系上 `EvilBorsch` 已经把我们的 3/4 个坑独立踩过并解了。

---

## 4. 打包 / 发行面

| 面 | 结论 | 证据 |
|---|---|---|
| **AUR** | **零包**。`aur.archlinux.org/rpc/v5/search/droidloom` → `{"resultcount":0,"results":[]}` ⇒ 不存在 `droidloom` / `droidloom-bin` / `-git` 任何一个 | AUR RPC v5 |
| 官方发行 | 自托管 pacman 仓库（`install.sh` 加 repo，x86_64 + aarch64），release 资产 `packages` tag（image/runtime/base/source） | README §Install + 我们 11-27 报告 |
| **Debian/Ubuntu** | 仅 `EvilBorsch` 的 fork 内 `.deb`（`packaging/eb-ubuntu/`，由**上游 pacman 包重打包** + 自编 9 个 Rust 程序；版本 `0.1.0-49+ebN`），**无 PPA、无 wnpp/RFP、Debian 源内无包**（检索无匹配，见 §8 缺证） | `docs/EB-BUILD.md`（fork）+ 上游 `docs/BUILDING.md` |
| **Fedora** | 两条线：`oodzchen` 的 specs（#25）→ 被 **`FFT-infra` rebase 承接**并出 RPM release（`r51-fedora44-1`、`r52-fedora44-1`）；另有「某人建了 Fedora Copr，全部构建失败」 | #25、#66、FFT-infra releases |
| **NixOS** | `yigexuanmu/droidloom-nix`（flake + module，7 commit）、`pharra`（2 commit，release 33 基线，已旧） | fork commits 页 |
| **openSUSE** | 无任何痕迹 | forks/issues 全扫 |
| **「不用 podman 的构建」** | **有，两条**：① `EvilBorsch` `tools/eb-build-runtime`（cargo 交叉编 9 个 host 程序，**57 s / 空 target，二次构建位相同**）+ `tools/eb-build-debs`（校验上游归档 SHA-256 → 重打包 → 逐文件对上游 `.MTREE`；用 `mmdebstrap` extract 变体做 342 MB Ubuntu arm64 sysroot，**3 min**）；② `Reixo0` `droidloom-update: build host programs against a lib64 sysroot` | `docs/EB-BUILD.md`；Reixo0 commit 列表 |
| 与我们 `BUILD.md` 的交叉验证 | 一致：**纯 Rust 宿主件不需要 Arch sysroot**（他们也只是 apt 装 `gcc-aarch64-linux-gnu` + glslang）；需要 Arch/sysroot 的是 C 依赖件。他们的 glibc 门槛实测 `GLIBC_2.39`（我们是 2.39 ≤ 设备 2.41） | `docs/EB-BUILD.md` §2 |

---

## 5. 调试便利性对比（判据：非 Arch 宿主 + 需要看 Wayland/text-input 日志 + 能只重编一个组件）

| 能力 | 上游 main(52) | EvilBorsch `eb/*` | FFT-infra `fedora-rpm`/`stylus` | Reixo0 | dev-kenn |
|---|---|---|---|---|---|
| `droidloom-doctor` / `droidloomctl doctor`（只读宿主前置检查，JSON，exit 0/2/1） | ✅ 有 | ✅ 有（并用它做回归） | ✅ 有（#66「doctor passes」） | ✅ | ✅ |
| `droidloomctl logs / crashes / --json`（无需 sudo，boot 未完成也能读） | ✅ | ✅ | ✅ | ✅ | ✅ |
| `DROIDLOOM_TRACE`（trace 开关，例如 `=input` 拿 `editor=` 诊断行） | ⚠️ **源码有、docs 未列**（我方 #65 评论引用；`docs/*` 全文未见该变量） | 同上（随上游） | 同上 | 同上 | 同上 |
| Wayland/text-input 侧可观测性 | 中：`touch_age_ms`、IME start/restart/finish/show 日志；`text-input-v1.md` 定义 editor 状态字段 | 中（同上） | 中 + 笔输入 ABI 文档化 | 较高（视频/层日志大量新字段） | 低 |
| 非 Arch 宿主可复现的构建 | ❌ 官方只给 podman + Arch ARM sysroot 路线 | ✅ **`.deb` + 57 s 交叉编 + 逐文件校验**（最高） | ✅ RPM + `build-rpm --architecture`（可跨架构出包） | ⚠️ 有 sysroot 工具但无打包 | ❌ |
| 只重编一个组件（不整包/不碰 AOSP） | ⚠️ 仅 `--surfaceflinger-only`（且需已备好的 ARM64 workspace） | ✅ 明确分层：「image/base = 上游原件不改；runtime = 自编」 | ⚠️ 同上游 | ✅ host 程序可单编 | ⚠️ |
| 面向「phosh/非 Denial 合成器」的证据 | 中（README：只需 `xdg-shell` + `linux-dmabuf` v4，但测试只在 Hyprland/Denial） | 中（Denial on Ubuntu） | 中（Denial 0.6.10） | 中 | 低 |
| 装机后可诊断性增强 | 基线 | ✅ `install --notify` 逐步通知、`prepare` 失败原因（126/127）、`60-droidloom-loop.rules`（49 个 loop 卷→0）、`droidloom-install-apk.desktop` | 中（RPM 附带 SELinux/firewalld 策略） | 低 | 低（keymapper 有 example profile + 文档） |

**判定**：对「非 Arch + 需要看 Wayland/text-input 日志」最友好的是 **`EvilBorsch:eb/main`**（宿主层可编可查可回滚，且它的每条改动都写了「怎么验的、哪台机器上验的」）；
**`FFT-infra`** 在「诊断结论沉淀」上第二（Docker `iptables-legacy` 抢 FORWARD、netd/相机日志噪声、input 路由 190 px 一次性偏差都写清楚了，可直接抄进我们的 `PITFALLS`）；
`Reixo0` 功能最猛但对我们的两条主诉（IME、打包）零帮助，且 **87 commits behind**；
`dev-kenn` 只覆盖手柄/键位映射（对应上游 #37/#60）。

---

## 6. 结论：3 条可执行选项

### 选项 A（基线，必做）**继续跟上游 `main`，只维护我们的 patch 集**

- 做法：跟 release 号升包（52 已出；`image-52` 若仍 `depend = droidloom-base=0.1.0-49`，只需下小包）；4 条 patch 照 `BUILD.md` 顺序打（003 需 `fuzz=2`）。
- **理由**：上游是**唯一有 CI/发布链**的线，且我们的 3 条 patch 已有上游风格的等价 commit 可抄（见 B）。
- **判据（怎么知道选对了）**：① 下一个 release（53）出来后 `patches/local/*` 全部 `--fuzz=0`（003 允许 `fuzz=2`）仍能应用；② `grep -rn 'forward-signals' runtime/` 与 `runuser` 命中数按基线递减（= 上游在吸收）；③ 我们提的 issue 得到 `synthia-si[bot]` 回复，或被写进 release notes。
- **代价**：每个 release 都要重打/重编一次（~29 s 编译 + 3 个二进制部署 + 回滚备份），Android 镜像类缺陷（#65/#69）无 ETA。

### 选项 B（推荐作为**补丁来源**，不作为跟随基线）**跟 `EvilBorsch` 的 `eb/*`**

- 做法：不整包跟（与 `TASKS/NEXT.md` ~~T2~~ 裁决一致），只把 `eb/main` 的 25 条里我们要的 3 条**替换**为同源 commit：
  `201000a`(runuser `/usr/sbin`) / `5380af3`(去 `--forward-signals`，pidfd + 校验父进程) / `2712d37`(宿主 resolver 进 lease + power-off 停机)；
  工具链层直接用 `docs/EB-BUILD.md` 的 `eb-build-runtime`（cargo 交叉编）+ `eb-build-debs`（`.MTREE` 逐文件校验）思路改造我们 `BUILD.md`。
- **理由**：① **ahead 25 / behind 0** —— 它 rebase 在最新 `main`(`e6f18c4`) 上，是唯一「跟着上游一起动」的第三方线；② 它的 commit message 就是我们 `PITFALLS` 里那几条的字面描述（util-linux 2.41 / Debian sbin / `1.1.1.1`-`8.8.8.8` 硬编码）；③ 它的 `.deb` 打包方式（重打包上游包 + 只换 host 程序 + 逐文件校验）正是我们「不整包 fork」的工程化范本。
- **判据**：① 取到 `eb/main` 后，`git log --oneline` 里我们那 4 条 patch 有 3 条变成「已存在」；② 用它编出的 `droidloomd` 在设备上 `droidloomctl status`=ready、`nft list ruleset | grep -c dl_dns_redirect`=0（同我们 11-27 验收）；③ `eb/main` 持续保持 `behind_by == 0`（用 compare 复查），`docs/EB-BUILD.md` 的 `upstream.lock` 跟着升到 52/53。
- **风险（必须写明）**：1 star、单人、在 **WSL Ubuntu 26.04** 上验，**没有 phosh 场景**（他们跑 Denial），也没测 phosh-osk-stub / `zwp_text_input_v3` 面板路径；`upstream-pr` 分支 **24 / 26** 说明**上游一条都没合**，一旦上游改 `supervisor`/`development.rs` 我们要自己 rebase（我们 003 已经因为 002 的改动吃过 `fuzz=2`）。

### 选项 C（并行，零技术成本）**上游化我们要的「非 Arch 宿主 + 可观测性」——但用 issue，不用 PR**

- 形态：一页 proposal，发在 issue（PR 通道关闭）。要点建议（每条都有第三方先例可引，降低「只有你一个人想要」的观感）：
  1. **官方化「repack + 自编 host 程序」**：引 `EvilBorsch/docs/EB-BUILD.md` 的 `.MTREE` 逐文件校验法 + `upstream.lock`（SHA-256 + 版本），说明产物可与上游 pacman 包逐文件对账。
  2. **宿主兼容性三件**：`runuser` 走 `/usr/sbin`、util-linux < 2.42 无 `--forward-signals`、`/proc/config.gz` 缺失时用 `/boot/config-*`（后者引 `oodzchen` #25）——已被 #58 提过一次，我们可补「Debian 13 独立复现」。
  3. **可观测性**：`DROIDLOOM_TRACE` 进 `docs/`；`droidloom-doctor` 增「当前 IME 不是自带 headless 那个」告警（正是 #69 的第 3 条 Asks，等于替我们自己的诉求加票）。
  4. **贡献通道**：beta 期至少开一个 `contrib/` 分支或 patch-collection issue，把散落的 deb/rpm/nix 三条线挂上去（现在 `oodzchen` 与 `FFT-infra` 的 Fedora 工作就是重复劳动）。
- **判据**：bot/维护者给出**明确采纳或拒绝**（不是沉默），或某条进入 release notes/`docs/`。
- **代价**：一次写作 + 等回复；不改变任何技术现状，只是把「我们会反复踩」变成「上游记得住」。

**净建议**：**A 做基线 + B 做补丁与工具链来源 + C 并行提一页 proposal**。不建议整包跟任何 fork（含 EvilBorsch）——理由不是质量，而是**所有第三方线都 behind 或未上游化，且没有一条测过 phosh**。

---

## 7. 矛盾 / 分歧（显式记录，不擅自消解）

1. **「官方只给 Arch 包」的精确化**：更准确是**「官方只给自托管 pacman 仓库，且 AUR 无包」**（AUR search = 0）。差别有意义：Arch 用户也不是从 AUR 装，而是加第三方 repo ⇒ 「Arch-only」是**发布链选择**，不是打包格式不可移植。
2. **Fedora 两条线重复**：`oodzchen`(#25) 与 `FFT-infra`(#66) 是同一件事的两份实现，`FFT-infra` 自述「Fedora branch 是 oodzchen 的三条 rebase 后加我们两条」⇒ 不是分歧，是**碎片化**；但它同时说明「非 Arch 补丁没有汇总点」。
3. **`Reixo0` 的定位矛盾**：41 条自有 commit 且粒度像上游风格（“Codec2 V4L2: …”、“Video layers go to the host directly”），但 **ahead 41 说明一条都没进 `main`**，且 behind 87。是否曾以别的身份向上游贡献过，**未证实**（见 §8）。
4. **`FFT-infra/droidloom@main` vs 其分支**：main 是 10-24 的纯镜像（0 自有 commit），真工作在 `fedora-rpm`/`stylus-tablet-v2`/`integration/r52-sheng` ⇒ **只读默认分支会得出「死 fork」的错误结论**，本轮已按分支重判。
5. **`david-xyz-abc/droidloom-fedora`** 名字指向 Fedora 打包，但 repo **“Never updated”**（空壳）⇒ 与 §4「Fedora 有两条线」不矛盾，但排除第四条。

---

## 8. 缺证 / 未解决

| 缺口 | 影响 | 现状 |
|---|---|---|
| `DROIDLOOM_TRACE` 究竟有哪些取值、输出到哪 | 影响「我们能不能靠 trace 定位 #65」 | **docs 全文未命中**该变量；唯一出处是我方 #65 评论（读源码得出）+ `text-input-v1.md` 只说「IME 日志区分 start/restart/finish/show」。**未在源码中直接核到定义点**（无 shell；GitHub code search 需登录） |
| #58（EvilBorsch）/ #66（FFT-infra）**是否被维护者读过** | 决定「提 issue 是否有用」 | 两个 issue 的 timeline 均无回复（`updated_at == created_at`）⇒ 至少 48 h 无回应，**不能据此断言通道无效**（#35 是 30 h 后 bot 回复的） |
| Debian wnpp / RFP 是否存在 | 决定「有没有人正式请求 Debian 打包」 | 仅用 AUR RPC + web 搜索核查（无匹配），**未直连 `bugs.debian.org` wnpp 索引**，按「未发现」记录 |
| 其余 ~24 个分叉的 ahead/behind | 影响「有效分叉数」的精确度 | 用「tip SHA 比对 + commits 页首条作者」推定 0 自有 commit，**未逐个跑 compare**（省限流） |
| Discord `#droidloom` 内容 | 可能已有「Debian 怎么装」的现成答案 | **未读**（未加入服务器；仅从 #68 footer 确认频道存在） |
| `synthia-si[bot]` 背后是谁、有无决策权 | 决定选项 C 该找谁 | 只知道它从 Denial Discord 开单；`denialwm`（组织号）与 `doctorlogix`（commit 作者）关系**未证实** |

---

## 9. 来源

**Kept（一手，且直接支撑结论）**
- `GET /repos/denialwm/droidloom` — stars/forks/默认分支/`pushed_at`/`has_discussions=false`。
- `GET /repos/denialwm/droidloom/branches` — 只有 `main` 一条线。
- `github.com/denialwm/droidloom/pulls?q=is:apr` — **PR 通道关闭**（关键新事实）。
- `github.com/denialwm/droidloom/forks?include=active,inactive,network,archived&page={1,2}` — 33 条目枚举与创建/更新时间。
- `compare/main...EvilBorsch:eb/main` — **ahead 25 / behind 0**、`base_commit=e6f18c4`、commit 列表。
- `compare/main...EvilBorsch:upstream-pr` — 24 / 26、改动文件表（38 文件，含 `packaging/eb-ubuntu/*`、`tools/eb-*`）。
- `compare/main...Reixo0:main` — 41 / 87、123 文件、子系统分布。
- `compare/main...dev-kenn:main` — 13 / 35、5 文件。
- `compare/main...FFT-infra:fedora-rpm` — 5 / 6、`packaging/fedora/*`、`tools/droidloom-package/src/fedora.rs`(682 行)。
- `raw docs/EB-BUILD.md`（EvilBorsch）— 57 s 交叉编、`.MTREE` 校验、`.deb` 三包分层、`upstream.lock`。
- issue **#58**（Ubuntu 26.04 arm64 兼容报告 + “PRs closed during beta”）、**#66**（Fedora 44 + 笔输入 + RPM release）、**#25**（Fedora/Ubuntu 诉求 + oodzchen 两条分支 + 3 人讨论）、**#35**（bot triage 形态 + barbet health HAL 根因）、**#63**（报告者自修自关）。
- `raw docs/desktop-integration.md`（doctor 语义/exit code）、`raw docs/contracts/text-input-v1.md`（IME 面板/`zwp_text_input_v3`/dismiss 语义）、`raw docs/README.md`、`raw README.md`。
- `aur.archlinux.org/rpc/v5/search/droidloom` — **resultcount 0**。

**Rejected / 降权**
- `david-xyz-abc/droidloom-fedora`、`richardfrk`、`8749236` 等 13 个 “Never updated” 空壳 — 无内容。
- `alderman-norta92/droidloom-apk` — 改名的空镜像（9-22 后未动），名字易误判为「APK 打包 fork」。
- `yaxiaiyuting` / `oodzchen@main` / `FFT-infra@main` — 落后镜像，仅用来证明「默认分支 ≠ 活跃度」。
- `docs/KNOWN_ISSUES.md` — 极长且大量是 x86 翻译器/游戏兼容长篇，与「跟哪条线」弱相关（只取「Clash/Brawl 本地修复未进入发布包」这一条口径）。
- Brave/Exa 搜索命中的 fork 首页 snippet — 全是同一段 README，无增量（本轮 firecrawl 402 配额耗尽，已绕开）。

---

## 10. 下一步（只留最有用）

1. **（≤10 min，需 shell）** 直接核 `DROIDLOOM_TRACE`：解包已在盘的 `~/dl-droidloom-51/droidloom-source-0.1.0-51.tar.gz`，`grep -rn 'DROIDLOOM_TRACE' .` —— 定值域与输出位置，#65 的 traced build 才能提。
2. **（≤30 min，需 shell）** 把 `eb/main` 的 `201000a/5380af3/2712d37` 与我们 `00{2,3,4}-*.patch` 做逐 hunk 对比（只需 `source-51.tar.gz` 里的对应文件），决定「替换」还是「并存」；顺带抄 `60-droidloom-loop.rules`（49 个 loop 卷→0，纯收益）。
3. **（1 轮写作）** 起草选项 C 的一页 proposal（引用 #25 #58 #66 #69 四条既有诉求 + EB-BUILD 的可对账打包法），**发不发、何时发**由父代理按 `AGENTS.md`「上游发信」口径决定。

---

## 11. 父代理独立复核（2026-11-28 11:2x，`gh api` 直查，rule 7）

| 断言 | 复核命令 | 结果 |
|---|---|---|
| 上游统计 611 stars / 32 forks / 38 open issues / `pushed_at 2026-11-27T11:45:05Z` | `gh api repos/denialwm/droidloom --jq …` | **完全一致** |
| `main` tip = `Package release 52` / `e6f18c47cb4fc8fbd160a128cd55f1c47ba048da` | `gh api repos/denialwm/droidloom/commits/main` | **一致**（author date 2026-11-27T11:44:48Z） |
| **PR 通道关闭** | `gh api "repos/denialwm/droidloom/pulls?state=open"` 与 `state=all` | 两者均 **HTTP 404 Not Found**（比 HTML 空页更硬：API 层就不存在该端点）⇒ **确认** |
| `EvilBorsch:eb/main` = ahead 25 / behind 0 | `gh api "repos/denialwm/droidloom/compare/main...EvilBorsch:eb/main"` | **ahead 25 / behind 0 / total 25** |
| 那 3 条关键 commit 真实存在且 message 照抄 | `gh api repos/EvilBorsch/droidloom/commits/{201000a,5380af3,2712d37}` | `package-support: Find runuser in /usr/sbin too` / `supervisor: stop Android without unshare --forward-signals` / `supervisor: host resolvers in the lease, stop Android by powering it off` ⇒ **一致** |

> 结论口径（父代理）：lane 的数字与结论**可复现**；本轮唯一需要改动我方既有口径的是「droidloom 不能提 PR」（见 `PITFALLS #757`）。
