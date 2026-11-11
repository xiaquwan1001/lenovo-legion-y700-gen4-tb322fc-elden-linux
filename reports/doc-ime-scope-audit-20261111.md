# 文档口径核实：IME / 中文输入 真实进度与剩余动作（2026-11-11）

- lane：文档口径核实（**全程零设备动作**：未 ssh / 未 fastboot / 未重启；只读仓库 + 主机源码树 + 主机侧 apt 索引 + GitHub API）
- 触发：用户 2026-11-11 原话——「说中文候选只差组词是过时口径，实际上昨天关于 phosh+Fcitx5 需要自己编译某些接口的调查以及 xime 技术的调查没有完成闭环。」
- 核实结论（先给判定）：**「只差组词」这句不成立**（理由见 §1 末）；本轮把「自编 phoc 到哪一步」这条 **U5 结案**（11-10 报告 §8 的 U5 主机侧可核部分已核完），并**否掉一条并行 lane 的归因**（「换 phoc 0.59 就会弹」——主机侧 diff 证明 0.58→0.59 的 enable→activate 逻辑逐字未变，见 §4 D12）。
- check-doctor 基线：进入前 `FAIL=0 WARN=6`；结束时同（见 §6）。
- 产物：本文件（不改任何 SSOT；INDEX/TASKS/DEVICE/PITFALLS/versions/PROGRESS 一字未动）。

## 0. 复现命令（本文所有断言的入口）

```sh
# 0a) 现役 0.58.0 源码是否含 IM keyboard-grab NULL 修复（= 上游 bb1f7465）
tar xf /opt/elden/arm64-sid/build-phoc/src58/phoc_0.58.0.orig.tar.xz -C /tmp/p058chk
grep -n "keyboard_grab = data" /tmp/p058chk/phoc-0.58.0/src/input-method-relay.c      # 119、136 ⇒ 未修
grep -n "keyboard_grab = relay->input_method" /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src/input-method-relay.c  # ⇒ 0.59~rc1 已修
# 0b) Debian 0.58.0-1 的 debian/patches 是否 backport（答案：否）
grep -c "input-method-relay" /opt/elden/arm64-sid/build-phoc/src58/debian/patches/Apply-upstream-patches.patch       # 0
grep -n "^--- a/" /opt/elden/arm64-sid/build-phoc/src58/debian/patches/Apply-upstream-patches.patch                   # 只碰 subprojects/wlroots-0.20.x
# 0c) 我们 2026-10-18 那份补丁能否直接落到 0.58.0（答案：能，无需重写）
cp -r /tmp/p058chk/phoc-0.58.0 /tmp/p058apply && cd /tmp/p058apply \
  && patch -p1 --dry-run -l < /home/xuqianhui/y700-elden/patches/upstream/phoc-im-keyboard-grab-2026-10-18/0001-input-method-relay-Fix-NULL-deref-in-keyboard-grab-d.patch   # rc=0
# 0d) wvkbd 是否需要自编（答案：不需要，Debian sid arm64 有包）
grep -m2 -A2 "^Package: wvkbd$" /opt/elden/arm64-sid/var/lib/apt/lists/mirrors.ustc.edu.cn_debian_dists_sid_main_binary-arm64_Packages   # Source: wvkbd (0.15-1) / Version: 0.15-1+b1
# 0e) 在机合成器实际广告的 IM 相关全局（2026-11-11 上机留档，本 lane 未新增设备动作）
grep -n "input_method\|text_input\|virtual_keyboard" reports/artifacts/droidloom-l2-phoc-20261111/device-wayland-info-with-syncobj.txt
# 0f) 孤儿报告核查（全仓 README/INDEX 是否引用 11-10 IME 报告）
grep -rln "ime-phosh-fcitx5-invest-20261110" --include=*.md . | grep -v "^./reports/\|^./TASKS/sessions/"    # 空 ⇒ 无 README 引用
# 0g) xime 复核（本轮重新抓，与 11-10 一致）
gh api repos/ximeiorg/XimeChe --jq '{lic:.license.spdx_id,pushed:.pushed_at,stars:.stargazers_count}'

# 0h) 0.58 → 0.59~rc1 到底改了什么 IM 相关代码（⇒ §4 D12）
diff -u /tmp/p058chk/phoc-0.58.0/src/input-method-relay.c \
      /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src/input-method-relay.c | grep -c '^@@'   # = 1（只有 grab destroy 那一处）
grep -n PHOC_TEXT_INPUT_VERSION /tmp/p058chk/phoc-0.58.0/src/desktop.c \
      /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src/desktop.c                               # 两版都是 2
diff -rq /tmp/p058chk/phoc-0.58.0/src /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src         # 共 4 个文件不同
diff -u /tmp/p058chk/phoc-0.58.0/src/phosh-private.c /opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1/src/phosh-private.c | grep -ci '^[-+].*input'   # 0

# 0i) 并行 lane 的设备实测（本 lane 未新增设备动作）
grep -n 'enable\|activate' reports/ime-osk-pop-20261111.md | head
```

> 主机源码树引用声明：`/tmp/p058chk/phoc-0.58.0` = pristine 0.58.0（由 `phoc_0.58.0.orig.tar.xz` 解出）；
> `/opt/elden/arm64-sid/build-phoc/phoc-0.59~rc1` = 上游 0.59~rc1，**但 `src/desktop.c` 已被我们的 syncobj 补丁污染**
> （同目录有 `desktop.c.orig`）⇒ 比 IM 只看 `input-method-relay.c`（无 `.orig`，内容 = 上游 `bb1f7465` 形态），或重拉 pristine tarball。

---

## 1. IME / 中文输入 真实进度分档表

