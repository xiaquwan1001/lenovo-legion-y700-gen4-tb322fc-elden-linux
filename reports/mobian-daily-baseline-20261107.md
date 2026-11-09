# Mobian(Debian sid) 日用用户态基线补齐 — 2026-11-07

> 会话：2026-11-07（pi 会话见 `TASKS/sessions/2026-11-07-日用用户态基线补完.md`）
> 设备：U2 `HA2EXB0E`，在机 `vk172`（`7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty-debug-vk172`），
> 持久根 `/dev/sda17` ext4（`LABEL=linux17`），`Debian GNU/Linux forky/sid`，Phosh 0.55 会话 `c1`。
> 本报告是**日用基线**这一层的唯一证据面；包清单一律以 `rootfs/debian/daily-baseline.tsv` 为准。

---

## 0. 结论（数字）

| 项 | 补前 | 补后 |
|---|---|---|
| 设备已装包 | **1355** | **1625**（+270，全部新增，无升级/无删除） |
| 构建侧 `apt-list.txt`（`--no-install-recommends` 的最小闭包入口） | **121** 包 | **147** 包（并入 daily-baseline P0+P1） |
| `sudo` | ❌ 不存在（`/usr/bin/sudo: No such file`） | ✅ `1.9.17p2-11`，桌面用户 **NOPASSWD** |
| locale | ❌ `locales` 未装、`/etc/locale.gen` 为空、`locale` 报 `Cannot set LC_*` | ✅ `en_US.UTF-8` + `zh_CN.UTF-8` 已生成；`/etc/default/locale` = `zh_CN.UTF-8` |
| 中文字体 | ❌ `fc-list :lang=zh` = **0**（只有 DejaVu/Lato，中文全豆腐块） | ✅ **30** 个字族；`fc-match 'sans-serif:lang=zh-cn'` → `Noto Sans CJK SC` |
| 桌面组件 | 缺 keyring / portal-phosh / g-c-c / gvfs-backends | ✅ 全在（详见 §2） |
| 输入法 | fcitx5 装了但**没有任何自启**、无 IM 环境变量 | 🟡 有 user unit + environment.d + Rime；**组词端到端未证实**（§5） |
| zram | 装了但每次启动 `zramswap.service` FAILED（内核无 `CONFIG_ZRAM`） | ✅ **已收口（2026-11-09 核实）**：在机 `7.3.1-debug-vk184-00003` 有 `CONFIG_ZRAM=m`，`zramswap` active、`zram0` 7.3 G（§5.2） |

三条产物（构建侧固化 + 设备侧可复现）：

1. `rootfs/debian/daily-baseline.tsv` — 日用包基线（**50 条 P0/P1 + 9 条 P2 只登记**），列 = 包 / 优先级 / 分类 / 理由。
2. `rootfs/debian/daily-baseline.sh` — 配置逻辑（sudo 组 + NOPASSWD、locale-gen + 中文 LANG、fcitx5 user unit + enable、zram 内核门），**构建 chroot 与设备跑同一份**。
3. `scripts/mobian-daily-baseline.sh` — 主机侧驱动：解析 tsv → 设备 `apt-get install` → 推配置脚本 → 复查；`--check` 只报告（退出码 0 = 达标）、`--list` 只打印。

门禁：`bash rootfs/debian/tools/check-pkgmap.sh` → `结果: FAIL=0 WARN=0`，`日用基线: P0+P1=47（已并入）P2=9（只登记）解析失败=0`。

---

## 1. 根因：为什么「包不完整」

不是掉包，是**两张清单的覆盖面差**：

- `rootfs/debian/apt-list.txt` 的来源是 `rootfs/debian/pkgmap.tsv`，而 pkgmap 的来源是
  `rootfs/persistent-overlay/apk-world.txt`（**Alpine 时代的 apk world，用途 = 硬件 bring-up + 调试**）。
- `rootfs/debian/build-rootfs.sh` 第 3 步用 `apt-get install --no-install-recommends $(apt-list)`。
  ⇒ 最终根 = minbase（`--variant=minbase`）+ 121 个包 + 它们**不含 Recommends** 的 Depends 闭包 = 1355 包。
- 于是「桌面能起来」和「能当日常平板用」之间差了一整片：
  `sudo` 不在世界集里；`locales` 不在（`/etc/locale.gen` 是 debootstrap 留下的空文件）；
  CJK 字体从没被列过；`gnome-keyring` / `xdg-desktop-portal-phosh` 属于 phosh-core 的 Depends，
  但本工程装的是 `phosh` 本体而非 `phosh-core` 元包；`man-db` / `bash-completion` / `vim`
  属于 Mobian `mobian-base` 的 Depends，而本工程从来没有 mobian-* 元包。

