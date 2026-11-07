# Debian sid + Phosh 日用必备包清单调研（2026-11-07）

> 问题：一个可日常使用的 Mobian/纯 Debian+Phosh 平板需要哪些包；`--no-install-recommends` 精简根会漏掉哪些。
> 对象：elden (TB322FC) Debian sid(forky/sid) + Phosh 0.55，rootfs 由 build-rootfs.sh (minbase + --no-install-recommends) 搭建，已装 1355 包。
> TSV：`reports/artifacts/mobian-pkg-20261107/daily-baseline.tsv`（57 行，P0 = 21）

## 0. 结论速览

1. **不要自己从零猜清单**。上游有两个权威基线可直接抄：
   - Mobian `meta-mobian 0.5.6`（`mobian-base` + `mobian-phosh-base`，Salsa control 原文已抓取）——它就是"Debian + Phosh 平板日用"的官方答案，其中明确 Depends `sudo / locales / man-db / bash-completion / rfkill / gnome-keyring 隐含 / fonts-noto-cjk` 等本次实测缺失的包。
   - Debian `meta-phosh`（`phosh-core` / `phosh-full` / `phosh-pim`，sid 版本 57.1）——`phosh-core` 把 `gnome-keyring`、`gnome-settings-daemon`、`gnome-control-center`、`xdg-desktop-portal-phosh`、`pipewire-pulse`、`libspa-0.2-bluetooth`、`iio-sensor-proxy`、`gnome-session-bin`、`gvfs` 全部列为 **Depends**。
2. **--no-install-recommends 的主要伤害**有两类：① phosh-core 的 Recommends（portal-gtk/wlr、phrog、phosh-mobile-settings、epiphany、network-manager-config-connectivity-debian、iio-sensor-proxy 等）在最小根里全部缺失；② 无元包托底时连 `locales`、`sudo`、`man-db`、`rfkill`、`bash-completion` 这类 "base 级" 包都不会被拉进来——mobian 的做法是把这些写进 meta 包 Depends 而不是 Recommends。
3. 最省事的落地路线：给 rootfs 补装 `phosh-core`（或自建一个对齐 `mobian-base + mobian-phosh-base` 的本地 meta 清单），再用本报告 TSV 的 P0/P1 做差额核对。

## 1. 上游参考集：Mobian meta 包与 Debian task-phosh-desktop

### 1.1 meta-mobian 0.5.6（来源：repo.mobian.org 源码包 control，已抓取原文）

- 下载：https://repo.mobian.org/pool/main/m/meta-mobian/meta-mobian_0.5.6.tar.xz
- `mobian-base` Depends（节选与本项目相关的）：`alsa-ucm-conf, alsa-utils, busybox, callaudiod, ca-certificates, console-setup, dosfstools, e2fsprogs, file, kbd, **locales, locales-all**, **man-db**, mobian-archive-keyring, pipewire-audio, rtkit, usb-modeswitch, usbutils, wireplumber, libnss-myhostname, libnss-systemd, libpam-cap, **bash-completion, curl, less, psmisc, sudo**, bluetooth, dnsmasq-base, iptables, iw, network-manager, **libspa-0.2-bluetooth**, net-tools, **rfkill**, systemd-resolved, wireless-regdb, wireless-tools, wpasupplicant`；Recommends：`btrfsprogs, f2fs-tools, openssh-client, rsync`。
- `mobian-phosh-base` Depends：`phosh-core, feedbackd-device-themes, at-spi2-core, iio-sensor-proxy, **fonts-noto, fonts-noto-cjk, fonts-noto-color-emoji, fonts-noto-mono, fonts-noto-ui-core**, mesa-libgallium, wayland-protocols, libgdk-pixbuf2.0-bin, libcanberra-gtk3-module, gnome-themes-extra-data, mobian-tweaks-phosh, network-manager-applet, xdg-desktop-portal-gtk, xdg-desktop-portal-wlr, xdg-user-dirs`；Recommends：`gnome-initial-setup, flatpak`。
- 平板（无 modem）场景不需要 `mobian-phone-base` / `mobian-phosh-phone`（telephony 件）。

