# #406 `fastboot boot` 的镜像会活过**普通暖复位**，退回 boot_b 必须经 bootloader

## 现象（2026-10-26 实测，HA2EXB0E）

`fastboot boot out/boot-elden-vk163.img` 起了一个 UTS 完全不同的内核（`…-debug-vk163`）做零写盘验证，
验证完在设备里执行 `reboot`，55 s 后 ssh 回来：

```
uname -r  →  7.3.0-rc7-debug-vk127-…-debug-vk163      ← 还是测试内核！
uptime    →  149 s                                     ← 确实重启过
```

同时 `boot_b` 的内容读回是**旧内核**（kernel sha `b6a074ff…` = vk152），槽属性 `retry=6 succ=1` 未变。
⇒ 重启真的发生了，但 ABL 没有去读 `boot_b`，而是又起了上次 `fastboot boot` 交棒的那个镜像。

## 判据（不要用「我 reboot 过了」当证据）

* **唯一可信判据 = 启动后读内核身份**：`uname -r` / `/proc/version` 与 `boot_b` 该有的值逐字比对
  （本项目还要比对模块 vermagic，见 `PITFALLS #394`）。
* 经过一次 bootloader 往返即可确认退回：
  `reboot2 bootloader` → `fastboot devices` 有设备 → `fastboot reboot` → 起来后 `uname -r` 回到 `boot_b` 的值。
  （实测该往返后立刻回到 `…-vk127…`、42 模块。）
* 物理 POR 也有效（Q32 已证三个复位入口对显示无差异），但**暖复位不算**。

## 影响

* 任何「`fastboot boot` 验证完 → `reboot` → 继续在 boot_b 上做事」的流程都可能**还在测试内核上**，
  后续把测试镜像的异常当成日常线回归（或反过来）。
* 与 `#391`（`fastboot boot` 后 USB 变 `1d6b:0104`、60–90 s 才枚举）叠加时极易误判为「设备没起来」。

## 正确做法

（1）零写盘实验结束，先 `reboot2 bootloader` + `fastboot reboot` 退回，再核对 `uname -r`；
（2）报告里「设备已回 boot_b」必须附 `uname -r` 输出，不允许只写「已 reboot」。