**处置口径**：不引入 `mobian-*` 元包（会把 Mobian 的整套策略/服务带进来，与本工程的
greetd appliance、自维护 userland 冲突），而是**自己列一张正交的「日用基线」表**，
并把它并进构建侧的唯一安装清单。上游两个权威基线（`meta-mobian 0.5.6` 的
`mobian-base`/`mobian-phosh-base` 与 Debian `phosh-core`）只作为**选包依据**被引用，不被安装。

---

## 2. 实际补装（设备侧，2026-11-07 一轮）

全部经 `apt-get install -y --force-confold`，装前 `apt-get -s` 模拟确认 **0 升级 / 0 删除**：

| 组 | 包 |
|---|---|
| 管理员/shell | `sudo` `bash-completion` `command-not-found` `man-db` `vim` `ncdu` |
| locale/字体 | `locales` `fonts-noto-cjk` `fonts-noto-core` `fonts-cantarell` `fonts-liberation2` `fonts-noto-color-emoji` |
| 桌面/会话 | `gnome-keyring`(+`libpam-gnome-keyring`) `xdg-desktop-portal-phosh` `gnome-control-center` `gvfs-backends` |
| 音频 | `playerctl` `gstreamer1.0-pipewire` `gstreamer1.0-plugins-good` `gstreamer1.0-libav` |
| 蓝牙/网络 | `bluetooth`（bluez 的 systemd 使能包，bring-up 只装了 bluez 本体） `rfkill` |
| 电源 | `power-profiles-daemon` `zram-tools`（见 §5） |
| 截图/剪贴板 | `wl-clipboard` `wtype` |
| 输入法 | `fcitx5` `fcitx5-rime` `fcitx5-frontend-gtk3` `fcitx5-frontend-gtk4` |

`zram-tools` 装了但内核无模块 ⇒ 已 mask（§5）。`gir1.2-gtk-4.0` 仅为 §5 的取证一次性安装。

---

## 3. 配置（`rootfs/debian/daily-baseline.sh` 干的四件事）

1. **sudo 提权可用**：本机桌面账户 `passwd -S` = **NP**（无口令，greetd 自动登录 appliance），
   所以 sudo 不能用口令提权 ⇒ 写 `/etc/sudoers.d/90-elden-desktop`（`xuqianhui1001 ALL=(ALL:ALL) NOPASSWD: ALL`，`visudo -c` 校验通过）
   + 用户入 `sudo` 组。**账户若有口令则脚本只入组、不写 NOPASSWD**（同一份脚本两态都安全）。
2. **locale**：`/etc/locale.gen` 打开 `en_US.UTF-8` / `zh_CN.UTF-8` → `locale-gen` → `/etc/default/locale`
   写 `LANG=zh_CN.UTF-8` + `LANGUAGE` + 8 条 `LC_*`。
   判据用 `locale -a`（**Debian 是 `locale-archive`，不是逐 locale 目录**，`ls /usr/lib/locale` 判不出来，踩过）。
3. **输入法自启**：`/etc/environment.d/50-elden-ime.conf`（`GTK_IM_MODULE=fcitx` / `QT_IM_MODULE=fcitx` / `XMODIFIERS`）
   + `/etc/systemd/user/fcitx5.service`（`ExecStart=/usr/bin/fcitx5 -r --disable waylandim`）
   + **系统级** wants 链接 `/etc/systemd/user/graphical-session.target.wants/fcitx5.service`
   （不用 `~/.config/systemd/user`：构建 chroot 里没有用户 home，构建侧与现场要同一路径生效）。
   `--disable waylandim` 是必须的：Phosh 0.55 的 `phosh-osk-stevia` 已占 OSK/输入法槽位。
4. **zram 内核门**：有 `zram.ko` 就确保未 mask；没有就 `mask zramswap.service`（幂等、可逆）。

---

## 4. 现场验证（全部在机，v172）

```
# 提权（无口令账户）
$ su - xuqianhui1001 -c 'sudo -n true && echo OK'        → OK
# locale
$ locale | head -3                                       → LANG=zh_CN.UTF-8 / LANGUAGE=zh_CN:zh / LC_CTYPE="zh_CN.UTF-8"
$ locale -a | grep -E 'zh_CN|en_US'                      → zh_CN.utf8 / en_US.utf8
# 中文
$ fc-match 'sans-serif:lang=zh-cn'                       → NotoSansCJK-Regular.ttc: "Noto Sans CJK SC"
$ fc-list :lang=zh | wc -l                                → 30
# 桌面服务与会话
$ loginctl list-sessions                                  → c1 seat0 tty7 active
$ systemctl --failed                                      → 空（mask 后 zramswap 不再 FAIL）
$ dpkg-query -f '.\n' -W | wc -l                          → 1625
$ df -h /                                                 → 22G/188G
```

