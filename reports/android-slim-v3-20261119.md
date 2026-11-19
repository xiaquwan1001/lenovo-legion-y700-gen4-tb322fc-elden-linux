# 安卓「彻底精简 v3」+ 安卓/Linux 双轨共存契约（2026-11-19）

- 状态：**主机侧造件 + EDL 写入 super 已完成，读回逐字节一致；设备在 `qdl reset` 后未重新枚举 ⇒ 首启判据未取得**
- 机型：TB322FC（elden，U2 `HA2EXB0E`），当前 `current-slot=a`
- 只动 **`super`（LUN0 LBA 90504+）**；`linux17`/`boot_b`/`userdata`/`vbmeta*`/`init_boot_a` 一律未碰
- 产物：`out/android-slim-v3-20261119/{new/,edl/,rb/,work/,MANIFEST 在 new/ 内}`

---

## 0. 一页结论

| # | 结论 | 等级 |
|---|---|---|
| 1 | **共存契约成立**：11-19 现场 EDL 读回 LUN0 主表 = `super 90504..5857671` / `userdata 5972392..73277434` / `linux17 73277435..123871226`，16 条目**两两不重叠**，且**不存在**旧破坏设计的单 `linux` 分区。核对器 `scripts/android-linux-coexist-check.py` 退出码 0 | 实测 |
| 2 | **v3 镜像**：`system_a.img` **3920 MiB**（v1 5296 / 原厂 11423）、`super_min_v3.img` **7109 MiB**（v1 8481.5）——比 v1 再省 **1.34 GiB** | 实测 |
| 3 | **三个「v1 卡动画」相关面已同时处理**：① `/system/preinstall`、`/system/etc/AI` 保留为**0 子项空目录**（`File#list()` 得空数组）② `launcher.db` / `launcher_2layer.db` 47→**15 行**，剩余行引用的包**全部存在**（`com.zui.camera`/`filemanager`/`settings`/`leos.appstore`/`contacts`/`safecenter` + 产品分区里的 `com.lenovo.menu_assistant.hd`）③ 空目录带 `security.selinux=u:object_r:system_file:s0`（本机无 `setfattr`，用 `os.setxattr` 打） | 实测 |
| 4 | **EDL 写入 7109 MiB @42.2 MiB/s（2 min 48 s）**，读回 1819904 扇区 **sha256 = 主机**（`51eae107…`，第二把尺子） | 实测 |
| 5 | `qdl reset` 后设备**从 USB 完全消失**（`lsusb` 无 `05c6:*` / `18d1:*`，`adb`/`fastboot` 均无），240 s 未重新枚举 ⇒ 需要人按电源键；**首启「进不进桌面」= 未上机** | 实测 |
| 6 | KSU root **未并入**（按用户口径「刷完精简系统再补装」）：`out/android-root-20261119/` 仍待上机；它只动 `init_boot_a` + `vbmeta_a`，与 super 互不依赖 | 决策 |

---

## 1. 拆分与共存（本轮用户要求的第一件事）

### 1.1 契约（冻结，脚本可判）

| 分区 | LBA（4096 B/扇区） | 大小 | 归属 | 谁可以写 |
|---|---|---|---|---|
| `super` | 90504..5857671 | 22.00 GiB | Android（a 槽动态分区） | 只有 Android 线；EDL `write 0/90504` |
| `vbmeta_system_a/b`、`metadata`、`rawdump`、`pstoredump` | 5857672..5972391 | ~0.5 GiB | Android | 只有 Android 线 |
| `userdata` | 5972392..73277434 | 256.75 GiB | Android `/data` | 只有 Android 线（`fastboot -w`） |
| `linux17` | 73277435..123871226 | 193.00 GiB | Linux 根（b 槽 `LABEL=linux`） | 只有 Linux 线（设备侧 `dd`/`resize2fs`） |
| `boot_a` / `dtbo_a` / `vbmeta_a` | LUN4 | — | Android 启动链 | 只有 Android 线 |
| `boot_b` / `dtbo_b` / `vbmeta_b` | LUN4 | — | Linux 启动链 | 只有 Linux 线 |

判据命令（只读）：

