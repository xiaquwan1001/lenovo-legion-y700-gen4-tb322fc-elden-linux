# droidloom 部署（工单 D）——U2 平板 TB322FC，2026-11-26

- **设备**：U2（`ssh elden-root`，192.168.7.1），在机内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，根 `/dev/sda17` 190G。
- **性质**：设备侧安装 + 上机取证。**零刷写、零分区写、零内核改动**；全部写入为 additive（新目录/新文件/追加 subuid 行），回滚见 §7。
- **判据基线**：L1–L4 定义 = `reports/droidloom-feasibility-20261110.md` §4 表 + `reports/droidloom-status-20261111.md` §1.2；App 兼容静态结论 = `reports/droidloom-app-compat-20261125.md`（J2/J3）。

## 0. 一页结论（三个二值）

| # | 问题 | 判定 | 一句话依据 |
|---|---|---|---|
| 1 | **cell 起没起** | ✅ **起** | `droidloomctl status` = `cell u1001 is running …; Android is ready`；doctor `ready=True blockers=0`（13 PASS / 1 WARN，WARN 与 2026-11-11 基线同项 `security.host_lsm`）；`applications` 列出 2 个系统应用；L4 单点 = `launch com.android.settings` 返回窗口对象 + 用户侧留待目视 |
| 2 | **Limbus 起没起** | ❌ **没起（装上了，启动即被杀）** | 三 split 安装 `Success`；`launch` 后 AppSealing（INKA，v2.35.1.0）主进程初始化即 `Kill Process [20059]` + 弹 `AppSealingAlertDialog`（窗口已 Displayed）后进程退出；`droidloomctl launch` 报 `Launch has no attached application task` |
| 3 | **小红书起没起** | ✅ **起（窗口级）** | 单 APK 官方路径 `droidloomctl install` 成功；`launch com.xingin.xhs` 返回窗口对象（task=7/11，两次），主 Activity `IndexActivityV2` 1440x2400 上屏，logcat 无 FATAL/SIGSEGV/SIGILL；**但 cell 无网（见 §5 缺口-1）⇒ 信息流/登录类功能预期不可用** |

## 1. 取件（全部本地现成件，零新下载）

| 件 | 来源 | sha256（前 16 位） | 校验 |
|---|---|---|---|
| `droidloom-base-0.1.0-49-aarch64.pkg.tar.zst` | 主机 `~/dl-droidloom-49/rb-base.zst`（2026-11-25 已下） | `40712a6eb1bcc451` | `zstd -t` 过；**与上游 release asset digest 逐字一致**（GitHub API 实查） |
| `droidloom-image-0.1.0-49-aarch64.pkg.tar.zst` | 同上 | `8257effad113503e` | `zstd -t` 过；`.PKGINFO` pkgver=0.1.0-49 arch=aarch64；体积与 app-compat 报告记录一致（66 862 311 B） |
| `droidloom-runtime-0.1.0-49-aarch64.pkg.tar.zst` | 同上 | `6e5cf18c7c196f3f` | 同上（11 047 451 B） |
| Limbus 三 split + 小红书 base | 主机 `~/apk-20261125/`（2026-11-25 自 vivo V2454A 提取，`SHA256SUMS` 在案） | 4 件与既有 `SHA256SUMS` 逐字一致 | 传输后设备侧 sha256 复核一致 |

APK 现查结论：**设备 `/sdcard`、`~/Downloads`、`~/.cache` 无现成包，但主机 `~/apk-20261125/` 已有全部所需包** ⇒ 未触发「停下问总管」条件，未从第三方站点下载任何东西。

## 2. 安装步骤（每步判据）

