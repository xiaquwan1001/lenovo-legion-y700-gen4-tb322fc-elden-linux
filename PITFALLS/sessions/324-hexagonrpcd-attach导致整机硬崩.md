# #692 让 `hexagonrpcd` attach ADSP sensor PD 会**硬崩整机**（无 Oops、无 pstore、journal 直接截断）—— 复现前必须带走证据再上机

## 现场（2026-11-19 晚）

目标 = 恢复 G1-34 传感器链。装好 `hexagonrpcd` + `iio-sensor-proxy` 后 `hexagonrpcd` failed，日志：

```
Could not open FastRPC node (/dev/fastrpc-adsp): Permission denied
Starting /usr/libexec/hexagonrpc/hexagonrpcd (INIT_ATTACH_SNS) on /dev/fastrpc-adsp
```

真因（第一层）= `/dev/fastrpc-adsp` 是 `crw-rw---- root:root`，而 unit 是 `User=fastrpc`；
包自带 `60-hexagonrpcd.rules`（`SUBSYSTEM=="misc", KERNEL=="fastrpc-*", OWNER/GROUP="fastrpc", MODE="660"`）是对的，
但节点在规则安装**之前**就由 early 加载的 fastrpc 模块创建 ⇒ 需要 re-trigger（或重启一次）才生效。

修 owner 后（`chown fastrpc:fastrpc /dev/fastrpc-adsp`）**再 `systemctl restart hexagonrpcd`，10 s 内整机掉线**：

- SSH reset by peer → 设备彻底离线；约 1 min 后自动回 Linux（uptime 归零）。
- `journalctl -b -1` 用户态日志到崩溃前一刻**直接截断**，内核日志末尾没有任何 Oops/panic。
- `/sys/fs/pstore` **空**（pstore/ram 守卫会拒绝与 initrd 重叠的 ramoops zone ⇒ 本机没有崩溃落盘通道）。

⇒ 崩溃形态属于「ADSP PD attach 时整机硬挂/看门狗复位」，**不可用软件日志取证**，必须先建取证通道再复现。

## 复现前的准备（下次照这个顺序做，别裸试）

- **取证通道**（任选其一并先确认能用）：
   - 串口：`console=ttyGS0` 已在 cmdline，但 USB gadget 随崩溃一起消失 ⇒ 需要**另一条物理串口**（或屏幕拍照）才有用；
   - `pstore`：本机被 pstore/ram 守卫挡掉 ⇒ 想用要先给 ramoops 一个不与 initrd 重叠的窗口（同 vk192 上游补丁做的事）；
   - 内核 `panic=15` 已知，看不到 Oops = 不是 panic 路径，而是硬挂 ⇒ 只能靠外部看门狗/串口。
- **先落盘**：`nohup dmesg -w > /var/log/dmesg-attach.log 2>&1 &`（崩溃前已写的行还在 ext4 上）。
- **一次一个变量**：先只 `systemctl start hexagonrpcd`（不 restart 服务链、不动桌面）。

## 已排除/待查（下次接着判）

- **不是** `/dev/fastrpc-adsp` 缺失（节点在）、**不是** 权限（已修）、**不是** fastrpc 模块没载（`lsmod` 有）。
- 待查：`qcom,non-secure-domain` 是否真的在现役 DTB 的 **adsp** fastrpc 节点上（G1-34 的根因就是它只在 cdsp 上；
  vk172 修好过，但 vk192 的 DTB 是否仍带要现查 `cat /proc/device-tree/.../fastrpc*/qcom,non-secure-domain`）。
- 待查：ADSP 固件版本/`adsp.mdt` 是否来自原厂 259 包（重建根只拷了 `/lib/firmware/qcom/sm8750` 的 96 个文件）。

## 同时得到的一条技术判断（独立于崩溃）

Debian 13 里 **没有 `libssc2`/`libssc-bin`**（`apt-cache search libssc` 只出 sigscheme），
而 `iio-sensor-proxy` 的 Debian 包 **没有链 libssc**（`ldd /usr/libexec/iio-sensor-proxy` 只有 glib/gio）。
⇒ 即便 qrtr svc 400 起来了，Debian 版 proxy 也没有 SSC 后端可用（它只会读 `/sys/bus/iio`，而本机该目录恒空）。
要做传感器，必须**自建 `libssc` + `iio-sensor-proxy -Dssc=true`**（或继续用 `ssccli` 路线给容器供数）。
这条与崩溃是两件事：崩溃先解决取证，SSC 后端才是真正的功能缺口。
