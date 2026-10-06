# init 固化 / 稳固化（2026-10-06）

关联：`PITFALLS` #107（slim 缺 `/bin/sh`）、#109（三份 init 分叉）、`TASKS.md` §1（G1-30）、
`archive/topics/DRIVER-VERIFY-2026-10-06.md` §5（用户原始要求）。

## 1. 用户诉求

每次启动都有 init 相关告警（mount / VFS / `/bin/sh`）。目标是**稳固化**：别让 init 的
失败静默、别让告警误导、别让 init 自身不可复现。

## 2. 静态取证（主机侧）

1. **三份 init 分叉**：
   - `initramfs/init`（→ boot 镜像 initramfs）
   - `rootfs/init`（→ 磁盘根 `/init`，8134 B，与设备上 `/init` 逐字节相同）
   - 差异：相机预载块、`audio-alsa-init` 钩子、`findfs` fallback、`ttyGS1` respawn 四处不一致。
2. **设备 `/init` 由 awk 补丁拼出**：`scripts/patch-init-{ath12k,net,time,charge,bt,dbus}.sh`
   在设备上原地改 `/init`（各自留 `/init.bak-*`）。不可复现，且只有 `rootfs/init` 这一支被
   同步更新，boot 镜像那支没跟上。
3. **init 自身输出无处留存**：USB ACM 控制台（`ttyGS0`）要 `usb-gadget` 起来后才出现，
   而 boot 早期 init 的 mount/getty 等 stderr 直接上 console ⇒ 事后 `dmesg` 里没有，
   实测 `/run/dmesg-boot.txt` 只有内核消息。**这是「告警看不到原文」的直接原因。**
4. `.pi` shell 交叉验证：`dash -n` 与 `initramfs/busybox sh -n` 均可作为主机侧语法闸。

## 3. 改动（本轮，主机侧已落地）

| 改动 | 文件 |
|---|---|
| 唯一真源 init（RAM initramfs + 持久根共用一个文件，`on_initramfs` 分支） | `initramfs/init` |
| 唯一真源（第二份已删） | `rootfs/init`（git rm） |
| 磁盘根 `/init` 改从真源生成 | `rootfs/build-rootfs.sh` |
| awk 补丁时代结束（6 个脚本退休） | `scripts/patch-init-*.sh`（git rm） |
| 主机侧自检 | `scripts/check-init.sh`（新增） |

加固点（都在 `initramfs/init`）：

- `log()/warn()/fatal()`：同时写 console 与 `/dev/kmsg`，开机日志进 dmesg。
- `mnt()`：`mountpoint` 幂等守卫（避免 switch_root 后重复挂载报 EBUSY）+ 3 次重试 + 失败显式告警。
- **preflight 自检**：`sh mount umount mountpoint switch_root mkdir cat sleep grep` + 根解析器
  （`blkid` 或 `findfs`）必须齐；缺则 `fatal` + `rescue` 丢交互 shell，**不再盲目继续**（#107 的
  userspace 版，避免只剩内核 `No working init found` 一句话）。
- `switch_root`：解析失败/挂载失败/无 `/init|/sbin/init|/bin/sh` 全部显式 `warn` 并留在 RAM 根，
  不再静默回退；`/persist` 缺失也告警。
- 新增 `/var/log/elden-boot.log`（dmesg 快照，跨复位可取证）。
- `ttyGS1` 带外 shell 恢复（两种 root 都有）。

## 4. 验证状态

- **主机侧 ✅**：`scripts/check-init.sh` 全绿；`VERSION=inittest scripts/build-boot-slim.sh`
  出 21,856,256 B 镜像；cpio 内 `/init` 与真源逐字节相同；274 个 applet 链接近全
  （`sh/mount/umount/mountpoint/switch_root/sleep/grep/blkid` 均在）。
- **真机 ⏳ 待做**：部署新 `/init` 到磁盘根 → 重启 → 验证 greetd/桌面/SSH 回归 +
  dmesg 出现新 `[init]` 行。**恢复路径**：纯 RAM 变体（无 `elden_root`）停在 initramfs，
  可 `mount /dev/sda17 /mnt` 后把 `/init.bak-*` 拷回。

