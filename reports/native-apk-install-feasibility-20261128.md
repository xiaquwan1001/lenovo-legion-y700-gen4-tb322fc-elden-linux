# 「自建 APK 包管理器：装进我们的安卓环境 → 进 Phosh 网格 → 点开就跑」可行性评估（2026-11-28）

- **性质**：设备**只读**实测（仅 `ssh elden` 上的查询/`droidloomctl` 只读子命令/`adb shell` 读状态）+ 仓库内既有结论复用；**零装包、零 `restart`、零改属主、零写配置**；唯一写入 = 本文件。
- **目标形态（用户原话拆解）**：拿到 apk → 直接安装进"我们的安卓环境" → 出现在 Phosh 应用网格（.desktop + 图标）→ 点开就跑；**尽量不依赖 Google/Android 宿主，也不重编 AOSP 镜像**。
- **不重推的先例（直接引用，不重新论证）**：
  - `reports/droidloom-app-compat-20261125.md`（GMS/PI/应用三问）、`reports/droidloom-deploy-20261126.md`（上机装→起→launch 全链）、`reports/droidloom-display-sizing-20261126.md`（窗口尺寸根因）、
  - `reports/waydroid-droidloom-userland-interface-20261026.md`（Waydroid 14 条硬依赖 + droidloom 7 类接口差 + A1/A2/A3 抽象裁决）、
  - `reports/c3-pi-tiers-closeout-20261110.md` + `reports/droidloom-app-compat-20261125.md` §1.1（PI / Widevine 三档天花板）。
- **证据级别**：每条标 **实测**（本轮命令输出）/ **静态**（读既有报告、包元数据）/ **推断**（外推，未取证）。

---

## 0. 一页结论

| 问题 | 判定 | 一句话依据 |
|---|---|---|
| 「apk → 网格图标 → 点开就跑」这件事能不能做 | **能，而且现役装置上已经发生过**：`droidloomctl applications` 列出 6 个 Android 应用，每个都有 `~/.local/share/applications/droidloom-<hash>.desktop` + 128x128 图标 | 实测（§1.2/§1.3） |
| 最划算的形态 | **B = droidloom 前端（薄封装）**，MVP ≈ **8–14 h**，且**不需要任何镜像/内核改动** | §2 表 + §3 |
| Waydroid 路线（A）值不值得先做 | **不值得先做**，但它是**唯一便宜的 GMS 入口**（`waydroid init -s GAPPS` 一个开关 vs droidloom 要自备 LiteGapps + 全新 data + aapt2 环境）。当前 Waydroid 在本机 **完全未初始化**（`images` 目录不存在） | 实测（§1.1） |
| 需要"不动 AOSP / 不动内核态"能不能达成 | **能，且已经达成**：两条路都用预编译 Android（droidloom 自带 base/image；Waydroid 用 `ota.waydro.id` 的 LineageOS VANILLA）。内核侧唯一硬需求 `CONFIG_ANDROID_BINDERFS=y` 现役内核**已编入** | 实测（§1.4） |
| 这条路线的能力上限 | **相机 / 传感器 / 触觉 / DRM(Widevine) / Play Integrity / 反作弊 / FCM 推送 / 32 位专有 APK** —— apk 管理器**一条都不会改善**，这些全是 runtime 与内核态问题 | §4 |

---

## 1. 现状实测（只读）

### 1.1 Waydroid：装好了，但**完全未初始化**（当前不能装任何 apk）

```sh
ssh elden 'waydroid --version; waydroid status; sudo -n ls -la /var/lib/waydroid'
```

```
1.6.3
Waydroid is not initialized, run "waydroid init"
总计 24
drwxr-xr-x  3 root root 4096 11月21日 23:59 .
drwxr-xr-x 55 root root 4096 11月27日 11:07 ..
drwxr-xr-x  2 root root 4096 11月21日 23:59 cache_http
-rw-r--r--  1 root root  426 11月21日 23:59 waydroid.cfg
-rw-r--r--  1 root root 5720 11月22日 00:01 waydroid.log
```