```sh
python3 scripts/android-linux-coexist-check.py --gpt <gpt0-primary.bin> [--super-img <img>]
```

它同时校验：三段 LBA 逐字节一致、全部条目两两不重叠、**不存在** `linux`/`elden-super`/`elden-data` 单分区（2026-11-17 覆盖事故的形状）、
`--super-img` 字节数 ≤ `super` 分区字节数（写 90504 不会越界到 `vbmeta_system_a`）。

### 1.2 为什么会覆盖（复述一次，避免重犯）

2026-11-17 的 GPT-minimal 设计把单个 `linux` 分区的起点放在 **LBA 90504 = `super` 起点** ⇒ 写 Linux 根必然吃掉 super 头 6 GiB，
a 槽从此起不来（`INDEX.md` §…回退口径条）。**共存形态不是那个设计**：Linux 只能待在 `linux17`，不许再改 GPT 起点，
除非先用 coexist-check 证明新表仍然不重叠。

### 1.3 两条线的写入门（本轮实证）

- Android：`qdl write 0/90504 super_min_v3.img` → 范围 `90504..1830407`，距 `super` 末尾还差 402 万扇区 ⇒ 结构上碰不到 `vbmeta_system_a`
- 备份：覆盖前已有 ① 原厂 `backup/official-rom-15.10.259/super_*.img` ② v1 `out/android-min-20261118/pkg/super_min.img`（在机件的逐字节同源）
- 写后：EDL 读回 1819904 扇区 sha256 对比（不做「传输完成」当判据）
- GPT：写前现场 dump 六 LUN 主/备表到 `out/android-slim-v3-20261119/edl/`（含 `SHA256SUMS.txt`）

---

## 2. v3 镜像内容（相对原厂 259）

### 2.1 删（逻辑字节：约 7.9 GiB / 其中池 3.27 GiB）

| 项 | 说明 |
|---|---|
| `/system/preinstall/*` | **全部 41 个池目录**（3.27 GiB，含 ZUI 自有 8 项）；目录本身保留为空 |
| `/system/etc/AI/*` | 3.21 GiB 模型；目录本身保留为空 |
| `/system/etc/bgmusic` | 209 MiB 背景音乐 |
| `bootanimation_mcdonalds.zip` / `shutdownanimation_mcdonalds.zip` | 23.7 MiB 零售主题动画 |
| 18 个无用 leaf 包 | `ZUIEpos`(373.7) `ZuiNewBrowser`(268) `LFHTianjiaoTablet`(219) `ZuiAILens`(158) `ZUILenovoLevision`(139) `ZuiStandbyMode`(100) `ZuiGameHelper`(98.8) `XiaotianTrigger`(35.8) `ZuiAIStylus`(32.8) `UDSEngine`(23.5) `LenovoOTA`(17.9) `LenovoWhatsNew`(8.3) `LenovoLoggerPannel`(3.6) `EngineeringCode`(0.9) `TabletUE`(0.5) `ZuiXlog`(0.4) `TabletPushOut`(0.3) |

### 2.2 保（明确不删，附理由）

- 启动链/桌面/权限/Provider：`SystemUI`(= `system_ext/priv-app/ZuiSystemUI`)、`ZuiLauncher*`、`ZuiCoreService`、`ZuiSettings`、
  `ZuiPermissionController`、`ZuiPackageInstaller`、全部 `etc/permissions`、`etc/selinux`、`framework`、`apex`、`oat/vdex`
- 可见功能：`ZuiCamera(+Assistant/QR)`、`ZuiFileManager`、`LenovoStore`(应用商店)、`LenovoID`、`ZuiSecurity`、`ZuiWallpaperSetting`、
  `ZuiThemeSettings`、`ZuiSoundPicker`、`ZuiContacts*`、`PenService`+`etc/pen`（本机带笔 SKU）

### 2.3 桌面布局（占位根因）

| db | 原 | v3 | 说明 |
|---|---|---|---|
| `/system/etc/launcher.db` | 47 行 favorites | **15 行** | 按 59 条「待删包名」裁；剩余 5 个文件夹行 + 7 个可见应用 + 3 个 widget/搜索行 |
| `/system/etc/launcher_2layer.db` | 47 | **15** | 同清单 |

