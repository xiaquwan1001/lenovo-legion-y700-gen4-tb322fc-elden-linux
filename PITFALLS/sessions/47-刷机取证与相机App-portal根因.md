# 四十七、刷机取证与「相机 App 无画面」的 portal 根因（#331–#336）

> 报告：`reports/suspend-enable-vk128-vk129-fail-20261018.md`（内核侧）、
> `reports/camera-app-portal-rootcause-20261018.md`（相机侧）。

## 结果速览

| 事项 | 结果 |
|---|---|
| `CONFIG_SUSPEND=y`（vk128 / vk129 两次） | ❌ **都失败**：fastboot 交接后只亮背光、SSH 不通、约 15 s 后关机 |
| vk129 的配置干净度 | ✅ 已与 vk127 可用 config 逐项 diff，**只剩 15 项 suspend 连带项** ⇒ 排除配置污染 |
| 相机 App（Snapshot 50）无画面 | ✅ **定位**：`org.freedesktop.portal.Camera` 的 `IsCameraPresent=false`；后端 gtk/wlr 都不实现 Camera |
| 相机本身 | ✅ 完好（`cam` 30 fps + AE 收敛；`libcamerasrc` 出流；`gst-device-monitor` 列出 2 台含 Rotation 270/90） |
| 当前设备 | ✅ 已回滚 `boot_b-vk127`，可用 |

## #331 `fastboot boot` 在本机不生效

`fastboot boot out/boot-elden-vk128.img` 报 `OKAY`，但设备**回落到磁盘 boot_b**。
判据：在机 `/proc/version` 的构建时间戳仍是旧的（`Oct 17 17:06:17`）。
⇒ **必须 `fastboot flash boot_b`**，且需要 AVB 签名（`scripts/sign-boot-b.sh`，
公钥 sha1 `1e54e86e…` 必须与 `vbmeta_b` 的 chain descriptor 一致，否则 ABL 拒）。
本机 ABL **没有 `fastboot fetch`**（#290）⇒ 刷前读不回备份，回退只能靠 `bootslot-b/*.img` 存档。

## #332 UTS 必须与在机模块目录逐字一致

要得到 `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`，必须
`make LOCALVERSION=-vk127`（源码 `CONFIG_LOCALVERSION="-debug"` + `LOCALVERSION_AUTO=y`）。
名字一旦不同，已部署的 **1597 个 `.ko` 全部失效**（含相机模块 ⇒ 相机直接不可用）。
验收：从成品 `boot.img` 里解出 kernel → 找 `Linux version` 与 `vermagic` 两串，逐字比对。

## #333 `olddefconfig` 会偷偷加符号

`scripts/apply-kernel-fragment.sh` 走的 `make olddefconfig` 引入了 vk127 里没有的
`ARCH_SUPPORTS_KEXEC` / `# CONFIG_KEXEC is not set`。
"只加一项"的正确做法：**从可用 config 出发**改，再用 `diff` 证明差异只剩目标项；
由依赖引入的无关项（如 `FW_CACHE` / `FSL_RCPM`）可接受，但必须逐个看过。

## #334 改 `.config` 的两个致命操作

- 手工编辑 `.config` 后**直接 `make`** ⇒ 新符号没有答案，进交互提问，
   非 tty 下报 `Error in reading or end of file`，构建实际失败但 `make` 返回 0。
- `make oldconfig` + `yes ""`（喂默认值）⇒ **把整片配置刷成 Kconfig 默认，等于毁掉原 config**
   （本轮踩到：diff 从 15 行暴增到数百行 KVM/AMD/SND 噪音）。
   ⇒ 只用 `make olddefconfig`；改完先删 `include/config/auto.conf{,.cmd}` 再编。

## #335 「相机 App 没画面」先查 portal，别查驱动

GNOME Snapshot 50 的二进制里**只有 `pipewiresrc`**（无 `libcamerasrc`/`v4l2src`），
它要经 `org.freedesktop.portal.Camera` 拿 PipeWire 节点。诊断阶梯：

```
cam / libcamerasrc / gst-device-monitor     全正常      ⇒ 驱动、libcamera、IPA、朝向元数据都没问题
strings /usr/bin/snapshot | grep pipewiresrc             ⇒ 确认走 PipeWire 路线
gst-launch pipewiresrc ! …                  target not found
busctl --user get-property … Camera IsCameraPresent      ⇒ false      ← 直接根因
busctl --user introspect …impl.portal.desktop.{gtk,wlr}  ⇒ 都不实现 Camera
apk add xdg-desktop-portal-gnome                         ⇒ 修法
```

⚠️ 本项目 2026-10-07 记过「Snapshot 50 + libcamera-gstreamer 全通」，与"只认 pipewiresrc"不矛盾：
当年 PipeWire camera（或 portal 后端）是工作的，后来可能被 `apk` 升级/清理移除（**未验**）。

## #336 `CONFIG_SUSPEND=y` 在这棵树上启动即死（未定点）

- 现象：背光亮（bootloader 点的）、SSH 从没起来、约 15 s 后关机（= `panic=15` 自动重启）。
- 已排除配置污染（见 #333）。**归因：suspend 代码路径本身。**
- 下一步必须先取栈：
  - vk129 的 cmdline 已加 `printk.always_kmsg_dump`；ramoops 在 DT（`ramoops@c2000000`，16 KiB）、
    `CONFIG_PSTORE_RAM=y` ⇒ 失败重启后 `mount -t pstore pstore /sys/fs/pstore && ls`。
  - 若 pstore 空：走 `/dev/ttyGS0` 串口抓完整 dmesg。**⚠️ 不要再建议 `panic=0`**（2026-10-22 实测反证）：
    `kernel.panic=0` 会让 panic 后**停在原地不自救**——USB gadget 掉出、串口关闭、SSH/fastboot 全不可达，
    每轮都必须人工长按电源键；而 `panic=0` 想换来的「ramoops 不被新启动覆盖」也**没兑现**（panic 时刻串口与 ramoops 都无 panic 文本）。
    正确取舍 = `panic=5` 级：设备自暖复位回 boot_b，`pstore-catch` 下次启动自动归档，暖复位不掉电则 ramoops 应保留。
  - 另一条更硬的坑：`/etc/sysctl.d/99-freeze-trace.conf` 硬写 `kernel.panic = 20`，**覆盖 cmdline 的 `panic=`**；
    做 panic 可见性实验必须改运行时 `echo N > /proc/sys/kernel/panic`，改 cmdline 无效。
  - `record-size` 缺失会让「panic 进 pstore」根本不成立：DTS 只有 `console-size`/`pmsg-size` 时内核**没有独立的 panic/oops 持久区**，
    唯一出口是 console 环形缓冲，会被下一次启动的 printk 立刻覆盖。实测：真 `echo c > sysrq-trigger` 后 `/sys/fs/pstore` 全空。
    加了 `record-size` 后 `dmesg` 才首次出现 `pstore: Using crash dump compression: deflate`（= record 区生效的标志）。
- 静态怀疑点（未验）：`CONFIG_PM_GENERIC_DOMAINS_SLEEP=y` 让 genpd 参与
  `genpd_power_off_unused`，可能关掉启动关键电源域（本机 `rpmhpd` 的 `sync_state` 门控在开机窗口
  一次性求值，见 Q24/N1b）。二分：只开 `SUSPEND=y` 而 `PM_GENERIC_DOMAINS_SLEEP=n`。
