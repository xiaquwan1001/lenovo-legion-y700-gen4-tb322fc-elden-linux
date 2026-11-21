# 从零把「虚拟键盘 + 中文输入 + 候选窗」做到可用 —— 一页 RUNBOOK（考古整理，2026-11-21）

> lane 类型：只读考古整理（不装包、不写设备、不改 TASKS 正文）。
> 目标读者：一台刚重建完 Debian/trixie 根（`/` = `/dev/sda17`、Phosh 会话可用、无任何 IME 包）的操作者。
> 所有结论附命令 + 原始输出片段；未验证项显式标 **未验证**。
> 状态三档：**A=已完成/可复现** · **B=部分可用** · **C=已知不可用（含已撤回方案）**。

## 0. 一页结论（先读这段）

### 0.1 现机是什么（2026-11-21 10:0x 只读实测，**与历史报告的前提不同，先读这张表**）

| 项 | 现值 | 历史报告写的是 | 影响 |
|---|---|---|---|
| 内核 | `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0` | vk184 / vk189-00002 | 无（用户态无关） |
| Debian | `13.7`（trixie） | trixie | — |
| **phoc** | **`0.46.0-1`（发行版版本号）** | 0.58.0-1 自编 syncobj / 0.59~rc1 自编 | 我们的 phoc 补丁（#615 版本门、syncobj）**在现机几乎肯定不存在**（版本号差两代），但 `dpkg-divert`/`apt-mark` 未核（设备 10:2x 后不可达）⇒ **未验证**；历史「补丁后仍不弹」的判据链要重做 |
| **phosh** | **`0.46.0-3+deb13u1`** | 0.58.0-1 / 0.59~rc1 | 同上 |
| **OSK 包** | **`phosh-osk-stub 0.46.0-1`**（`/usr/bin/phosh-osk-stub --allow-replacement`，PID 1466，持有 `sm.puri.OSK0`） | 「`phosh-osk-stevia 0.59~rc1`」/「squeekboard 1.43」 | **名字对不上是同一角色**：`--allow-replacement` + `sm.puri.OSK0` ⇒ 就是历次报告里的「stevia 那一层」；trixie 发行版的包名是 `phosh-osk-stub`。squeekboard **未装**（`dpkg -l squeekboard` 空） |
| fcitx5 | `5.1.12-2`，进程 `/usr/bin/fcitx5 -d`（**手工起的**，PPID=1，09:21） | unit 拉起 `-r --disable waylandim` | 现机**无** `--disable waylandim`，且 unit `inactive` |
| rime | `fcitx5-rime 5.1.10-2` + `~/.local/share/fcitx5/rime/`（build/luna_pinyin.userdb 在） | 同 | 可用 |
| `~/.config/fcitx5/profile` | `Items/0=rime`（**对**），`DefaultIM=keyboard-us`（不影响新 IC） | — | P2 的判据已满足 |
| `~/.config/fcitx5/config` | **不存在** ⇒ `CurrentUI=classicui`（实测 `gdbus … CurrentUI` → `('classicui',)`） | 11-15 曾手工写 `CurrentUI=kimpanel` | 现机候选链路 = classicui（phoc 上建不出窗） |
| `/etc/environment.d/50-elden-ime.conf` | 有，且**含 `GTK_IM_MODULE=fcitx`** | 11-15 §3c 已注释掉（`.bak-20261115`） | **重建根把 #618/T4 的修复又冲掉了** |
| `/usr/share/dbus-1/services/org.fcitx.Fcitx5.service` | `Exec=/usr/bin/fcitx5`（**无 flag**） | 11-15 T1 已改 `-r --disable waylandim` | 同上，重建即回退（#660 场景） |
| `elden-ime-focusd` | 二进制在位（sha **`5cf98e1d…`** = 仓库 `out/ime-host/` 同件）、unit `enabled` 但 **`inactive`**；用户总线上 **`org.kde.impanel` 无 owner** | 11-13 上机时在跑 | **现机自动弹/收桥没在跑** |
| `graphical-session.target` | **`inactive`** | — | 这是 focusd/fcitx5 都不自启的**结构性原因**（见 P1 判据） |

⇒ 一句话：**现机 = 刚重建的 stock trixie 根 + 只有 `profile`(rime) 与两个 user unit 被脚本捞回来，其余 T1/T2/T4 三项手工修复全部丢失；OSK 桥 `enabled` 却没跑。**

### 0.2 三档状态（严格按证据分，不把撤回方案写成可用）

| 档 | 内容 | 关键证据 |
|---|---|---|
| **A 已完成/可复现** | ① 包清单 + 配置脚本幂等（`daily-baseline.tsv` + `daily-baseline.sh` + `scripts/mobian-daily-baseline.sh`）；② 中文组词引擎接线（`Items/0=rime` 判据 + rime 数据在位）；③ `elden-ime-focusd` 二进制可重建且现机件与仓库件同 sha；④ 桥的「弹/收」行为（2026-11-12/13 真机上机：Firefox URL 栏 `Visible` false→true，关窗 2 s 内收，`ELDEN_IME_IDLE_SEC=4` 生效）；⑤ 配置层体检脚本 `scripts/ime-candidates-check.sh`（只读）；⑥ `phosh-osk-stub` 的 `sm.puri.OSK0` 控制面本身（`SetVisible`/`Visible` 通） | §2–§6 各段原始输出 |
| **B 部分可用** | ① OSK 自动弹/收：**机制成立、现机未运行**（桥 inactive、target inactive）；② GTK3/GTK4 应用里的中文组词：**栈换代后未复验**（#653 遗留「GTK3 不建 fcitx IC」；现机是 0.46 栈，与 0.59 结论不可互推）；③ 中/英切换入口（应用网格图标 `fcitx5-ime-toggle` + 胶囊 `fcitx5-indicator`）：脚本有、现机未核 | §7 的「未验证」行 |
| **C 已知不可用** | ① **候选窗**（classicui 在 phoc 建不出窗；kimpanel 唯一的画手 `elden-ime-candidates.py` 已按 #646 **撤下**，且撤下是**正确**的——它 map/unmap layer surface 会打断输入上下文）；② `wvkbd + fcitx5 --disable waylandim 关掉` 那条「单栈」路线：需 phoc 带 IM-grab NULL 修复，现机 phoc 是 0.46 原件 ⇒ 不可用；③ 「phoc 升版本就能自动弹」：已证伪（#615：`enable` 对 v≥2 客户端**故意** return） | §7、§5 |

### 0.3 从零部署的最短路径（命令级，细节在各阶段）

