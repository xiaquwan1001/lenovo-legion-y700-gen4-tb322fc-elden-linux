# 安卓「干净瘦身 v2」+ 卡 ZUXOS 动画静态定因

- 日期：2026-11-19 ｜ **纯主机侧**（无 adb / fastboot / qdl / ssh / EDL；无 sudo；未碰 `out/android-min-20261118/new/*`）
- 机型：TB322FC elden（U2 `HA2EXB0E`，原厂 Android 16 `ZUXOS_1.5.10.259_260611_PRC`）
- 输入：`out/android-min-avb-20261118/parts/system_a.img`（原厂 system_a，11.43 GiB）、
  `out/android-min-20261118/new/system_a.img`（v1 已上机件，5.0 GiB）、`out/android-min-20261118/pkg/super_min.img`（8481.5 MiB）、
  `out/android-min-20261118/diag/*`、`backup/official-rom-15.10.259/`、`backup/HA2EXB0E-16+512/edl-20261118/`
- 产物：`scripts/android-img-lswalk.py`、`scripts/android-img-grepmap.py`、`scripts/android-launcher-db-trim.py`、
  `scripts/android-slim-v2-plan.sh`；`out/android-slim-v2-20261119/`（清单 TSV、textdump、grepmap、裁剪后的 launcher.db）
- 标注口径：**[实测]** = 本机命令/文件证据；**[机制]** = 上游或本项目已记录机理；**[推断]** = 由前两者推出、未上机

---

## 0. 一页结论（数字先）

| # | 结论 | 等级 |
|---|---|---|
| 1 | **v1 镜像是「外科式」删除**：与原厂 system 逐条对账，差异 **262 条**，**全部**落在 `/system/preinstall`、`/system/etc/AI`、`/system/etc/bgmusic` 三棵子树内；**新增 0 条**、三棵子树外丢失 **0 条** | 实测 |
| 2 | **SELinux 面清白**：`/system/etc/selinux/*` 全在（`plat_file_contexts` 48,488 B 等）；抽查 v1 镜像 **150/150** 个文件仍带 `security.selinux` xattr ⇒ 「镜像侧 context 半擦除」这条基本可排除 | 实测 |
| 3 | **「桌面占位图标」的静态来源已定因**：`/system/etc/launcher.db` + `launcher_2layer.db` 各含 **47 条 favorites（39 条带 intent）**，指向池里的第三方包（抖音/优酷/爱奇艺/WPS/Canva/百度网盘/快手/剪映…）与 **ZUI 自有池应用**（图库/便签/天气/闹钟/日历/录音机/换机/计算器）。池删了、布局没删 ⇒ 全新 `/data` 恢复默认布局后必然出现占位条目 | 实测 + 机制 |
| 4 | **池与已装应用零重名**：`/system/preinstall` **41 个目录 / 3272.0 MiB**，`/system/app`+`priv-app` **115 个目录**，交集 **0**；ZUI 自有 8 项（**354.9 MiB**）**只存在于池里** | 实测 |
| 5 | **「卡动画」= bootanimation 的第三段无限循环**：`/system/media/bootanimation.zip` 的 `desc.txt` = `p 1 0 part1` / `p 1 0 part2` / **`p 0 0 part3`**（part3 = `lenovo_3_powerup_loop_*.png` × 42 帧）⇒ 用户看到的循环动画就是 bootanim 本体，**意味着 `service.bootanim.exit` 从未被置 1**，即 **system_server 侧 WMS/AMS 没走到 bootFinished**（不是内核卡死、不是 ZUI 自播动画） | 实测 + 机制 |
| 6 | **现有 diag 全部早于事故**：`diag/` 快照时间 14:54–16:09，而 wipe→卡动画发生在精简包实测（步骤 D）之后；`pstoredump` 读回 **128 MiB 全零**；`logfs` 里 **9 次**启动都走到 `Shutting Down UEFI Boot Services`（交接正常），其中一条历史记录是上午的 `Slot _a is unbootable, trying alternate slot`（#672 那次）。⇒ **本轮不能给卡动画「已定因」，只能给候选链 + 判据命令** | 实测 |
| 7 | `reports/artifacts/android-min-flash-20261118/01-before-wipe-launcher.png` **不可用作证据**：3040×1904、26,930 B，逐像素统计 **0 / 5,788,160** 个像素灰度 > 8 ⇒ 纯黑帧 | 实测 |
| 8 | **v2 体积（模型已用 v1 实测校准，误差 −16 MiB / 0.3%）**：A 变体 system **5664 MiB** / super **8864 MiB**（8.66 GiB）；B 变体 system **5280 MiB** / super **8480 MiB**（8.28 GiB）。EDL 写盘 **3.3–3.5 min** @42.2 MiB/s | 实测（清点）+ 校准 |
| 9 | **AVB 不需要动**：现役 `vbmeta_a` = 自签 `Flags=1`（HASHTREE_DISABLED），设备 `ro.boot.veritymode=disabled`、boot state `orange(1)`（logfs 实测）⇒ 换 system 尺寸不触发重签；要回绿灯才需按新尺寸重算 `vbmeta_system_a` 的 hashtree | 实测 + 机制 |

