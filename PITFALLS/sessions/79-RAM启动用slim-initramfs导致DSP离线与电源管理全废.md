# RAM 启动镜像用 `initramfs-slim` ⇒ ADSP/CDSP 离线 ⇒ 电源管理（battmgr）全废（#390）

> 日期：2026-10-25 · 场景：为跑 Gunyah 用 `fastboot boot` 起了一版「-@ DTB」镜像
> （内核与日用同源、DTB 只多 `__symbols__`），**唯一差异是 ramdisk 用了 `initramfs-slim`（1 MB）**。
> 起来后 WiFi 正常、SSH 正常，但「电源管理」全坏。

## 症状（可判定的三条）

- `/sys/class/power_supply/qcom-battmgr-{bat,usb,wls}` **存在**，但读任何属性都返回
  `Resource temporarily unavailable`（= `-EAGAIN`，说明 PMIC GLINK 通道没人应答）。
- `/sys/class/remoteproc/remoteproc{0,1}` → `state=offline`（adsp / cdsp 都没起来），
  `dmesg` 里**一条 q6v5/pas 日志都没有**（不是失败重试，而是根本没加载到固件）。
- `lsmod | grep -E "pmic_glink|battmgr"` 为空 ⇒ `qcom_battmgr`/`pmic_glink` 的 probe 从未成功。

## 根因

`initramfs-slim` **不含 `/lib/firmware`**（`scripts/build-initramfs.sh` 开头就写了「仅用于纯 RAM 研究，
切勿用它做驱动/DTS 验证（vk60 的教训）」）。而 `q6v5_pas` 在 **switch_root 之前**就从 initramfs 取
ADSP/CDSP 固件（磁盘 `/lib/firmware` 那时还没挂）⇒ 固件 `-ENOENT` ⇒ DSP 永久 offline ⇒
PMIC GLINK / battmgr / 充电 / 电量全部不可用。

**为什么 WiFi 反而正常**：ath12k 固件在磁盘 `/lib/firmware/ath12k/...`，switch_root 之后才加载，
所以「WiFi 好、电源坏」是这条坑的典型指纹，别误判成「主线缺 pmic 驱动」。

## 判据（三步，60 秒内定性）

```bash
for d in /sys/class/remoteproc/remoteproc*; do cat $d/name $d/state; done   # 期望 running
cat /sys/class/power_supply/qcom-battmgr-bat/capacity                      # -EAGAIN = 本坑
zcat <ramdisk.cpio.gz> | cpio -t --quiet | grep -c '^lib/firmware'          # 0 = 本坑
```

## 修法

实验镜像只要涉及 switch_root 之后的驱动/服务，**ramdisk 必须用日用那份全量 ramdisk**
（当前 = `out/rootfs-vk127.cpio.gz`，62 MB，与 `out/boot-elden-vk152.img` 内 ramdisk 逐字节相同）：

```bash
mkdir -p build/gunyah-port   # 已带 -@ / gunyah 的内核树
KDIR=$PWD/build/gunyah-port VERSION=<名字> RAMDISK=$PWD/out/rootfs-vk127.cpio.gz \
  bash scripts/build-boot.sh
```

产物：`out/boot-elden-dtbo2.img`（2026-10-25 实测：`fastboot boot` + 刷进 boot_b 两条路都正常，
adsp/cdsp `running`、battmgr 可读、`/dev/gunyah` 同时可用）。