### 1.2 Debian meta-phosh（来源：https://packages.debian.org/sid/phosh-core 与 /sid/phosh-full）

- `phosh-core`（sid, meta-phosh 57.1）Depends 关键项：`phoc, phosh, phosh-mobile-tweaks, phosh-osk-stevia, xdg-desktop-portal-phosh, gnome-session-bin, gnome-settings-daemon, gnome-control-center, gnome-keyring, libpam-gnome-keyring, gnome-online-accounts, gnome-backgrounds, fonts-cantarell, fonts-inter-variable, gsettings-desktop-schemas, dconf-gsettings-backend, evolution-data-server, gvfs-backends, gvfs-fuse, network-manager, libspa-0.2-bluetooth, pipewire-pulse, sound-theme-freedesktop, glib-networking, feedbackd, squeekboard, gstreamer1.0-plugins-base/good`。
- `phosh-core` Recommends：`epiphany-browser, gnome-console, gnome-contacts, phosh-mobile-settings, phrog(greeter), xdg-desktop-portal-gtk, xdg-desktop-portal-wlr, iio-sensor-proxy, network-manager-config-connectivity-debian, sound-theme-phosh, phosh-tour, feedbackd-device-themes` → **这批就是精简根最常缺的图形外围**。
- `phosh-full` Depends 增补：`wl-clipboard, xwayland, avahi-daemon, desktop-base, papers, gnome-console/clocks/weather, gstreamer1.0-libav/plugins-ugly, gapless`；Recommends：`file-roller, gnome-usage, livi, phosh-plugins, pfs-utils` 等。
- `task-phosh-desktop`（https://packages.debian.org/sid/tasks/task-phosh-desktop ）= `phosh-core + task-desktop + phosh-full + phrog + synaptic + network-manager-gnome`，是 tasksel 侧的"手机装机任务"。

## 2. 分类清单

见 TSV：`reports/artifacts/mobian-pkg-20261107/daily-baseline.tsv`，57 行，P0 21 个。类别覆盖：管理员与 shell、locale 与字体、输入法、桌面/会话、音频、蓝牙网络、电源与温控、截图剪贴板、调试工具。P0 判定标准：缺失即某条日常功能链路断裂（显示/输入/联网/音频/提权/电量/portal）。

## 3. 专项问答

### a) 缺 sudo：GNOME 设置/udisks 挂载/网络配置哪些失效？pkexec 现状？

**结论：Phosh 图形链路不依赖 sudo，缺 sudo 不致面板/挂载/网络失效；失效风险在图形 polkit agent 与 polkitd 本身。**

- GNOME 设置面板、udisks2 挂载、NetworkManager 改配置全部走 **polkit** 授权，而非 sudo。Polkit 的说明与 Debian 维护者的原话：任何希望做特权动作的系统服务（udisks、NetworkManager、flatpak --system…）需要的是 **agent**，它"要么内建于桌面 shell（GNOME Shell、Phosh），要么独立启动"。
  来源：https://github.com/linuxmint/cinnamon/issues/10172 （Debian polkit 维护者评论）
- **Phosh 内建 polkit agent**，因此装好 `polkitd`（Debian sid 包名）即可；Phosh 被列为虚拟包 `polkit-1-auth-agent` 的提供者。
  来源：https://packages.debian.org/sid/polkit-1-auth-agent
- `pkexec` 在 Phosh 的 **TTY 回退路径**有已知问题：无 GUI agent 时 pkexec 走 pkttyagent，会出现 "No session for cookie" 认证失败。
  来源：https://www.reddit.com/r/PinePhoneOfficial/comments/oya689/does_pkexec_ls_work_for_you_on_phosh/ （2021 年，现 Phosh 内建 agent 后 GUI 提权正常；TTY 路径未证实已修复 → 标**未证实**）