---

## 1. 方法与产物（全部只读、可复跑）

| 脚本 | 作用 | 关键实现 |
|---|---|---|
| `scripts/android-img-lswalk.py` | debugfs 递归列目录 → TSV（type/mode/uid/gid/size/path） | 不需要 root/loop；BFS + 并发，`/system` 全树 **4138 条 / 0.4 s** |
| `scripts/android-img-grepmap.py` | 在 ext4 镜像里定位「哪个文件含有某个字面串」 | 一遍 `grep -abo` → 块号 → `debugfs icheck` → `ncheck`；12 GB 镜像单串 ~6 s |
| `scripts/android-launcher-db-trim.py` | 按包清单裁剪桌面默认布局，并清空因此变空的文件夹行 | 纯 `sqlite3`；不改原文件，输出 `.trimmed` |
| `scripts/android-slim-v2-plan.sh` | v2 计划器：`--variant A\|B`，默认 dry-run 只打印；`--apply` **也只打印**需 root/需设备的命令 | 体积由 debugfs 现清点算，不写死 |

产物落点 `out/android-slim-v2-20261119/`：`ls-system-full.tsv`（原厂全树）、`ls-system-v1.tsv`（v1 全树）、
`grepmap/{system_a,product_a,vendor_a,system_ext_a}.tsv`、`textdump/`（init rc / sysconfig / build.prop / launcher.db /
services.jar 的 dex / 相关 apk）、`launcher.db.v2A|v2B`、`launcher_2layer.db.v2A`、`drop-pkgs-A|B.txt`。

复跑：
```bash
python3 scripts/android-img-lswalk.py --img out/android-min-avb-20261118/parts/system_a.img \
        --root /system --out /tmp/orig.tsv --jobs 16 --max-depth 10
python3 scripts/android-img-lswalk.py --img out/android-min-20261118/new/system_a.img \
        --root /system --out /tmp/v1.tsv  --jobs 16 --max-depth 10
bash scripts/android-slim-v2-plan.sh --variant A      # 只读打印
```

---

## 2. 枚举：与「首启 / 预装 / 桌面占位」有关的一切（实测清单）

### 2.1 预装池本体
- `/system/preinstall/` **41 个目录、3,272.0 MiB**（占原 system 内容 11,671 MiB 的 28%）；每个目录 = 一个可安装 apk（部分带 `lib/`、`oat/`）。
- **只有池才有的 ZUI 自有应用**（`/system/app` / `priv-app` 里没有同名目录）：`ZuiGallery`(139.7 MiB)、`ZuiNotes`(121.9)、
  `XuiCalendar`(27.6)+8 个 overlay、`ZuiClone`(21.8)、`ZuiWeather`(17.7)、`ZuiAlarm`(15.7)、`XuiRecorder`(9.2)、`XuiCalculator` ⇒ **合计 354.9 MiB**。
- 第三方池（2917.1 MiB，最大 8 项）：`Wangyiyun`(网易云 349.3)、`Capcut_prc`(剪映 218.3)、`BaiduNetdisk`(216.6)、`AiFlashPoint`(209.9)、
  `MotoReadyFor`(181.1)、`Weibo_HDwm`(169.3)、`iqiyi`(164.9)、`Moffice_196`(WPS 155.9)、`MiguPlay`(153.1)、`DouYin`(139.7)、`Youku`、`Canva`、`kwai_HD`…
