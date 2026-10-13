# 研究：让 Phosh 出现「自动旋转」tile 并随重力旋转 —— 正确配方（2026-10-09）

## 结论前置（一句话 + 最大风险）
- **首选改法一句话**：Phosh 的自动旋转是 **phosh 自带**（`rotation-manager` 直接读系统总线 `net.hadess.SensorProxy`，经 phoc 的 Mutter DisplayConfig 设 transform，锁状态绑 gsettings `org.gnome.settings-daemon.peripherals.touchscreen:orientation-lock`），**完全不依赖 gnome-settings-daemon**；所以**别走 gsd 路线**——真正要做的是让 phosh 进入 `MODE_SENSOR` 并拿到实时 `AccelerometerOrientation`，即 **修复 iio-sensor-proxy 3.9 的 SSC claim 竞态（G1-34 已定位的 `ssc-claim-race.patch`）+ 让 phosh 在 iio-sensor-proxy 起来之后再启动**。
- **最大风险**：若照旧计划往 `RequiredComponents` / `/etc/xdg/autostart` 加 `org.gnome.SettingsDaemon.Orientation.desktop` 去 exec 一个**不存在的 `gsd-orientation`**，gnome-session 会把它当必需组件拉不起 → **fail-whale / respawn 环**（同 PITFALLS #51 gsd-power exit1 教训）。即便自研 shim 注册 `org.gnome.SettingsDaemon.Orientation` 名也**无用**，因为 phosh 根本不查这个名。

> 本文件与运行时产出 `.pi/sessions/subagent-artifacts/outputs/b6ba30e2-…/research.md` 内容一致。

---

## 关键推翻：原「D-Bus 总线错配 / tile 绑 org.gnome.SettingsDaemon.Orientation」根因是错的
根因文档假设「Phosh 的自动旋转 tile 绑定 `org.gnome.SettingsDaemon.Orientation`，该接口缺席 → tile 不显示」。**源码证明此假设错误**：gsd 50 里根本没有 orientation 组件可绑，且 phosh 从不引用该名。设备「无 tile + 方向锁死」的真因在 **iio-sensor-proxy ↔ phosh 的原生链路**（claim/时序），不在 gsd。

---

## Findings

### F1. gsd 46/47/50 不产出任何 orientation 二进制/插件（gsd 路线不可行）
- **Claim**：上游 `gnome-settings-daemon` 的 `plugins/meson.build` 里 `all_plugins` 列表在 **gnome-46** 与 **master(50/51)** 两分支**完全相同**，均 **不含 orientation**：
  `a11y-settings,color,datetime,power,housekeeping,keyboard,media-keys,screensaver-proxy,sharing,sound,usb-protection,xsettings,smartcard,wacom,print-notifications,rfkill,wwan`。
  每个 enabled 插件生成一个 `libexec/gsd-<name>` helper + 一个 `/etc/xdg/autostart/org.gnome.SettingsDaemon.<Camel>.desktop`（`Exec=@libexecdir@/gsd-@pluginname@`），由 `desktop-files.patch` 恢复。**orientation 从不在此列**，故不存在 `gsd-orientation` helper，也没有 `org.gnome.SettingsDaemon.Orientation.desktop`。
- 设备实测 `apk info -L` 只有 17 个 `gsd-*` helper、**无主 `gnome-settings-daemon` 二进制、无 gsd-orientation**，与本源码一致（拆分包模型里根本没有 orientation 可拆）。
- **Sources**：
  - gsd master plugins/meson.build — https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/raw/master/plugins/meson.build （确证）
  - gsd gnome-46 plugins/meson.build — https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/raw/gnome-46/plugins/meson.build （确证）
  - Alpine desktop-files.patch（`Exec=…/gsd-<name>` 的模板与来源）— https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/gnome-settings-daemon/desktop-files.patch （确证）
  - Alpine v3.22 包文件清单（无 orientation、无主二进制，只有 gsd-* helper）— https://pkgs.alpinelinux.org/contents?branch=v3.22&name=gnome-settings-daemon&arch=aarch64&repo=community （确证）