```sh
# 0) 一条命令装包+落配置（幂等，主机侧驱动；--check 只报告）
scripts/mobian-daily-baseline.sh --check     # 先看缺什么
scripts/mobian-daily-baseline.sh             # 装 P0/P1 + 跑 daily-baseline.sh

# 1) 三项手工修复（脚本**不覆盖**，重建根后必丢 —— 见 §8 断层 G1）
#    T1 D-Bus 激活 Exec 带 flag；T2 CurrentUI=kimpanel；T4 摘掉 GTK_IM_MODULE

# 2) 起桥（注意 graphical-session.target 在本栈不 active ⇒ 需要显式 start）
systemctl --user start elden-ime-focusd

# 3) 唯一判据入口
scripts/ime-candidates-check.sh              # exit 0 = 配置层全绿
```

> 但**第 3 步全绿也不等于「候选窗能看见」**：绿只代表「该有的件/参数在位」，画候选的那一半在 C 档。

## 1. 阶段表

| 阶段 | 目标 | 载体（仓库件 → 设备落点） | 状态档 | 判据（一条） |
|---|---|---|---|---|
| **P0** | 包与字体到位 | `rootfs/debian/daily-baseline.tsv`（P0/P1） → `scripts/mobian-daily-baseline.sh` | A | `--check` rc=0（包齐 + `MISS=0`） |
| **P1** | fcitx5 起来、自启、不抢 OSK 槽 | `daily-baseline.sh §3` → `/etc/systemd/user/fcitx5.service` + `/etc/environment.d/50-elden-ime.conf` | B（现机 `graphical-session.target` inactive ⇒ 不自启） | `pgrep -x fcitx5 \| wc -l` = 1 且 args 含 `--disable waylandim` |
| **P2** | 新 IC 进 Rime、候选数据非空 | `daily-baseline.sh §3b`（`Items/0=rime`） | A（现机已满足） | `profile` 的 `[Groups/0/Items/0] Name=` = `rime` |
| **P3** | 屏幕键盘能显/能隐 | 现机的 `phosh-osk-stub`（`sm.puri.OSK0`）；**不装 squeekboard/wvkbd** | B | `busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible` 能读写 |
| **P4** | 自动弹/收（kimpanel 桥） | `out/ime-host/elden-ime-focusd` + `rootfs/debian/ime/elden-ime-focusd.service` → `/usr/local/bin/` + `/etc/systemd/user/` | B（机制 A，现机未跑） | `busctl --user list \| grep -c org.kde.impanel` = 1 且 owner=桥 |
| **P5** | 候选窗可见 | 无可用件（`elden-ime-candidates.py` 已撤） | **C** | 打字过程中 `NotifyFocusOut` = 0 且屏上有候选（截图） |

## 2. P0 装包

### 2.1 清单（`rootfs/debian/daily-baseline.tsv`，列 `包名 | 级别 | 组 | 为什么`）

| 包 | 级别 | 为什么（原文摘） | 2026-11-21 现机 |
|---|---|---|---|
| `locales` | P0 | `/etc/locale.gen` 为空、`LC_ALL` 报错 | 在位 |
| `fonts-noto-cjk` | P0 | 中文显示的唯一来源（装前中文全是豆腐块） | 在位 |
| `fonts-noto-core` | P0 | `mobian-phosh-base` Depends | 在位 |
| `fcitx5` | P1 | 中文输入主框架；Debian 不带 user unit（脚本落一个 `--disable waylandim` 的） | `5.1.12-2` |
| `fcitx5-rime` | P1 | Rime 引擎（拼音/双拼） | `5.1.10-2` |
| `fcitx5-frontend-gtk3` | P1 | GTK3 IM 模块（候选窗由它在客户端内自绘 —— 见 §7） | `5.1.3-3` |
| `fcitx5-frontend-gtk4` | P1 | GTK4/libadwaita（Phosh 自身、gnome-control-center） | `5.1.3-3` |
| `fcitx5-config-qt` | P1 | **真 UI 包**；只有 `fcitx5-configtool` 薄壳时点图标「没反应」（11-09 定位） | `5.1.8-1` |
| `fonts-cantarell` / `fonts-noto-color-emoji` | P1 | Phosh UI 字体 / emoji | 在位 |
| `libgtk4-layer-shell0` + `gir1.2-gtk4layershell-1.0` | P1 | 顶栏胶囊 `fcitx5-indicator.py` 与（已撤的）候选浮条都用 GTK4 layer-shell | 在位 |
| `squeekboard` | **不在 tsv** | `apt-list.txt:121` 与 `pkgmap.tsv:186` 还留着它 | **未装**（正确：上游「unmaintained」，见 §5） |
| `wvkbd` | 无 | Debian sid main 有 `0.15-1+b1`（不需自编，`reports/doc-ime-scope-audit-20261111.md` §0d） | 未装（P5/单栈路线才需要） |
| `phosh-osk-stub` | 无（随 phosh 而来） | 本栈的 OSK 本体，提供 `sm.puri.OSK0` | `0.46.0-1` |

### 2.2 命令与判据

```sh
# 主机侧（cwd=/home/xuqianhui/y700-elden），一条命令装包 + 落配置：
timeout -k 10 900 scripts/mobian-daily-baseline.sh --check   # 只报告，rc=1=未达标
timeout -k 10 1800 scripts/mobian-daily-baseline.sh         # 装 + 配置 + 复查
```

判据原文（脚本自述，`scripts/mobian-daily-baseline.sh:19-22`）：① tsv 里每个 P0/P1 包 `dpkg` 状态 = `install ok installed`；② `daily-baseline.sh --check` 输出 `MISS=0`。

**期望输出尾部**：
```
  ok   包齐（NN 个）
  配置巡检：结果: MISS=0
结果: 已达标（日用基线就绪）
```

**失败判定 / 回退**：`--check` 打印的 MISS 行就是缺口（逐条对应 `daily-baseline.sh` 的 `say "[N. …]"` 段）；apt 只装不升级、`--no-remove`，回退 = `apt remove <包>`；脚本无写盘副作用除 `dpkg`（`device-lock.sh` 串行化）。

**注意**：`daily-baseline.sh §3` 会**写入** `GTK_IM_MODULE=fcitx`（`rootfs/debian/daily-baseline.sh:139-146`），这与 §3c 的 T4 结论（必须摘掉）**直接冲突** —— 见 §8 断层 G1。

## 3. P1 fcitx5 基础（环境变量 → unit → 自启 → 不抢 OSK 槽）

### 3.1 环境变量：本栈的正确值不是全部 `=fcitx`（两条判据互相矛盾，必须知道选哪条）

