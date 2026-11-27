# droidloom 0.1.0-49 → 0.1.0-51 升级 + 占位 IME 复判（T15/T3 收口，2026-11-27 晚，父代理上机）

- **性质**：设备侧 additive 升级（`tar --zstd -xf -C /` 覆盖 runtime+image，复用 base-49），零刷写、零分区写、零内核改动。
- **设备**：U2（`ssh elden`，2001:…/192.168.7.1，用户 `xuqianhui1001`），在机内核 `7.3.1-debug-vk189-suspend-g4da9a8b69fc8`，根 `/dev/sda17` 190 G。
- **前置资产**（父代理 11-27 白天已备）：`~/dl-droidloom-51/{image,runtime}-0.1.0-51-aarch64.pkg.tar.zst` + `source-51`。
- **判据**：T15 = 「`droidloomctl status` 仍 Android ready + 再判 IME」；T3 = 「占位 IME 状态机缺陷是否被 51 修掉」。

## 0. 一页结论

| # | 问题 | 判定 | 依据 |
|---|---|---|---|
| 1 | 51 装上了吗 | ✅ **装上并跑起来** | `droidloomctl status` = `cell u1001 is running …; Android is ready`；`droidloom-doctor` = **READY / 0 blockers**（1 WARN = `security.host_lsm`，与 49 基线和 11-11 基线同项） |
| 2 | 51 修好占位 IME 了吗 | ❌ **没有** | 把默认 IME 切回 `com.android.droidloom.ime/.HostInputMethod` 后点搜索框：`ImeTracker: system_server:… onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`（与 49 逐字同一失败相位）；宿主 `phosh-osk-stub` 进程活着但**没有任何 OSK 窗口**，`grim` 截图无键盘 |
| 3 | 51 有没有别的变化 | 🟡 **一半**（诚实标注） | 49 的样本里有 `DroidloomIME: start input restarting=true` + `RemoteInputConnectionImpl: Session id mismatch`；**51 三份样本全是 `restarting=false`**，且 `dumpsys input_method` 由 49 的 `mInputShown=false/mWindowVisible=false` 变成 **`mInputShown=true`**。但「`show request` 仍被判失败 + 屏上无键盘」这个**用户可见事实不变** ⇒ 缺陷未修 |
| 4 | 绕行还在吗 | ✅ **Fossify 仍可用**（已恢复为默认 IME） | 切回 `org.fossify.keyboard/.services.SimpleKeyboardIME` 后点搜索框：`mInputShown=true`、`dumpsys window` 出现 `Window{… InputMethod}` / `mInputMethodWindow=…`，`input text hello` 落进输入框（截图 `osk-fossify.png`） |
| 5 | 回滚路径 | ✅ 一条命令 | 两包都在主机 `~/dl-droidloom-49/`（`image` 66 862 311 B / `runtime` 11 047 451 B，`zstd -t` 过），按同法 `tar --zstd -xf -C /` 覆盖即可；`/etc/droidloom/*` 与 `/var/lib/droidloom/users/1001` 未被本次覆盖触碰 |

## 1. 安装步骤（每步判据）

```sh
# 1) 传输 + 逐字节校验（主机 sha256 = 设备 sha256）
scp droidloom-{runtime,image}-0.1.0-51-aarch64.pkg.tar.zst elden:/tmp/dl51/
sha256sum /tmp/dl51/*.zst
#   runtime 5e9f188fad43b77fea447cd73c50692438d138710a18b36a845d7f2d6dbd0bf2
#   image   7f260d3863c798f893146e2f4ae2fecf6c4df23c5ad300b1b833027f72959656
# 2) 升级前快照（56 行 sha，留档 /var/lib/droidloom/upgrade-51/pre-49-sha.txt）
# 3) 停：systemctl --user stop droidloom.service
# 4) 解包（排除包元数据，否则会把 .PKGINFO/.MTREE 摊到 /）
sudo tar --zstd -xf <pkg> -C / --exclude=.PKGINFO --exclude=.MTREE --exclude=.BUILDINFO --exclude=.INSTALL
# 5) 起：systemctl --user daemon-reload && systemctl --user start droidloom.service
```

- `droidloomctl --version` 仍是 `0.1.0`（版本粒度在包 release 上），真版本看 `settings`/`/etc/droidloom/package-state.json`（**本轮未改它**，仍记 `release: 49`——见 §4 待办 ③）。
- 解包**先 runtime 后 image**（image 里含 `usr/lib/droidloom/current` 软链与 `images/vendor.raw.img`）。
- base-49 复用（`image-51` 的 `.PKGINFO`：`depend = droidloom-base=0.1.0-49`）⇒ 未重下 903 MB。

## 2. 占位 IME 复判（T3 的「先升再判」）

**干净样本**（cell 重启后首启 App，避免上一次残留态）：

```sh
adb shell settings get secure default_input_method
#   com.android.droidloom.ime/.HostInputMethod
systemctl --user restart droidloom.service   # 新 cell
droidloomctl launch com.android.settings     # ⇒ launched … task=23
adb shell input tap 950 330                  # 点 Settings 搜索框
```

结果（Android UTC `12:39:46`）：

