# 面板熄屏的 SSH 唤醒通道（2026-11-26）

> 用户 2026-11-26：「screencap 与宿主 grim 都取到黑屏…做一个 ssh 能直接唤起屏幕的持久服务」。

## 0. 结论与用法

**已交付并端到端实测**：`ssh elden 'elden-wake'` 或 `ssh elden-root 'touch /run/elden-wake.trigger'` 都能把面板从 idle 熄屏叫回来。

| 件 | 位置 | 说明 |
|---|---|---|
| 仓内脚本（SSOT） | `scripts/wake-screen.sh` | `--check` 只读体检 / 默认唤醒 / `--selftest` 判据自证；POSIX sh |
| 设备命令 | `/usr/local/bin/elden-wake` | root:root 0755，可由任意 SSH 会话调用（内部按 uid 1001 注入） |
| 设备服务 | `elden-wake.path` + `elden-wake.service`（**enabled**） | 触发 = `touch /run/elden-wake.trigger`；服务自删触发文件 |
| 回滚 | `systemctl disable --now elden-wake.path; rm /etc/systemd/system/elden-wake.* /usr/local/bin/elden-wake` | 纯 additive |

## 1. 真因（与直觉相反，已入 `PITFALLS #735`）

黑屏时三条「常识判据」全部指向「亮的」：`dpms=On`、`bl_power=0`、`status=connected`；`dmesg` 无 DPU/DSI 报错；cell 正常。
真因 = **phoc 在 idle 时停帧**（不改 DRM DPMS、不改背光）。

**唯一可用判据**：合成器出帧能力 —— `grim` 成功 **且** PNG > 60 KB（本机亮屏 130–180 KB、全黑 < 40 KB）。
⚠ `adb exec-out screencap` **不能**当面板亮的证据：本次实测黑屏时它仍返回 140 KB「成功」图（Android 侧还在出帧，面板仍黑）。

**唤醒机制**：`ydotoold` 常驻，`ydotool mousemove -- 500 500` 注入一次指针事件，phoc 立即恢复出帧（实测 194 KB→178 KB）。

## 2. 端到端验收（2026-11-26T11:0xZ，设备锁内，设置已还原）

```
gsettings idle-delay 5 → 等 20 s
熄屏后 grim      : 失败（黑屏）                       ← 阴性样本
熄屏后 screencap : 140783 B（仍「成功」）              ← 证明 screencap 不是判据
touch /run/elden-wake.trigger（走 path unit）
唤醒后 grim      : 成功 178214 B                      ← 阳性样本
恢复 idle-delay=300 / lock-enabled=true
```

服务侧日志：`elden-wake[281443]: 屏已亮，无需唤醒` → `Finished elden-wake.service`（幂等，亮屏时只读探测、不注入）。

## 3. 两个连带坑（已写进脚本与服务）

1. **path unit 必须在服务里删触发文件**（`ExecStartPost=-/bin/rm -f /run/elden-wake.trigger`），否则同一文件反复触发 ⇒ `Start request repeated too quickly` / `unit-start-limit-hit`（首次安装即踩到）。
2. **别用 `grim` 的 rc 单独判亮**：全黑图也可能成功写出 ⇒ 判据带体积门槛；`--selftest` 就是断言「空文件必须判不亮」。

## 4. 与其它轮的接口

- 本轮一切「取不到画面」的误判（键盘复验、全屏复验）都可能只是这条熄屏；以后先 `ssh elden 'elden-wake'` 再截图。
- 建议纳入 `deploy-desktop-shell.sh --check`（与 udev/phosh/phoc 同级判据）与设备重建 checklist；本轮只做 additive 安装，未改 deploy 脚本。