```sh
ssh elden-root 'cat /etc/environment.d/50-elden-ime.conf'
#   GTK_IM_MODULE=fcitx      ← 现机：重建后又写回来了
#   QT_IM_MODULE=fcitx
#   XMODIFIERS=@im=fcitx
ssh elden-root 'grep -n IM_MODULE /etc/environment'      # PAM 侧来源（会连 sudo -u 一起带）
```

| 取值 | 后果 | 出处 |
|---|---|---|
| `GTK_IM_MODULE=fcitx` | GTK 客户端走 D-Bus IM 模块（`im-fcitx5.so`），**不发** `zwp_text_input_v3.enable` ⇒ phoc/OSK 不知该弹；但客户端**能组词**（中文上屏） | `PITFALLS #618` A/B 表（`fcitx`=0/0/false；`wayland`=1/1/true） |
| 不设 / `wayland` | GTK 走自带 Wayland IM ⇒ 发 `enable`；但**没了 fcitx 组词**（stevia 组词未验） | 同上 + `#653` 遗留 |

⇒ **2026-11-15 的裁决（台账 T4）是「摘掉」**：`/etc/environment` 与 `/etc/environment.d/50-elden-ime.conf` 两处都注释掉（各留 `.bak-20261115`）。理由 =「#618 遮蔽使桥之外的自动弹/收不可能」。**但 `daily-baseline.sh §3` 又写回去** ⇒ 两条口径至今未统一（§8 G1）；**重建根后的默认行为 = 有遮蔽**。

判据（必须看 **phosh 进程的环境**，不是 shell）：
```sh
ssh elden-root 'tr "\0" "\n" < /proc/$(pgrep -x phosh | head -1)/environ | grep -E "^(GTK|QT)_IM_MODULE=|^XMODIFIERS="'
# 期望（T4 生效）= 无输出；现机 = 三行都在
```
生效时机：改 `/etc/environment.d/*` 后 `systemctl restart greetd` **不够**（user manager 不重建，phosh 仍带旧变量），必须 `systemctl restart user@1001.service`（会话断一次）—— `TASKS/sessions/2026-11-15-IME候选回归台账.md` §3c。

### 3.2 fcitx5 的启动（两条路 flag 必须一致）

unit 原文（`daily-baseline.sh` §3 写入；与现机 `/etc/systemd/user/fcitx5.service` 逐字相同）：

```ini
[Unit]
Description=Fcitx5 input method (Rime; waylandim disabled: phosh-osk-stevia owns the OSK slot)
After=graphical-session-pre.target
PartOf=graphical-session.target
[Service]
Type=simple
ExecStart=/usr/bin/fcitx5 -r --disable waylandim
Restart=on-failure
RestartSec=3
[Install]
WantedBy=graphical-session.target
```

enable 用**系统级** `/etc/systemd/user/graphical-session.target.wants/`（构建 chroot 没有用户 home，系统级才能构建/现场同一路径生效）：
```sh
ln -sf /etc/systemd/user/fcitx5.service /etc/systemd/user/graphical-session.target.wants/fcitx5.service
```

**两条启动路径**（`#660`，今天又踩了）：
```sh
ssh elden-root 'grep Exec /usr/share/dbus-1/services/org.fcitx.Fcitx5.service'
# 现机：Exec=/usr/bin/fcitx5        ← 无 flag ⇒ 任何 D-Bus 激活拉起第二个实例，退出时写回 profile（#619/#660）
# 期望：Exec=/usr/bin/fcitx5 -r --disable waylandim
```
T1 修法（改前留 `.bak`）：
```sh
ssh elden-root 'cp -a /usr/share/dbus-1/services/org.fcitx.Fcitx5.service{,.bak-$(date +%Y%m%d)}'
ssh elden-root 'sed -i "s|^Exec=/usr/bin/fcitx5\$|Exec=/usr/bin/fcitx5 -r --disable waylandim|" /usr/share/dbus-1/services/org.fcitx.Fcitx5.service'
```

判据（必须落到**会话用户的总线**，否则恒假 —— `PITFALLS #663`）：
```sh
UID_=1001; UR=/run/user/$UID_; UH=/home/xuqianhui1001
asuser() { setpriv --reuid=$UID_ --regid=$UID_ --init-groups env HOME=$UH \
  XDG_RUNTIME_DIR=$UR DBUS_SESSION_BUS_ADDRESS=unix:path=$UR/bus "$@"; }
asuser systemctl --user is-active fcitx5        # 期望 active（现机 inactive，进程是手工 -d 起的）
ps -eo args | grep -c '^/usr/bin/fcitx5 -r --disable waylandim'   # 期望 1
grep -c 'Wayland native input method protocol: 1' <fcitx5 日志>   # 期望 0（开 waylandim 会抢 OSK 槽）
```

**现机两个实测坑**：
1. `systemctl --user is-active graphical-session.target` = **inactive**（`ActiveEnterTimestamp` 空）⇒ `WantedBy=graphical-session.target` 的两个 unit **实际都不会自启**；现机 fcitx5 = 手工 `fcitx5 -d`（PID 1514，PPID=1，09:21:23）。
2. 所以「`is-enabled`=enabled」**不能当验收判据**：要么显式 `systemctl --user start fcitx5 elden-ime-focusd`，要么先让会话拉 active target（本栈 phosh/greetd 没人拉）。

### 3.3 失败判定 / 回退

| 失败表现 | 判定命令 | 处置 |
|---|---|---|
| fcitx5 没起 | `pgrep -x fcitx5\|wc -l` = 0 | `systemctl --user start fcitx5`，看 `journalctl --user -u fcitx5 -n 30` |
| 两个实例 | 上条 = 2 | 是 D-Bus 激活那条拉起的 ⇒ 先做 T1 |
| 抢了 OSK 槽（键盘不弹） | `grep -c 'Wayland native input method protocol: 1'` ≠ 0 | 加 `--disable waylandim` |
| 回退 | — | `systemctl --user disable --now fcitx5`（保留 OSK + 字面输入，基线不倒退） |

## 4. P2 中文输入（rime）

### 4.1 机制一句话（#619 实测）

fcitx5 给**每个新建输入上下文**用的是 `profile` 里 **`[Groups/0/Items/0]` 的 `Name=`**；`DefaultIM=` 只影响组内切换起点，**改不了新 IC 拿哪个引擎**。写成 `keyboard-us` ⇒ 中文看着能打、候选恒空。

### 4.2 设备现状（本轮实测，**已满足**）