```sh
ssh elden 'waydroid app list; sudo -n ls /var/lib/waydroid/images; sudo -n tail -2 /var/lib/waydroid/waydroid.log'
```

```
Waydroid is not initialized, run "waydroid init"
ls: 无法访问 '/var/lib/waydroid/images': 没有那个文件或目录
urllib.error.URLError: <urlopen error [Errno 110] Connection timed out>
```

**判读（实测）**：
- `waydroid-container.service` **active (running)**，`lxc 6.0.4` 在位，但 **`images_path=/var/lib/waydroid/images` 不存在** ⇒ `waydroid app install/list` 全部不可用。
- `waydroid.cfg` 只记了 OTA 源：`system_ota=…/waydroid_arm64_only/VANILLA.json`（**VANILLA = 无 GAPPS**），`vendor_type=MAINLINE`，`arch=arm64_only`。
- 上次 `init` 失败原因 = **下载超时**（`URLError Connection timed out`，2026-11-22）。本轮复测主机侧 **HTTPS 出网正常**：`curl -o /dev/null -w %{http_code} https://ota.waydro.id/…/VANILLA.json` = **200** ⇒ 当时是瞬断/代理问题，不是策略封锁。
- **没有任何 per-app `.desktop`**。包只装了 3 个桩（实测原文）：

```
/usr/share/applications/waydroid.app.install.desktop
  Name=Install in Waydroid ; NoDisplay=true ; MimeType=application/vnd.android.package-archive
  Exec=waydroid app install %f
/usr/share/applications/Waydroid.desktop        Exec=waydroid（Actions=stop;initialize）
/usr/share/applications/waydroid.market.desktop Exec=waydroid app intent android.intent.action.VIEW %u
```

⇒ **上游 Waydroid 本身不做"应用图标进网格"**；它只有「双击 apk → 装」和「一个整块 Android 桌面窗口」。
**这正是候选 A 里"自建前端"要补的那一段。**

### 1.2 droidloom：**现役、活着、且已经产出网格图标**

```sh
ssh elden 'systemctl list-units --no-pager | grep -i droidloom; droidloomctl status'
```

```
droidloomd.service            loaded active running  Droidloom Android cell lifecycle daemon
cell u1001 is running from /etc/droidloom/cell.json; Android is ready
```

```sh
ssh elden 'droidloomctl applications'
```

```
listed 6 Android applications
LimbusCompany   com.ProjectMoon.LimbusCompany/com.ProjectMoon.LimbusCompany.LimbusCompanyActivity
Files           com.android.documentsui/com.android.documentsui.LauncherActivity
Settings        com.android.settings/com.android.settings.Settings
Trime           com.osfans.trime/com.osfans.trime.MainLauncherAlias
rednote         com.xingin.xhs/com.xingin.xhs.index.v2.IndexActivityV2
Keyboard        org.fossify.keyboard/org.fossify.keyboard.activities.SplashActivity.Green
```

```sh
ssh elden 'ls /home/xuqianhui1001/.local/share/applications/droidloom-*.desktop | wc -l;
           head -20 /home/xuqianhui1001/.local/share/applications/droidloom-051e1d36….desktop;
           ls -l /home/xuqianhui1001/.local/share/icons/hicolor/128x128/apps/droidloom-* | head -3'
```

```
6
[Desktop Entry]
Type=Application
Name=rednote
Comment=Android application via Droidloom
TryExec=/usr/bin/droidloomctl
Exec=/usr/bin/droidloomctl launch com.xingin.xhs --component com.xingin.xhs/…IndexActivityV2 --user 0
Icon=droidloom-051e1d36c9f55d8e8d6f15122264d0f8
StartupWMClass=com.xingin.xhs
X-Droidloom-Managed=true
X-Droidloom-Package=com.xingin.xhs
-rw------- 1 xuqianhui1001 xuqianhui1001 11419 11月26日 …/droidloom-051e1d36….png   （共 6 张 128x128）
```