> 现役栈（2026-11-11）= Debian/Mobian 根 + phosh 0.59~alpha1 + **phoc 0.58.0（我们自编的 syncobj 件，见 §2）**
> + OSK = `phosh-osk-stevia` + `fcitx5 5.1.23-1 --disable waylandim`（`rootfs/debian/daily-baseline.sh:154,161`）。
> **注意：SSOT 里 C11 写的栈（squeekboard）与现役栈已不是同一套**（见 §4 D5）。

| 档 | 内容 | 证据（命令 / 文件:行 / 原文） |
|---|---|---|
| **A 已成立** | Rime 组词引擎 + GTK3/4 IM 模块在位（缺它中文完全不工作，Alpine 世代已证） | `rootfs/debian/daily-baseline.tsv:46-49`（fcitx5 / fcitx5-rime / fcitx5-frontend-gtk3 / gtk4 全 P1）；`reports/zh-ime-touch-chinese-20261020.md` §1 表 3 |
| **A 已成立** | 触屏可切中/英：顶栏胶囊（GTK4 layer-shell）+ 应用网格图标；配置器可开（真 UI 包 `fcitx5-config-qt`） | `rootfs/debian/ime/fcitx5-indicator{.py,.service}`、`fcitx5-ime-toggle{,.desktop}`；`reports/ime-chinese-20261109.md` §6（用户实机「胶囊可见 / 配置器能开」） |
| **A 已成立** | 协议面不缺任何东西：`zwp_input_method_manager_v2` v1、`zwp_text_input_manager_v3` **v2**、`zwp_virtual_keyboard_manager_v1` v1、`zwlr_virtual_pointer_manager_v1` v2，共 **57 全局** | `reports/artifacts/droidloom-l2-phoc-20261111/device-wayland-info-with-syncobj.txt:252,253,258,260`；`grep -c "^interface:"` = 57 |
| **A 已成立** | 「谁弹键盘」机制链已查清（源码级）：客户端 `zwp_text_input_v3.enable`/`show_input_panel` → phoc `activate_osk()` → `wlr_input_method_v2.activate` → stevia 显示；IM 槽位单占 = `zwp_input_method_v2`（**不是** `text-input-v3`） | `reports/ime-phosh-fcitx5-invest-20261110.md` §1.2（`src/input-method-relay.c:484-491`）、§1.3、§6.0（更正 §1.3 的版本常量误判）、§7.2 |
| **B 未成立（现役栈）** | **点输入框 → 屏幕键盘自动弹出**：现役 Debian 栈失败，且**两层独立断裂**：① 默认会话三变量 = `fcitx` ⇒ GTK 不建 `zwp_text_input_v3`；② 即使去掉模块、客户端真发 `enable`，**phoc 0.58 也不向 input-method-v2 客户端发 `activate`** | ① `reports/ime-chinese-20261109.md` §6 表（用户实机「弹不出来」）+ `reports/ime-osk-pop-20261111.md` §4-U3（`/proc/1109/environ` 三变量）；② `reports/ime-osk-pop-20261111.md` §2/§3（E4 有 `enable()` 3/3、E3 stevia 零 activate）+ 本报告 §4 D12（0.58→0.59rc1 该文件仅一处 grab 修复，enable→activate 逻辑逐字未变） |
| **B 未成立（现役栈）** | 因此 **「中文组词上屏」这条验收在现役栈上并未过**：2026-10-20 那次 `nihao`→「你好」是 **Alpine 3.24 / Phosh 0.55.0 / phoc 0.55.1 / squeekboard** 世代，OSK 与合成器都换过两代 | `reports/zh-ime-touch-chinese-20261020.md` 头部（vk127 / Alpine / Phosh 0.55.0）；`reports/ime-chinese-20261109.md` §6（现役 = 弹不出键盘 ⇒ 无输入路径可言） |
| **C 未定案（路线）** | 三条路线里**只有 A1 有现成件、零上游**：`elden-ime-focusd`（kimpanel `SetRelativeSpotRect` → `sm.puri.OSK0.SetVisible`）源码在仓，但 **Debian 侧没有部署路径**（部署脚本还是 Alpine 的 `apk`） | `patches-userland/zh-ime/elden-ime-focusd.c`；`scripts/deploy-zh-ime.sh:24`（`apk list -I` 预检）；`grep -rn focusd rootfs/debian/` ⇒ 零命中 |
| **C 未定案（路线）** | A2/A3（fcitx5 开 waylandim 独占槽 + wvkbd 走 virtual-keyboard 画键盘）= 「能组词 + 有键盘」唯一干净解；**前提是 phoc 带 IM-grab NULL 修复**，否则 fcitx5 一 grab 就崩合成器 | 11-10 报告 §2.1（`waylandimserverv2.cpp:214-222` grab）、§4(b)（wvkbd `main.c:1240-1252` 无条件建 virtual-keyboard、`im_unavailable()` 空实现）、§7.3 表；本轮核实修复**不在**在机件（§2） |
| **D 已否掉** | 自编候选条 `candidate-bar`（杀掉候选照常）；libei/EIS（phoc 0.58 全树零命中）；squeekboard 复活（上游项目描述原文「This software is unmaintained」+ 在机装了不跑）；`phoc #302` 当「不弹」根因（那条是层叠遮挡） | `patches-userland/zh-ime/withdrawn/README.md`；11-10 报告 §4(b)、§1.5、§2.3 |
| **D 已否掉（xime 这条）** | `ximeiorg/XimeChe` **不能当解**，只能当「`input-method-v2 + virtual-keyboard + 自绘候选` 在 wlroots 类合成器上可行」的结构先例 | 本轮复核原文（README:9「当前输入法只支持 wayland 应用和 KDE（KWin）桌面，不支持 Gnome」；README:13「我只考虑支持KDE，不会考虑支持Gnome」）；`crates/xime-wayland/src/im_v2.rs` 现 1046 行、`:38 zwp_text_input_v3`、`:58 ZwpVirtualKeyboardManagerV1` ⇒ 协议需求与 fcitx5 waylandim 同构；元数据 `GPL-3.0 / pushed 2026-11-02 / 35★`（本轮 `gh api` 重取，与 11-10 一致） |