驱动脚本自检（本机 ⇒ 设备）：

```
$ bash scripts/mobian-daily-baseline.sh --check
  缺 1 个：fonts-noto-color-emoji     # 首轮；装后消失
  结果: 未达标（见上）
$ bash scripts/mobian-daily-baseline.sh
  FIX   enable fcitx5（graphical-session.target.wants）
  FIX   内核无 zram 模块 ⇒ mask zramswap.service
  结果: 已达标（日用基线就绪）
$ bash scripts/mobian-daily-baseline.sh --check
  结果: 已达标（包齐 + 配置齐）           # 幂等：第二轮 FIX=0
```

---

## 5. 未收口 / 新发现（都写在这里，别在别处复写数字）

### 5.1 🟡 中文输入法「组词上屏」未证实（P1）

- 现状：fcitx5 以 user unit 常驻（`org.fcitx.Fcitx5` / `org.freedesktop.portal.Fcitx` 在总线上），Rime 引擎已加载，
  OSK 槽位归 `phosh-osk-stevia`（它走 **`zwp_virtual_keyboard`**，不是 `input-method-v2` ⇒ 与 C11 的 squeekboard 方案不同，
  理论上按键会经 GTK/QT IM 模块进入 fcitx5）。
- 实测（**合成按键路径**，GTK3 与 GTK4 各一窗口 + `wtype` 注键 + `/tmp` 落盘读回）：
  - `fcitx5 --disable waylandim` + `GTK_IM_MODULE=fcitx`：`im-fcitx5.so` 确实被 dlopen、`libFcitx5GClient.so.2` 也进，
    但 `fcitx5-remote` 状态恒 = **1（inactive）**，`fcitx5-remote -s rime` 后窗口里仍是 `nihao1` 字面量 ⇒ **输入上下文未建立**。
  - 对照臂 `ibus` + `ibus-rime`（`GTK_IM_MODULE=ibus`，`ibus list-engine` 有 `rime`）：同样字面量 ⇒ **不是 fcitx5 独有问题**。
  - ⇒ 结论只到「**合成 wtype 按键不会触发组词**」；**触摸 OSK 的真实按键路径未被否证**（需要人手在屏上点一次）。
- 已回退 ibus（`apt purge ibus ibus-rime ibus-gtk3 ibus-gtk4 ibus-data`），保持单一 IM 栈。
- 下一步（下次设备会话，成本 ~10 min）：屏上点输入框 → OSK 敲 `nihao` → 看是否有候选窗。三条分支：
  ① 有候选 ⇒ 收口；② 无候选但字面量上屏 ⇒ 换 C11 的 squeekboard 栈（`squeekboard` 已在 apt-list，配 `elden-ime-focusd`）；
  ③ 无候选且无反应 ⇒ 用 `fcitx5 --verbose '*'`（或 `journalctl --user -u fcitx5 -f`）看 IC 是否 `CreateInputContext`。

### 5.2 ✅ 内核缺 `CONFIG_ZRAM`（配置侧已补，2026-11-07 同日）

`modprobe zram` → `FATAL: Module zram not found in directory /lib/modules/7.3.0-rc7-…`；
`lsmod | grep zram` = 0；`systemctl start zramswap` 每次开机 FAILED。
⇒ 不是包问题，是 `arch/arm64/configs/*`（本工程 `config-daily-c1` 系列）没开 `CONFIG_ZRAM`（且大概率也没 `CONFIG_ZSWAP`）。
处置：本脚本 mask 该 unit（可逆）。

**配置侧已补齐（2026-11-07）**：
- `patches/config-daily-c1` 与 `patches/config-vk163-modular-v2-20261026` 均写入 `CONFIG_ZRAM=m` + `CONFIG_ZSMALLOC=m` + LZO backend
  （`ZRAM_BACKEND_LZO=y` / `FORCE_LZO=y`，其余 backend 保持关闭）。