- **Confidence**：高。**确切删除版本：低**（未钉死是 GNOME 42 还是 45 周期删的；但 46 与 50 均已无，足以支撑决策）。历史证据：orientation 曾长期是 gsd 内置插件并 port 到 iio-sensor-proxy（2015 提交 https://mail.gnome.org/archives/commits-list/2015-May/msg05208.html ），后被上游移除。

### F2. Alpine 不是「漏打包」orientation——上游就没有，改 APKBUILD/装子包也拿不到
- **Claim**：Alpine `gnome-settings-daemon` APKBUILD（现 51.0）`subpackages` 只有 `dev/lang/systemd/udev`，构建期 **没有** `-Dorientation=disabled` 之类的开关（gsd meson 也**无** orientation 选项，`disabled_plugins` 里也没有它）。Alpine 的 `desktop-files.patch` 只是「revert 上游 Drop .desktop files」，按 `all_plugins` 生成 helper 的自启文件。**结论**：无法通过重装/额外子包/补 APKBUILD 得到 `gsd-orientation`——它在 gsd 50 里不存在。
- **Sources**：APKBUILD — https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/gnome-settings-daemon/APKBUILD （确证）；meson 无 orientation 见 F1。
- **Confidence**：高。

### F3. Phosh 原生实现自动旋转，读系统总线 `net.hadess.SensorProxy`，不碰 gsd
- **Claim（依赖链，源码确证）**：
  1. `src/sensor-proxy-manager.c`：`PhoshSensorProxyManager` 以 **`g-bus-type = G_BUS_TYPE_SYSTEM`** 连 **`net.hadess.SensorProxy`**（对象 `/net/hadess/SensorProxy`）。→ 与设备现状（proxy 只在系统总线、`HasAccelerometer=true`）**匹配**，「总线错配」假设作废。
  2. `src/rotation-manager.c`：
     - `ORIENTATION_LOCK_SCHEMA_ID = "org.gnome.settings-daemon.peripherals.touchscreen"`，`ORIENTATION_LOCK_KEY = "orientation-lock"`；`constructed()` 里 `g_settings_bind(... "orientation-locked", SYNC_CREATE|BIDIRECTIONAL)`。→ **phosh 自己消费这个 key**（设备读到 false 却「无人消费」，恰说明 rotation-manager 从未进入工作态，见 F4）。
     - `on_has_accelerometer_changed()`：`mode = has_accel ? MODE_SENSOR : MODE_OFF`，构造时用 `notify::has-accelerometer` + 立即读一次来定 mode。
     - 进入 `MODE_SENSOR` 后 `ClaimAccelerometer`；`on_accelerometer_orientation_changed()` → `match_orientation()` 读 `AccelerometerOrientation` 并 `phosh_monitor_manager_set_monitor_transform()` + `apply_monitor_config()`（即经 **phoc 的 Mutter DisplayConfig** 设 panel transform）。
  3. `src/rotateinfo.c`（tile/状态图标数据源）：`enabled = (mode==SENSOR && !orientation_locked)`；`present = !!get_monitor()`（有可旋转内置屏）。
  4. `src/quick-settings.c`：rotate tile 的 `on_rotate_clicked` 在 `MODE_SENSOR` 下翻转 `orientation-locked`；`on_rotate_long_pressed` 切 `MODE_SENSOR`↔`MODE_OFF`。tile 定义在 `quick-settings.ui` 模板，可见性由 rotateinfo 的 `present`/rotation-manager 驱动。
- **Sources**：
  - src/sensor-proxy-manager.c — https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/sensor-proxy-manager.c （确证）
  - src/rotation-manager.c — https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/rotation-manager.c （确证）
  - src/rotateinfo.c — https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/rotateinfo.c （确证）
  - src/quick-settings.c + src/meson.build — https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/quick-settings.c 、 https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/meson.build （确证）
- **Confidence**：高。
- **推断（标注）**：`quick-settings.ui` 里 rotate tile 的 `visible` 具体绑到 `PhoshRotateInfo:present`（=rotation-manager 有可旋转 monitor）。我读到了 rotateinfo 的 present/enabled 与 quick-settings 的回调，但 **.ui 文件路径本次 raw 404 未取到**，故「tile 可见性 == 有可旋转 monitor」为**高置信推断**，父进程可用 F6 的调试日志一条命令证实/证伪。