- 池内 `etc/default-permissions/`：只有 3 个 ZUI 自有包的默认权限（weathercenter/calendar/deskclock）。

### 2.2 会话里的「预装」相关 init/配置（都不是硬阻塞，逐条已读）
| 文件 | 内容 | 对首启的影响 |
|---|---|---|
| `/system/etc/init/preinstall.rc` | **只有** `on post-fs-data: mkdir /data/app-lib2; chmod 644 /data/app/preloadapp.cfg` | 无阻塞（`chmod` 目标不存在只报错） |
| `/system/etc/fstab.postinstall` | 把 **system_other**（`slotselect_other`）挂到 `/postinstall` | 与 a 槽无关；镜像里 `/postinstall` 是空目录 |
| `/system/etc/init/csdk.lenovocust.rc` | `wait /dev/block/by-name/lenovocust` + mount `/lenovocust` | 该分区**在 GPT 里存在**（LBA 902..77701），不阻塞 |
| `/system/etc/sysconfig/preinstalled-packages-*.xml` | 6 个文件全是 AOSP 模板，`<config></config>` 空 | 与联想池无关（`preinstall` 只出现在版权注释里） |
| `/system/etc/permissions/privapp-permissions-*.xml` | 含 `com.zui.launcher`/`com.zui.gallery`/`com.zui.notes`… 共 26 个 zui/lenovo 包 | 只是权限白名单，包不存在时不报错 |
| `/system/etc/default-permissions/`, `/system/etc/motorola/bgintents/` | 每包一份默认权限/自启策略 | 同上 |

**没有**发现任何 `on post-fs-data` / `on init` 里引用 `/system/preinstall`、`/system/etc/AI`、`bgmusic` 的 rc
（`grep -rn '/system/preinstall\|/system/etc/AI\|bgmusic' textdump/init/*` 唯一命中是 `csdk.lenovocust.rc` 的 `/lenovocust`）。

### 2.3 谁在代码里硬编码了被删的路径（`grepmap` + `strings`，**这是本轮最关键的一条**）
| 载体 | 命中的字面串 | 说明 |
|---|---|---|
| `/system/framework/services.jar`（classes2.dex） | `/system/preinstall`、`/oem/preinstall`、`system/preinstallapk`、`system/waitpreinstallapp` | 联想/摩托定制的 `com.android.server.pm.PreInstallPackageHelper`：字段 `mEnablePreinstallApp` / `mPreinstallAppDirInSystem` / `mPreinstallAppDirInOem` / `mPreinstallAppsUpdatedOrRemoved` / `mWaitPreinstallApps`，方法 `isPreinstallApp`、`prepareInstallPackages`、`addPackage2PreinstallAppsUpdatedOrRemovedRecordFile`；日志串 `Preinstall app enabled? `、`[Preinstall] user delete/update`、`preinstall apps which skiped base on country code` ⇒ **记录文件在 `/data/system/preinstallapk`、`/data/system/waitpreinstallapp`（都在被 wipe 的 /data 里）** |
| `/system/framework/services.jar`（classes3.dex） | `com.zui.server.permission.PreinstallAppPermInitializer`（`onBootPhase`、`FLAG_KEY_COMPLETED`、`loadPreInstalledResources`） | **PMS 子系统在 boot phase 里做「预装应用权限初始化」** |
| `/system/priv-app/ZuiCoreService/ZuiCoreService.apk` | `PREINSTALL_APP_PATH`、`INSTALL_PREINSTALL_APP`、`MSG_INSTALL_PREINSTALL`、`savePreinstallAppInfo`、`/system/preinstall/`、`./system/preinstall/VideoPlayer/VideoPlayer.apk` | ZUI 自己的预装安装器（含写死路径） |
| `/system/priv-app/TabletUE/TabletUE.apk` | `preInstallApp path = ` + `/system/preinstall` | `ue_server`（`init.lenovo.ue.rc`，`class main priority -10`） |
| `/system/priv-app/ZUISetupWizardExtPRC/ZUISetupWizardExtPRC.apk` | `/system/preinstall`，以及 `/system/etc/AI/models/{llama,qwen,safety/endpoints.json}` | 首启向导同时引用池与 AI 模型 |
| `ZuiAILens.apk` / `ZuiAIService.apk` | `/system/etc/AI/models/...` | v1 删掉 AI 权重后这两个包**已经是残件** |
| 3 个 AOSP apex（bt/runtime/virt） | 字面 `/system/preinstall` | 无关（库内字符串巧合） |