**判读（实测）**：**"装 → 图标 → 网格 → 点开"的前半段 droidloom 已自带**（`droidloom-applications` 从 Android 包管理器目录生成 .desktop + 抓图标）。这也是 B 比 A 便宜的根本原因：**图标提取和 .desktop 生成不用自己写**。

### 1.3 droidloom 的安装/启动接口与已知缺口

```sh
ssh elden 'droidloomctl install --help; droidloomctl launch --help; cat /home/xuqianhui1001/.config/droidloom/window-policy-v1.json'
```

```
Install a standalone APK, updating an existing app while retaining its data
  <APK>  Host path to a standalone APK (split APK bundles are unsupported)     ← 缺口 1

Launch one Android application in the boot-managed runtime
  --component / --resolution WIDTHxHEIGHT / --user / --spec

{ "schema": 1,
  "default": { "mode": "windowed", "size": { "width": 1904, "height": 3040 } },
  "applications": { "com.xingin.xhs": { "mode": "windowed", "size": { "width": 1904, "height": 3040 } } } }
```

| 缺口 | 现状（实测/静态） | 旁路 |
|---|---|---|
| **1. 分片 APK 不收** | CLI 明文 `split APK bundles are unsupported` | **`adb` 已在位且 cell 可达**：`adb devices` → `10.177.0.2:5555 device`。`reports/droidloom-deploy-20261126.md` §2 已用 `install-multiple` 装过 Limbus 三 split（`Success`）⇒ **旁路已上机验证** |
| **2. 无 GMS** | `ls /usr/lib/droidloom/addons` → **No such file or directory** | 需自备 LiteGapps（≤512 MiB，`module.prop` 形）+ aapt2/apksigner/Java 环境 + **全新 `data_dir`** + 升到 0.1.0-49+（`droidloom-app-compat-20261125.md` §1.3） |
| **3. 无宿主侧 aapt/aapt2/apksigner** | `which aapt aapt2 apksigner` → **全空** | 图标提取不用自己做（droidloom 已做）；**只有 GMS 路线需要它** |
| **4. cell 无默认路由 ⇒ 无外网** | `adb shell ip route` → 只有 `10.177.0.0/30 dev wlan0 proto kernel src 10.177.0.2`；`ping 223.5.5.5` → `PING_FAIL` | 需宿主侧 NAT/默认路由（与 `reports/droidloom-deploy-20261126.md` §5 缺口-1 同项，**仍未修**） |
| **5. 无反作弊/PI** | Limbus 装上但 `AppSealing` 初始化即 `Kill Process` | **不可旁路**（§4 天花板） |
| **6. 无相机/传感器/触觉 broker** | `reports/waydroid-droidloom-userland-interface-20261026.md` §2 X4：`/dev/input` 为空 tmpfs，`sys/class/leds` 无可 bind 面 | 需上游 `droidloom-devices`（braun/dmail 依赖），**不在 MVP 内** |

在版：`droidloomctl 0.1.0`；`/etc/droidloom/package-state.json` 仍记 `release: 49`，`/var/lib/droidloom/upgrade-51` 存在（`reports/droidloom-upgrade-51-ime-20261127.md` 记 0.1.0-51 running / doctor 0 blockers）⇒ 实际 runtime = **0.1.0-51**（静态+实测混合，`droidloomctl --version` 不打印 release 号）。

### 1.4 内核/宿主前置：两条路都**不需要动内核**

```sh
ssh elden 'zgrep -E "CONFIG_ANDROID_BINDERFS|CONFIG_ANDROID_BINDER_DEVICES" /proc/config.gz'
```

```
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
```

现役内核 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8-dirty #5`，根 `/dev/sda17` 190G（可用 **159G**），合成器 = `phoc/phosh`（0.1.0-51 起 `linux-drm-syncobj` 已可选，presenter 回退到 DMA-BUF fence ⇒ **2026-11-11 那张 phoc 补丁不再是硬前提**）。

---

## 2. 四个候选（同一把尺子）