- 判据（在 `build/daily`，7.3-rc7 树）：seed 该 config → `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= olddefconfig`
  ⇒ `CONFIG_ZRAM=m` / `CONFIG_ZSMALLOC=m` 解析成立；**第二遍 olddefconfig 零变化**；
  `scripts/check-modular-config.sh` → `PASS: 锚点全部 =y（27 个）/ olddefconfig 幂等 / tristate 自洽`；
  `make modules M=drivers/block/zram`（`KBUILD_MODPOST_WARN=1`，无 vmlinux 时属预期）→ `zram.ko` **786 792 B**。
- **尚差一步**：编进日常镜像并上机（现役 vk172 内核仍无 `zram` 模块）。镜像一旦带 `zram.ko`，
  `rootfs/debian/daily-baseline.sh` 的内核门会自动**解除** `zramswap` 的 mask，无需人工。
- 树卫生：验证用的 `.config` 已还原（备份 `/tmp/daily-config-before-zram-20261107`），`build/` 不入库。

**✅ 收口（2026-11-09 在机核实，U2）** —— 这一项已无剩余动作：

| 判据 | 实测值 |
|---|---|
| 在机内核 | `7.3.1-debug-vk184-00003-gec74c4795a43`（`boot_b` 启动） |
| `/proc/config.gz` | `CONFIG_ZRAM=m` / `CONFIG_ZSMALLOC=m`（后端仅 LZO：`CONFIG_ZRAM_BACKEND_LZO=y`、`DEF_COMP="lzo-rle"`） |
| 模块树 | `/lib/modules/<rel>/kernel/drivers/block/zram/zram.ko` 44 288 B |
| `zramswap.service` | `enabled` / `active` / `Result=success` / `ExecMainStatus=0` |
| 实际 swap | `zramctl` = `/dev/zram0 lzo-rle 7.3G [SWAP]`；`swapon --show` 7.3 G |
| 基线门 | `daily-baseline.sh --check` → `[4. zram] ok 内核有 zram 模块，zramswap 可用`，`MISS=0` |

- **mask 已自动解除**（脚本内核门的「有模块就 unmask」分支），无需人工；`systemctl --failed` 不再有 `zramswap`。
- 两个静默不一致（不阻塞，只登记）：① `/etc/default/zramswap` 写 `ALGO=lz4`，内核无 `CONFIG_ZRAM_BACKEND_LZ4`
  ⇒ 静默回退 `lzo-rle`（`/sys/block/zram0/comp_algorithm` = `[lzo-rle] lzo`）；② `PERCENT=50` 优先于 `SIZE=512`，
  所以盘是内存一半（7.3 G）而非 512 MiB。坑 → `PITFALLS #573`。
- **①已从配置侧修掉（2026-11-09）**：`patches/config-daily-c1` 与 `config-vk163-modular-v2-20261026` 均改为
  `CONFIG_ZRAM_BACKEND_LZ4=y`（`LZ4_COMPRESS/DECOMPRESS` 本就 `=y`，无新依赖）⇒ `olddefconfig` 两遍零变化、
  `check-modular-config.sh` PASS、`zram.ko` 786 816 B（旧 786 792 B）。**在机内核仍是纯 LZO，下次重建才生效。**
- 取证原文：`reports/artifacts/zram-closeout-20261109/verify.txt`。

### 5.3 `p7zip-full` 在 sid 已无此包名

`apt-cache policy p7zip-full` → `Candidate: (none)`；sid 的 7z 走 `7zip`。已在 tsv 里不登记该包（避免门禁 FAIL）。

---

## 6. 复现（在任一台等价单元上）

```
# 1) 构建侧（改包集后必须跑，会重写 apt-list.txt 并校验 sid 可解析）
bash rootfs/debian/tools/check-pkgmap.sh

# 2) 重建根（含日用基线配置；§5 步骤已接进 build-rootfs.sh）
sudo bash rootfs/debian/build-rootfs.sh

# 3) 或只补现役设备（幂等，走 device-lock 串行）
bash scripts/mobian-daily-baseline.sh --check     # 先看差多少
bash scripts/mobian-daily-baseline.sh             # 补齐
```

---

## 7. 引用（避免孤儿报告）

- 任务台账：`TASKS/README.md` §1 **G1-37**。
- 会话记录：`TASKS/sessions/2026-11-07-日用用户态基线补完.md`。
- 踩坑：`PITFALLS/sessions/05-设备上装包环境.md` **#538/#539/#540**。
- 选包依据（子代理调研，含上游 meta 包依赖面与来源 URL）：`reports/mobian-daily-pkgs-20261107.md`、
  `reports/artifacts/mobian-pkg-20261107/daily-baseline.tsv`。
- 任务盘点（同会话，子代理）：`reports/task-inventory-20261107.md`。