**「只差组词」这句为何不成立**（一句）：现役 Debian 栈连「点输入框弹出屏幕键盘」都还没过（11-09 用户实机否；**今日 16:40 并行 lane 的 E0/E2/E3/E4 已把断裂层钉到 phoc 合成器侧**，见 §1.1），而「能组词 + 有键盘」的 A2/A3 卡在**需要我们自己编进 phoc 的 IM keyboard-grab 修复**（本轮已核：在机自编件与 Debian 0.58.0-1 都**不含**），且**换 phoc 0.59 并不会让键盘自己弹**（§4 D12）——所以「剩一次人手触摸」把至少 3 类 agent 可自办的动作（判据实验、phoc 重编、A1 桥部署）全部隐藏了。

### 1.1 与并行 lane 的交叉核实（写作时 16:3x 仓库内无设备结果；16:40 出现 `reports/ime-osk-pop-20261111.md`）

| 项 | 该 lane 的设备结果 | 对本报告的影响 |
|---|---|---|
| E0 OSK 本体 | **通过**（`SetVisible true` → `Visible (<true>,)`） | 排除 stevia 渲染/三道闸 ⇒ 本报告 §3 原 M1 的 E0 半段作废（已完成） |
| E2 槽位 | **通过**（`grep -c 'Input method unavailable'` = **0**；stevia 绑到 `zwp_input_method_v2#43`） | U2 结案 |
| E4/E3 | 客户端 GTK3/GTK4 均发出 `enter → enable() → commit()`（3/3），**stevia 零条 activate** ⇒ **断裂在 phoc** | §1 的 B 档从「机制层推定」升级为「设备实测」；U1 结案 |
| U3 / U6 / U12 | U3 确认 `GTK_IM_MODULE=fcitx` 真在 GUI 会话环境里；U6 设备上**没有** `wayland-protocols` 包/目录；U12 `org.kde.impanel` **无 owner**（⇒ A1 桥确实没部署，支持本报告 D5/D8） | 本报告 §6 未完成项相应删除 U3/U6/U12 |
| 其归因「怀疑缺 `bb1f7465`／与 11-10 报告 §5 假说一致 ⇒ phoc ≥ 0.59」 | **本报告主机侧证据否掉这条归因**（见 §4 D12） | 直接影响排期：换 0.59 不解决「不弹」 |

---

## 2. 自编 phoc 现状核实（11-10 报告 §8 的 **U5 结案**）

### 2.1 在机跑的是不是我们编的？——是

| 项 | 值 | 证据 |
|---|---|---|
| 在机 `/usr/bin/phoc` | **我们的** `phoc-0.58.0-syncobj`，7 543 080 B，sha256 `863731b0b323…7cb5` | `out/phoc-syncobj-arm64-20261111/MANIFEST.md`「★ 用哪个」表 + 上机步骤；`reports/droidloom-l2-phoc-syncobj-20261111.md` §9（`install -m 0755 phoc-0.58.0-syncobj /usr/bin/phoc`、`systemctl restart greetd`、两条判据全绿） |
| 回退件 | `/usr/bin/phoc.orig-0.58.0`，sha `d36d9d94…`（发行版原件） | 同上（`cp -a` 备份段） |
| 编译方式 | phoc 0.58.0 原源 + **Debian `Apply-upstream-patches.patch`** + **我们的 `0001-desktop-advertise-linux-drm-syncobj-v1.patch`**，内嵌 wlroots-0.20.2 静态 | `scripts/build-phoc-arm64.sh` 第 3/4 步（**只有这两层 patch**）；`PITFALLS` #612 |
| 在机产物形态 | 57 全局含 `wp_linux_drm_syncobj_manager_v1` v1；`NEEDED` 无 libwlroots | `reports/artifacts/droidloom-l2-phoc-20261111/device-wayland-info-with-syncobj.txt:275`；构建脚本第 6 步自校验 `[ "$WR" = 0 ]` |

### 2.2 0.59 的 `bb1f7465`（IM keyboard-grab NULL 修复）在不在「Debian 0.58.0-1」或「我们自编件」里？——**都不在**

| 检查 | 结果 | 原始输出 |
|---|---|---|
| 上游 0.58.0 原源 | **未修**（`data` 直接当 grab 指针） | `src/input-method-relay.c:119  struct wlr_input_method_keyboard_grab_v2 *keyboard_grab = data;`（`grep -n "keyboard_grab = data"` ⇒ 119、136） |
| 上游 0.59~rc1 | **已修**（改从 relay 取） | `phoc-0.59~rc1/src/input-method-relay.c` diff hunk：`- struct … *keyboard_grab = data;` → `+ keyboard_grab = relay->input_method->keyboard_grab;` |
| Debian `phoc_0.58.0-1` 打包补丁 | **不含该修复**：唯一那份 `Apply-upstream-patches.patch`（244 行）只碰 3 个文件，全在 `subprojects/wlroots-0.20.x/`（`include/wlr/types/wlr_text_input_v3.h`、`types/wlr_text_input_v3.c`、`types/wlr_layer_shell_v1.c`）；`grep -c "input-method-relay"` = **0** | `grep -n "^--- " …/debian/patches/Apply-upstream-patches.patch` |
| **我们的在机自编件** | **同样不含**：构建脚本只叠两层 patch，其中我们的补丁 `--- a/src/desktop.c` / `+++ b/src/desktop.c`（**只改 desktop.c**） | `grep -n "^--- \|^+++" patches/phoc-syncobj-20261111/0001-desktop-advertise-linux-drm-syncobj-v1.patch` |
| 我们 2026-10-18 那份同缺陷补丁能否直接落到 0.58.0 | **能，不需要重写**（11-10 报告 §5 猜「因 wlroots 0.20 行为变化需重写」= **偏保守，可撤回**） | `patch -p1 --dry-run -l … 0001-input-method-relay-Fix-NULL-deref-….patch` ⇒ `checking file src/input-method-relay.c` `rc=0`（且 Debian 那份 patch 不碰同文件 ⇒ 无冲突） |