```
ImeTracker: com.android.settings.intelligence:… onRequestShow at ORIGIN_SERVER reason SHOW_AUTO_EDITOR_FORWARD_NAV
ImeTracker: com.android.settings.intelligence:… onFailed at PHASE_SERVER_UPDATE_CLIENT_VISIBILITY
DroidloomIME: finish input
DroidloomIME: start input restarting=false editable=true
DroidloomIME: show request configChange=false
ImeTracker: system_server:… onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE      ← 与 49 同一失败相位
ImeTracker: com.android.settings.intelligence:… onRequestShow at ORIGIN_CLIENT reason SHOW_SOFT_INPUT fromUser true
ImeTracker: com.android.settings.intelligence:… onCancelled at PHASE_CLIENT_REPORT_REQUESTED_VISIBLE_TYPES
```

- `dumpsys input_method` ⇒ `mInputShown=true`（49 是 `false`）；但宿主侧 `grim` 截图**无键盘**，`wlrctl toplevel list` 只有 App 窗口，没有 OSK 顶层。
- 宿主 `phosh-osk-stub` 进程在（`ps -eo comm | grep` 命中 1 个）⇒ 「OSK 没画」不是 daemon 没起。
- 与静态结论一致：`HostInputMethod.onShowInputRequested()` 在 49/51 都 `return false`（51 的 IME 增量全在 subtype/layout 与 inset，无 show/dismiss 状态机）⇒ **升级不能修键盘**，本轮实测确认。

## 3. 顺带观察到的两个新现象（未定因，只记）

| # | 现象 | 复现条件 | 证据 |
|---|---|---|---|
| a | `droidloomctl launch` 报 `read framework reply: framework response deadline expired`（等 100 s+ 后），且 Android 侧焦点停在 `com.android.droidloom.home/.HomeActivity`，而 App 任务 `visible=false` | **占位 IME 为默认 + 上一次 launch 未完成**时连续 launch；重启 cell 后同一 App 能正常起（`task=23` 正常） | `journalctl --user -u droidloom.service` 无报错，只有 `Droidloom requested host activation` + `composition targets … configure=2 size=1902x3039`；该现象与 §2 的 IME 缺陷是否同源**未分离**（两个自变量同时在场） |
| b | 面板被锁屏 + DPMS Off 时会话态「看着像 App 没起」 | 设备空闲自动锁屏后 | `wlr-randr` = `Enabled: no`、`/sys/class/drm/card0-DSI-1/dpms` = `Off`；`grim` 报 `failed to copy output DSI-1`。解锁判据链见 §3.1 |

### 3.1 无人上机需要「唤醒 + 解锁」时的正确姿势（本轮踩坑）

- `wlr-randr --output DSI-1 --on` 能把 DPMS 打回 On（否则 `grim`/`adb screencap` 全是黑图）。
- 解锁必须在**宿主合成器层注入触摸**：仓库**已有** `tools/uinput-touch.c`（`tap X Y` / `swipe X1 Y1 X2 Y2`，默认 1904x3042，注释里已写明「phosh 只有在最后一次输入是触摸时才展开 OSK」），交叉编 `tools/uinput-touch-build.sh`。
- 本轮教训：父代理**先手写了一份 python evdev 注入脚本**才想起来 `tools/uinput-touch` 已存在（临时件已丢弃，未入库）⇒ 下轮先 `ls tools/ scripts/ | grep -i uinput`。
- 注入需要 root（`/dev/uinput`）⇒ `sudo -n python3 …` / `sudo -n out/tools/uinput-touch swipe 952 2800 952 600` 均可（设备 `sudo` 免密）。

## 4. 待办（本轮未做，均已登记）

| # | 待办 | 判据 | 阻塞 |
|---|---|---|---|
| ① | 占位 IME 缺陷提上游 issue（62 条 issue 零命中 `showSoftInput`） | issue 发出 + 带 49/51 两版日志对照（本轮 §2 就是 51 版样本） | **需用户放行外部发帖** |
| ② | ②-b：把 T2 的 4 条本地 patch 打到 51（`--forward-signals` / `runuser` / cell DNS / `WifiProvisioning` 自愈） | 见 `TASKS/NEXT.md` T2 | 需备份 runtime；可回退 |
| ③ | `package-state.json` 的 `version.release` 仍是 49（本轮未改，怕与 helper 校验冲突） | 跑一次 `droidloom-package-helper` 的正式更新路径对齐，或用 pacman 语料包重装 | 无；不影响运行（doctor/启动都不读它） |
| ④ | §3-a 的 launch 卡死要**单变量**分离（只切 IME，不叠加重复 launch） | 4 种组合各 1 次：{49,51} × {占位 IME,Fossify}，看 `framework response deadline expired` 是否只在占位 IME 出现 | 需 cell 重启若干次（本机已可无人执行） |

## 5. 收尾设备态

- 默认 IME = `org.fossify.keyboard/.services.SimpleKeyboardIME`（绕行保留）；占位 IME 仍 enabled 未卸载。
- cell = 0.1.0-51 running / Android ready；`droidloom-doctor` READY 0 blockers。
- 未改任何内核/分区；`/var/lib/droidloom/users/1001` 与 `/etc/droidloom/*` 原样。