### F4. 设备「无 tile + 锁死」的真因候选（都在 phosh↔iio 原生链路）
- **Claim（推断，需 F6 日志定位是哪一条）**：
  - (a) **iio-sensor-proxy 3.9 SSC claim 竞态**（G1-34 已实测钉死）：claim 后 SSC 后端不开 polling → `AccelerometerOrientation` 冻结 → `match_orientation` 恒拿初值/`undefined` → 不旋转。
  - (b) **启动时序**：phosh 先于 iio-sensor-proxy 起来时，`PhoshSensorProxyManager` 构造即读一次 `has-accelerometer`；若此刻为假且之后无 `PropertiesChanged` 到达，`mode` 可能停在 `OFF`。（GDBus 对象管理通常会在名字出现后更新，但初值竞态值得排除。）
  - (c) **无可旋转内置 monitor**：若 phoc/DT 未把面板上报为可旋转 builtin，`present=false` → tile 不显示。
- 这些都**与 gsd 无关**。最可能是 (a)（G1-34 已确证现象）。

### F5. postmarketOS / Mobian：同样靠 phosh 原生，不加 gsd orientation（回答父进程 Q3）
- **Claim**：pmOS/Mobian 跑的是**同一份上游 phosh**（F3 的原生 orientation），配 `iio-sensor-proxy`，**不装、也无法装 gsd-orientation**（上游无此物），其 `phosh.session` 的 `RequiredComponents` 自然**不含** `org.gnome.SettingsDaemon.Orientation`（设备现状与其一致，非缺失）。tile 显示与旋转完全靠 phosh 原生链路 + iio-sensor-proxy 正常出数。
- **Sources**：gsd 无 orientation（F1，确证）+ phosh 原生（F3，确证）；本仓设备现状 `RequiredComponents` 无 Orientation（`/usr/share/gnome-session/sessions/phosh.session`，见根因文档）。
- **Confidence**：高（源码/包事实支撑）。「pmOS 具体不加 gsd-orientation」为**由上游源码与包内容推出的高置信结论**；未逐台核 pmOS recipe（无必要，因上游 gsd 根本没有该组件）。

### F6. 验收判据（父进程命令级，改在 phosh 原生链路）
系统总线侧（先证 claim-race 修复让 orientation 实时）：
```
# 1) 确认有加速度计
gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy \
  --method org.freedesktop.DBus.Properties.Get net.hadess.SensorProxy HasAccelerometer   # => <true>
# 2) 关键：claim 后边转边看是否实时变化（验证 SSC claim-race 已修）
gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy \
  --method net.hadess.SensorProxy.ClaimAccelerometer
for i in $(seq 8); do gdbus call --system --dest net.hadess.SensorProxy --object-path /net/hadess/SensorProxy \
  --method org.freedesktop.DBus.Properties.Get net.hadess.SensorProxy AccelerometerOrientation; sleep 0.4; done
#    期望：姿态变化时值在 normal/left-up/right-up/bottom-up 间实时切换（不是冻结）
```
phosh 侧（tile 与旋转）：
- Phosh 快速设置出现「自动旋转」tile；点一下翻转：
  `gsettings get org.gnome.settings-daemon.peripherals.touchscreen orientation-lock` 应随之 `true↔false`。
- 开（lock=false）→ 随姿态转；关（lock=true）→ 锁定。
- 若 tile 仍不出现，用日志一条定位是哪条 gate（F4）：
  `G_MESSAGES_DEBUG=phosh-rotation-manager,phosh-sensor-proxy-manager phosh …`（或在既有会话 journal 里 grep）→ 关键行：
  `Got no sensor-proxy, no automatic rotation`（=sensor-proxy 没建成）／`Found a accelerometer` 与否／`Rotation manager mode: <0=OFF/1=SENSOR>`／`Built-in monitor present: <0/1>`。
- **不再**检查 `org.gnome.SettingsDaemon.Orientation`（该名不会、也不应出现）。

---