**小时数假设（统一口径，务必按此理解）**：① 1 h = 一个熟悉本仓库上下文的工程师 1 小时；② 不含"读文档/找资料"时间（本仓库已有 20+ 篇报告兜底）；③ 不含物理动作（刷写/装机）；④ 含自检与失败重试的必要轮次各 1 次；⑤ **不含**相机/传感器/触觉/PI 这些"天花板项"（§4 单列，任何候选都不计入）。

| | **A. Waydroid + 自建 apk 前端** | **B. droidloom install+launch 前端** | **C. redroid/headless + Wayland 桥** | **D. 不跑 Android runtime** |
|---|---|---|---|---|
| **形态** | `waydroid init`（VANILLA/GAPPS）→ LXC 里跑 LineageOS → 自写 CLI+GTK：装包 / 图标提取 / .desktop 生成 / 窗口策略 / 权限预置 | 薄封装 `droidloomctl install` + `adb install-multiple` 兜底分片；图标与 .desktop **复用 droidloom 自带**；window-policy/权限预置做配置写入 | 容器化 AOSP 镜像（redroid）headless 起，靠 `scrcpy`/屏幕捕获 + 输入注入桥到 Wayland | 原生 Linux 替代 / Web/PWA / Box64+Wine 跑 x86 应用 |
| **MVP 小时** | **24–36 h**（bring-up 14–22 + 前端 8–12 + 图标/desktop 4–6；**假设**：老经验可复用，见下行风险） | **8–14 h**（前端 CLI 4–6 + GTK 4–6；分片旁路 1–2；权限预置 1–2）；**核心链 0 h（已通）** | **30–50 h**（binder + 软件渲染 + 捕获/注入 + 音频 + 网络，全是从零） | 4–60 h（视能力目标；**得不到"跑 apk"**） |
| **要重编 Android 镜像？** | **否**（`ota.waydro.id` 预编译 LineageOS；GAPPS 变体也是预编译） | **否**（base 903 MB + image 67 MB + runtime 11 MB 均为上游 release 预编译；本机已有的 locals 补丁不是 MVP 前提） | **否**（社区预编译 redroid 镜像），但**内核模块/渲染路径要试** | 不适用（无 Android） |
| **动内核态？** | 否（binderfs 已在） | 否（binderfs 已在） | **可能要**（`ashmem`/dmabuf heaps/`binderfs` 组合，redroid 版本敏感） | 否 |
| **上游依赖** | waydroid 1.6.3（Debian 包，已在） + lxc 6.0.4（已在） + Mesa/freedreno + `ota.waydro.id` | droidloom 0.1.0-51（已装） + `adb`（已在） + polkit/subuid（已配） | redroid 镜像 + scrcpy + 输入注入（`wayland-ime`/uinput） | Wine/Box64/Turnip-zink/Proton — **与 apk 无关** |
| **覆盖度：能跑哪些** | **最广**：arm64 APK（含分片，`waydroid app install` 支持），GMS 变体一个开关就有；**但 UI 单窗口**（`show-full-ui`），**没有真正的 per-app 窗口** | arm64 **独立 APK** 直接；**分片走 adb 旁路**；**per-app 独立 Wayland 窗口**（`reports/droidloom-deploy-20261126.md`：Settings/rednote 起窗口）。**无 GMS**（成本高、成功率未证）；**arm64-only**（纯 `armeabi-v7a` 包预期装不上） | 理论最广（AOSP 完整），实际受"捕获+注入"限制：**单窗口、触控延迟、无 Wayland 原生缩放** | **跑不了任何 APK** |
| **GMS** | **便宜**：`waydroid init -s GAPPS`（预编译，含 gapps） | **贵且不确定**：自备 LiteGapps + 全新 data + aapt2/apksigner + 0.1.0-49+；即便成功 Play 仍显示 **uncertified**（上游原文，`app-compat-20261125.md` §1.1） | 部分镜像自带 gapps 变体；仍 uncertified | 无 |
| **DRM / PI** | **结构性不可达**（Waydroid `test-keys`/`userdebug` 直出；无 TEE） | **结构性不可达**（shared-kernel 无 Android SELinux 私有策略；上游明文 "Play Integrity are not supported claims"） | 同上 | 不适用 |
| **主要风险** | ① **从零 bring-up**：本机 Waydroid 现已"未初始化"，而历史 14 条硬依赖（D1–D14）里 D6/D7/D10/D11/D13/D14 **全部要重做一遍**（相机 provider 64 位补丁、`config_nodes` 漏项、音频 4 修、`/dev/fuse`）；② 单窗口 UX 与用户「点开就跑」预期不符；③ kernel 7.3 + `arm64_only` 镜像组合未在现 rootfs 上验过 | ① **cell 无外网**（在线 App 全废）；② 分片旁路依赖 `adb` 常开（安全面 trade-off）；③ 窗口尺寸被 Android task bounds 覆盖（需 `task resize` 兜底）；④ 上游 0.x 日更、契约漂移 | ① 无 per-app 窗口（产品目标直接不达标）；② 输入/音频/DPI 全靠自己；③ 无既有资产 | 目标不匹配（用户要的是 apk） |
| **判据强度** | 实测（§1.1）+ 静态（14 条依赖表） | **实测（已通）** + 实测缺口（§1.3） | 静态/行业惯例，**零实测** | 静态 |

