# session：droidloom 告警收尾（doctor + invalid Android frame）2026-11-11

- lane：G2/C12 收尾「droidloom 告警」。产物：`reports/droidloom-warn-20261111.md`。
- 纪律：全程只读 + 一次 adb `cmd notification post`（无写盘/重启/账号）。设备锁串行执行。

## 做了什么
1. **doctor（实测）**：13 PASS / 1 WARN / 0 BLOCK，READY。唯一 WARN = Host LSM hardening
   （`runtime/droidloom-doctor/src/lib.rs:767-791`，非 required，设备 active LSMs=capability）。
2. **invalid Android frame（实测）**：1919 次 / connected 1921，区间 12:49:05–13:53:06，
   **严格 2 s 周期（≈0.5 次/s，更正旧口径 1 次/s）**；15:38/15:41 两次 cell 会话 0 失败。
3. **ABI 错配假设否证（实测）**：Android logcat `DroidloomNotifications: DROIDLOOM_NOTIFICATIONS_ABI=3;`
   与宿主 strings 一致（均 3）。旧报告「logcat 无 NotificationBridge」= 当时 cell 未起的假象。
4. **端到端实测通过**：16:19 adb post 测试通知 → 宿主 `notifications.state` mtime 16:19 落盘 ⇒ 通道现在可用。
5. **定性**：有源码可改（需先取 rev30 源码 + 一行 `Err(_)`→`Err(e)` 日志改动再重编）；
   循环诱因 = 当时某条特定通知内容过不了宿主 `ingest()` 校验，属内容级瞬态，非协议/ABI 级。
6. **降级备案**：无运行时开关（`main.rs:3065-3068` 无条件 start）；本轮不需要；复发时走二进制补丁或重编加 env 门。

## 判据命令
- `journalctl --no-pager | grep -c "invalid Android frame"`（1919）
- `strings -a /opt/dl-test/usr/bin/droidloom-wayland | grep -o "DROIDLOOM[A-Z_]*=[0-9]*;"`
- `adb -s 10.177.0.2:5555 logcat -d -s DroidloomNotifications`
- `ls -l /run/user/1001/droidloom/notifications.state`（post 后 mtime 变化）

## ★SSOT 待并入（总管）
- TASKS/README C12 行③：通知通道「仍坏」→「已自愈 + 瞬态定性 + 0.5 次/s 口径」。
- reports/droidloom-notifications-abi-20261111.md：假设 A 否证、假设 B/C 边界更新。
- PITFALLS 候补：droidloom 通道取证前先确认 cell 在跑。
