# 2026-10-26（续 2）· M6 上机未收口：Debian 根候选 8 发调试，断点定死在 `switch_root`

- **日期**：2026-10-26
- **pi 会话 id**：见 `$PI_SESSION_ID`
- **主题**：把 Debian(forky/sid) 目标根（`linux17`）用 `fastboot boot` 起起来（M6）。**未成功**，但把停点定死了。
- **结论（4 条）**：
  1. **不是根的问题**：设备上 `chroot /mnt/deb /bin/sh` → `chroot-exec-ok` + `forky/sid`；`dash -n /init` 通过；`sbin/init -> ../lib/systemd/systemd`。ext4 挂载也正常（trace t=0.97→0.98）。
  2. **停在 `switch_root`**：trace 显示 4 个 `mount --move` 全部完成、`exec switch_root /newroot /init` 已发出，而磁盘 `/init` **一行 trace 都没写**（它在开头就会写）⇒ 卡在 busybox `switch_root` 内部（递归删旧 initramfs 树）或 exec 失败。
  3. **取证通道只剩一个可用**：`/init` trace → **常开 fd 9 直写目标根 ext4**（`/var/tmp/elden-init-trace.log`）。**pstore/pmsg 在本机不可用**（写 `/dev/pmsg0` 返回 0 但 `/sys/fs/pstore` 恒空）；串口 console 是 **后起** 的（gadget 由 `/init` 自建）⇒ `t≈2–6 s` 的埋点物理上不可见。
  4. **两个结构隐患已修**：`elden_early_gadget=1`（RAM 阶段就建 gadget，把恢复通道提前一层）；`switch_root` 返回失败时把 `/dev /proc /sys /run` 搬回 RAM 根（否则 lifeline 静默全废、表现等同硬挂）。
- **证据指针**：
  - 报告（权威，含完整调试记录与逐字 trace）`reports/m6-debian-candidate-boot-nousb-20261026.md` §6
  - 坑 `PITFALLS #414–#416`（`PITFALLS/sessions/96-…`）、`PITFALLS/sessions/95-…`（本类故障形态）
  - 候选镜像（均零写盘 `fastboot boot`）：`out/boot-elden-vk164-debianroot.img` … `vk171-swrerr.img`（7 发，全部登记进 `versions/vk-registry.tsv`）
  - ramdisk `/init` 当前 sha `678cccb7…`（含 `elden_early_gadget` + trace 双通道 + switch_root stderr 重定向 + 伪 fs 回搬）
  - 新脚本 `scripts/serial-probe.sh`、`scripts/serial-capture.sh`、`scripts/serial-sysrq.py`
- **未做 / 待做**：**读 `vk171-swrerr` 的结果**（`switch_root` 的 stderr 已重定向进 trace，错误文案就是答案）；若确系删除阶段 → 改「自实现 mount --move + chroot + exec」或 slim ramdisk 复验；M2（归档旧 root）已判定**不必要**（`linux17` 内容 = f2fs 手术的复制源，`linux18` 上有同一份）。
- **设备态**：**需物理 POR**（USB 有 `1d6b:0104`，无 SSH/fastboot）。`boot_b` 未变（`retry=6 succ=1 unbootable=0`），`linux18`（Alpine）未动。

## ★SSOT 待并入

- `TASKS/README.md` 已加 **T19**。
- `reports/mobian-migration-plan-20261021.md` §4 状态块的 **S7** 行可补：候选镜像链 + 断点位置。
- `DEVICE/README.md` §1.1 可补一句：`linux17` 现在是「Debian 根 + 最新 `/init`（sha `678cccb7…`）」，且其启动停在 `switch_root`。