1. **前置现查**：`/opt/dl-test`、`droidloomctl`、droidloom unit、`/etc/droidloom`、`/var/lib/droidloom` 全部不存在（与派工单一致）；`hexagonrpcd{,-suspend,-resume}`、`iio-sensor-proxy` 仍 masked，`--failed`=0，phoc/phosh 各 1。
2. **内核/宿主前置**（引 feasibility 判据，非新假设）：vk189 `CONFIG_NF_TABLES=y`/`CONFIG_VETH=m`/`CONFIG_ANDROID_BINDERFS=y`、binderfs 已挂、`nft list ruleset` rc=0、`/dev/dri/renderD128 (msm_dpu)`；**2026-11-11 的 rootfs 属主结构性卡点已不存在**（`/ /var /var/lib /etc /usr` 现 `root:root 0755`）。
3. **摊装**：三个 pacman 包 `tar --zstd -xf -C /`（base 41 项 / image 302 项 / runtime 644 项）；`/usr/lib/droidloom/current → runtime` 软链在位，9 个 `droidloom-*` 二进制 + 9 个 systemd unit 落位（system 1 + user 8）。
4. **subuid 契约**：追加 `xuqianhui1001:300000:100000`（`/etc/subuid`+`/etc/subgid`；原 `100000:65536` 行未动；备份 `/etc/sub{uid,gid}.bak-dl-20261126`）。
5. **doctor（L1–L2 判据）**：`droidloom-doctor` = **ready=True blockers=0**，13 PASS / 1 WARN（`security.host_lsm`，非阻塞，同 2026-11-11 基线）。证据：`reports/artifacts/droidloom-deploy-20261126/doctor-final.txt`。
6. **官方 setup**：`droidloom-package-helper setup --uid 1001 --data-home … --state-home …`（root 跑，等价 pkexec 路径）⇒ 生成 `/etc/droidloom/{cell.json,runtime.env,package-state.json}` + polkit 规则 + `/var/lib/droidloom/users/1001/data`；GPU 判定 `Qualcomm ae01000.display-controller (msm_dpu) native (Mesa)`。
7. **起 cell（L3 判据）**：`systemctl --user enable --now droidloom.service` → `droidloomctl status` = `cell u1001 is running …; Android is ready`；`droidloomctl applications` = `listed 2 Android applications`（Files / Settings）。
8. **L4 单点**：`droidloomctl launch com.android.settings` = `launched … object=… composer_display=2 android_display=0 task=6`（独立 Wayland 窗口已创建；**用户目视确认留待总管/用户**）。
9. **开机自启**：`systemctl --user is-enabled droidloom.service` = enabled（`graphical-session.target.wants` 软链在位）。

### 安装途中修掉的三个非预期（均为 additive、可回退）

| # | 症状 | 根因 | 修法 |
|---|---|---|---|
| a | cell 起不来，droidloomd 循环报 `unshare: 未识别的选项 "--forward-signals"` | Debian trixie util-linux **2.41.5** 无该选项（2.42 新增；上游按 Arch 2.42+ 开发） | 从 **Debian testing util-linux 2.42.4-1 arm64** deb 只提取 `unshare` 二进制装到 `/usr/local/bin/unshare`（PATH 先于 `/usr/bin`；不动系统包；libc 依赖仅 libc.so.6，trixie glibc 可跑，实测 `unshare --forward-signals … echo` OK）。**回退 = 删该文件** |
| b | `droidloom-applications: catalog refresh deferred: Permission denied` | `~/.local` 为 root:root（2026-11-19 遗留）且 `~/.local/state` 不存在 | `install -d -o xuqianhui1001 -g xuqianhui1001 -m 700 /home/xuqianhui1001/.local/state`（仅新建目录） |
| c | `adb` 不在设备 | runtime 包不自带（Arch 侧为依赖） | `apt install adb`（Debian 正常包，additive） |

## 3. 小红书安装与启动（J3 上机）

```sh
droidloomctl install /home/xuqianhui1001/dl-apps/xhs/base.apk   # vivo 整包，单 APK 官方路径
# ⇒ "APK installed successfully; the application catalog will refresh automatically"
droidloomctl launch com.xingin.xhs
# ⇒ launched … object=… task=7（复测 task=11）
```
- 主 Activity `IndexActivityV2` 1440x2400 上屏；`libun7zip.so` 等 arm64 原生库加载 ok；logcat **0 条 FATAL/SIGSEGV/SIGILL**。日志：`artifacts/…/xhs-launch-log.txt`、`xhs-first-launch-log.txt`。
- compat 报告的风控栈（libxyass/SystemHealer/tinyd/msaoaid）未触发崩溃级反应——**但 cell 无网**，风控/信息流真实判定被网络缺口压住（见 §5）。

