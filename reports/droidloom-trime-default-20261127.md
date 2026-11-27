# droidloom：Trime 落成默认中文输入法（T30）—— 2026-11-27 深夜，纯 adb 无人值守

- **性质**：U2 `ssh elden` + `adb -s 10.177.0.2:5555`（cell）；全程 `uiautomator dump` 读屏 + `input tap` 驱动，**无需用户目视**。
- **一句话**：**Trime 已是默认 IME，`nihao` → 候选首项「你好」→ 选中后输入框真出中文**；向导走完 `DONE` 后重启 app 不再落 `SetupActivity`。
- **根因更正（推翻 T30 立项时的假设）**：`Skip starting rime: storage not available!` **不是「必须用 SAF 选外部目录」**。Trime 3.3.13 首启向导 Step 1 有两种模式：「Sync from external storage」（要 SAF 目录）与 **「Use app-specific storage」（默认选中）**；后者就够用，数据目录 = `/storage/emulated/0/Android/data/com.osfans.trime/files`。真因是**向导没走完 ⇒ rime 不启动**；把 Step 1→2→3 重走一遍，librime 立刻自己部署。

## 1. 判据表

| # | 判据 | 结果 | 证据 |
|---|---|---|---|
| ① | 默认 IME = Trime | ✅ | `settings get secure default_input_method` = `com.osfans.trime/.ime.core.TrimeInputMethodService`（`ime set` 后由系统写入） |
| ② | 词库部署成功、无 storage 报错 | ✅ | logcat `rime.trime`: `finished updating schemas: 3 success, 0 failure` / `3 tasks ran: 3 success, 0 failure`（luna_pinyin_simp + luna_pinyin + stroke，`luna_pinyin.dict.yaml` 走 `table.bin`）；无再出现 `storage not available`。仅剩无害 `Encode failure: 'Ｘ戰警'` 类全角词条告警 |
| ③ | 软键盘真出中文 | ✅ | 截图：键盘为「朙月拼音」，点 `n i h a o` 后候选态 `ni hao` + 候选栏 `你好 你好 逆號 擬好 …`；点首项后 Settings 搜索框 `text="你好"`（`uiautomator dump` 读回） |
| ④ | 向导收口（不再每次首启弹 SetupActivity） | ✅ | Step 3 出现 `Done` 勾 + `DONE` 按钮；点掉后 `monkey -p com.osfans.trime` 落 `com.osfans.trime/.ui.main.MainActivity` |

## 2. 做法（可复现，全部在 `ssh elden` 内）

```sh
A="adb -s 10.177.0.2:5555"
# 1) 打开向导，Step1 保持默认 "Use app-specific storage"
$A shell monkey -p com.osfans.trime -c android.intent.category.LAUNCHER 1
# 2) 读屏（每步都靠它定位，不用猜坐标）
$A shell 'uiautomator dump /data/local/tmp/ui.xml >/dev/null; cat /data/local/tmp/ui.xml'
#    Step1/2/3 用 input tap 点 NEXT（右 1712,2863）/ PREV（左 190,2863）/ DONE
# 3) 切默认 IME（向导 Step3 的 action_button 也可，但 adb 更可靠）
$A shell 'ime enable com.osfans.trime/.ime.core.TrimeInputMethodService; \
          ime set com.osfans.trime/.ime.core.TrimeInputMethodService'
# 4) 找输入框触发键盘：Settings 主页 → 搜索条
$A shell 'am start -a android.settings.SETTINGS'; $A shell input tap 951 335
$A shell 'dumpsys input_method | grep -m3 -E "mCurMethodId|mInputShown"'   # mInputShown=true
# 5) 截图 → 按软键盘坐标点 n i h a o → 点候选「你好」；再 dump 验证
$A exec-out screencap -p > /tmp/x.png
```

## 3. 两个下次别再踩的点

1. **`adb shell input text` 不走 IME**：它把按键直接注入前台 app，Rime 的组词/候选根本不参与 ⇒ 只能**截图读软键盘坐标 + `input tap`** 逐键点。这是本轮唯一「必须看图」的环节。
2. **`uiautomator dump` 只给当前窗口**：会话用 modal dialog 时先 `dumpsys window | grep mCurrentFocus` 确认焦点窗口，否则会误判「点了没反应」（本轮 Step3 的 SELECT INPUT METHOD 弹窗就是这样，最后改用 `ime set` 绕过）。

## 4. 残留 / 未做

- **整机重启后默认 IME 仍 Trime** 未本轮复核（`default_input_method` 在 settings 库，属持久项；T5 已同口径测过 Fossify 跨真重启保持）。若要闭环，下次重启窗口顺带 `settings get secure default_input_method` 读一次即可。
- Trime 中文/英文切换靠键盘左下「中英」键；英文体验不如 Fossify（用户已裁决取中文，不再回退）。
- cell `/sdcard` = 宿主 `/dev/sda17` pass-through ⇒ Rime 词库（`files/rime/build/*.bin`）落在**宿主根分区**，属既有记载，无需处置。
