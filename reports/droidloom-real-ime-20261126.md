# droidloom 真 IME 绕行（工单 D6）——Fossify Keyboard 装进 cell，三轮连续输入验收通过（2026-11-26）

- **性质**：设备侧 additive 安装（装一个第三方开源 IME APK + 切默认输入法），零刷写、零分区写、不改 droidloom 既有文件；`com.android.droidloom.ime/.HostInputMethod` **保留未禁用**，仅新增并切默认。
- **定因前置**：`reports/droidloom-ime-keyboard-20261126.md`（占位 IME ↔ 宿主 OSK 状态机缺陷，本轮不重推）。
- **设备**：U2，`ssh elden` / `ssh elden-root`，内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，droidloom 0.1.0-49，cell 运行中，adb 端点 `device:droidloom`。全程 `scripts/device-lock.sh` 串行。

---

## 0. 一页结论

| # | 问题 | 判定 | 一句话依据 |
|---|---|---|---|
| 1 | **真 IME 装上没** | ✅ | `adb install` = Success；`pm list packages` 有 `package:org.fossify.keyboard`；`ime list -s` 出两行（占位器 + Fossify） |
| 2 | **默认 IME 切换没** | ✅ | `default_input_method`：`com.android.droidloom.ime/.HostInputMethod` → **`org.fossify.keyboard/.services.SimpleKeyboardIME`**；`dumpsys input_method` `mSelectedImeId` 同值 |
| 3 | **键盘可用性（三态）** | ✅ **连续输入可用** | 三轮「点框→输入→再点」共 9 张截图逐张目视二值判定全过（§3）；`mInputShown=true` 6/6 次；字符逐轮累积 `113 → 113 3 → 113 33 → 113 333` |

**与定因报告的关系**：旧失败模式 `onFailed at PHASE_IME_ON_SHOW_SOFT_INPUT_TRUE`（由占位器 pid 960 报）在切换后 logcat 窗口内 **0 次**——仅存的 2 次都发生在切换前的 10:37:20（父代理复现段）；切换后 xhs 的每次 `onRequestShow` 都以 `onCancelled at PHASE_CLIENT_APPLY_ANIMATION`（键盘已在显示、动画阶段良性取消）收尾。**键盘由 Android 侧 Fossify 自己画**（截图可见其数字九宫格 + 剪贴板/设置图标），不再依赖宿主 OSK 的 `sm.puri.OSK0` 状态机 ⇒ 缺陷被绕开。

---

## 1. APK 取件（来源 + 哈希，全部核验后才装机）

| 项 | 值 |
|---|---|
| 应用 | **Fossify Keyboard**（Simple Mobile Tools Keyboard 的开源延续，AGPL），v1.9.1 (versionCode 14) |
| 来源 URL | `https://f-droid.org/repo/org.fossify.keyboard_14.apk`（经本机代理 `127.0.0.1:7890`；**直连 f-droid.org 超时**，按全局规则先判代理再下载） |
| 版本核验 | `https://f-droid.org/api/v1/packages/org.fossify.keyboard` = suggestedVersionCode 14 / versionName 1.9.1 |
| **sha256** | **`e326885c08b68212fd9fdda9be8a4fa492d5daba7ff37bb4ff4511826f40a8d0`** |
| 核验方式 | 与 **F-Droid 官方 index-v2.json**（`https://f-droid.org/repo/index-v2.json`）内该 APK 条目的 `sha256` + `size`(17 098 779 B) **逐字一致**；主机→设备 scp 后设备侧 `sha256sum` 复核一致 |
| 版本码甄别 | 首次 enable 用错 id `org.fossify.keyboard/.ui.KeyboardActivity`（那是启动 Activity 不是 IME 服务），logcat 留有 2 条 `unrecognized IME ID`（预期噪声，已留档）；真 id 由 `ime list -s -a` 查得 |

本地先行检索（`find ~ -iname '*keyboard*.apk' …`）= 0 命中，才触发下载；APK 主机侧留存 `reports/artifacts/droidloom-real-ime-20261126/org.fossify.keyboard_14.apk`，设备侧 `/tmp/org.fossify.keyboard_14.apk`。

## 2. 安装与切换（每步判据）

```sh
# 证据文件均在 reports/artifacts/droidloom-real-ime-20261126/
adb -s device:droidloom install -r /tmp/org.fossify.keyboard_14.apk        # ⇒ Success (install.log)
adb -s device:droidloom shell pm list packages | grep -i fossify           # ⇒ package:org.fossify.keyboard (pm-list.txt)
adb -s device:droidloom shell ime enable org.fossify.keyboard/.services.SimpleKeyboardIME   # ⇒ now enabled (ime-enable.log)
adb -s device:droidloom shell ime set    org.fossify.keyboard/.services.SimpleKeyboardIME   # ⇒ selected   (ime-set.log)
```

- 切换前 `default_input_method` = `com.android.droidloom.ime/.HostInputMethod`（ime-default-before.txt）；切换后 = `org.fossify.keyboard/.services.SimpleKeyboardIME`（ime-default-after.txt / ime-default-final.txt）。
- `enabled_input_methods` 现为三项（latin / **droidloom 占位器（保留）** / fossify），**占位器未 disable**（ime-enabled-after.txt）。
- 附带发现：cell image 自带 AOSP `com.android.inputmethod.latin/.LatinIME`（`/product/app/LatinIME/LatinIME.apk`）但此前既不在 `ime list -s` 也没被设默认——本轮未动它，留作另一个潜在回退项。