**⇒ 一句话现状**：**我们已经在自编并在机运行 phoc（0.58.0 + syncobj），但它只补了 droidloom 要的 syncobj 全局，没有补 IME 要的那一处 IM keyboard-grab NULL 修复；再叠一层现成补丁 + 一次 chroot 重编（脚本第 5 步自陈 15–25 min）就能拿到 A2/A3 的前置。** 上游侧该修复已进 0.59~rc1（`bb1f7465`，2026-11-08），我们那份 MR 仍「待推送」（`patches/upstream/phoc-im-keyboard-grab-2026-10-18/README.md` 状态行）。

---

## 3. 闭环所需动作（6 条；每条 = 动作 / 判据 / 代价 / 是否需人 / 是否需上游）

| # | 动作 | 判据（可复跑） | 代价 | 需人（触摸/盯屏） | 需上游 |
|---|---|---|---|---|---|
| **M1** | **补 E4 缺的两个探针**（回答「phoc 为何不发 activate」，决定要不要上游）：复跑 E4 时同屏看 ① 客户端 `WAYLAND_DEBUG=1` 里 `zwp_text_input_manager_v3` 的 **bind 版本**；② 合成器侧 `G_MESSAGES_DEBUG=all` 是否有 `Enabling text input when input method is gone` | bind = **2** ⇒ 属协议 v2 语义（早退，客户端须自发自 `show_input_panel`）⇒ **不是 bug，不上游**，且换任何 phoc 版本都不弹；bind = **1** 仍无 activate ⇒ 真 phoc bug ⇒ 按 `ime-osk-pop` §3 素材投递上游 | ≈5 min（E0/E2/E3/E4 已由并行 lane 跑完，本条只是补探针） | 半（日志可代判） | 看结果（bind=1 时上游） |
| **M2** | **E5/E6 收尾**：三道闸（`screen-keyboard-enabled` / activation-filter / hw-tracker）与「phosh 不跟随焦点」行为实测（E0 已间接给一半答案） | `gsettings get … screen-keyboard-enabled` = true 且无外接键时 hw-tracker allow-active=true；不点输入框时 `Visible` 恒 false | ≈2 min；拔插属物理动作 | **是**（拔插） | 否 |
| **M3** | **A1 落地（优先级最高）**：给 Debian 做一份 `focusd` 部署段（源码现成 `patches-userland/zh-ime/elden-ime-focusd.c`，落 `rootfs/debian/ime/` + user unit），并给 `scripts/deploy-zh-ime.sh` 标「仅 Alpine 世代」。**为何现在最优先**：设备实测两层断裂都在 text-input/activate 路上（§1.1），focusd 走 **kimpanel(DBus) → sm.puri.OSK0** 完全绕开两者 | `busctl --user list \| grep -F org.kde.impanel` 有 owner（现测为 **0**，`ime-osk-pop` §4-U12）；点输入框 → `sm.puri.OSK0.Visible` `false→true`；`grim` 见键盘 | 158 行 C + 1 个 unit（现成件）+ 设备侧需 `gcc/gio` 开发头（`deploy-zh-ime.sh:38` 已预检，缺则跳过）；主机侧交叉编更稳 | **是**（真触摸一次最稳，或 grim 判） | 否（本地胶水，不上游） |
| **M4** | **重编 phoc 带 IM-grab 修复**（≠ 修「不弹」，只防崩；见 D12/D13）：把 2026-10-18 那份 patch 作第 3 层入 `scripts/build-phoc-arm64.sh` 第 3 步（紧跟 `0001-syncobj.patch` 之后） | 构建前 `patch --dry-run` rc=0（**本轮已过**）；产物新 sha 入 `MANIFEST.md`；上机 `wayland-info` 仍 **57 全局含 syncobj**、`droidloom-wayland` 仍 0 次 `bind failure`（不退化）；新增一条：`fcitx5 -r`（开 waylandim）起停 3 次后 **phoc PID 不变** | chroot 重编 15–25 min + 换 1 个二进制 + `systemctl restart greetd` | 否 | **修复本身已在上游 0.59**（`bb1f7465`）；我们那份 MR 待推 = 可选上游化，不阻塞本机 |
| **M5** | **A2/A3 实验**（须 M4；且不期望「自动弹」，键盘显隐靠 M3 的桥或手动图标）：`apt install wvkbd`（**Debian sid arm64 有 `0.15-1+b1`，不需要自编 OSK**）+ fcitx5 开 waylandim + M4 的 phoc | 键盘由 wvkbd 画、候选由 fcitx5 出、`nihao`→「你好」**且无重复上屏**（= 同时结掉 U8/U9） | 装 1 包 + 换 phoc + 一次真触摸；回退 = `apt remove wvkbd` + 装回 `phoc.orig-0.58.0` | **是** | 否（纯组合现成件；fcitx5 上游对 phoc 无兴趣，`gh search issues --repo fcitx/fcitx5 phosh` = 0 条） |
| **M6** | **xime 结项**：在 SSOT 里把 XimeChe 定位为「结构先例，非候选方案」，并停止后续投入 | SSOT 一行含作者原文「不支持 Gnome」（README:9/README:13）+「`im_v2.rs` 的协议需求与 fcitx5 waylandim 同构」+「v2 路径从未在 phoc 跑过（过度外推禁止）」 | 文档一行 | 否 | 无 |