- `sudo` 仍是 mobian-base 的 Depends（见 §1.1），CLI 日常提权刚需，P1。另注意：NetworkManager 管理连接要求用户在 `netdev` 组，udisks 默认策略允许本机 active 会话免密挂载（ArchWiki/udisks2 默认 policy，未逐条核 Debian sid 原文 → 细节标**未证实**）。

**修复动作**：`apt install polkitd sudo`；`usermod -aG sudo,netdev <user>`；确认 `phosh` 已装（自带 agent）。

### b) locales 缺失修复步骤（Debian 13/sid）

**现象**：minbase + --no-install-recommends 只装 `libc-bin` 级别的 locale 支撑，`/etc/locale.gen` 为空、`perl: warning: Setting locale failed` / `LC_ALL` 报错。

**正确步骤**（来源：Debian wiki Locale，https://wiki.debian.org/Locale ；man locale-gen）：

```bash
apt install locales                # mobian-base 另装 locales-all，二选一
sed -i 's/^# *\(zh_CN.UTF-8 UTF-8\)/\1/; s/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen                          # 生成到 /usr/lib/locale
update-locale LANG=zh_CN.UTF-8 LC_CTYPE=zh_CN.UTF-8   # 写 /etc/default/locale（不要手写 LC_ALL）
```

要点：
- Debian 13/14 上 `locale-gen` 来自 `locales` 包，编辑 `/etc/locale.gen`（去掉行首 `#`）后执行；`/etc/default/locale` 用 `update-locale` 写，**只设 LANG**，不要设 `LC_ALL`（`LC_ALL` 仅用于调试覆盖，setlocale 检查会因此报错）。
- `localectl set-locale LANG=zh_CN.UTF-8` 亦可（systemd 250+ 直接改 /etc/default/locale）。未在设备上实测 → 步骤本身为 Debian 标准流程，标**未逐条实测**。

### c) fonts-noto-cjk vs -extra 取舍与 fc-match 期望

- 实测 Debian 侧包大小（`apt-cache show`，本机 amd64 sid 源）：`fonts-noto-cjk` deb ≈ 61.2MB（装后 ≈ 91MB），`fonts-noto-cjk-extra` deb ≈ 144.6MB（装后 ≈ 215MB）。差值 ≈ 124MB 换来的是 **多字重**（Thin/Light/Medium/Black）与 Noto Serif CJK 全字重。
- 本机（同样装了 noto-cjk）`fc-match 'sans-serif:lang=zh-cn'` 输出：
  `NotoSansCJK-Regular.ttc: "Noto Sans CJK SC" "Regular"` —— **装 fonts-noto-cjk 后设备上的期望输出即为此**；若回退到 DejaVu 或出现 "DejaVu Sans: Unknown" 即字体缺失/缓存未刷新（`fc-cache -f`）。
- **取舍**：只装 `fonts-noto-cjk`（P0）；`-extra` 为 P2，仅在需要排版多字重时加装。极端省空间可用 `fonts-wqy-zenhei`（≈8MB）应急，但缺衬线与粗体。
- Mobian 侧证据：`mobian-phosh-base` Depends `fonts-noto-cjk`（不含 -extra），见 §1.1。
  来源：https://packages.debian.org/sid/fonts-noto-cjk

### d) Phosh 上中文 + fcitx5-rime 自启正确做法

**结论：环境变量放 systemd 用户会话侧（`~/.config/environment.d/*.conf` 或 /etc/environment 均可），自启用 autostart desktop 文件；但 Phosh/phoc 上有"合成器单输入法"约束，属于已知坑。**