## 落地改法（父进程执行；**不动 gsd**）
前提事实：主 gsd 二进制/`gsd-orientation` 不存在（F1/F2），因此**不要**改 `phosh.session:RequiredComponents`、**不要**新增 `org.gnome.SettingsDaemon.Orientation.desktop`。

### 首选（最小、可持久、可回退）：修 iio-sensor-proxy + 保证 phosh 晚于 proxy 启动
1. **修 SSC claim 竞态**（G1-34 已给补丁，1 hunk）：给 iio-sensor-proxy 3.9 打
   `ssc-claim-race.patch` — https://raw.githubusercontent.com/blu-sharky/piano-sensors/main/patches/iio-sensor-proxy/ssc-claim-race.patch
   设备重编安装（父进程有构建/设备通道）。这是让「开→随姿态转」成立的**根因修复**（否则 tile 出现也冻结不转）。
2. **会话内保证 proxy 先于 phosh**：确保 iio-sensor-proxy 系统服务在多用户/phosh 会话前 `rc-update add`/已 running（本仓 `scripts/openrc-enable.sh` 里 idempotent 追加）。
3. **锁状态**：`gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false`（若设备默认 true 会「有 tile 但锁死不转」）。

idempotent 片段示意（放 `scripts/openrc-enable.sh` 或 `rootfs/persistent-overlay` 的 setup）：
```sh
# 幂等：确保 iio-sensor-proxy 开机自启且早于桌面会话
rc-update add iio-sensor-proxy default >/dev/null 2>&1 || true
rc-service iio-sensor-proxy status >/dev/null 2>&1 || rc-service iio-sensor-proxy start
# 幂等：解锁自动旋转（写进用户 dconf；桌面会话用户跑）
sudo -u <deskuser> DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus \
  gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false
```
**持久化**：iio 补丁产物走 pkgs/rootfs overlay（与既有 vk64/vk72 资产同法）；服务启用写 `scripts/openrc-enable.sh`；gsettings 写用户 dconf（overlay 的 `etc-greetd/`/用户 profile 已管）。
**回退**：`rc-update del iio-sensor-proxy default`；还原 `pkgs-phosh/iio-sensor-proxy-*.apk` 覆盖（`apk fix`/重刷 overlay）；`gsettings reset …orientation-lock`。**全程不需还原 phosh.session/autostart**（因为本方案不改它们）——比原 A/B 方案回退面更小。

### 明确不要做的（原候选 A/B 已否决）
- **不要**把完整主 gsd 或 `org.gnome.SettingsDaemon.Orientation.desktop` 塞进 `RequiredComponents`/`/etc/xdg/autostart`：exec 目标 `gsd-orientation`/主 gsd 都不存在 → gnome-session 报「Unrecoverable failure in required component」→ fail-whale/respawn（同 PITFALLS #51）。
- **不要**自研 shim 去注册 `org.gnome.SettingsDaemon.Orientation`：phosh 不查该名（F3），白费且可能与 phosh 自身锁语义打架。

---

## 风险与最小化
- **主风险**：误改 `RequiredComponents` 拉不存在的 helper → 会话崩（见上）。最小化：本方案根本不碰 session 描述文件。
- **次风险（真实且需处理）**：SSC claim 竞态导致 tile 出现但方向冻结——必须用 `ssc-claim-race.patch`；否则「开→转」不过。验收 F6 step 2 专门验这点。
- **启动时序风险**：若 tile 因 mode 停 OFF 而不出现，用 F6 调试行区分 (b)/(c)；(b) 让 phosh 晚于 proxy 启动即可，(c) 属 phoc/DT 屏可旋转性问题（另案，勿动 mount-matrix）。
- **版本差异**：本报告读的是 phosh main(0.58) 源码，设备是 0.55.0。核心链路（system-bus SensorProxy + orientation-lock bind + monitor transform via phoc）自 ~0.16 起长期稳定；quick-settings 与其 rotate tile 于 0.4x 引入，0.55 必含。`.ui` 可见性绑定为推断（F3 末），用 F6 日志即可闭环。

---

