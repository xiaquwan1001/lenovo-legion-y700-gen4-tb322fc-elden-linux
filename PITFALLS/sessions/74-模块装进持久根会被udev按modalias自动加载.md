# 「零写盘」实验仍有持久副作用：模块进 `/lib/modules` 后 udev 会按 modalias 自动加载（#385）

> 日期：2026-10-24 · 场景：`fastboot boot` 零写盘引导 Gunyah 内核，把 9 个 `.ko` 装进持久根 `/lib/modules/<UTS>`。
> 实验后重启回日用内核（vk152），发现 `lsmod` 里 **`gunyah_wdt` 已被自动加载**——而 vk152 的 config 里 `CONFIG_GUNYAH_WATCHDOG` 并未开启。

## 机理

`qcom_scm` 在探测时按 SMCCC UUID 注册了平台设备 `gunyah-wdt`（modalias = `platform:gunyah-wdt`）。
一旦 `/lib/modules/<UTS>` 里**存在** `gunyah_wdt.ko`，udev 的 modalias 规则就会 `modprobe` 它；
模块的 `vermagic` 与在机 UTS 相同 ⇒ 加载成功。也就是说：

- **分区确实零写盘**（没写 boot/system）；
- **但持久根的 `/lib/modules` 是会被改的**，并且会**改变日用系统的后启动行为**。

## 纪律

- 说「零写盘实验」时，只承诺「不写分区」；模块安装属持久副作用，要在报告里显式列出（本轮已记：`reports/gunyah-boot-test-20261024.md` §4）。
- 需要「绝对无副作用」时：模块放 `/tmp` 用 `insmod <绝对路径>`，或实验后 `rm -rf /lib/modules/<UTS>/kernel/{...}` + `depmod -a` + `rmmod`。
- 反过来利用它：想让日用线验证某个 =m 驱动，把 `.ko` 放进模块树即可（udev 自动绑 modalias），不用改 `/etc/modules`。