```sh
sed -n '1,30p' /home/xuqianhui1001/.config/fcitx5/profile
#   [Groups/0] … DefaultIM=keyboard-us
#   [Groups/0/Items/0]  Name=rime          ← 只看这一行
#   [Groups/0/Items/1]  Name=keyboard-us
ls /home/xuqianhui1001/.local/share/fcitx5/rime
#   build  installation.yaml  luna_pinyin.userdb  sync  user.yaml
```

### 4.3 写 profile 的正确顺序（三条坑都要守）

```sh
# ① 先停 unit + 杀残留（两步都要），判据必须 = 0
systemctl --user stop fcitx5
for p in $(pgrep -x fcitx5); do kill -9 $p; done
sleep 2; pgrep -x fcitx5 | wc -l        # 必须 = 0（否则改了也会被"退出写回"覆盖）
# ② 此时才写（模板 = rootfs/debian/daily-baseline.sh:288-300）
# ③ 起 unit 后读回
systemctl --user start fcitx5; sleep 8
gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
  --method org.fcitx.Fcitx.Controller1.InputMethodGroupInfo 默认
# 期望 ('us', [('rime', ''), ('keyboard-us', '')])
```
坑：fcitx5 **退出时把内存态写回 profile**；`pkill -x fcitx5` 杀不掉（unit 立即拉起）；**`AddInputMethodGroup` 会新建 `[Groups/1]` 而 `GroupOrder` 只有 `0=默认`** ⇒ 顺序错乱且读回旧值，**不要用它**。

### 4.4 判据 / 失败 / 回退

| 判据 | 命令 | 期望 |
|---|---|---|
| 新 IC 引擎 | 开新窗（新 IC）后 `fcitx5-remote -n` | `rime` |
| 组顺序 | `InputMethodGroupInfo 默认` | `('us',[('rime',''),('keyboard-us','')])` |
| 候选数据 | `dbus-monitor "interface='org.kde.impanel2'"` 抓 `SetLookupTable` | 数组里有真汉字 `[你 那 呢 能 年]` |

注：`fcitx5-remote` 在**systemd user service 作用域**里常返回 0（无 IC），SSH 跑只能当提示、不能当门禁（`reports/ime-chinese-20261109.md` §2 坑 1）。
**稳定门禁 = `scripts/ime-candidates-check.sh` 的 `profile Items/0 = rime`**（只读，不调 `fcitx5-remote`）。

**回退**：`profile.bak-<date>`；`keyboard-us` 留在 `Items/1`，`Ctrl+Space` / 胶囊切回英文。

## 5. P3 OSK 选型与部署（本栈谁真能用）

### 5.1 四个候选与真实地位

| 候选 | 本栈能不能用 | 证据 | 结论 |
|---|---|---|---|
| **`phosh-osk-stub`**（历次报告里的「stevia」） | ✅ **现役那一层** | 现机 `PID 1466 /usr/bin/phosh-osk-stub --allow-replacement`，持有 `sm.puri.OSK0`；`busctl get-property … Visible` → `b false` | **选它**（已装，零成本） |
| `squeekboard` | 历史可用（Alpine/Phosh 0.55 世代），**现栈未装未验** | `reports/zh-ime-touch-chinese-20261020.md`（那次「全链可用」就是它）；`doc-ime-scope-audit` §1 D 档：上游自述 unmaintained | **不用** |
| `wvkbd` | ❌ 需单栈（fcitx5 开 waylandim）+ **phoc 带 IM-grab NULL 修复** | `doc-ime-scope-audit` §1 C 档 + `patches-userland/zh-ime/withdrawn/README.md`；`bb1f7465` **不在**在机 phoc（版本号 0.46，未核实 divert，**未验证**） | **不用**（路线已否） |
| fcitx5 自带 `waylandim` 当 OSK | ❌ 它不画键盘 | 2026-11-09 §3 B 臂实测「能组词、屏幕键盘消失」，当日回退 | **不用** |

### 5.2 名字分离（不要把四个名字当一个东西）

- 报告里的 **`phosh-osk-stevia`**（0.59~rc1，unit = **`mobi.phosh.OSK.service`**）与现机 **`phosh-osk-stub` 0.46.0** 是**同一角色、不同版本/包名**；都带 `--allow-replacement`、都提供 `sm.puri.OSK0`。
- `scripts/ime-candidates-check.sh` 末条判据写死 `grep -cE 'phosh-osk-stevia|squeekboard'` ⇒ **现机恒 FAIL**（实测 `FAIL OSK 进程在跑 want=1 got=0`）——这是**脚本判据过时**，不是 OSK 不在（§8 G3）。

### 5.3 控制面（P3 唯一 API）与判据

```sh
# 读
busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible   # 现机: b false
# 写（本轮未执行：只读约束）
busctl --user call sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true # 期望 ()，再读 = true
```
历史判据（`reports/ime-osk-pop-20261111.md` E0，squeekboard 世代）：`SetVisible true` → `Get Visible` = `(<true>,)`；同一轮还发现 **`SetVisible true` 不会自动回退** ⇒ 实验前先 `SetVisible false` 清污染。

**失败判定**：`Visible` 能读但 `SetVisible` 后不变 ⇒ OSK 没绑槽（`journalctl --user -b | grep -c 'Input method unavailable'` 期望 0）。
**回退**：`SetVisible false`（不改盘）。

## 6. P4 elden-ime-focusd 桥（唯一的自动弹/收通路）

### 6.1 为什么必须有它（两层独立断裂，任意一层都足以让「点输入框自动弹」失效）

1. **客户端层**：`GTK_IM_MODULE=fcitx` ⇒ GTK 走 D-Bus IM，**不发** `zwp_text_input_v3.enable`（`#618`，A/B 表）。
2. **合成器层**：即使客户端真发了 `enable`+`commit`，**phoc 对 v≥2 客户端故意 return**（`src/input-method-relay.c:handle_text_input_enable` 的 `if (version >= SHOW_INPUT_PANEL_SINCE_VERSION) return;`，`PHOC_TEXT_INPUT_VERSION=2`）⇒ 没有任何 `activate_osk()`（`#615`，0.58 与 0.59~rc1 该文件逐字同源）。

⇒ **桥 = 绕开整条协议链**：`fcitx5 kimpanel SetRelativeSpotRect`（或 `Enable(true)`）→ `sm.puri.OSK0.SetVisible(true)`。

### 6.2 三份件与落点（仓库 → 设备）