### 2.1 为什么 A 的"24–36 h"是**乐观值**
`reports/waydroid-droidloom-userland-interface-20261026.md` §1 列的 14 条硬依赖中，属于"镜像/容器内部行为"的 8 条（LXC 配置、`config_nodes`、音频 4 修、`/dev/fuse`、`/dev/dma_heap`）**在我们换过 rootfs 之后全部回到零点**（`/var/lib/waydroid` 只剩 cfg + log）。所以 A 不是"加一个前端"，而是 **"重做一遍 Waydroid 上机 + 再加一个前端"**。这条路历史上做过，所以不是不可能，只是**不是 MVP**。

### 2.2 为什么 B 是"最划算"
用户要的四段链条里，**后两段（网格图标 / 点开就跑）droidloom 已经免费提供**，且是**比 Waydroid 更好的形态**（每 App 一个独立 Wayland 窗口，而非一整块 Android 桌面）。真正缺的只是**前三段的产品化**（apk 拖进来 → 分片识别 → 装 → 校验图标落地）+ **两个运行时缺口**（外网、窗口尺寸兜底）。

---

## 3. 最短 MVP：B 形态，10 步，每步一个判据

> 形态选定：**droidloom 薄封装**（CLI 优先，GTK 后置）。**不动 AOSP 镜像、不动内核态、不换合成器、不重启 greetd**。
> 标记 🔵 = **本机（仓库侧，纯用户态，零设备写入）当场可落地**；🟢 = 设备侧用户态可逆写；🟡 = 涉及运行时策略，需用户点头。

