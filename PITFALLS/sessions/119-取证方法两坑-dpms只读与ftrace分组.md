# 119 · #456 两个「取证方法」坑：`dpms` sysfs 是只读 + ftrace 分组不能按时间间隔切

- **日期**：2026-10-28
- **场景**：B5/M6 **U2**（非原子→原子回调时序）取证，`scripts/b5-u2-atomic-timeline.sh`。

## 坑 1：`/sys/class/drm/card0-DSI-1/dpms` 在本机是 **0444 只读**，写它就是 `Permission denied`

```
-r--r--r-- 1 root root 4096 /sys/class/drm/card0-DSI-1/dpms     # 不是 0644
# echo Off > dpms  ⇒  sh: cannot create …: Permission denied   （root 也一样）
```

- 原因：DRM 连接器的 legacy `dpms` 属性只有在驱动实现 `atomic_set_property` 一类钩子时才可写；
  msm 这条链上没有 ⇒ sysfs 呈只读（`modetest -w 36:DPMS:3` 同样空操作，`scripts/g1-22-dpms-test.sh` 头注释早有记录）。
- **正路** = 走会话总线让合成器做真实原子提交：
  `gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.SetActive <true|false>`
- **且必须以会话用户身份调**：session bus 用 EXTERNAL 认证（uid 必须等于 bus 属主），root 直连报
  `Error connecting: Could not connect: No such file or directory` / 认证失败。可用做法：
  `runuser -u <user> -- env XDG_RUNTIME_DIR=/run/user/<uid> DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/<uid>/bus gdbus …`
  （`loginctl show-session c1 -p RuntimePath` 在本机可能是**空**，直接取 `/run/user/$(id -u $U)` 更稳。）
- 附带判据：`dpms=Off` 本身**不代表坏了** —— 空闲熄屏时 `dpms=Off` + `enabled=disabled` 是正常态；
  判「显示栈掉了」必须看 `loginctl` 里 seat0 会话是否还在、`phoc` 是否还在、`systemctl --failed` 是否空。

## 坑 2：ftrace 分组**不能按时间间隔切**，`panel_prepare` 一项就能吃掉 227 ms

首版检查器用「相邻事件间隔 > 50 ms 就切一次提交」，结果：

```
FAIL  采到 enable 方向样本 n=0
```

原因是同一次原子提交里 `drm_atomic_bridge_chain_pre_enable()` **全部返回后**才调
`drm_atomic_bridge_chain_enable()`，而 `drm_panel_prepare()`（面板 DCS 初始化，bonded 双 link 各一次）
实测阻塞 **219.4–224.2 ms** ⇒ 50 ms 阈值把它劈成两个「提交」。

- **正确锚点** = 桥链入口函数：`drm_atomic_bridge_chain_disable` 起一个 disable 组、
  `drm_atomic_bridge_chain_pre_enable` 起一个 enable 组，组内再断言相对次序。
- 一般化：**「一次事务」的边界要用语义标记（入口/出口函数），不要用时间阈值**；
  时间阈值只在已知事务内耗时上界（此处 ≈230 ms，且它本身就是被测对象）时才勉强可用。