**顺带（不计 6 条内，属正确性收口）**：U5 结案（§2）与「判据从『有没有 `show_input_panel`』改成『有没有 `zwp_text_input_v3.enable`』」（11-10 报告 §6.0）应一并并入 SSOT，否则后人还会按错判据查。

---

## 4. 文档漂移清单（本轮增量；只建议，未改任何文件）

> 格式：`严重度 | file:line | 现状 | 证据 | 建议精确改法`。共 **13 条 = P0×2 / P1×6 / P2×5**。

### P0

**D1 | TASKS/README.md:89（**§2** 的 C11 行；派工单写「§1 的 C11 行」——实际 C11 在 §2，行号 89 = 唯一命中）**
- 现状：C11 = `✅ 已上机验收`，验收标准写「点输入框→触屏键盘→拼音→候选→上屏中文」，栈写 **squeekboard**。
- 证据：现役栈 OSK = stevia（`rootfs/debian/daily-baseline.sh:132` 段标题「OSK 槽位留给 phosh-osk-stevia」、`:154` unit 描述同）；现役栈上**点输入框键盘弹不出来**（`reports/ime-chinese-20261109.md` §6 表，用户实机）；「已验收」那次是 Alpine + squeekboard（`reports/zh-ime-touch-chinese-20261020.md` 头部）；squeekboard 上游原文「This software is unmaintained」且**在机装了不跑**（11-10 报告 §1.5、头部在机包表）。
- 建议：验收列改「**（2026-10-20 Alpine/squeekboard 世代）** 点输入框→…→上屏中文；**现役 Debian/stevia 栈 2026-11-09 复测 OSK 不弹 ⇒ 验收失效**」，状态 emoji 由总管定（见 §4.1 计数影响）。

### P1

**D2 | TASKS/README.md:136（§4 开放待办的 G1-37 尾段）**
- 现状：`**剩 ① 中文「组词上屏」实测**（…需人手触摸，非 agent 可代办）`。
- 证据：§1 的 B/C 档 + §2（自编 phoc 不含 IM-grab 修复 ⇒ A2/A3 未开跑）+ 11-10 报告 §8（U1–U13 **13 项全开**，§6 的 E0–E8 **零执行**，其中 E0/E1/E2/E4 属「只读/秒回退」的 agent 可办项）。
- 建议：整段替换为本报告 §5.2 的一句短句。

**D3 | TASKS/README.md:133-134（§4 同一条内）**
- 现状：`**取舍**：`text-input-v3` 槽位 OSK 与 fcitx5 二选一 —— 现为 `--disable waylandim`（保 OSK）…`（把「二选一」写成协议定局，且槽位名字错）。
- 证据：单占的是 `zwp_input_method_v2`（11-10 报告 §1.2，`src/input-method-relay.c:484-491`）；`zwp_text_input_manager_v3` 在机广告 **v2** 且可多客户端（`…/device-wayland-info-with-syncobj.txt:253`）；「不占槽也能出键盘」的现成实现存在（wvkbd `main.c:1240-1252` 无条件建 virtual-keyboard，`im_unavailable()` 是空函数 ⇒ 被 fcitx5 占槽仍可打字，11-10 报告 §4(b)）；且 `wvkbd 0.15-1+b1` 在 Debian sid main（§0d 命令）。
- 建议：删「二选一」定局句，改写为「**现役 A 模式（`--disable waylandim`）只是取舍之一，不是协议定局**：单占槽位是 `zwp_input_method_v2`；走 A2/A3（fcitx5 开 waylandim + `wvkbd` 走 `virtual-keyboard`）可同时拿到组词与键盘，前提见 §5.1『未闭环』」。

**D4 | PITFALLS/README.md:271（索引行 232 = `#578`）**
- 现状：「Phosh/phoc **没有 SNI 托盘** …；且 **`text-input-v3` 槽位 OSK 与 fcitx5 二选一**（`fcitx5 -r` 能组词但无键盘 / `--disable waylandim` 有键盘但 Wayland 原生应用不能组词）」。
- 证据：同 D3（名字错 + 结论被 11-10 报告 §4/§7 否掉一半）。**归因侧没错**：「`GTK_IM_MODULE=fcitx` ⇒ GTK 不建 `zwp_text_input_v3` ⇒ OSK 收不到 activate」这条**是对的**（fcitx5-gtk README 首行自述 = 「Gtk im module … and … **dbus** client library」，11-10 报告 §2.2；Alpine 世代实测 = `PITFALLS/sessions/59` §5），所以**不要把「OSK 不弹」也归到「抢槽位」**——两件事：抢槽位 = 键盘没了；`GTK_IM_MODULE` = 焦点信号没了。
- 建议：`#578` 改写为「**没有 SNI 托盘 ⇒ fcitx5 图标不显示（自绘胶囊补）**；单占槽位是 `zwp_input_method_v2`，OSK 与 fcitx5 抢同一槽 ⇒ 后到者 `unavailable`；**另一条独立故障**：`GTK_IM_MODULE=fcitx` 让 GTK 绕过 `text-input-v3` ⇒ phoc 不发 activate ⇒ OSK 不弹；『组词 vs 键盘』不是定局，wvkbd 不占槽即可共存（需 phoc 带 IM-grab NULL 修复）」。

**D5 | PROGRESS.md:118**
- 现状：`**C11 触屏中文输入法**（squeekboard + fcitx5/Rime + OSK0）` 作为 G2 现状口径。
- 证据：同 D1（现役 OSK = stevia；`grep -rn squeekboard rootfs/debian/` ⇒ 只在 `pkgmap.tsv:182` 与 `apt-list.txt:119`，OSK 段早已换）。
- 建议：同步为「（fcitx5/Rime + OSK 槽位归 phosh-osk-stevia；2026-11-09 现役栈 OSK 不弹，剩余动作见 `reports/ime-phosh-fcitx5-invest-20261110.md`）」。