| 件 | 仓库 | 设备 | 现机核对（2026-11-21） |
|---|---|---|---|
| 源码 | `patches-userland/zh-ime/elden-ime-focusd.c`（20 288 B，11-13 22:45） | — | — |
| 二进制 | `out/ime-host/elden-ime-focusd`（73 456 B，arm64 **glibc 动态**链 glib/gio） | `/usr/local/bin/elden-ime-focusd` | sha **`5cf98e1d7294fe64c9902ecb95aaeb37c161c9c60a68cc2696a455df9863413d`**，两边 `sha256sum` 完全相同 ✅ |
| unit | `rootfs/debian/ime/elden-ime-focusd.service` | `/etc/systemd/user/elden-ime-focusd.service` + `…/graphical-session.target.wants/` 软链 | unit 在、`Environment=ELDEN_IME_IDLE_SEC=4`、`Restart=always`、enabled |

重建命令（**不要**在设备上编；主机 arm64 chroot 内编）：
```sh
timeout -k 10 1200 bash packaging/elden-userland/build/elden-ime-focusd.sh --dry-run   # 先看要做什么
timeout -k 10 3600 sudo bash packaging/elden-userland/build/elden-ime-focusd.sh          # 产物落 out/ime-host/
# 它在 /opt/elden/arm64-sid chroot 里 apt-get install build-essential pkgconf libglib2.0-dev 后跑
#   patches-userland/zh-ime/build-elden-ime.sh（gcc -O2 -Wall … pkg-config gio-2.0 glib-2.0）
```

装到设备（幂等的是 `daily-baseline.sh §3b2`，只装 unit/软链，**不装二进制**）：
```sh
ssh elden-root 'install -m 0755 /dev/stdin /usr/local/bin/elden-ime-focusd' < out/ime-host/elden-ime-focusd
scripts/mobian-daily-baseline.sh --check   # §3b2 三项：二进制在位 / unit 已装 / 已 enable
```

### 6.3 四改语义（源码逐条，`ELDEN_IME_IDLE_SEC` 是第五改）

| # | 语义 | 源码位置 / 常量 | 用户可见效果 |
|---|---|---|---|
| ① | **零矩形不当「要打字」**：`SetRelativeSpotRect(0,0,0,0)` 只记「疑似失焦」，持续 **400 ms** 才收 | `want_keyboard()` / `zero_rect_since_us` / `> 400000` µs | 建 IC 时不再误弹；收起快（11-13 由 2 s 改 400 ms） |
| ② | `Enable(false)` **立即收** | `method_call` 的 `Enable` 分支 | 切走的即时反馈 |
| ③ | `State==-1` **连续 5 次**（≈5 s）⇒ 收 | `fcitx_gone_ticks >= 5` | fcitx5 崩了不留僵尸键盘 |
| ④ | 订阅 `sm.puri.OSK0` 的 `PropertiesChanged` 维护本地可见性，回调路径**零 D-Bus 往返** | `on_props_changed` + `osk_get_visible()` 只在启动取一次 | 打字不卡（旧版每次光标更新同步 `Get Visible`，500 ms 超时会把 `SetLookupTable` 顶住） |
| ⑤ | `State==0 ⇒ 收` **加闸门**：只有本 IC 曾观测到 `State==1`（`fcitx_seen_active`）才允许 | `idle_check()`；`osk_hide()` 里复位 | 修 11-13 的真实回归：非 fcitx 客户端 `State` 恒 0 ⇒ 键盘弹起 1 s 内被自己收掉（`#653`） |
| ⑥ | 轮询 **250 ms** + 兜底超时 `ELDEN_IME_IDLE_SEC`（unit 里 = **4 s**；组字中 +16 s，**有界**） | `g_timeout_add(250,…)`、`idle_sec`、`IDLE_COMPOSING_EXTRA` | 「点空白处」在 **2 183 ms** 内收（旧 42 991 ms，`#644`） |
| ⑦ | `RequestName` 返回值检查：`result=2/3`（别人是主属主）⇒ **日志一句 + exit 0**，不让 `Restart=always` 每 3 s 空转 | `main()` 末尾 `if (rn != 1u && rn != 4u)` | 旧 autostart 与 unit 并存时不再刷屏 |

`ELDEN_IME_IDLE_SEC` 是**唯一运行期旋钮**（`Environment=` 或 drop-in）。`0` = 关闭该兜底（会留下僵尸键盘，**不要**在 Firefox 场景用）。
调参实测（`#644`）：45 s ⇒ 42 991 ms；4 s ⇒ 2 183 ms；12 s 用于**验证超时通路**（`hide requested by idle timeout`）。

### 6.4 上机判据（每条都带期望输出；全部来自 11-12/11-13 真机实测）

```sh
# 0) 会话用户总线包装（必须；见 §3.2）
asuser() { setpriv --reuid=1001 --regid=1001 --init-groups env HOME=/home/xuqianhui1001 \
  XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus "$@"; }

asuser systemctl --user start elden-ime-focusd        # ★ 本栈必须显式 start（graphical-session.target 不 active）
asuser systemctl --user is-active elden-ime-focusd    # active
pgrep -fc '^/usr/local/bin/elden-ime-focusd$'         # 1（只有一个实例）
asuser busctl --user list | grep -c 'org.kde.impanel' # 1，且 PID 列 = 上面那个 PID
kill -9 <pid>; sleep 5; asuser systemctl --user is-active elden-ime-focusd   # active（自愈）
# 带矩形会弹（注意接口名是 org.kde.impanel2，对象路径 /org/kde/impanel）
asuser busctl --user call org.kde.impanel /org/kde/impanel org.kde.impanel2 SetRelativeSpotRect iiii 10 20 100 40
asuser busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible   # b true
# 无 IC 会收
sleep 2; … Visible                                                                    # b false
```

真客户端端到端（2026-11-12 已过）：起 Firefox（about:blank，URL 栏自动获焦 = 真 IC）→ `State` 0→1、`Visible` false→**true**，日志 `show requested by SetRelativeSpotRect (0x72)`；关 Firefox → 2 s 内 `false`。截图 `reports/artifacts/ime-osk-focusd-20261112/firefox-urlbar-osk.png`（sha `273eafcc…`）。

**失败判定（按日志签名分诊，日志 `logmsg` 打到 stderr ⇒ `journalctl --user -u elden-ime-focusd`）**：

| 日志签名 | 含义 | 处置 |
|---|---|---|
| `already owned (result=2); exiting quietly` | 有旧 autostart/别的实例占着 `org.kde.impanel` | `mv ~/.config/autostart/elden-ime-focusd.desktop{,.disabled-$(date +%Y%m%d)}` 后重启 unit |
| `Visible->1 (signal)` → 紧接 `hide requested by fcitx State=0` | 旧版 `#653` 回归（无限闸门） | 换 `5cf98e1d…` 及以后的二进制 |
| 一直 `hide requested by idle timeout` | 客户端不发 blur（Firefox 就是）**正常行为** | 调 `ELDEN_IME_IDLE_SEC`（4 太短/45 太长） |
| 完全没日志 | unit 没起（本栈最常见：`graphical-session.target` inactive） | `systemctl --user start elden-ime-focusd` |