---

## 3. 「卡 ZUXOS 动画」静态定因（候选链 + 支撑/反驳 + 判据命令）

### 3.0 先把「卡点在哪一层」钉死（已可定）
`desc.txt` = `p 1 0 part1` / `p 1 0 part2` / **`p 0 0 part3`**（`part3/lenovo_3_powerup_loop_*.png`，42 帧）。
bootanim 只在 `service.bootanim.exit=1` 时退出，而该属性由 system_server 侧（WMS `performEnableScreen` → AMS `bootAnimationComplete`）设置。
⇒ **观测到的「卡在 ZUXOS 动画 >10 min」= system_server 没走完启动**（[机制]，旁证：v1 状态的 pstoredump 全零、logfs 9 次启动全部正常交接、槽属性未被再标 UNBOOTABLE —— 但这三份 dump 都早于事故，见 §0-6，故只作弱证据）。
这条把候选面从「整条引导链」收窄到「**用户态 boot 阶段**」，并且**否证**「ZUI 自己在播开机动画」「kernel 卡死」两种说法。

### 3.1 候选链（按可能性排序，全部**未上机取证**）

| # | 候选链 | 支撑证据 | 反驳证据 | 判据（上机命令） |
|---|---|---|---|---|
| **H1** | **fresh `/data` 首启时，联想的「预装安装」链缺少输入目录**：PMS `PreInstallPackageHelper`（+ `/data/system/preinstallapk`、`/data/system/waitpreinstallapp` 记录）+ `PreinstallAppPermInitializer`（boot phase）+ `ZuiCoreService.MSG_INSTALL_PREINSTALL` 三处都以 `/system/preinstall` 为输入；/data 刚被擦 ⇒ 记录文件全无 ⇒ 走「首次全量预装」分支，而目录不存在 | ① 路径与记录文件全部硬编码在 services.jar / ZuiCoreService（§2.3）；② **同一 v1 镜像在旧 /data 上两发 `boot_completed=1`，只有 wipe 后才卡** ⇒ 差异项必然落在「首启/首次安装」路径；③ 桌面占位图标是该链缺席的直接可见后果 | 目录不存在时正常实现只会「无可装项」；没有反编译证据表明它 `await`/`sleep` 等完成（本机无 baksmali/jadx，**未做 dex 反编译**） | `adb shell 'ls -l /data/system/preinstallapk /data/system/waitpreinstallapp; dumpsys package | grep -i preinstall'`；`adb logcat -d -b all \| grep -iE 'Preinstall\|PreInstallPackageHelper'`；`adb shell service list \| grep -i install` |
| **H2** | **桌面/home 未就绪**：`/system/etc/launcher.db` 47 条默认布局里 30 条指向已删包，ZuiLauncher 首启恢复时反复解析失败 ⇒ WMS `performEnableScreen` 等 home 首帧永不满足 ⇒ bootanim 不退出 | 布局文件在 system 里、47 行/39 intent 已实测；被删包里含 ZUI 自己的 home 相关组件（`com.zui.launcher`、`com.zui.launcherSDK`、`ZuiHomeSettings` 仍在，但图库/便签/天气/闹钟没了） | Launcher 通常只是跳过不可解析项，不会死循环；`com.zui.launcher` 本体未被删 | `adb shell dumpsys window \| grep -iE 'mBootAnimationComplete\|EnableScreen\|mCurrentFocus'`；`adb shell dumpsys activity activities \| grep -i 'ResumedActivity\|mFocusedApp'`；`adb logcat -d \| grep -iE 'Launcher\|ANR in\|am_crash'` |
| **H3** | **`/system/etc/AI` 缺失触发首启向导/服务异常**：`ZUISetupWizardExtPRC` 引用 `models/llama|qwen|safety/endpoints.json`，`ZuiAIService`/`ZuiAILens` 同源 | 三个包都硬编码了这些路径（§2.3） | 这类异常发生在 boot_completed 之后，**解释不了动画不退**；但能解释用户看到的「点开提示无网络」 | `adb logcat -d \| grep -iE 'ZuiAIService\|AILens\|SetupWizard.*Exception'`；`adb shell ls /system/etc/AI` |
| **H4** | **super 的 LP metadata 形状变了 + `/metadata` 被清**：v1 用 lpmake 重打，`first_logical_sector` 2048→**1024**、`-cow` 七分区与 `cow` 组被丢、三份 metadata 内容相同，但 header `flags=0x1`（**VIRTUAL_AB_DEVICE**）仍在 ⇒ `ro.virtual_ab.enabled=true` 与「无 COW 分区」不一致 | `scripts/android-super.py list` 实测（下表） | 无快照待合并时 init 走普通 dm-linear，理论上不阻塞；且 v1 在旧 /data 上起过两次 | `adb shell 'getprop ro.virtual_ab.enabled; ls /metadata; dumpsys -l \| grep -i snapshot'`；`adb shell 'mount \| grep -E "dm-\|system"'` |
| **H5** | **`/data` 半擦除 / SELinux 相关**（依据是当时 `adbd: Could not set SELinux context for subprocess` + 之后 adb 完全不枚举） | 时间线上确实先发生 | **镜像侧已否证**：selinux 策略文件全在、150/150 抽样文件带 xattr、与 v1 的差异只有 3 棵子树；`fastboot -w` 之后又做过 recovery factory reset（=又格式化一次 /data 与 /metadata） | `adb shell 'getprop ro.boot.selinux; getenforce; ls -Z /data/system \| head'`；`adb logcat -d -b all \| grep -i 'avc:'` |