**D6 | `reports/ime-phosh-fcitx5-invest-20261110.md`（整份报告 = 孤儿）**
- 现状：全仓**没有任何 README/INDEX 引用**它；只有 `TASKS/sessions/2026-11-10-C3三档收口与H2巡检.md:30` 与 `…Waydroid网络定案与droidloom复评.md:26` 两处会话记录。
- 证据：`grep -rln "ime-phosh-fcitx5-invest-20261110" --include=*.md . | grep -v "^./reports/\|^./TASKS/sessions/"` ⇒ 空；`grep -n "输入法\|IME\|ime" INDEX.md` ⇒ 空；check-doctor §13 只校「被引用路径存在」，不校孤儿 ⇒ 门是绿的（`checked=457`）。
- 建议：总管并入时加三处指针——§4 该条末尾「权威 `reports/ime-phosh-fcitx5-invest-20261110.md`」、C11 行「相关」列、PITFALLS `#578` 行的指针列。

### P2

**D7 | rootfs/debian/daily-baseline.sh:139-140（注释）**
- 现状：「Phosh 0.55 的 phosh-osk-stevia 走 `zwp_virtual_keyboard`（**不是** input-method v2）」。
- 证据：stevia 明确拿 `zwp_input_method_manager_v2`（11-10 报告 §1.5，`pos-input-method.c:301`）；virtual-keyboard 是**输出方向**；在机 registry 同时有两者（`:252` 与 `:258`）。
- 建议：注释改为「stevia **同时**是 `zwp_input_method_v2` 客户端（拿 activate）与 `virtual_keyboard` 建立者（送按键）；fcitx5 开 `waylandim` 会抢走前者」。

**D8 | scripts/deploy-zh-ime.sh（Alpine-only，却仍是 SSOT 的「部署入口」）**
- 现状：C11 行与 `patches-userland/zh-ime/README.md:4` 都写「部署 `bash scripts/deploy-zh-ime.sh`」。
- 证据：脚本 `:24` 用 `apk list -I` 预检且**失败也继续**（`:23-25` 那段尾有 `|| true`），随后第 1 步就 `scp` 覆盖 `/usr/local/bin/`、`/usr/share/applications/`、`/etc/xdg/autostart/{org.fcitx.Fcitx5,elden-ime-focusd}.desktop`，第 2 步「禁用旧方案」；现役设备是 Debian（`TASKS/README.md` T17 行：`/etc/os-release` = Debian forky/sid）⇒ 照 SSOT 执行会在现役设备上装 squeekboard 世代自启项，与 stevia 栈对打。
- 建议：脚本头加 3 行「**世代限定**：仅 Alpine 3.24（`apk`）；Debian/Mobian 现役栈请用 A1 部署段（待建，见 `reports/doc-ime-scope-audit-20261111.md` §3 M3）」，并在预检失败时 `exit 1`（别继续写设备）。

**D9 | rootfs/debian/pkgmap.tsv:182 + rootfs/debian/apt-list.txt:119（squeekboard）**
- 现状：squeekboard 仍在构建 apt-list 与 pkgmap（注为「OSK（C11 输入法栈）」）。
- 证据：11-10 报告头部（在机 `squeekboard 1.43.1-2.1` **装了但未跑**）+ 上游自述 unmaintained。
- 建议：要么把注改成「备用 OSK / 仅历史栈，现役 = stevia」，要么下次基线回收时移除（P2 卫生，不阻塞）。

**D10 | reports/ime-chinese-20261109.md:37、:49（§3 两处结论）**
- 现状：「Wayland 的输入法槽位（`text-input-v3`）同一时刻只能有一个客户端」、「这条取舍**没有免费解**」。
- 证据：11-10 报告 §8「另记文档不一致 #2」已登记同一件事；机制层正确表述见 D3。
- 建议：报告顶部加一行横幅「**§3 的槽位名与『无免费解』结论已被 `reports/ime-phosh-fcitx5-invest-20261110.md` §1.2/§4(b) 更正**」（历史报告保留原文，只挂更正指针）。

**D11 | out/phoc-syncobj-arm64-20261111/MANIFEST.md「构建」行 + TASKS/README.md:1065（§5 Q3 的 ②）**
- 现状：MANIFEST 写「脚本 `scripts/build-phoc-arm64.sh`（**`--version 0.58` 分支**）」，但脚本的入参是环境变量 `VER=${VER:-0.58.0}`（无 `--version` 解析）；Q3 的 ② 还写「已落地（**主机侧**）」并指 `out/phoc-syncobj-arm64-20261111/**phoc**`——那正是 MANIFEST 里标「**勿上机**」的 0.55.1 件，而在机跑的是 `phoc-0.58.0-syncobj`。
- 证据：`grep -n "VER=\|version" scripts/build-phoc-arm64.sh`（只有 `VER=${VER:-0.58.0}`）；`out/…/MANIFEST.md` 附节标题「附：`phoc`（0.55.1…勿上机）」；上机件与判据见 `reports/droidloom-l2-phoc-syncobj-20261111.md` §9。
- 建议：MANIFEST 改 `VER=0.58.0 bash scripts/build-phoc-arm64.sh`；Q3 的 ② 改「已**上机**（在机 = `phoc-0.58.0-syncobj`，sha `863731b0…`；回退件 `/usr/bin/phoc.orig-0.58.0`）」并把产物名从 `…/phoc` 改 `…/phoc-0.58.0-syncobj`。