## 4. Limbus 安装与启动（J2 上机）

**分片缺口确认**：`droidloomctl --help`/`docs/INSTALL.md` §5 仍「single, standalone APK only」⇒ 官方 CLI 不支持 splits，与 2026-11-25 静态结论一致。

**最小可行绕过（已验证可行）**：不用 adb（cell 网络死，见 §5），复刻 supervisor 自己的 `droidloomctl install` 底层原语——`nsenter` 进 cell 跑 `cmd package install-create/-write -S/-commit` 会话分片安装：

```sh
CELLPID=$(pgrep -f "droidloom-supervisor development-enter" | head -1)
nsenter --target $CELLPID --mount --uts --ipc --net --pid --cgroup --root --wd --env -- \
  /system/bin/cmd package install-create -r --user 0        # ⇒ Success [1358747597]
cat base.apk                    | nsenter … cmd package install-write -S 32089880    $SID base
cat split_config.arm64_v8a.apk  | nsenter … cmd package install-write -S 63989568    $SID split_config.arm64_v8a   # Success: streamed …
cat split_UnityDataAssetPack.apk| nsenter … cmd package install-write -S 1340289371  $SID split_UnityDataAssetPack # Success: streamed …
nsenter … cmd package install-commit $SID                                          # ⇒ Success
```

**启动结果 = 被安全层杀**：

```
I AppSealing: BUILD VERSION : 2.35.1.0 (Core Version = C220605-002)
I AppSealing: Initiate AppSealing Security : ARM64
E AppSealing: !!!!!!!!!!! Kill Process ..........................[20059]
I ActivityTaskManager: START … cmp=com.inka.appsealing.AppSealingAlertDialog …
I ActivityTaskManager: Displayed com.ProjectMoon.LimbusCompany/com.inka.appsealing.AppSealingAlertDialog … +571ms
```
主进程自 SIGKILL，随后每次 `launch` 都重复同一序列。**判定 = 「装得上、起不来（AppSealing 反篡改层）」**，非 Unity/CPU 拓扑问题（那些日志干净）。AppSealing 检测类别（dex 字符串）：`BLOCK_ENV_ROOTING_ALERT` / `BLOCK_ENV_EMULATOR_ALERT` / developer options / USB debugging；本形态最可能命中 **rooting 检测**（cell `androidboot.selinux=permissive` + shared-kernel）或 emulator 启发式。日志：`artifacts/…/limbus-appsealing-log.txt`、`limbus-first-launch-log.txt`。
**对上游（denialwm/droidloom）**：值得提 issue——「AppSealing-protected apps（Limbus Company 1.118.0）在 shared-kernel cell 上 init 即自杀（Kill Process [20059] + alert dialog）；疑因 permissive SELinux / 非真实设备画像；KNOWN_ISSUES 未覆盖」。
**对 GApps 路线**：AppSealing 检测与 GMS 无关，装 GApps 预期救不了；**不建议**为此立项 GApps（compat 报告 §1.3 的四步成本仍在）。

## 5. 剩余缺口（按重要性）

1. **cell 无网（未解，本轮最大缺口）**：`droidloom-u1001` netns 内 `wlan0` UP 但**始终无 IPv4**；宿主侧 `dlh1001` 上 tcpdump 2 分钟+重后完整 boot 期**零帧来自 cell**（`artifacts/…/tcpdump-no-cell-traffic.txt`）。已查实：DHCP responder 按源码应答（packet socket），`wifi_provisioned=true`（SystemUI 侧 `droidloom-wifi` SharedPreferences，宿主文件直读），wificond/supplicant-service.droidloom 进程在、扫描事件正常，但 **supplicant 关联 → ClientModeImpl → DHCP 链条未发生**（无任何 DHCP DISCOVER）。⇒ adb 端点（10.177.0.2:5555）不可达 ⇒ `adb install-multiple` 官方分片旁路不可用（本轮用 nsenter staging 绕过）；小红书信息流/登录、Limbus 资源拉取都被压住。**判据命令**：`nsenter --net=/run/netns/droidloom-u1001 ip -4 addr show dev wlan0`（期望出现 `inet 10.177.0.2/30`）；`tcpdump -i dlh1001`（期望 DHCP DISCOVER）。
2. **Limbus × AppSealing**（见 §4）：上游 issue 待提；本仓不做绕过（反篡改对抗超出边界）。
3. **util-linux shim**：`/usr/local/bin/unshare`（2.42.4）是部署件的一部分；Debian testing 正式发布该版本后可删除。PITFALLS 候选：「Debian trixie util-linux 2.41 缺 `--forward-signals`，droidloom cell 起不来」。
4. **未测**：音频 broker、`droidloom-devices`（haptics/camera/location）、`droidloomctl dpi`、重启后自启实测（enable 已落，未做整机 reboot 验证）、窗口触摸/键鼠交互的用户目视确认。

