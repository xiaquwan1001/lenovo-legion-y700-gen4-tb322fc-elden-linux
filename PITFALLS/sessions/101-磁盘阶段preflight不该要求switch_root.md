# #422 磁盘根的 `/init` preflight 不许要求 `switch_root`（一个用不到的命令迟滞整台机）

- **日期**：2026-10-26
- **场景**：M6/T19，Debian(forky/sid) 根 + 仓库 `/init` 的 `fastboot boot` 候选镜像
- **现象**：设备「活着但全静默」——USB gadget 在、无 SSH、无 fastboot、串口无输出；8 发候选镜像全同。

## 根因（一句话）

`initramfs/init` 的 preflight 用**同一份工具清单**跑两个阶段，其中含 `switch_root`；
而 `switch_root` **只在 initramfs 阶段用**。Debian 的 `busybox` 包只装 `/bin/busybox`、**不装 applet 符号链接**
⇒ 磁盘阶段 `command -v switch_root` 必失败 ⇒ 磁盘 `/init` **第一屏**就 `fatal "missing essential tool(s)"` → `rescue()`；
PID 1 的 `exec /bin/sh` 拿不到 tty（`/bin/sh: 0: can't access tty`）⇒ 全静默，肉眼等同「卡在 switch_root 内部」。

## 为什么难抓

**①** `rescue()` 是**故意不 panic** 的设计（PITFALLS #107 的产物），所以内核不报 `No working init found`、不复位、不落 pstore；
**②** 恢复通道（usb0/ttyGS0）本身在 `rescue()` **之后**才拉起（PITFALLS #413）⇒ 静默是必然；
**③** 唯一的取证面是「常开 fd 9 直写目标根 ext4」（`/var/tmp/elden-init-trace.log`）；
   本次那 3 条 FATAL 能被看到，是因为调用点是 `exec switch_root … 2>&9`，**磁盘 `/init` 的 stderr 顺着继承的 fd 9 落盘**。
**④** 磁盘阶段一行 `elden-init/disk …` 都没有 ≠ 「磁盘 `/init` 没跑」，而是**preflight 在 `trace()` 之前**。

## 修法（已落地，2026-10-26）

**①** `initramfs/init`：把「阶段判定」提到 preflight 之前（`root_phase_disk()`，主流程复用同一函数）；
   工具清单按阶段取 —— 磁盘阶段只要 `sh mount umount mkdir cat sleep grep`（+ `findfs|blkid` 只在 initramfs 阶段要）。
**②** `initramfs/init`：加 busybox applet 回退（`have_applet`）——「能力在、名字不在」不再判根坏。
   ⚠️ **`switch_root` 例外**：调用点是 `exec switch_root`，**exec 只认路径、不认 shell 函数**
   ⇒ 用 `SWITCH_ROOT_CMD`（`switch_root` 或 `"$BB switch_root"`）这种可拆词形式，不能用同名函数。
**③** 门禁：`rootfs/debian/stage.sh` 新增 **I 段**（`/init` 按阶段取清单 + 磁盘工具在 overlay∪chroot 内 + 跑回归测试），
   回归测试 `scripts/test-init-preflight.sh`（4 用例：磁盘无 switch_root 应过 / applet 回退 / initramfs 缺 switch_root 应失败且点名 / applet 形态 exec 友好）。
**④** `packaging/elden-userland/files/init` 与 `MANIFEST.tsv` 同步（overlay 的 `/init` 是副本，不同步 = 门禁 F/I 打架）。

## 教训（可迁移）

- **preflight 的判据要跟「这一阶段真正用什么」对齐**，否则一个不相干的命令能让整机静默；
- 用 `exec` 的目标永远不能是 shell 函数/别名（`exec` 走 execvp）；
- 「有取证通道」和「取证通道能覆盖失败点」是两件事：`trace()` 必须在 preflight **之前**就有最小兜底（本轮靠继承 fd 9 侥幸拿到）。

## 证据

`reports/m6-switch-root-breakpoint-resolved-20261026.md`（逐字 trace + 目标根工具核对表）、
`TASKS` T19、`initramfs/init`（`root_phase_disk` / `have_applet` / `SWITCH_ROOT_CMD`）、
`scripts/test-init-preflight.sh`、`rootfs/debian/stage.sh` 门禁 I。
