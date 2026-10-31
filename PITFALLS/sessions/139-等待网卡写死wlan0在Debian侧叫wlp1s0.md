# #475 · 等待网卡的脚本写死 Alpine 的 `wlan0`：Debian 侧叫 `wlp1s0` ⇒ 每轮启动白等满超时

- 日期：2026-10-31
- 现象：整机启动到 `multi-user.target` 要 **~2 分钟**（POR 后实测 `multi-user` 在 ~128 s），比应有值慢 ~95 s。
  日志只有一行不起眼的 `elden: net-selfheal: wlan 未在 120 s 内 UP，照常执行`。
- 根因：`packaging/elden-userland/hooks/net-selfheal.pre` 的判据是
  `ip -br link | grep -q '^wlan.*UP'` —— 那个名字是 **Alpine 的 `wlan0`**；
  Debian + NetworkManager 把同一块卡命名为 **`wlp1s0`**（`wlan` 字面量根本不是前缀）。
  于是循环永远不提前 `exit 0`，每轮必定跑满 12 × 10 s。
- 为什么以前没暴露：换根到 Debian 之后才改名；而超时分支是「照常执行」⇒ 功能正常、只有启动变慢，
  没有任何 FAIL/失败单元 ⇒ 只能靠读 `journalctl -o short-monotonic` 的单元起止时刻发现。
- 判据（改前/改后，同一台机）：
  - 改前：`net-selfheal` 3.1 s 起 → **128 s** 结束（跑满超时），`multi-user.target` ~128 s。
  - 改后：3.1 s → **10.2 s**（**7.1 s** 完成），`multi-user.target` **33.2 s**、`graphical.target` **33.2 s**
    ⇒ 净省 **~95 s**。
- 修法：判据改成「任意 `wl*` 无线接口、`UP` 且已拿到 IPv4」：
  `ip -br addr | grep -qE '^wl[^ ]+ +UP +([0-9]{1,3}\.){3}[0-9]{1,3}/'`，上限 **20 s**
  （本机 wlan 约 9 s 可用，20 s 留余量；超时仍「照常执行」，不阻断启动）。
- 教训（可推广）：**跨发行版迁移时，任何「按接口名/单元名匹配」的判断都要复验**。
  `wlan0` / `eth0` / `rc-service` / `openrc` 这类字面量在 Debian 侧全部失效，且失效形态通常是
  **静默降级**（等满超时 / 什么都不做），不报错 ⇒ 必须用「起止时刻」而不是「有没有报错」来验收。
- 顺带（同一单元）：`hexagonrpcd` 在该轮以 `status=0/SUCCESS` **796 ms 后自己退出**是**按需退出**（无客户端），
  不是崩溃；`iio-sensor-proxy` 随后正常出值（`monitor-sensor` → `tilt=face-up`）。别把它当失败单元。