## 3. 验收：三轮「输入-失焦-再点」（adb 全自动，未打扰用户）

启动：`droidloomctl launch com.xingin.xhs` ⇒ `launched … task=19`，等 8 s。每轮 = `input tap 912 790`（手机号框）→ 截图 → `input text 3` → 截图 + `dumpsys input_method | grep mInputShown` → 再 `input tap` → 截图 + dumpsys。

**逐张二值判定（截图 = 1904x3040 整屏 screencap，目视键盘出现/消失）：**

| 轮 | 截图（artifacts/） | 键盘判定 | 字段内容 |
|---|---|---|---|
| 1 tap 后 | `round1-a-after-tap.png` | **出现**（Fossify 数字九宫格） | `113`（进场既有内容） |
| 1 输入后 | `round1-b-after-text.png` | **仍在** | `113 3`（新字符上屏） |
| 1 再点后 | `round1-c-after-retap.png` | **仍可唤出（在）** | 同上 |
| 2 tap 后 | `round2-a-after-tap.png` | **出现** | — |
| 2 输入后 | `round2-b-after-text.png` | **仍在** | `113 33` |
| 2 再点后 | `round2-c-after-retap.png` | **在**（尺寸与 b 逐字节同，实为持续显示） | — |
| 3 tap 后 | `round3-a-after-tap.png` | **出现** | — |
| 3 输入后 | `round3-b-after-text.png` | **仍在** | `113 333` |
| 3 再点后 | `round3-c-after-retap.png` | **在** | — |

- `mInputShown`：6 次 dumpsys 采样（每轮输入后 + 再点后）**全部 true**（dumpsys-ime.txt）。
- **成功判据命中**：三轮后键盘仍能唤出且能继续输入；字符逐轮累积且与 `input text` 次数精确对应（非猜，截图字段 + dumpsys 对照）。
- 测试后现查 `mInputShown=false`：为测试序列结束、字段失焦后的正常回落，非缺陷复发（keyboard 可再次唤出已由第 2/3 轮 tap 证明）。
- `view-*-full.png` 为同图 1/3 缩放副本，供快速目视。

## 4. 回退命令（一行）

```sh
ssh elden 'adb -s device:droidloom shell ime set com.android.droidloom.ime/.HostInputMethod'
```
（彻底拆除：`adb -s device:droidloom uninstall org.fossify.keyboard`；设备侧 APK `/tmp/org.fossify.keyboard_14.apk` 可留可删。）

## 5. 收尾门禁（收工实测）

| 门 | 值 | 证据 |
|---|---|---|
| `systemctl --failed` | **0** | close-failed-units.txt |
| phoc / phosh | **1 / 1** | close-phoc-phosh.txt |
| cell | `cell u1001 is running …; Android is ready` | close-cell-status.txt |
| 宿主 adb | `10.177.0.2:5555 device … device:droidloom` | close-adb-devices.txt |
| 设备锁 | 每个操作块结束即释放（本报告收工时 free）；无长 sleep 进程残留 | — |

## 6. 残余风险 / 未做

1. **持久化未做整机重启验证**：`default_input_method` 写在 cell 的 `settings secure`（`/data/system/users/0/settings_secure.xml`），随 cell data 持久，理论跨重启；但本轮未重启 cell/整机复测（不影响本工单判据）。
2. **候选词/全键盘/中文输入未测**：本轮判据只覆盖「数字九宫格连续输入」；Fossify 全键盘与中文（其内置无中文布局，需后续评估，如 Necessary/FFSEO 键盘或 LatinIME 外挂词典）未验。
3. **占位器仍 enabled**：droidloom 的 `HostInputMethod` 留在 `enabled_input_methods` 里作回退，与本次缺陷共存无冲突（它不再是默认就不会被调用）。
4. **上游根治仍欠**：本方案是绕行；droidloom 桥的状态机缺陷本身待提 issue（定因报告 §3 方案 B，未在本工单范围）。
5. 字段进场既有内容 `113`（可能是父代理此前复现的残留），与本工单无关，未清理（清空会引入额外变量）。

## 7. 产物指针

- 本报告 = 唯一领域写入；证据目录 `reports/artifacts/droidloom-real-ime-20261126/`：
  - APK 原件 + `org.fossify.keyboard_14.apk`（sha256 见 §1）；
  - 安装/切换：`install.log`、`pm-list.txt`、`ime-{enable,set}.log`、`ime-list-{before,after,after-all}.txt`、`ime-enabled-{before,after}.txt`、`ime-default-{before,after,final}.txt`、`latin-pm-path.txt`；
  - 验收：`round{1,2,3}-{a,b,c}-*.png`（9 张原始截图）+ `view-*.png`（缩放副本）、`dumpsys-ime.txt`、`dumpsys-input-method-full.txt`、`logcat-recent.txt`、`xhs-launch.log`；
  - 收尾：`close-{failed-units,phoc-phosh,cell-status,adb-devices}.txt`。