剩余行引用的包逐个核对存在（`com.zui.camera`、`com.zui.filemanager`、`com.android.settings`、`com.lenovo.leos.appstore`、
`com.zui.contacts`、`com.zui.safecenter`、`com.lenovo.menu_assistant.hd`(= `product_a/priv-app/LenovoXiaoTian`)）。

---

## 3. 构建与自检（可复跑）

```sh
sudo bash scripts/android-slim-v3-build.sh            # 全流程（stage 可重入）
sudo bash scripts/android-slim-v3-build.sh --verify-only
```

自检全绿（`new/MANIFEST.md` 由脚本生成）：

- `e2fsck -fn` clean；`/system/preinstall`、`/system/etc/AI` 存在且 0 子项且带 `security.selinux`
- 18 个删除项在树里不存在；9 个保留项存在
- `launcher.db*` 无已删包引用（`scripts/android-launcher-db-check.py`）
- super metadata slot 0/1/2 均可读；`lpunpack` round-trip 出的 `system_a` 与 `new/system_a.img` **逐字节相同**

脚本新增件：`scripts/android-apk-pkgname.py`（自解 AXML 读包名，本机无 aapt）、
`scripts/android-launcher-db-check.py`、`scripts/android-linux-coexist-check.py`。

---

## 4. 上机记录（本次）

| 时间 | 动作 | 结果 |
|---|---|---|
| 19:5x | `fastboot -s HA2EXB0E oem edl` | 9008 枚举（`lsusb` `05c6:9008`） |
| 19:5x | `scripts/linux-gpt-dump.sh --out out/android-slim-v3-20261119/edl` | 六 LUN 主/备表落盘；主表 header+entries CRC 全 True（该脚本打印的 `entries_DIFF/crc_BAD` 是它按 `alt-4` 取 5 扇区、条目实际在 `alt-32` 的**窗口不足**造成的误报，已用独立脚本复核） |
| 20:0x | `python3 scripts/android-linux-coexist-check.py --gpt edl/gpt0-primary.bin --super-img new/super_min_v3.img` | 5 条 OK，rc=0 |
| 20:0x | `qdl -s ufs -R <loader> write 0/90504 new/super_min_v3.img` | 6.9 GiB，**2 min 48 s @42.2 MiB/s** |
| 20:0x | `qdl -s ufs -R <loader> read 0/90504+1819904 rb/super_rb.img` | 6.9 GiB；`sha256 = 51eae107…` **= 主机件** |
| 20:0x | `qdl reset` | 设备离开 9008 后 **USB 上完全消失**（240 s 无 `05c6`/`18d1`/`adb`/`fastboot`） |

### 未做（等下一步）

1. **首启**：需要人按一次电源键（物理动作），然后 `fastboot -w` + 首启观察（`fastboot -w` 是破坏性写 = 需用户确认）。
2. **KSU 补装**：Android 进桌面后按 `scripts/android-ksu-flash.sh --apply`（先 `--backup-only`）。
3. **回退路径**：v1 `out/android-min-20261118/pkg/super_min.img`（同样写 90504）/ 原厂 `backup/official-rom-15.10.259/super_*.img`。

---

## 5. 判据（下次上机怎么算成功）

- `sys.boot_completed=1` 且 `dumpsys window | grep -i EnableScreen` 有值（不再是 bootanimation 第三段无限循环）
- 桌面无占位图标：`ls /system/preinstall` 为空目录、`pm list packages | wc -l` 明显少于 279
- 若仍卡动画：`adb logcat -d -b all > /tmp/hang3.log`（**这是唯一能把 H1/H2 分开的输入**）+
  `adb shell 'ls -l /data/system/preinstallapk /data/system/waitpreinstallapp'`

---

## 6. 未决

1. 首启判据未取得（设备需物理上电）。
2. 删除 18 个 leaf 包是否触发 ZUI 首次开机向导依赖（`ZUISetupWizardExtPRC` 保留）——只有上机可判；回退件在手。
3. `-d auto` 出的 super 元数据 `device_size` = 7454326784（< 分区 22 GiB），与 v1 同口径（v1 也是 8893497344 < 22 GiB 且两发成功）⇒ 沿用，不改。