**主管判读**：H1 与 H2 共享同一个「首启」前提，且都能被同一次上机区分开（见 §5 E1/E2）。H5 只在镜像侧被否证，
设备侧（/data 状态）仍未被否证——但目前证据里它已经是最弱的一条。

补充（§0-6 已列）：**本轮所有 diag 都不能定因**：`pstoredump` 128 MiB 全零（14:57 读回，早于 wipe；且 DDR 型 ramoops 掉电即失，即使有内容也读不出）、
`logfs` 9 次启动全部正常交接（含 `VB2: boot state: orange(1)`、`Cmdline: … androidboot.selinux=permissive`）、
唯一异常记录是上午的 `Slot _a is unbootable, trying alternate slot`（#672，已闭环）。
⇒ 卡动画那一次**没有任何 ABL/kernel/pstore 记录留在主机侧**。

### 3.2 附：super 元数据形状实测（H4 的表）
```
                         原厂 slot0                 v1 super_min（三份 metadata 内容相同）
first_logical_sector     2048                       1024
alignment / offset       524288 / 491520            524288 / 491520
header flags             0x1 (VIRTUAL_AB)           0x1 (VIRTUAL_AB)
分区数                   14 (7×_a + 7×_a-cow)       7（无 -cow）
groups                   default / qti_…_a / cow    default / qti_…_a
system_a                 ~11.25 GiB                 5296 MiB
```

---

## 4. v2 计划（`scripts/android-slim-v2-plan.sh`）

### 4.1 两个变体（差别只有一行：ZUI 自有池应用保不保）
| | 删 | system | super | vs v1 |
|---|---|---|---|---|
| **A（推荐先上）** | 第三方池（2917.1 MiB）+ `/system/etc/AI`（3209.5 MiB）+ `bgmusic`（209.1 MiB）+ 两个 mcdonalds 动画（23.7 MiB） | **5664 MiB** | **8864 MiB**（8.66 GiB） | +383 MiB |
| **B（最小）** | A 的全部 + ZUI 自有池 8 项（354.9 MiB） | **5280 MiB** | **8480 MiB**（8.28 GiB） | −1 MiB（≈ v1，v1 已是该配置下限） |