## 5. 与「告警原文」的关系

本轮先把 init 输出接到 `dmesg`，下一次真机启动即可拿到**完整** userspace 告警原文
（含用户看到的 mount / VFS / `/bin/sh` 那几条），据此再决定是否还有第三类根因。
`#107` 的 `No working init found` 已由 applet 符号链接修复，若真机仍见，会在新日志里现形。

## 6. 引用

- `initramfs/init`、`scripts/check-init.sh`、`rootfs/build-rootfs.sh`
- `PITFALLS` #107/#109；`TASKS.md` §1 G1-30

---

## 7. 开机刷屏真因（2026-10-06 实机定位）★

用户看到的「进桌面之前的 mount / VFS / `/bin/sh` 之类告警」，原文是：

```
/init: line 35: sleep: not found                      （约 60+ 次）
/init: line 36: can't create /dev/null: nonexistent directory
/init: line 39: can't create /dev/kmsg: nonexistent directory
```

**不是**内核报错，也不是 `/bin/sh` 缺失，而是 **`switch_root` 与后台任务竞态**：

1. boot_b 的 RAM init（10-02 旧版，5869 B）把「等 `/dev/sde79` 挂 `/persist`」写成
   **后台子 shell**（`( … ) &`，见其 line 34-45）。
2. 主流程很快找到 `linux17` 并 `exec switch_root`；内核随即释放 initramfs。
3. 孤儿子 shell 仍在旧根里循环：`sleep` 二进制随 initramfs 删除 → `not found`；
   重定向 `2>/dev/null`、`> /dev/kmsg` 也随 `mount --move /dev` 失效 → `nonexistent directory`。
4. 直到 `i>=100`（10 s）循环结束，噪音停止。

**为什么一直没被串口抓到**：取证走的是 USB ACM（`ttyGS0`），而该 console
要到 `usb-gadget` 起来（≈8.8 s）才注册，刚好错过这几行。**正确取证＝读屏幕缓冲
`/dev/vcs1`**（`cat /dev/vcs1`），它保存了进桌面前的最后 47 行 VT 内容。

**修复**：`initramfs/init` 里 `/persist` 改 **同步 + 有界等待（5 s）**，且只在
「纯 RAM 启动（`elden_root` 为空）」时执行——磁盘根启动本来就会 `switch_root`
掉它，后台挂载纯属竞态源。

**验证资产**：
- `out/boot-elden-vk60.img`：内核 + DTB 与 boot_b **逐字节相同**（vk47clean，保证
  `/lib/modules` 匹配），仅把 60 MB 全家桶 ramdisk 换成 1.1 MB 最小 initramfs +
  修好的 init。21,516,288 B（20.5 MiB）。
- `out/boot_b-live.img`：改动前 boot_b 的完整 96 MiB 备份（回滚用）。
- 主机侧：`dash -n` + `busybox ash -n` + `check-init.sh` 全绿；cpio 内 `/init` == 真源。

**待上机**：`fastboot boot out/boot-elden-vk60.img`（零写盘）→ 确认无刷屏且进桌面；
通过后可 `fastboot flash boot_b` 永久生效（回滚 `fastboot flash boot_b out/boot_b-live.img`）。

## 8. 次要发现：ttyGS0 上 getty 与内核 console 混流

USB 串口（`/dev/ttyACM0` = `ttyGS0`）既是内核 console 又跑着 `getty -n -l /bin/sh`，
内核 printk 会被该 shell 当输入读走，产生 `/bin/sh: syntax error: unexpected ")"`、
`/: Permission denied` 等（`PITFALLS` #8 的救急通道即此）。这是**另一类**「/bin/sh 告警」，
只在 USB 串口出现、不在屏幕。原设计 `ttyGS1` 才是「回显不被 dmesg 污染」的带外 shell
（本轮已恢复 `respawn ttyGS1`）；是否停掉 `ttyGS0` getty 待用户拍板（#8 的救急配方依赖它）。