| # | 步骤 | 判据（可自动断言） | 落地面 |
|---|---|---|---|
| 1 | 🔵 写 `tools/apk-install/apk_install.py` 骨架（`plan` / `install` / `verify` 三动词，argparse + `--json`） | `apk-install --self-test` 通过：对 `~/apk-20261125/` 现存 4 个包解析出 `{pkg, versionCode, abis, splits[]}` 与 `SHA256SUMS` 逐字一致 | **本机即可**（不碰设备） |
| 2 | 🔵 分片判定器：`base.apk` 单包 → `droidloomctl install`；`*.xapk/*.apks/base+config.*` → 组 `adb install-multiple` 命令行（dry-run 只打印） | 对 Limbus 三 split 输出**恰好一条** `install-multiple`，顺序 base→`config.arm64_v8a`→`UnityDataAssetPack`；单包输入输出 `droidloomctl install` | **本机即可** |
| 3 | 🔵/🟢 `.desktop`+图标一致性校验器（复用现役 6 条真样本做回归基线） | 6/6 通过：`Exec` 里的包名在 `droidloomctl applications` 里存在、`Icon=` 指向的 png 存在且 ≥1 KiB、`StartupWMClass` == 包名 | 本机（读设备只读输出） |
| 4 | 🟢 安装执行（每步留回执）：`droidloomctl install <apk>` 或 `adb -s 10.177.0.2:5555 install-multiple …` | `adb shell pm list packages \| grep <pkg>` 命中 **且** 60 s 内 `droidloomctl applications` 出现该包 **且** `.desktop` 与 `.png` 同时落地 | 设备用户态 |
| 5 | 🟢 启动验证：`droidloomctl launch <pkg> --json` | 返回 `object=` / `task=`；随后 `dumpsys window windows` 里该 task 的 `mBounds` 与第 6 步策略一致 | 设备用户态 |
| 6 | 🟡 窗口策略落地（**已知坑**：`window-policy-v1.json` 只作用于"无尺寸的初始 configure"，被 Android task bounds 覆盖） | 二级判据：`configure` 尺寸 == 策略值；若被覆盖，用 `cmd activity task resize <task> 0 0 1904 3040` 兜底并记入策略表（`reports/droidloom-display-sizing-20261126.md` §2 已实测有效） | 设备用户态策略 |
| 7 | 🟢 权限预置：手册化白名单 → `appops set` / `pm grant`（CAMERA / LOCATION / POST_NOTIFICATIONS / READ_MEDIA_*） | `dumpsys package <pkg> \| grep -c granted=true` ≥ 手册条目数；且 App 首启**不再弹**已知权限框 | 设备用户态 |
| 8 | 🟢 卸载/回滚动词：`pm uninstall <pkg>` + 清理 `.desktop`/图标 | 卸载后 `droidloomctl applications` 不再列出、`.desktop`/`.png` 消失；`adb shell pm list packages` 不命中 | 设备用户态 |
| 9 | 🟢 GTK4/libadwaita 前端（列表 + 装 + 打开 + 卸载 + 窗口尺寸下拉），`X-AppStream-Ignore` 免污染 | 从文件管理器双击 apk 到窗口出现 **≤3 次点击、零终端**；GUI 的所有动作与 CLI 等价（同一 JSON 输出） | 设备用户态 |
| 10 | 🟢 双击关联优先级：新增我们的 `application/vnd.android.package-archive` handler（**不改** Waydroid 包内那个 `NoDisplay=true` 条目，靠 mimeapps 优先级取胜） | `xdg-mime query default application/vnd.android.package-archive` 返回我们的 desktop 文件名 | 设备用户态 |

**MVP 之外的必做项（不进 10 步，但决定"在线 App 能不能用"）**：cell 默认路由/NAT（缺口 4）。判据：cell 内 `ip route` 出现 `default` 且 `curl`/`wget` 取回 200。成本 4–8 h，**取决于 veth/nft 现状，未取证**。

---

## 4. 这条路线的能力上限（apk 管理器**一条都不会改善**）

| 项 | 为什么 apk 管理器救不了 | 证据 |
|---|---|---|
| **Widevine / DRM 播放** | 无 TEE、shared host kernel 无 Android 私有 SELinux 策略；连 L3 库都没有 | `reports/c3-pi-tiers-closeout-20261110.md`；`docs/threat-model-v2.md:116-119`（上游原文） |
| **Play Integrity / 反作弊** | 属性投影"必要不充分"；AppSealing 在 Limbus 上**实测秒杀** | `reports/droidloom-deploy-20261126.md` §0 行 2 |
| **GMS 依赖 / Play 许可 / FCM 推送** | 无 GMS ⇒ 依赖 GMS 的登录、地图、FCM；装了 GMS 仍是 `uncertified` | `reports/droidloom-app-compat-20261125.md` §1.1 |
| **相机** | 需要 runtime 侧 HAL provider + 宿主 loopback（Waydroid 侧我们做过 64 位补丁）；droidloom 侧**连 broker 都没有** | 同上 §2 X4；`reports/waydroid-camera-provider-rootcause-20261019.md` |
| **传感器 / 触觉** | droidloom 容器无 `sys/class/leds` 可 bind、`/dev/input` 是空 tmpfs ⇒ 桥的挂载面消失 | 同上 §2 X4 / §3 A3 |
| **32 位专有 APK** | droidloom 镜像 arm64-only；Waydroid `arch=arm64_only` ⇒ 纯 `armeabi-v7a` 包预期装不上 | 实测 `waydroid.cfg`；`app-compat` §2.1 ABI 表述 |
| **窗口/DPI 适配** | 不是 apk 层问题：Android task bounds 覆盖 Wayland 初始 configure | `reports/droidloom-display-sizing-20261126.md` §1 |
| **手势/输入边界** | 触控边缘滑动仍透传前台应用（lisgd 不 grab） | `reports/droidloom-osk-keypad-hide-20261128.md` §A |