## 6. 关键数字

- 包：base 903 293 629 B / image 66 862 311 B / runtime 11 047 451 B；摊装后 `/usr/lib/droidloom` ≈ 2.4 GiB；Limbus 写入 data ≈ 1.44 GiB。
- doctor：**13 PASS / 1 WARN / 0 BLOCK**；applications：**2**；launch 成功记录：settings task=6、xhs task=7/11、Limbus task=9/10（被杀）。
- 传输：rsync over USB-NCM ≈ 18.6 MB/s，全部 sha256 设备侧复核一致。

## 7. 回滚步骤（已实测不触发）与当前安全态

零刷写 ⇒ 无分区/槽回滚需求。逐项拆除（如需回到 2026-11-26 13:5x 状态）：
```sh
ssh elden-root 'su xuqianhui1001 -c "export XDG_RUNTIME_DIR=/run/user/1001; systemctl --user disable --now droidloom.service"'
ssh elden-root 'systemctl stop droidloomd; rm -rf /usr/lib/droidloom /usr/bin/droidloom-* /usr/lib/systemd/system/droidloomd.service /usr/lib/systemd/user/droidloom-* /usr/share/droidloom /etc/droidloom /etc/polkit-1/rules.d/49-droidloom.rules /var/lib/droidloom /var/lib/systemd/linger 2>/dev/null; rm -f /usr/local/bin/unshare; cp -a /etc/subuid.bak-dl-20261126 /etc/subuid; cp -a /etc/subgid.bak-dl-20261126 /etc/subgid; rm -rf /home/xuqianhui1001/dl-apps /opt/dl-pkgs /home/xuqianhui1001/.local/state'   # 保留 adb 与 ~/.android 可选
```
**实测安全态（收工时）**：`hexagonrpcd{,-suspend,-resume}`、`iio-sensor-proxy` 仍 masked（未碰）；`systemctl --failed`=0；phoc=1 / phosh=1（`pgrep -x`）；`graphical.target`=active；waydroid-container=active；droidloomd=active、user `droidloom.service`=active（cell 运行中，小红书窗口在桌面）。

## 8. 产物指针

- 本报告 = 唯一领域写入；证据目录 `reports/artifacts/droidloom-deploy-20261126/`（doctor-final / applications-list / xhs-launch-log / limbus-appsealing-log / limbus-first-launch-log / tcpdump-no-cell-traffic / device-config-snapshot / dl-49-sha256 / boot-log-sample）。
- 设备侧保留件：`/opt/dl-pkgs/`（三个 zst，重装免下）、`/usr/local/bin/unshare`、`/etc/sub{uid,gid}` 追加行、`/home/xuqianhui1001/dl-apps/{limbus,xhs}`（APK 原件）。
- 设备锁：lane `droidloom-deploy-d`，收工 release。


---

## D24 首轮对账（2026-11-26 晚）：本节两条缺口已各自收口

- **§5 缺口-1「cell 无网」= 已修**（探针改 vivo + 独立 nft DNS 重定向 + 解禁 `Droidloom`），实测 `VALIDATED` 且 `adb` 端点在线 ⇒ 详见 `reports/droidloom-cell-network-20261126.md` §8。
- **小红书画面不全 = 已修**（per-app 窗口覆写）⇒ `reports/droidloom-display-sizing-20261126.md` 末节。
- **键盘不可用 = 已绕开**（装真 IME）⇒ `reports/droidloom-ime-keyboard-20261126.md` §5；根因未根治，属 `TASKS/dim/D24.md`。
