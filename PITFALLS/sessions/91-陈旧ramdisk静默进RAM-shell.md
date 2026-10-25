# #407 用陈旧 ramdisk 打包会静默落在 RAM shell：USB 会枚举、但没有 IP

## 现象（2026-10-26 实测）

为模块化内核（vk163）打 boot 镜像时沿用了旧命令 `RAMDISK_KIND=rootfs RAMDISK=out/rootfs-vk127.cpio.gz`。
`fastboot boot` 之后：

* 主机 `lsusb` **能看到** `1d6b:0104 Multifunction Composite Gadget`（gadget 正常）；
* 但 `192.168.7.1` ping 不通、ssh 超时；串口日志尾部是 `~ #`（busybox shell 提示符）。

根因：`rootfs-vk127.cpio.gz` 里的 `/init`（md5 `3e40853f…`）是 7.2 时代版本，switch_root 时
`mount -t ext4` **写死**；生产根已经是 **f2fs `/dev/sda18`** ⇒ 挂不上 ⇒ `/init` 按设计回落到 RAM root
（救援分支），于是：内核起来了、gadget 起来了、但 `/init` 的网络块没跑（无 udhcpd 应答），**没有任何 IP**。
判据链：`uname -r` = 新内核 + `findmnt /` 不是 `/dev/sda18` + 串口 `~ #`。

## 正确做法

* 打「生产根」用的镜像，ramdisk 必须用**仓库 `/init`**（含 blkid/fstype 探测）那份：
  `out/initramfs-full-elden.cpio.gz`（= `RAMDISK_KIND=full`，或先用 `scripts/build-initramfs.sh full` 重建）。
  `boot_b` 上现役的 f2fs 镜像用的就是它（manifest 可查 `ramdisk=` 字段）。
* 打包前先看 `out/boot-elden-<ver>.manifest` 里上一版镜像的 `ramdisk=` 与 `cmdline=`，别凭记忆选。
* 出事后的救援通道：gadget 虽无 IPv4，但通常还有 IPv6 链路本地地址
  （`ping -6 ff02::1%<if>` 学到 `fe80::…`，再 `ssh -6 root@fe80::…%<if>`），
  里面 `/usr/local/sbin/reboot2 bootloader` 就能回 fastboot —— 本轮就是这样恢复的，不必物理断电。