**回退**（基线不倒退，`T-A8`）：`asuser systemctl --user disable --now elden-ime-focusd` ⇒ 键盘仍可用 `sm.puri.OSK0.SetVisible` 手动控制（应用网格图标 `fcitx5-ime-toggle`）。

### 6.5 关于候选/preedit 信号转发（已随浮条一起撤下，代码仍在）

`focusd` 从 11-13 版起还会把 kimpanel 收到的内容转成 `org.elden.ImePanel` 信号（`Lookup/Show/Spot`），给已撤下的浮条用。
**它不影响弹/收**（纯附加），但意味着：源码里的 `strip_show()` 会被调用而**没有监听者** —— 这是设计如此，不是故障。

## 7. P5 候选窗（现状 = C 档：**不可用**，且必须知道为什么）

### 7.1 三条互斥的候选渲染路径，只有一条在历史上真正出过窗

| 路径 | 谁画 | 在本栈状态 | 证据 |
|---|---|---|---|
| **A. 客户端内自绘**（GTK IM 模块 `im-fcitx5.so`） | 客户端进程自己 | 历史可用（**Alpine / Phosh 0.55 / squeekboard 世代**）；现栈未复验 | `reports/zh-ime-touch-chinese-20261020.md` §1 事实 4：「杀掉 `candidate-bar` 后候选照常出现、`你好` 照常上屏 ⇒ 候选窗由 fcitx5-gtk IM 模块自己画」+ 截图 `1 你好 2 妳好 3 逆號 4 擬好 5 你` |
| **B. classicui**（fcitx5 自带面板） | fcitx5 自己建窗 | ❌ **phoc 上建不出窗**（需要的窗口协议 phoc 不提供）；现机 `CurrentUI=classicui`（实测 `('classicui',)`) | `#619` 层 A；`reports/ime-chinese-20261109.md` §1：classicui 在 Wayland 下只打一行 `Created classicui for wayland display:`，屏上无任何面板 |
| **C. kimpanel 面板**（`elden-ime-focusd` 当 owner） | **面板自己** | ❌ 面板 UI 已按 `#646` **撤下**（`disable --now`，`daily-baseline.sh §3b3` 不再装/启） | `#645`：`CurrentUI=kimpanel` 时「没有面板就没有任何可见反馈」；`#646`：v1 浮条一上机就废 |

⇒ **现栈无论切 classicui 还是 kimpanel 都没有候选窗**：classicui 画不出，kimpanel 没人画。

### 7.2 方案 A（候选浮条）为什么撤回 —— 这是**硬约束**，不是「没调好」

真机症状（用户实测，`#646`）：「输入 `n` 的一瞬间弹出的候选窗把整个页面顶掉了，然后返回原页面；切换过程让刚刚缓冲的输入字符被直接打上屏幕。」
机制：`Show(true)` = `set_visible(True)+present()`，`Show(false)` = `set_visible(False)` ⇒ **组字每次开始/结束都 map/unmap 一个 layer surface**；在这套合成器上 layer surface 的 map/unmap 会触发焦点重算 ⇒ 客户端输入上下文被打断（fcitx 提交/重置组字）。
注意：**渲染本身在主机侧是通的**（`busctl emit` 灌数据能出正确截图 `nihao` + `1 你 2 那 …`），所以「主机侧能画」**不能**当验收（`#646` 教训）。

### 7.3 重做的前置条件（未验证的路线，不要当计划）

1. layer surface **全程 mapped**（启动即 present 一次），显示/隐藏只切 **opacity / 内容**，**绝不 unmap**；
2. **判据 = 打字过程中 `NotifyFocusOut` 计数必须为 0**（合成器侧要看得到；本栈取法**未验证**）；
3. 定位只用 `LayerShell.set_margin`，**不改 anchor/layer**（mapped 后改也可能重排）；
4. 已知的运行期坑：GTK4 layer-shell 在 Python 进程里必须 `Environment=LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgtk4-layer-shell.so.0`（否则 `GtkWindow is not a layer surface`；drop-in 已留在设备 `/etc/systemd/user/elden-ime-candidates.service.d/ldpreload.conf`，unit 仍 disabled）；
5. 数据侧已就绪：`focusd` 的 `org.elden.ImePanel` 信号（`Lookup(preedit, items, cursor)` / `Show(b)` / `Spot(iiii)`）+ `SelectCandidate` 走 `libkimpanel.so`。

**最小验收（唯一有意义的那条）**：一次真机输入里 —— 组字不被打断（无 `NotifyFocusOut`）、缓冲字符不被直接提交、屏上截到候选条。任何只证明「画出来了」的证据都无效。

### 7.4 现在的可选项（给用户/后续 lane 的诚实清单）

- **要候选窗就先做 §7.3 的前置验证**（工程量大于桥本身），或
- **回到路径 A**：把 `CurrentUI` 保持 `classicui`/不设，让 GTK 客户端自己画候选 —— 但这条路与 `GTK_IM_MODULE=fcitx` 强绑定，且与「自动弹/收」（`#618` T4 裁决）**直接冲突**；在 0.46 栈上是否成立**完全未验证**（`#653` 在 0.59 栈上观测到 GTK3 不建 fcitx IC）。

## 8. 知识断层清单（哪条只活在会话里、哪条判据已失效、哪条是未验证推断）

### 8.1 结构性断层：修好的东西**没有任何脚本守着**（重建即丢）

