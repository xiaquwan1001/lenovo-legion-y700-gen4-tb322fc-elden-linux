# #414–#416 · 卡死取证的三个反直觉事实：pmsg 不落地、串口 console 后起、mount --move 之后 /proc 没了

> 2026-10-26 · 场景：把根从 Alpine 换成 Debian 的候选镜像，`fastboot boot` 后设备「活着但全静默」（有 USB gadget，无 SSH/无 fastboot/串口无输出）。
> 相关：`PITFALLS/sessions/95-…`（这一类故障的形态）、`reports/m6-debian-candidate-boot-nousb-20261026.md`（完整调试记录）。

## #414 pstore/pmsg **不能**当取证通道（这颗内核上写成功但读不到）

**现象**：`echo x > /dev/pmsg0` 返回 0，`/sys/fs/pstore` **恒空**；`mount -t pstore pstore /sys/fs/pstore` 也空。

**当时的内核侧证据（都是"看起来正常"的）**：
```
OF: reserved mem: 0x00000000c2000000..0x00000000c23fffff (4096 KiB) nomap non-reusable ramoops@c2000000
printk: legacy console [ramoops-1] enabled
pstore: Registered ramoops as persistent store backend
ramoops: using 0x400000@0xc2000000, ecc: 0
/dev/pmsg0 存在（c-w--w---- 251,0）
```
**结论**：`CONFIG_PSTORE=y / PSTORE_RAM=y / PSTORE_PMSG=y` + DT `ramoops` 齐全，`/dev/pmsg0` 也在，
但写入后 pstore 里没有记录 ⇒ **不要**把 pstore 当唯一证据面。`psstore` 的 console zone 只在
panic/oops 时才 flush（正常日志不进 zone），这点也容易误判成"能存"。

**替代（本轮实测有效）**：把 trace 写进**目标根的文件系统**，并且**保持一个常开 fd**：
```sh
exec 9>>/newroot/var/tmp/elden-init-trace.log   # 挂载成功后
printf '...\n' >&9                              # 每步一行，立即落盘
```
跨复位可读；且不受"后续行还在 tmpfs 里"的歧义影响（只写 `/run` 时，最后几条会随掉电消失，
导致断点看起来比实际早）。

## #415 串口 console 是「后起」的：gadget 起来之前的 printk 全丢

**现象**：`cat /dev/ttyACM0` 只能看到 `t=0…10.98 s` 的日志，之后一个字节都没有；而 `/init` 的埋点都在 `t≈2–6 s`。

**原因**：本机只有一条 console（`console=ttyGS0`），而 **ttyGS0 的 USB 复合 gadget 是 `/init` 自己创建的**
⇒ gadget 起来前，printk 发给了不存在的对端；gadget 连上时内核把 ring buffer 重放一遍（正好停在
gadget 创建那一刻的 t 值），**之后才是真正的实时输出**。

**三条实操结论**：
- 看到「日志停在某个 t 就没了」不要立刻判「设备挂了」——先确认那个 t 是不是 `usb-gadget start` 的时刻；
- 早发 gadget（`elden_early_gadget=1`，在 `switch_root` 之前建）能把窗口提前，但**不能提前到 t<1 s**（dwc3 要 probe）；
- 想拿早期日志只能落盘（见 #414 的 fd 方案），或改为 panic 触发 console zone flush。

## #416 `mount --move /proc` 之后，脚本自己就看不见 `/proc` 了（连带时间戳变空）

**现象**：trace 里 `move /dev` / `move /proc` 之后，`t=` 全变空，容易误读成"时间戳丢失/时钟问题"。

**原因**：`trace()` 里 `cut -d' ' -f1 /proc/uptime`，而 `/proc` 已被 `mount --move /newroot/proc` 搬走，
RAM 根上的 `/proc` 变成空目录 ⇒ 读到空字符串。**这不是故障，是预期副作用**。

**真正要留意的连带风险**：`mount --move` 之后若 `switch_root` **返回失败**（而不是成功 exec），
后面的 lifeline（usb-gadget / sshd / udhcpd）会因为 `/dev /sys /run` 都不在 RAM 根上而**静默全废**
⇒ 表现与「设备硬挂」完全一样。治法 = 失败分支里把四个伪文件系统搬回来：
```sh
for _m in dev proc sys run; do mount --move "/newroot/$_m" "/$_m" 2>/dev/null || true; done
```

## 附：主机侧 USB-NCM 没有 DHCP 租约（排查时才发现的）

设备侧 `udhcpd` 若没起来，主机 `enx*` 网卡会 `UP` 但**没有 IPv4**，`ssh 192.168.7.1` 直接 timeout
（看起来像设备没网络）。手工兜底（需 root）：
```sh
sudo ip addr add 192.168.7.2/24 dev enx021e5eede102
```
（`sudo bash -c ip addr add …` 会被引号吞成 `bash -c ip` ⇒ 什么都不发生，实测踩过。）

## 复现

```bash
# trace（每步一行，落目标根 ext4）
ssh root@192.168.7.1 'mkdir -p /mnt/d && mount -o ro /dev/sda17 /mnt/d && cat /mnt/d/var/tmp/elden-init-trace.log; umount /mnt/d'
# pmsg 是否可用（本机实测：写了也读不到）
ssh root@192.168.7.1 'echo probe > /dev/pmsg0; ls -la /sys/fs/pstore/'
# 免物理断电复位（SysRq over USB ACM；本机未验证成功）
sudo python3 scripts/serial-sysrq.py b
```
