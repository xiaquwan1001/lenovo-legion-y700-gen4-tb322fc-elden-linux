# #722 systemd ≥257 移除了 `reboot` 的位置参数 ⇒ `systemctl reboot bootloader` 是 **no-op**（rc=0、设备纹丝不动）

> 2026-11-25 实测（设备 systemd **257.13**，内核 vk189）。这条把「软路径不存在」的旧结论彻底推翻：
> 命令**发出去了、也返回 0**，但设备既没重启也没进 fastboot —— 因为 `bootloader` 被当成多余位置参数忽略/报错吞掉。

## 判据（30 秒分清真假）

```sh
systemctl --version | head -1                     # ≥257 ⇒ 位置参数不可用
before=$(cat /proc/sys/kernel/random/boot_id)
systemctl reboot --reboot-argument=bootloader     # 正确形态
# 10 s 内应见 fastboot devices 出现 SN；否则 after=$(cat …/boot_id) 仍是 before ⇒ 命令没生效
```

实测对照：`systemctl reboot bootloader`（位置参数）⇒ `boot_id` 不变、uptime 连续；
`systemctl reboot --reboot-argument=bootloader` ⇒ **~10 s 进 fastboot**（`HA2EXB0E  fastboot`）。

## 两个连带坑

- **设备上的 `elden-to-bootloader` 可能是旧副本**：旧副本 dry-run 打 `[dry] systemctl reboot bootloader`（无
   `--reboot-argument`）⇒ 看起来「软路径不成立」。判据 = `grep -c reboot-argument /usr/local/sbin/elden-to-bootloader`
   必须 ≥1（现役版 4 处）。重部署后 `--dry-run` 应打 `systemctl reboot --reboot-argument=bootloader`。
- 进 fastboot 的**后半段**不依赖 PSCI vendor reset：本板走 **nvmem-reboot-mode**（DT `/reboot-mode`
   `mode-bootloader = <0x02>` + `CONFIG_NVMEM_REBOOT_MODE=y`，PMIC SDAM cell 写 magic）。所以
   「kallsyms 里没有 vendor-reset handler」**不能**当作「进不了 fastboot」的证据。

## 处置

- 一律用 `systemctl reboot --reboot-argument=bootloader`（systemd <257 再回退位置参数）。
- 上机前先跑设备侧脚本的 `--dry-run` 看它到底要发什么，别只信注释。

## 附：`fastboot boot` 测试核的「只背光」现象（2026-11-25 实测）

G7 线测试核（`7.4.0-rc3-g7a-dwc3v11-reset-20261123-dirty`）经 `fastboot boot` 起机后，
**有一次只亮背光、屏上无画面**（phoc 未出图），而 SSH（USB 192.168.7.1）正常。
⇒ 纪律：**`fastboot boot` 只用于短测，测完立刻 `systemctl reboot` 回正常槽**；不要在测试核上
停留做长采样（本轮就因为在那颗核上采样被中断而让屏停在背光）。
`systemctl reboot` 后回到 vk189，`phoc/phosh` 正常、锁屏可见（截图取证）。