**一句话**：apk 管理器是**分发与呈现层**（把包安全装进 runtime、把图标放进网格、把窗口调成能看的大小）。**凡是"需要硬件信任根、需要 GMS 生态、需要 runtime HAL"的东西，都会被同一条天花板压住**——先做它能抬高「可用 App 数量」，但抬不高于 `c3` 三档结论与 `app-compat` J1/J2/J3 的天花板。

---

## 5. 复现命令（全部只读，可直接重跑）

```sh
# 1. Waydroid 现状（判据：输出 "not initialized"、images 目录不存在）
ssh elden 'waydroid --version; waydroid status; sudo -n ls /var/lib/waydroid/images'
# 2. Waydroid 的 .desktop 供给面（判据：只有 3 个桩，且 apk 桩 NoDisplay=true）
ssh elden 'ls /usr/share/applications | grep -i waydroid; cat /usr/share/applications/waydroid.app.install.desktop'
# 3. droidloom cell + 应用目录（判据：running + Android is ready + listed 6）
ssh elden 'systemctl is-active droidloomd; droidloomctl status; droidloomctl applications'
# 4. 网格图标证据（判据：6 个 droidloom-*.desktop + 6 张 128x128 png，Icon= 与文件名对应）
ssh elden 'ls /home/xuqianhui1001/.local/share/applications/droidloom-*.desktop | wc -l;
           find /home/xuqianhui1001/.local/share/icons -name "droidloom-*" | wc -l'
# 5. 分片缺口 + adb 旁路可用（判据：help 明文 unsupported；adb devices 有 10.177.0.2:5555）
ssh elden 'droidloomctl install --help | grep -i split; adb devices'
# 6. 无 GMS（判据：No such file or directory）
ssh elden 'sudo -n ls /usr/lib/droidloom/addons'
# 7. cell 无外网（判据：ip route 无 default；ping FAIL）
ssh elden 'adb -s 10.177.0.2:5555 shell "ip route"; adb -s 10.177.0.2:5555 shell "ping -c1 -W2 223.5.5.5 || echo FAIL"'
# 8. 内核不需要动（判据：BINDERFS=y 且 BINDER_DEVICES 三件）
ssh elden 'zgrep -E "CONFIG_ANDROID_BINDERFS|CONFIG_ANDROID_BINDER_DEVICES" /proc/config.gz'
# 9. Waydroid 的 init 通道是通的（判据：200）
ssh elden 'curl -s -o /dev/null -w "%{http_code}\n" https://ota.waydro.id/system/lineage/waydroid_arm64_only/VANILLA.json'
```

---

## 6. 建议（给总管的一句话）

**先做 B（droidloom 薄封装，8–14 h），把 §3 的 1–4 步当作第一刀**；同步把 §3 第 10 步（cell 出网）当独立小任务评估。
只有当出现"必须 GMS / 必须 Play 商店装包"的真实需求时，才回到 A —— 那时 A 的价值是**一个开关拿到 GAPPS 预编译镜像**，代价是重做 14 条依赖中的 8 条并接受单窗口 UX。C/D **不建议**：C 连"per-app 窗口"这个产品目标都不满足，D 直接不解决用户问题。