- Debian 的 `fcitx5` 包**不带 systemd user unit**（文件清单核查：https://packages.debian.org/sid/arm64/fcitx5/filelist 只有 `/usr/share/applications/org.fcitx.Fcitx5.desktop` 与 `fcitx5-wayland-launcher.desktop`）。所以：
  ```bash
  mkdir -p ~/.config/autostart && cp /usr/share/applications/org.fcitx.Fcitx5.desktop ~/.config/autostart/
  ```
  来源：https://fcitx-im.org/wiki/Setup_Fcitx_5/zh-cn （官方推荐 autostart 方式之一）
- 环境变量（来源：https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/zh-cn 、https://fcitx-im.org/wiki/Setup_Fcitx_5/zh-cn ）：
  - `XMODIFIERS=@im=fcitx`（XWayland 必需）、`QT_IM_MODULE=fcitx`（Qt 必需）；
  - **GTK**：GTK3/4 原生支持 text-input-v3，可走 `GTK_IM_MODULE=wayland`；设 `GTK_IM_MODULE=fcitx` 也可（fcitx 官方称 GTK 下 fcitx 模块体验最佳）。**不要只设 GTK 而漏掉 QT/XMODIFIERS**。
  - Phosh 会话由 systemd user manager 拉起，`~/.config/environment.d/im.conf` 写法（`GTK_IM_MODULE=fcitx` 一行一变量）对整个用户会话生效；`/etc/environment` 是系统级等价物。二选一即可，**推荐 environment.d**（不污染 root/服务会话）。
- **坑（重要）**：phoc 合成器一次只允许一个 input-method 客户端，squeekboard（Phosh 屏幕键盘）本身占着这个角色；fcitx5 以 `zwp_input_method_v2` 接入可能与 squeekboard 冲突（互抢/OSK 失效）。Mobian/Phosh 下 fcitx5 的稳定组合（哪个前端接入、是否禁 squeekboard）**未证实**，需在设备上实测验证（本报告不接触设备，留给后续任务）。
- `fcitx5-rime` 直接 `apt install fcitx5-rime`，配置在 `~/.local/share/fcitx5/rime`。

### e) gnome-keyring 缺失影响；是否 P0

**结论：P0。**

- `phosh-core` 将 `gnome-keyring` 与 `libpam-gnome-keyring` 列为 **Depends**（https://packages.debian.org/sid/phosh-core ），说明 DebianOnMobile 认定其为核心件。
- 缺失影响：
  1. WiFi 密码：NM 找不到 secret agent 时会把密码明文存到 `/etc/NetworkManager/system-connections`（root-only），**WiFi 仍能连**，但 GUI 侧"记住密码/提示输密码"体验降级（NM secrets 存储行为，标**未逐条实测**）。
  2. 应用侧：无 Secret Service D-Bus 服务 → Seahorse 无密钥库可管，浏览器/邮件/SSH 代理类应用无法保存密码。
  3. 登录解锁：无 `libpam-gnome-keyring` 则 keyring 不会随登录解锁，首次使用要再输一次密码。
- 修复：`apt install gnome-keyring libpam-gnome-keyring seahorse`（seahorse 为可选 GUI）。

## 4. 来源

- https://repo.mobian.org/pool/main/m/meta-mobian/meta-mobian_0.5.6.tar.xz （control 原文，已抓取）
- https://packages.debian.org/sid/phosh-core ；https://packages.debian.org/sid/phosh-full
- https://packages.debian.org/sid/tasks/task-phosh-desktop
- https://packages.debian.org/sid/polkit-1-auth-agent ；https://github.com/linuxmint/cinnamon/issues/10172 ；https://www.reddit.com/r/PinePhoneOfficial/comments/oya689/
- https://wiki.debian.org/Locale ；https://wiki.debian.org/Mobian
- https://packages.debian.org/sid/fonts-noto-cjk
- https://fcitx-im.org/wiki/Setup_Fcitx_5/zh-cn ；https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/zh-cn ；https://packages.debian.org/sid/arm64/fcitx5/filelist
- 包体积数据：本机 `apt-cache show fonts-noto-cjk fonts-noto-cjk-extra`（sid 源，amd64）