**A 的意义不是省空间，而是「功能完整 + 去掉占位来源」**：图库/便签/天气/闹钟/日历/录音机/换机/计算器是 ZUI 唯一来源（只在池里），
删掉后恢复出厂就没有这些系统应用；保它们只多 354.9 MiB。B 适合「只要能起来的最小镜像」。

体积模型校准：同一公式算 v1 得 5280 MiB（实测 5296），误差 −16 MiB / 0.3%；super 8480 vs 实测 8481.5。

`--apply` 打印的是**可直接执行**的整链（不是模板）：解包 → 删 → 空目录占位 → 裁布局 → `mke2fs` → **完整 `lpmake` 命令**
（system 用新尺寸，其余六个分区沿用 v1 实测尺寸 1466/993/571/141/12/2 MiB 与 `out/android-min-avb-20261118/parts/*.img`）→
三份 metadata 自检 + `slot0 == slot1` 比对 + `sha256sum`。跑之前确认 `parts/` 里六个 ext4 件在（共 12 GiB）。

### 4.2 除「删」之外的三个动作（这是 v1 缺的、直接对应占位/首启）
1. **裁默认桌面布局**：`launcher.db` 47→**A 25 行 / B 17 行**（`launcher_2layer.db` 同），两份裁剪件已生成并通过 `pragma integrity_check = ok`。
   现成件：`out/android-slim-v2-20261119/launcher.db.v2A|v2B`、`launcher_2layer.db.v2A`。
2. **空目录占位**：保留 0 字节的 `/system/preinstall` 与 `/system/etc/AI`，让调用方 `File#list()` 返回空数组而不是 `null`（消除 NPE 面）。
3. **不动**：`/system/etc/selinux`、`/system/etc/permissions`、`/system/etc/init`、`/system/framework`、`/system/apex`、全部 `oat`/`vdex`。

### 4.3 明确不删（附理由）
- `PenService`(259.6 MiB)、`/system/etc/pen`(43.4 MiB)：本机是带笔支持的 SKU，删了手写功能不可恢复。
- `ZuiSettings`/`ZuiPermissionController`/`ZuiLauncher*`/`ZuiCoreService`/`SystemUI`：启动链核心，删了直接不亮。
- `/system/media/audio/*`（铃声/闹钟，~20 MiB）：省不了多少，功能可见。
- `ZUIEpos`(373.7 MiB)、`ZuiWallpaperSetting`(271.8)、`ZuiNewBrowser`(268.0)、`ZuiCamera`(226.5)、`LFHTianjiaoTablet`(219.1)、
  `ZuiAILens`(158.4)、`ZUILenovoLevision`(139.2)、`ZuiStandbyMode`(100.2)、`ZuiGameHelper`(98.8)：**v2 不动**，
  列为 v3 待裁决（每项都对应桌面上一个可见入口/一张卡片，删了要同步改布局，且 ZuiLauncher 可能查它们的存在性）。

### 4.4 AVB / 回退
- **AVB**：`vbmeta_a` 现役自签 `Flags=1`、`veritymode=disabled`、boot state `orange` ⇒ 换 system 尺寸**不需要重签**，也不需要改 `vbmeta_system_a`。
  只在「将来回绿灯」时才需要 `avbtool add_hashtree_footer` 按新尺寸重算（原厂描述符里 system = 12,079,427,584 B，已不再匹配）。
- **回退**：v1 件 `out/android-min-20261118/pkg/super_min.img`（sha256 `e3d0d26f…`，两发 boot_completed=1）→ EDL 写回 LBA 90504；
  原厂 `backup/official-rom-15.10.259/super_*.img`（重刷 ~20 min，11-17 已走通）；GPT 双表 `backup/HA2EXB0E-16+512/edl-20261118/`；
  `boot_a`/`vbmeta_a` 原件 `out/android-min-20261118/pkg/vbmeta_a.img`（原厂 Flags=0）。

---

## 5. 建议的上机顺序（最省时间的判别法，全部需主代理执行）

