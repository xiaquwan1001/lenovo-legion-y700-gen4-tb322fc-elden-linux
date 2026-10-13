# reboot2-fixed 部署 runbook（C）——上机即执行

> 状态权威 `TASKS.md` G1-24。修复见 `rootfs/reboot2.c`：无参 = 普通重启（`LINUX_REBOOT_CMD_RESTART`），
> **显式传参**才给 XBL reason（`RESTART2 <mode>`）；旧版无参默认 `bootloader` ⇒ 一次裸 `reboot2` 静默进 fastboot（`.pi/plans/2026-10-09-阶段总结-B.md` §2.5.1 / §4 待办 4）。
> 产物 = aarch64 静态 ELF `out/reboot2-fixed`（**本包**，设备接入后按下部署）。

## 0. 传输通道澄清（与任务措辞的差异，见回报「矛盾」节）
- **主线上联 = SSH over USB-NCM gadget `root@192.168.7.1`（usb0，`/init` 静态配址）**，**不是 adb**（主线 Alpine 不跑 adbd）。
- `fastboot` **不能推单个文件**（只写分区镜像），故单文件用 **scp over ssh**；`fastboot` 仅用于进 fastboot/取证。
- adb 仅 stock/fastboot 取证场景（`scripts/bl-*.sh`），本部署用不到。

## 1. 核实产物（先 `file` 核实，别只信文档）
```bash
# 主机侧（研究者无 shell，未能代跑 file；此步上机前执行）
file out/reboot2-fixed            # 期望: ELF 64-bit LSB executable, ARM aarch64, statically linked
sha256sum out/reboot2-fixed
readelf -h out/reboot2-fixed | grep -E 'Machine|Type'   # Machine=AArch64；Type=EXEC(静态) 或 DYN(静态-pie)
```
- 已间接核实：ELF magic = 64-bit ELF；构建配方 `rootfs/build-overlay.sh:33` / `build-rootfs.sh:68` / `configure-ubuntu.sh:104` 均为 `aarch64-linux-gnu-gcc -static -Os -o .../reboot2 rootfs/reboot2.c`（直接证据：目标为 aarch64 静态）。

## 2. 部署位置探测（当前设备实际在跑哪个 reboot2）
```bash
TAB=root@192.168.7.1; SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=6 root@$TAB"
$SSH 'command -v reboot2; ls -l /usr/local/sbin/reboot2; sha256sum /usr/local/sbin/reboot2; head -c4 /usr/local/sbin/reboot2 | xxd'
# 目标路径 = /usr/local/sbin/reboot2（build-overlay/build-rootfs/configure-ubuntu 一致；持久层快照 rootfs/persistent-overlay/STATE.txt 亦此，旧件 709320 B Sep 28 2026 = 有 bug 版）
# 注意 /sbin/reboot 被包成 `busybox reboot -f`（STATE.txt），不认 reason ⇒ 必须用 /usr/local/sbin/reboot2。
```

## 3. 备份（务必先备份再覆盖）
```bash
$SSH 'cp -a /usr/local/sbin/reboot2 /root/reboot2.bak.$(date +%Y%m%d-%H%M%S) && ls -l /root/reboot2.bak.*'
```

## 4. 推送安装（scp over SSH → 原子替换）
```bash
scp -o StrictHostKeyChecking=no out/reboot2-fixed root@192.168.7.1:/usr/local/sbin/reboot2.new
ssh -o StrictHostKeyChecking=no root@192.168.7.1 \
  'chmod 755 /usr/local/sbin/reboot2.new && sha256sum /usr/local/sbin/reboot2.new && mv -f /usr/local/sbin/reboot2.new /usr/local/sbin/reboot2 && sha256sum /usr/local/sbin/reboot2'
# 校验：设备上 sha256 == 主机 out/reboot2-fixed
```

## 5. 验证（无参=普通重启；显式传参=reason 进 fastboot）
```bash
# 5a 用法串（应显示 "no argument = normal reboot"）
ssh -o StrictHostKeyChecking=no root@192.168.7.1 '/usr/local/sbin/reboot2 --help; echo rc=$?'   # rc=2

# 5b 显式传参 = reason → 进 fastboot（旧件同款行为，回归不受本次修复影响）
ssh -o StrictHostKeyChecking=no root@192.168.7.1 'sync; setsid /usr/local/sbin/reboot2 bootloader'
fastboot devices        # ~20 s 内应见设备（WIFI-BMISS 实测 22 s 进 fastboot）
fastboot reboot

# 5c 无参 = 普通重启（关键新行为）：设备应重启回主线 Linux（回到 SSH），**不落 fastboot**
ssh -o StrictHostKeyChecking=no root@192.168.7.1 'sync; setsid /usr/local/sbin/reboot2'
sleep 40; ssh -o StrictHostKeyChecking=no root@192.168.7.1 'echo NORMAL-REBOOT-OK'
#   期望：SSH 重新可达并打印 NORMAL-REBOOT-OK；且 fastboot devices 为空。若落 fastboot = 修复无效。
```

## 6. 回退
```bash
ssh -o StrictHostKeyChecking=no root@192.168.7.1 \
  'mv -f /root/reboot2.bak.<时间戳> /usr/local/sbin/reboot2 && ls -l /usr/local/sbin/reboot2'
# 或直接重新构建覆盖：rootfs/build-overlay.sh / build-rootfs.sh 会在下次烧写用新 reboot2.c 重编。
```

## 7. 纪律
- 面板失败 boot 上 `reboot -f` 会挂（DPU 卡死挡关机）→ 用 `echo b > /proc/sysrq-trigger`；本轮 5b/5c 若恰逢 Q28 失败态，改走 sysrq-b 或冷启。
- 冷启起步优先；连续热重启累积面板失败。`pkill` 用 `-x`。不写死序列号（fastboot 用探测值）。
- 覆盖用 `mv -f`（原子），不 `cp` 直接盖在正被 exec 的文件上。

## 8. 关联固化（部署后）
持久层重建时（`rootfs/build-overlay.sh`）会用 `rootfs/reboot2.c` 自动重编到 `/usr/local/sbin/reboot2`，本 runbook 是对**已烧设备**的在线热替换路径，二者结果一致。