| # | 断层 | 现场证据 | 处置建议（未执行，本轮只读） |
|---|---|---|---|
| **G1** | **`daily-baseline.sh §3` 主动写入 `GTK_IM_MODULE=fcitx`**，与 11-15 T4 的裁决（必须摘掉，否则 `#618` 遮蔽使自动弹/收只能靠桥）**正面冲突**；重跑基线就把 T4 冲掉 | `rootfs/debian/daily-baseline.sh:139-146`；现机 `/etc/environment.d/50-elden-ime.conf` 三行都在 | 二选一并写进 SSOT：要么删 §3 的 `GTK_IM_MODULE=fcitx`（保桥），要么承认「有遮蔽」是默认态并接受桥为唯一通路。**这正是 `#643` 的同一类错误（生成态的脚本没跟着改）** |
| **G2** | **T1（D-Bus `Exec` 带 flag）/ T2（`CurrentUI=kimpanel`）/ T4（摘 IM 变量）三项手工修复没有任何脚本覆盖** ⇒ 每次重建根都回退 | 11-15 §3b/§3c 做过；现机：`Exec=/usr/bin/fcitx5`、无 `~/.config/fcitx5/config`、`environment.d` 有遮蔽 | 三个幂等块（照 §3b2 的模式）进 `daily-baseline.sh`，各带 .bak 与判据 |
| **G3** | **体检脚本判据过时**：`scripts/ime-candidates-check.sh` 末条写死 `grep -cE 'phosh-osk-stevia|squeekboard'`，而本栈 OSK = `phosh-osk-stub` ⇒ **恒 FAIL** | 本轮实跑：`FAIL  OSK 进程在跑（stevia 或 squeekboard）  want=1 got=0`，同一次 `ps` 里 `phosh-osk-stub` 明明在 | 改成 `grep -cE 'phosh-osk-(stub|stevia)|squeekboard'` |
| **G4** | **`#660` 被三处引用但 PITFALLS 无正文**（编号空洞）：脚本头注释、台账 §1、`#663` 正文都引它 | `grep -rn '#660' PITFALLS/` 只命中引用，`grep '^# #660'` 无结果 | 在 `daily-baseline.sh` 或台账里补一条正文（两条启动路径 flag 不一致 ⇒ 第二实例 + 写回 profile） |
| **G5** | **同一二进制三处 sha 不一致**：`sources.tsv` 记 `8bfab82e…`、`build/elden-ime-focusd.sh` 注释记 `7b8b0b46…`、`#653` 记 `5cf98e1d…`；实测仓库 `out/` 与现机**都是 `5cf98e1d…`** | `sha256sum out/ime-host/elden-ime-focusd` = `5cf98e1d7294fe64…`；设备同值 | 以 `5cf98e1d…` 为准回填 `sources.tsv`/构建脚本注释（`8bfab82e` 是 `#653` 里记的**设备备份** `.prev-20261113`） |

### 8.2 判据在新栈上失效（不能照抄历史结论）

| # | 旧判据 | 为什么现在不成立 | 现状 |
|---|---|---|---|
| **G6** | `#618`：「`GTK_IM_MODULE=wayland` ⇒ `Visible=(<true>,)`」 | `#653` 已证：**在 phoc 0.59~rc1 + phosh 0.59~rc1 栈上不再成立**（GTK3 连 fcitx IC 都不建）；现机又是 **0.46** 栈，两代都不可互推 | **未验证**（现机需要真 IC + 一次打字） |
| **G7** | `#615`：「phoc 已去版本门（`grep -c` 源码 = 0）」 | 现机 phoc 版本号 = **0.46.0**（`dpkg -l`），我们的补丁/自编件按版本号判断不在；`divert`/`hold`/二进制 sha **未核**，0.46 是否含同一 `return` **未核实** | 结论上仍安全：**无论门在不在，桥都是必需**（客户端层遮蔽 + 门本身两层串联） |
| **G8** | 「unit `enabled` ⇒ 重登自启」 | 现机 `graphical-session.target` = **inactive**（`ActiveEnterTimestamp` 空）⇒ `WantedBy` 不生效；fcitx5 与 focusd 都 `enabled` 却 `inactive` | 必须显式 `systemctl --user start`，或先修会话 target 的拉起链（**未验证谁该拉**） |
| **G9** | 候选窗「已通」（11-11 用户目视 + 截图） | `#645` 复核同一张图：**只有 preedit、没有候选窗**；当时的「确认」是被 DBus 里的 `SetLookupTable` 数据误导 | **C 档**（§7） |
| **G10** | 文档：`apt-list.txt:121` / `pkgmap.tsv:186` 仍把 **squeekboard** 当 OSK | 现栈 OSK = `phosh-osk-stub`，squeekboard **未装**；上游自述 unmaintained | 文档漂移，需改或标注世代 |

### 8.3 只在会话/台账里、没有稳定指针的结论

- `T4` 的**生效方式**（改 `/etc/environment.d/*` 后必须 `systemctl restart user@1001.service`，`restart greetd` 不够）—— 只在 `TASKS/sessions/2026-11-15-IME候选回归台账.md` §3c。
- 「`SetAddonsState` 切 kimpanel **不持久**（重启回 classicui，长期做法 = addon conf `Enabled=False`）」—— 11-11 记的「未落地」；现机实测 `CurrentUI=('classicui',)`，**仍然没落地**。
- `fcitx5-indicator` 胶囊的 `LD_PRELOAD` 链接顺序坑（`reports/ime-chinese-20261109.md` §2 坑 2）—— 仓库/文档有，但**没有脚本校验**该 `Environment=` 行在不在。
- `org.kde.impanel` 的**接口名是 `org.kde.impanel2`**（对象路径 `/org/kde/impanel`）：用旧名调会报 `No such interface`，**不能据此判「桥没实现」**（`#653` 附注）。

### 8.4 从未验证过的（不要写成能力）

| 项 | 为什么关键 | 最小验证 |
|---|---|---|
| **GTK3 / GTK4 / Qt 各一例真 IC** | `#653` 遗留：0.59 栈上 GTK3 不建 fcitx IC（`DebugInfo` 只有 `program:phosh`）⇒ 中文组词链路未通；0.46 栈未知 | `fcitx5-diagnose` 看 `DebugInfo` 的 `program:` 列表 + 新窗后 `fcitx5-remote -n` |
| **Alt+Tab 跨窗漏收**（`T-H1`） | 收起判据 `State==0` 对「另一个也有 IC 的窗」是否触发未验 | `wtype -M alt -k Tab -m alt` 后 2 s 读 `Visible` |
| **锁屏/解锁**（`T-H4`） | 桥不看锁屏信号，且 OSK 锁屏键盘会抢槽 | `loginctl lock-session` → 读 `Visible` |
| **候选/键盘重叠** | 桥不渲染 UI，位置由 OSK 自己定 | 一次真机截图 |
| **`phosh-osk-stub` 的 `SetVisible` 在本版是否真的显键盘** | 历史证据分别取自 squeekboard（0.55）与 stevia（0.59）；**0.46 stub 只验证到「属性可读」** | `SetVisible true` → `Visible` true + 截图（本轮只读，未做） |
| **0.46 栈上 `Text-Input` 行为** | 所有「发不发 enable / phoc 传不传 activate」的实测都来自 0.58/0.59 | `WAYLAND_DEBUG=1` 跑 `probes/ime/ime-gtk3-entry.py` |

