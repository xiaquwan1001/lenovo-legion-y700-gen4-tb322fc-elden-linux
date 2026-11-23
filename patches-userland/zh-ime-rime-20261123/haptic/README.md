# OSK 按键震动（触屏打字反馈）—— 最小不改上游方案（2026-11-23）

## 0. 现状（静态核实）

- 硬件链路**已经在**：`aw86927-haptics` 驱动 + haptics-v3 系列两枚 FF 节点（`/dev/input/event2` =
  马达 A=6-005a、`event3` = 马达 B=6-005b），`ffrumble` 宿主基线工具已部署（`scripts/deploy-desktop-shell.sh:392-406`，
  `reports/best-state-and-gap-20261122.md:52`：触觉 2026-11-20 用户实测两侧震）。
- **phosh-osk-stub 0.46 源码里没有任何 haptic/ff/vibrate 钩子**（全 `src/*.c` grep `haptic|rumble|vibrat|EV_FF` = 0 命中，2026-11-23 本机 /tmp/osks/phosh-osk-stub-0.46.0 核实）。
  ⇒ 触屏打字没震感不是"震坏了"，是 OSK 从来没接这条线。

## 1. 最小方案：OSK 每键一次 ffrumble（~5 行 patch，环境变量开关）

唯一出口点是 `pos-input-surface.c` 的 `on_osk_key_symbol()`（phosh-osk-stub 0.46 `src/pos-input-surface.c:380-420`，
所有按键——字符与 KEY_* ——的唯一汇聚点）。补丁见本目录
`0001-osk-stub-keypress-haptic-hook.patch`：

- `ELDEN_OSK_HAPTIC_DEV` 未设 ⇒ 行为与上游**逐字节一致**（g_getenv 为 NULL 短路，g_spawn 都不调）；
- 设了 ⇒ 每键 spawn `ffrumble <dev> <ms> <mag>`（默认 `30ms 0x3333`，可用
  `ELDEN_OSK_HAPTIC_MS` / `ELDEN_OSK_HAPTIC_MAG` 覆盖）。

为什么不做常驻 daemon / libinput 监听：OSK 按键不产生任何内核事件（virtual-keyboard 协议直达
Wayland 合成器），外部进程**拿不到** per-key 信号；D-Bus 侧 `sm.puri.OSK0` 只有 Visible 开关。
⇒ 改 OSK 内部是唯一挂点，5 行 env-gated spawn 是不改上游行为的最小形态（patch 本身仍需重编
phosh-osk-stub；不打算投上游，走 divert+hold 纪律，PITFALLS #654）。

- 默认幅度 0x3333（≈20% 满幅，ffrumble 语义 `strong=weak=mag`，`scripts/ffrumble.c:83-84`）
  + 30 ms：短于可感阈值下限（aw86927 CONT 模式最短有效 ~20 ms，`reports/motor-haptics-vk127-20261017.md:41-45`
  的 amplitude 链路），长于 30 ms 打字节奏里会拖泥带水。**具体手感需上机标定**（§3）。
- 开关：环境变量即开关（user unit/drop-in 里 `Environment=`），无需新 GSettings schema。

## 2. 部署

```sh
# 1) 重编 osk-stub（宿主侧，glibc aarch64 环境；或直接把补丁打到设备当前包源码重编 deb）
cd phosh-osk-stub-0.46.0 && patch -p1 < 0001-osk-stub-keypress-haptic-hook.patch && meson compile
# 2) 设备侧（不改 /usr 二进制，走 divert）
ssh root@192.168.7.1 'dpkg-divert --add --rename --divert /usr/bin/phosh-osk-stub.upstream /usr/bin/phosh-osk-stub'
scp build/src/phosh-osk-stub root@192.168.7.1:/usr/local/bin/phosh-osk-stub-elden
# 3) 每键震动开关（写在 phosh-osk-stub 的 user environment）
mkdir -p ~/.config/systemd/user/phosh-osk-stub.service.d
printf '[Service]\nEnvironment=ELDEN_OSK_HAPTIC_DEV=/dev/input/event2\n' \
  > ~/.config/systemd/user/phosh-osk-stub.service.d/haptic.conf
systemctl --user daemon-reload && systemctl --user restart phosh-osk-stub
```

## 3. 需上机验证（60 s 脚本：`haptic-verify-60s.sh`）

见同目录脚本；判据三条：
1. `ffrumble /dev/input/event2 300 0xffff` 人手可感（链路基线，先于 OSK 验证）；
2. OSK 起来后打字，`getevent -c 3 /dev/input/event2` 在每次按键后有 `SYN_REPORT`（FF 触发到了内核）；
3. 人手判"太轻/太重"，调 `ELDEN_OSK_HAPTIC_MAG`（0x2000/0x3333/0x6666 三档）。

## 4. 回退

```sh
rm ~/.config/systemd/user/phosh-osk-stub.service.d/haptic.conf
systemctl --user restart phosh-osk-stub          # env 没了 = 行为回到上游
mv /usr/bin/phosh-osk-stub.upstream /usr/bin/phosh-osk-stub   # 二进制回退
dpkg-divert --remove --rename /usr/bin/phosh-osk-stub
```
