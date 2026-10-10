软件 POR 自动化的失败样本（用户目击）：
- run1（busybox poweroff -f + VBUS auto-on）成功：新 boot_id、uptime=17s、USB 重枚举、判定 GOOD。
- run2：进入锁屏后再次下发 poweroff -f，设备**未重启**；随后 GUI 卡死、音量键无响应（内核卡死征兆）。
- 主机侧观测：enx 消失、SSH 超时、fastboot 设备为空 → 整机无响应，需长按电源键强制断电。
结论（待复核）：软件 POR 机制存在，但**不可无人值守密循环**；冷起后设备可能 hang，hang 后
poweroff -f 已无法执行（SSH/内核死）。恢复只能物理强制断电（用户动作）。
