# #472 · 本机「串口控制台」与 SSH **同源**（都是 USB gadget）⇒ gadget 起不来时**没有任何观测面**

- 日期：2026-10-31（M3-1 v5 上机两发实测）
- 相关：#468（自建 boot.img 上机 USB 全消失的三个必要条件）、#92/#93（RAM 变体 vs 持久变体）、#391（快启后 60–90 s 才重新枚举）

## 现象

两发候选内核（pristine+v5）`fastboot boot` 都是 `Booting OKAY` 之后：SSH 300 s+ 不通、宿主 `lsusb` 连 gadget 都没有、
串口日志 `/var/log/elden-serial/ttyACM0.log` **零候选内核输出**——只有旧内核 shutdown 的 32 行。

## 根因（结构性）

设备 cmdline 是 `console=ttyGS0,115200 console=tty0`，`ttyGS0` = **USB gadget 的 ACM 功能**；
宿主看到的是同一个复合设备的两个接口（`ID_MODEL=TB322FC_mainline`，interface 02/04）。

⇒ **串口控制台、`usb0` 网络、SSH 三者共用 gadget**：gadget 一死，三者同时消失；
再叠加本机 **无外部 UART**、DTS **无 ramoops record-size**（`/sys/fs/pstore` 空）⇒ 早期死机**零证据**。

实测还证明：即使 initramfs 已含 gadget 全套 14 个 `.ko` 并显式 `modprobe`（第二发），仍零枚举
⇒ 「initramfs 缺模块」不是（唯一）根因，失败在更早的平台启动环节。

## 判据/做法

- **上机前先确认观测面**：`console=ttyGS0` 的实验必须接受「无 gadget = 全盲」；要早期取证只能
   ① 外部 UART（本机未接）、② ramoops `record-size`（且**恢复启动的内核也要带**，见 TASKS §5 Q28 记录）、
   ③ 不依赖 gadget 的判据（如内核写盘 marker，见 kexec 线 `reports/kexec-vk147-*`）。
- **pristine 血统内核不宜直接当上机载体**：上游 7.3-rc7 缺本机下游平台/显示补丁，两发都是早期失联；
   行为验证优先用 daily 血统（`m3v5-f2` 已证 typec 双口注册 + 12 次 `usb_role_switch_set_role`）。
- 失联后恢复 = 长按电源 10–15 s 强关再开机（`boot_b` 未动，回 vk183）；若换过模块树，必须整树回滚并核验 sha。