## Contradictions（记录，不擅改）
- 根因文档 `…自动旋转开关缺失-D-Bus总线错配.md` 称「tile 绑 `org.gnome.SettingsDaemon.Orientation`，该接口缺席」——**被 phosh/gsd 源码证伪**（该名不存在于 gsd 50，phosh 不引用）。
- 更早 `…G1-34-旋转阻塞.md` §2.2 反而写对了一半：「`gsd-orientation` 二进制不存在；Phosh 自带 `net.hadess.SensorProxy` 客户端」——与本报告一致；其 §2.1 的 **iio-sensor-proxy SSC claim 竞态**是本问题最可能的真因，且已给补丁。
- 两份设备文档对「真因」互相矛盾（一个指向 gsd 缺席，一个指向 iio claim 竞态）；本报告用源码裁定：**gsd 路径无效，iio↔phosh 原生链路才是着力点**。

## Missing evidence / 未决
- `quick-settings.ui` rotate tile 的精确 `visible` 绑定（`.ui` raw 404 未取到）→ 用 F6 调试日志现场证实（monitor present vs mode）。
- 设备 phosh 是否因**启动早于** iio-sensor-proxy 而缓存「无传感器」→ F6 `Found a/no accelerometer`、`Rotation manager mode` 一行可判。
- gsd orientation 插件被上游删除的**确切版本**未钉（不影响结论）。
- phoc 0.55.1 是否把该面板判定为 builtin 且可旋转（F4-c）→ 需 `G_MESSAGES_DEBUG=phosh-rotation-manager` 看 `Built-in monitor present`。

## Sources
**Kept（均为主源码/权威包库）**
- gsd master `plugins/meson.build`（`all_plugins` 无 orientation）— https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/raw/master/plugins/meson.build
- gsd `gnome-46/plugins/meson.build`（同列表，证明 46/47 也无）— https://gitlab.gnome.org/GNOME/gnome-settings-daemon/-/raw/gnome-46/plugins/meson.build
- Alpine APKBUILD（无 orientation 打包/开关）— https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/gnome-settings-daemon/APKBUILD
- Alpine desktop-files.patch（helper→autostart 生成机制）— https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/community/gnome-settings-daemon/desktop-files.patch
- Alpine v3.22 gsd 包文件清单（无 orientation/无主二进制）— https://pkgs.alpinelinux.org/contents?branch=v3.22&name=gnome-settings-daemon&arch=aarch64&repo=community
- phosh `sensor-proxy-manager.c`（system-bus SensorProxy）— https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/sensor-proxy-manager.c
- phosh `rotation-manager.c`（orientation-lock bind / mode / transform via phoc）— https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/rotation-manager.c
- phosh `rotateinfo.c`（tile present/enabled 数据源）— https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/rotateinfo.c
- phosh `quick-settings.c` + `src/meson.build`（rotate tile 存在与回调）— https://gitlab.gnome.org/World/Phosh/phosh/-/raw/main/src/quick-settings.c
- iio-sensor-proxy `ssc-claim-race.patch`（F4-a 修复）— https://raw.githubusercontent.com/blu-sharky/piano-sensors/main/patches/iio-sensor-proxy/ssc-claim-race.patch
- 本仓：`.pi/plans/2026-10-09-G1-34-旋转阻塞.md`、`PITFALLS.md #51/#584`（gsd-power fail-whale 教训）

**Rejected/deprioritized**
- Brave 检索里的 Ubuntu/Arch/Reddit 桌面旋转问答、qt-sensors gist：仅泛用桌面 iio/gsd 说明，与本 phosh 栈无直接权威，弃用。
- firecrawl：配额 402 耗尽，全程改用 headless Firefox 取原文（不影响结论，均已取到一手源码）。

## Next steps（父进程）
1. 落地首选：打 `ssc-claim-race.patch` 重编 iio-sensor-proxy + 保证 phosh 晚于 proxy + `orientation-lock false`（F6 验收）。
2. 若 tile 仍不出现：跑 `G_MESSAGES_DEBUG=phosh-rotation-manager,phosh-sensor-proxy-manager`，按 `Got no sensor-proxy / Found a-no accelerometer / mode / Built-in monitor present` 四行区分 F4(a/b/c)。
3. **不要**再往 `RequiredComponents`/autostart 加 Orientation 项。