| 实验 | 动作 | 判据 | 耗时 |
|---|---|---|---|
| **E0** | 设备现在在 fastboot；**先不前滚**，直接 `fastboot -w` → `fastboot reboot` → 抓 logcat | 能复现「卡动画」= 稳定故障；不复现 = 上一次是 `/data` 状态残渣（当时还做过 recovery factory reset） | ~12 min |
| **E0b** | 若 E0 复现：`adb logcat -d -b all > /tmp/hang.log`（**这是唯一能把 H1/H2 分开的输入**）；`dumpsys window \| grep -i EnableScreen`；`ls /data/system/preinstallapk /data/system/waitpreinstallapp`；`dumpsys package \| grep -c preinstall` | 有 `PreInstallPackageHelper`/`PreinstallAppPermInitializer` 卡住的 log = H1；有 `mBootAnimationComplete=false` + Launcher ANR = H2 | +3 min |
| **E1** | 刷 **v2-A**（EDL 3.5 min）→ `fastboot -w` → 首启 | 进系统 ⇒ 同时解决占位与卡死；仍卡 ⇒ 与「池/布局」无关，转 H4/H5 | ~25 min |
| **E2** | 若 E1 仍卡：刷**原厂 super** 只做一次对照首启（判据：同一 /data  wiped 状态下原厂能不能起） | 原厂也卡 ⇒ 问题在 /data/GPT/设备态，不在镜像；原厂能起 ⇒ 逐项二分（先只删 AI/bgmusic，再删池） | ~35 min |

**纪律提醒**：`fastboot -w` 之后**不要再做 recovery factory reset**（`PITFALLS #679`：首启 logo 72 s 属正常；重复格式化只会让
`/data` 与 `/metadata` 再被清一次，且每次打断会扣 `retry`）。

---

## 6. 未决 / 已知局限

1. **没有卡动画那一次的 logcat/pstore**：现有 diag 全在事故之前（§0-6）。这是本 lane 无法定因的根本原因。
2. **没有做 dex 反编译**（本机无 baksmali/jadx/apktool，pip 无 androguard）：`PreInstallPackageHelper` 是否 `await` 预装完成，只能凭字段名与日志串**推断**，未达机制级证据。
3. **launcher.db 里 39 个包 ↔ 池目录的一对一映射**：目录名/文件名判据（DouYin↔`com.ss.android.ugc.aweme` 等），
   精确判据需要 apk 的 `AndroidManifest` 包名（本机未做；`grepmap` 只能证明「串出现在哪个文件」，会被 vdex 交叉引用污染）。
   上机可用 `pm list packages | sort` 一次性核对。
4. **`super_min.img` 只带 `_a` 槽且丢 `-cow`**：`ro.boot.slot_suffix=_b` 的路径已不可用（b 槽无逻辑分区），与 `GPT-MINIMAL-DESIGN` 的 Linux b 槽方案**互斥**——这不是本 lane 的改动，但 v2 也不修它。
5. 设备当前在 fastboot、`_a` 槽 `unbootable=no / successful=yes / retry=6`（11-18 记录），本 lane 未做任何设备操作。

---

## 7. 需主代理执行的命令（本 lane 全部不执行）

```bash
# 先取证据（不改镜像）
fastboot -w                                  # 只擦 userdata+metadata
fastboot reboot
adb wait-for-device && sleep 90 && adb shell getprop sys.boot_completed
adb logcat -d -b all > /tmp/hang.log         # ★唯一能定因的输入
adb shell dumpsys window | grep -iE 'mBootAnimationComplete|EnableScreen'
adb shell 'ls -l /data/system/preinstallapk /data/system/waitpreinstallapp 2>&1; pm list packages | sort' > /tmp/pk.txt

# 构建 v2-A（需 root：loop 挂载 + rsync 保 xattr）
bash scripts/android-slim-v2-plan.sh --variant A --apply     # 打印全部命令，逐条执行
# 或直接复用现成裁剪件
cp out/android-slim-v2-20261119/launcher.db.v2A .../work/system_v2/etc/launcher.db

# 刷写（EDL，命令拆单条；同一发内不要夹别的写）
qdl write 0 90504 out/android-slim-v2-20261119/new/super_min_v2.img
qdl read  0 90504 <len> /tmp/rb.img && sha256sum /tmp/rb.img out/android-slim-v2-20261119/new/super_min_v2.img
```