**D12 | reports/ime-osk-pop-20261111.md §3 末段与 §6.1（并行 lane，16:40 新增）**
- 现状：「与调研报告 §5 假说一致：phoc 修复提交 `bb1f7465` 不在 0.58 中，**D2 路线必须 phoc ≥ 0.59**」+「**怀疑缺 `bb1f7465` 等价修复**」（把 E3/E4 实测到的「收不到 activate」归因给该修复）。
- 证据（主机侧，本报告实测）：`diff -u` 0.58.0 ↔ 0.59~rc1 的 `src/input-method-relay.c` = **只有一个 hunk**（grab destroy 的指针来源），`handle_text_input_enable()` 与 `activate_osk()` **逐字未变**；两版的 `src/desktop.c` 都是 `#define PHOC_TEXT_INPUT_VERSION 2`（`grep -n PHOC_TEXT_INPUT_VERSION`）⇒ **升到 0.59 不会改变 enable→activate 行为**；`bb1f7465` 只修「IM 销毁 keyboard grab 时崩合成器」。
- 建议：① 把该报告的归因行改为「**断裂在 phoc，但不是缺 `bb1f7465`**」；② 补两条候选机制与判据：**(a)** 客户端把 `zwp_text_input_manager_v3` bind 到 **v2** ⇒ `handle_text_input_enable()` 里 `wl_resource_get_version() >= ZWP_TEXT_INPUT_V3_SHOW_INPUT_PANEL_SINCE_VERSION(=2)` **早退**（协议 v2 语义：客户端须自己发 `show_input_panel`，GTK 直到 main 分支才有，11-10 报告 §6.0-H2）；**(b)** `text_input_is_focused()` 假（`focused_surface == NULL`）——若客户端 bind=1 仍无 activate，就是真 phoc bug，**可上游**（素材已在 `ime-osk-pop` §3）。两者都可用一条 `WAYLAND_DEBUG` 日志分辨。（另：`diff -rq src/` 共 4 个文件不同——除我们的 syncobj 补丁（`desktop.c`）与上游 grab 修复（`input-method-relay.c`）外，`phosh-private.c` / `xdg-toplevel.c` 的 diff 里 **零条 input 相关行** ⇒ 0.59 不可能从其它路径修好「不弹」。）

**D13 | reports/ime-phosh-fcitx5-invest-20261110.md §5 末行与 §9 第 3 句**
- 现状：「**最低版本建议（若走 D2）**：`phoc ≥ 0.59`（或给 0.58 打 `bb1f7465` 等价补丁）」与 §9「前提是 **phoc ≥ 0.59（`bb1f7465`）** 否则 grab NULL 崩合成器」——同一句里把「不弹」与「崩」两件事绑在一起，后人会读成「换 0.59 就能弹」。
- 证据：同 D12（该修复与 enable→activate 无关）。
- 建议：拆成两句写死口径：「**`phoc ≥ 0.59`（或自编叠 `bb1f7465` 等价补丁）只解决 fcitx5 grab 时的合成器崩溃**；**『点输入框不弹』与 phoc 版本无关**，现役唯一绕法 = A1 focusd 桥（不依赖 activate）或客户端显式 `show_input_panel`」。

### 4.1 §0 计数是否受影响（只判断，未改数字）

- 口径来源：`scripts/check-progress-counts.sh` 以 **§1/§2 行内 emoji 为真值**（脚本头注释 + `COMPLETE={✅🟢🎯}`），现算 = `G1 35/36 [✅32 🟢3 🟡1 ❌2]`、`G2 9/13 [✅7 🟢1 🎯1 🟡3 ⬜1]`；§0 只有两处手写数字，由 check-doctor §16 对账。
- **本报告 §5 的文案不动 emoji ⇒ §0 数字不变**（这是推荐做法：G1-37 行的「包/配置基线」确实完成了；IME 真实剩余动作放 §4 开放待办 + C11 行的验收限定里）。
- **升级点（若总管选择另一条路）**：把 C11 从 `✅` 降 `🟡` ⇒ G2 变 **8/13**；把 G1-37 从 `✅` 降 `🟡` ⇒ G1 变 **34/36**。任一改法**必须同批改 §0 两处手写数字**，否则 `scripts/check-doctor.sh` §16 直接 FAIL。按铁律本轮**不自行改**，只登记。

---

## 5. 替代文案（可直接粘贴）

### 5.1 G1-37 / C11 合并口径（一段；建议贴 §1 C11 行的「描述」格或 §4 条目正文）

> 体量：**322 个汉字**（含必要标识符共 1 655 非空白字符，`python3` 实测）⇒ 汉字数在 600 字限内；若要更短，用 §5.2 的单句。

