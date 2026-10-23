# 66 · 裸 `adb`/`fastboot` 探测把命令发给同总线的**另一台手机**；锁 fd 还会泄进 adb 守护进程

- 编号：**#371**
- 日期：2026-10-23
- 触发场景：为了给上游回信取证（stock Android 侧 `power_now`），跑 `scripts/slot-switch.sh a --reboot`
  把本机平板切到 a 槽。**当时总线上插着另一台 Android 手机（vivo）**。

## 1. 事故链（3 步，全部有输出可核）

(1) `slot-switch.sh` 的「我在哪」判断是 `have_adb() { [ "$(adb get-state)" = device ]; }` —— **没有 `-s <序列号>`**。
(2) 平板上跑的是 Linux（没有 adb），但总线上那台 vivo 是唯一 adb 设备 ⇒ `adb get-state` 返回 `device`
   ⇒ 脚本认定「在 Android」⇒ 执行 `adb reboot bootloader`。
(3) **那条命令发给了 vivo**（用户已断开）。平板全程未被触碰（脚本走到 `wait_fastboot` 超时后退出）。

同类隐患同样存在于 `have_fastboot() { fastboot devices | grep -q .; }` —— 只要总线上有任意一台 fastboot 设备
（另一台手机/开发板）就会被当成我们的。

## 2. 连带坑：设备锁 fd 泄进 adb fork-server，后续所有脚本永久阻塞

`lib-device-lock.sh` 用 `exec 9>>lock; flock 9`。脚本再由 shell 拉起 `adb ...` ⇒ **adb 客户端把 fd 9 一起继承**，
adb 又由 `adb -L tcp:5037 fork-server server` 常驻 ⇒ **锁被守护进程持有**。

复现（本次真实发生）：

```
$ fuser -v /tmp/elden-device-root_192_168_7_1.lock
  ... 72337 F.... adb            # ← 就是 adb fork-server
$ bash -x scripts/slot-switch.sh status
+ flock -w 300 9                 # 卡在这里 300 s，无任何输出
```

**判据**：`flock -w 300` 卡住且 `fuser <lockfile>` 指向 `adb`/`fastboot` 常驻进程。

## 3. 修法（已落地）

`scripts/slot-switch.sh`：

- **目标设备必须显式**：`SER` / `SERIAL` / `TABLET_SERIAL` 环境变量，或 `--serial <SN>`。
- **fastboot 侧**才允许自动推导，且**必须唯一**且 `product` 匹配 `$TABLET_PRODUCT_MATCH`（默认 `elden`），否则拒绝。
- **adb 侧永不猜**：没有显式序列号 → `have_adb` 恒假。
- **adb 一律关掉锁 fd**：`adbx() { timeout .. adb "$@" 9>&- ; }` ⇒ fork-server 不再继承 fd 9。

## 4. 通用纪律（写进来，避免下次）

(1) 任何脚本里出现**裸 `adb` / `fastboot`**（不带 `-s`）都是事故候选：多设备环境下它选谁由守护进程决定。
(2) `9>&-` 是设备锁与**常驻子进程**共存的最小代价；凡是会 fork 守护进程的命令（adb/fastboot/ssh 长连）都该关锁 fd。
(3) 事故后先 `fuser <lockfile>`，不要先怀疑设备。
