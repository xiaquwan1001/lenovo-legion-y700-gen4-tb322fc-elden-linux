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