## 9. 证据附录（本轮执行的命令 + 原始输出，2026-11-21 10:0x–10:2x）

### 9.1 设备身份与栈

```
$ ssh elden-root 'uname -r; cat /etc/debian_version'
7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0
13.7

$ dpkg -l phosh phoc phosh-osk-stub | tail -3
ii  phoc           0.46.0-1         arm64  Wayland compositor for mobile phones
ii  phosh          0.46.0-3+deb13u1 arm64  Pure Wayland shell for mobile devices
ii  phosh-osk-stub 0.46.0-1         arm64  An alternative on screen keyboard for Phosh

$ tr '\0' ' ' < /proc/1466/cmdline; echo
/usr/bin/phosh-osk-stub --allow-replacement

$ ps -eo user,comm | grep -E "phoc|phosh|osk|fcitx" | sort -u
xuqianh+ fcitx5
xuqianh+ phoc
xuqianh+ phosh
xuqianh+ phosh-osk-stub

$ dpkg -l | grep -Ei "osk|wvkbd|squeek" | awk '{print $2, $3}'
phosh-osk-stub 0.46.0-1        ← squeekboard 与 wvkbd 都未装
```

### 9.2 IME 会话态（会话用户总线）

> 本轮实际用法：`ssh elden-root 'su - xuqianhui1001 -c "export XDG_RUNTIME_DIR=/run/user/$(id -u); …"'`（语义等价于 §3.2 的 `asuser`）。
> ★ 以 root 直接跑 `systemctl --user` / `busctl --user` 读到的是 **root 的空总线** ⇒ 全部判据恒假（`PITFALLS #663`）。

```
$ systemctl --user is-active fcitx5 elden-ime-focusd
inactive
inactive
$ systemctl --user is-enabled fcitx5 elden-ime-focusd
enabled
enabled
$ systemctl --user is-active graphical-session.target
inactive                      ← 这就是上面两个 enabled 却 inactive 的原因
$ systemctl --user show -p Wants graphical-session.target
Wants=elden-ime-focusd.service fcitx5.service foot-server.service foot-server.socket
$ busctl --user list | grep -E "impanel|OSK0|Fcitx5"
org.fcitx.Fcitx5   1514 fcitx5          …     ← 有 fcitx5
sm.puri.OSK0       1466 phosh-osk-stub  …     ← 有 OSK
（无 org.kde.impanel 行 ⇒ 桥没注册）
$ ps -o pid,ppid,lstart,cmd -p 1514
1514  1  六 11月 21 09:21:23 2026  /usr/bin/fcitx5 -d      ← 手工起、无 --disable waylandim
$ busctl --user get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible
b false
$ gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller --method org.fcitx.Fcitx.Controller1.CurrentUI
('classicui',)                 ← 不是 kimpanel，且 classicui 在 phoc 建不出窗
```

### 9.3 focusd 三件与 profile

```
$ sha256sum /usr/local/bin/elden-ime-focusd        （设备）
5cf98e1d7294fe64c9902ecb95aaeb37c161c9c60a68cc2696a455df9863413d
$ sha256sum out/ime-host/elden-ime-focusd          （仓库）
5cf98e1d7294fe64c9902ecb95aaeb37c161c9c60a68cc2696a455df9863413d
$ grep -E "ExecStart|Environment|Restart" /etc/systemd/user/elden-ime-focusd.service
Environment=ELDEN_IME_IDLE_SEC=4
ExecStart=/usr/local/bin/elden-ime-focusd
Restart=always
$ sed -n '1,30p' /home/xuqianhui1001/.config/fcitx5/profile
[Groups/0] … DefaultIM=keyboard-us
[Groups/0/Items/0] Name=rime          ← P2 判据满足
[Groups/0/Items/1] Name=keyboard-us
$ ls /home/xuqianhui1001/.local/share/fcitx5/rime
build  installation.yaml  luna_pinyin.userdb  sync  user.yaml
$ ls /home/xuqianhui1001/.config/fcitx5/     （无 config ⇒ CurrentUI 走默认 classicui）
conf  profile
$ grep Exec /usr/share/dbus-1/services/org.fcitx.Fcitx5.service
Exec=/usr/bin/fcitx5                  ← #660 的第二条路径（无 --disable waylandim）
$ cat /etc/environment.d/50-elden-ime.conf
GTK_IM_MODULE=fcitx / QT_IM_MODULE=fcitx / XMODIFIERS=@im=fcitx   ← #618 遮蔽回来了
```

### 9.4 唯一体检入口实跑（本轮，只读）

```
$ bash scripts/ime-candidates-check.sh
PASS  fcitx5 实例数(=1)                           1
FAIL  fcitx5 启动参数含 --disable waylandim     want=1 got=0
PASS  systemd ExecStart 含 --disable waylandim      yes
FAIL  D-Bus 激活 Exec 也带 --disable waylandim   want=yes got=no (/usr/bin/fcitx5)
PASS  profile Items/0 = rime                         rime
FAIL  config CurrentUI = kimpanel                    want=kimpanel got=<空>
FAIL  elden-ime-focusd 在跑                        want=1 got=0
WARN  org.kde.impanel 无 owner（kimpanel 未注册） (busctl list 无此名)
WARN  systemd unit fcitx5 非 active                 inactive（进程在跑即可，但两条启动路径不一致）
FAIL  phosh 环境无 GTK_IM_MODULE=fcitx（#618 遮蔽） want=0 got=1
PASS  im-fcitx5.so（GTK3/4 IM 模块）在位       2
FAIL  OSK 进程在跑（stevia 或 squeekboard）   want=1 got=0     ← 判据过时（§8 G3）
---
汇总: PASS=4 FAIL=6  （判据正文 = PITFALLS #618/#619/#653/#660）
profile mtime: 2026-11-21 10:04:45.158619315 +0800 247
```

> 对照：2026-11-15 13:3x 同一脚本曾 **`PASS=11 FAIL=0`**（台账 §3c）⇒ 今天这 6 个 FAIL 里，**5 个是重建根丢失的手工修复**（G2）、1 个是脚本判据过时（G3）。

### 9.5 本轮取证边界（诚实标注）

- **只读**：未装包、未启停 unit、未 `SetVisible`、未改任何设备文件或仓库正文（只新增本报告）。
- 设备在 **10:2x 后不可达**（`ssh: connect to host 192.168.7.1 port 22: Connection timed out`，在机是 `-suspend` 核，疑进待机）⇒ §8.4 的几项「最小验证」**本轮都没能跑**。
- 历史引用的原始输出均注明出处文件与章节；未逐字复核的推断已标**未验证**。