> **中文输入（G1-37 用户态 + C11 触屏输入合并口径，2026-11-11）**
> **现役栈** = Debian/Mobian + phosh 0.59~alpha1 + **自编 phoc 0.58.0-syncobj** + `phosh-osk-stevia` + `fcitx5 5.1.23 --disable waylandim`。
> **已成立**：Rime 组词 + GTK3/4 IM 模块 + 配置器（真 UI 包 `fcitx5-config-qt`）+ 顶栏胶囊与应用网格的中/英切换；协议面不缺（在机 registry **57 全局**含 `zwp_input_method_manager_v2` v1、`zwp_text_input_manager_v3` **v2**、`zwp_virtual_keyboard_manager_v1` v1，`reports/artifacts/droidloom-l2-phoc-20261111/device-wayland-info-with-syncobj.txt:252-258`）。
> **未成立**：现役栈上**点输入框 OSK 不弹**（2026-11-09 用户实机；今日 16:40 `reports/ime-osk-pop-20261111.md` 把层钉实为 **两层**：GTK 三变量=fcitx 不发 text-input，**且 phoc 0.58 收到 `enable` 也不发 `activate`**）⇒ 「组词上屏」验收**在现役栈未过**；2026-10-20 的「你好」上屏属 Alpine + squeekboard 世代，OSK 与合成器都已换代。
> **三条路线**：**A1** stevia 占槽 + 部署仓库现成 `elden-ime-focusd`（kimpanel `SetRelativeSpotRect`→`SetVisible`），零上游零装包，代价 = 无自动收起、Wayland 原生应用不能组词；**A2/A3** fcitx5 开 `waylandim` 独占 IM 槽 + `wvkbd` 走 `virtual-keyboard` 画键盘（Debian sid 有 `wvkbd 0.15-1+b1`，OSK 不必自编），是「能组词 + 有键盘」的唯一干净解；**已否** = 自编候选条、libei（phoc 0.58 无实现）、复活 squeekboard（上游 unmaintained）、将 `phoc #302`（层叠遮挡）当「不弹」根因、**XimeChe**（作者原文「不支持 Gnome」，只作 `im_v2 + virtual-keyboard + 自绘候选` 的结构先例）。
> **未闭环（≠「只差一次触摸」）**：① 现役栈的「不弹」是**两层独立断裂**（设备实测 3/3：客户端已发 `enable`，**phoc 0.58 不转 `activate`**，`reports/ime-osk-pop-20261111.md` §2/§3），**换 phoc 0.59 不解决**（0.58→0.59~rc1 的 `input-method-relay.c` 仅一处 grab 修复，两版 `PHOC_TEXT_INPUT_VERSION` 都是 2）⇒ 现役唯一绕法 = **A1 focusd 桥**（走 DBus，不依赖 activate）；② A2/A3 才需要把 `bb1f7465` 等价补丁编进 phoc（防 grab 崩）——**Debian `phoc_0.58.0-1` 未 backport、我们的在机自编件也不含**，而本仓 2026-10-18 那份补丁 `patch --dry-run` 已 rc=0 ⇒ 一次 chroot 重编；③ 尚缺：E5/E6/E7/E8 + U8/U9/U10/U11/U13，且判据按 11-10 报告 §6.0 更正为查 `zwp_text_input_v3.enable`（不是 `show_input_panel`）。
> 证据：`reports/ime-phosh-fcitx5-invest-20261110.md`（机制 / 路线 / 判据，权威）、`reports/ime-chinese-20261109.md`（现役症状）、`reports/zh-ime-touch-chinese-20261020.md`（Alpine 世代验收）、`out/phoc-syncobj-arm64-20261111/MANIFEST.md`、`reports/doc-ime-scope-audit-20261111.md`（本核实）。

### 5.2 §4 开放待办用的短句（一条）

> - **G1-37 / C11 中文输入（口径更正：不止「差一次触摸」）** —— 现役 Debian 栈**点输入框 OSK 不弹**，且是**两层独立断裂**（三变量=fcitx 不发 text-input；**phoc 0.58 收到 `enable` 也不发 `activate`**，设备 3/3 实测 ⇒ **换 phoc 0.59 不解决**）；**A1** 聚焦桥（kimpanel→`sm.puri.OSK0`，走 DBus 故绕开两层）源码在仓但**没有 Debian 部署路径**（`scripts/deploy-zh-ime.sh` 仍 Alpine，且设备 `org.kde.impanel` 无 owner）；要「能组词 + 有键盘」须 **A2/A3**（fcitx5 开 `waylandim` + `wvkbd`，包在 Debian sid 现成），其前置是**需要我们把 IM keyboard-grab NULL 修复编进 phoc**——上游 `bb1f7465` 只在 **0.59~rc1**，**在机自编 phoc 0.58.0-syncobj 与 Debian 0.58.0-1 都不含**（本轮核实；本仓现成补丁 `--dry-run` 已 rc=0）；另 E5–E8 与 U8–U13 待跑。权威 `reports/ime-osk-pop-20261111.md`（设备实测）、`reports/ime-phosh-fcitx5-invest-20261110.md`（机制/路线）、`reports/doc-ime-scope-audit-20261111.md` §2/§3/§4。

---

## 6. 未完成项 / 边界（诚实标注）

1. **E5/E6/E7/E8 未跑**（本 lane 零设备；**E0/E2/E3/E4 已由并行 lane 于 16:40 交付**，见 `reports/ime-osk-pop-20261111.md`）⇒ 剩下的「为什么不发 activate」只差两个探针（§3 M1）。
2. **U8/U9/U10/U11/U13 需上机**（grab 与 virtual-keyboard 互作、重复上屏、Firefox 后端、stevia locate 断言、phosh 第三处兜底）；**U1/U2/U3/U6/U12 已结案**（并行 lane）；**U5 本轮主机侧结案**（§2）。
3. **设备上是否已装 wvkbd 未核**（只能证明 Debian sid 索引里有包）⇒ M5 前先 `dpkg -l wvkbd`。
4. **A1 的 Debian 部署段本轮未写**（本 lane 禁改 SSOT/脚本），只给了动作与判据（§3 M3）。它现在是**优先级最高的一条**（两层断裂都在 text-input/activate 路上，focusd 走 DBus 全绕开）。
5. **xime 只复核了元数据 + README + `im_v2.rs` 结构**（本轮 `gh api` 与 raw 抓取全部成功，无抓取失败项）；**未在设备上试过，也无意试**——判定为「结构先例，非候选方案」（§3 M6）。
6. **phoc 重编与上机未做**（零设备 + 2 h 时间盒）：M4 只做到「补丁可干净落到 0.58.0」这一步。
7. **11-10 报告 §5 那句「补丁需重写」已可撤回**（`patch --dry-run` rc=0）——但那是「代价被高估」的更正，不影响它「0.58 不含修复」的结论。
8. check-doctor：进入前与写完本文件后各跑一次，均 **FAIL=0 WARN=6**（WARN 集与本轮无关，未新增）。
