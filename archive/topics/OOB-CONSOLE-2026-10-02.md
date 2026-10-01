# 带外控制通道 — USB 串口 / ramoops（2026-10-02）

> 背景：SSH 只能覆盖"网络栈 + 用户态都健康"的场景；容器崩溃、内核 hang、网络掉了就抓瞎。
> 目标：建立**不依赖 IP/SSH**的内核级 OOB（out-of-band）通道。
> 结论：设备**已经内置**了大部分能力，零内核改动即可用；只差"持久化"和"跨重启日志"。

---

## 0. 一句话

**`/dev/ttyACM0` 已经是设备的实时内核日志口**（cmdline 里 `console=ttyGS0,115200`），
主机直接 `cat` 就能看 hangcheck/panic；再在 `ttyGS0` 上挂个 root shell 就是完整 OOB 控制台。
设备侧 kernel config 已具备 `KGDB=y`、`PSTORE_RAM=y`、`F_FS=y`（adb 可选）。

---

## 1. 已实测可用（2026-10-02）

| 项 | 值 |
|---|---|
| 设备 USB gadget | `g1` @ UDC `a600000.usb`，functions：`acm.GS0` + `ncm.usb0` |
| 设备串口节点 | `/dev/ttyGS0`（CDC-ACM） |
| 主机串口节点 | `/dev/ttyACM0`（用户已在 `dialout` 组，可直接打开） |
| **内核 cmdline** | `console=ttyGS0,115200 console=tty0 loglevel=8 ignore_loglevel ...` |
| 实测 | 主机 `timeout 3 cat /dev/ttyACM0` 收到实时 kernel log（binder 事务报错等） |
| root shell | 设备 `setsid sh -c 'exec sh </dev/ttyGS0 >/dev/ttyGS0 2>&1' &` → 主机 `bash scripts/serial-run.sh 'id'` 返回 `uid=0(root)` |

> 注意：`ttyGS0` 同时是 kernel console，shell 的输出会和 dmesg 交错、回显有延迟（正常）。
> 需要"干净"的交互式 shell 时，可再加一个 `acm.GS1`（见 §4 可选）。

---

## 2. 主机侧工具

`scripts/serial-run.sh`：termios raw + select 的收发封装。

```bash
bash scripts/serial-run.sh 'uname -r; id'          # 发一条命令并收 5s 回显
SERIAL_WAIT=10 bash scripts/serial-run.sh 'dmesg | tail -30'
bash scripts/serial-run.sh                          # 纯读 5s（看实时内核日志）
# 长时记录内核日志（推荐常开一个）：
cat /dev/ttyACM0 >> ~/y700-elden/logs/serial-$(date +%F).log &
```

---

## 3. 设备侧：OOB shell 本来就持久（本轮只补了 GS1）

**已发现**：`/init`（busybox init 的 PID1 脚本）里早就有：
```sh
respawn() { while true; do [ -c "/dev/$1" ] && setsid getty -n -l /bin/sh -L "$1" 115200 vt100; sleep 1; done; }
...
respawn ttyGS0 &
```
→ `ttyGS0` 上一直有一个 root shell（busybox getty `-l /bin/sh` 会 **exec** 成 sh，
所以 `pgrep getty` 看不到它；应验证 `/proc/<pid>/fd/0 -> /dev/ttyGS0`）。**无需额外持久化脚本。**

**本轮补丁**：GS0 同时是 kernel console，shell 回显会被 dmesg 污染。新增**第二个 ACM `acm.GS1`**
作为专用 OOB shell：

| 通道 | 主机节点 | 用途 |
|---|---|---|
| `acm.GS0`（`console=1`） | `/dev/ttyACM0` | 实时内核日志（printk） |
| `acm.GS1`（新） | `/dev/ttyACM1` | **干净的 root shell** |

改动（已包含在本项目）：

- `initramfs/usb-gadget`：`mkdir -p functions/acm.GS1` + `ln -s`（stop() 同步加清理）
- `initramfs/init`：`respawn ttyGS1 &`

**部署/验证（2026-10-02 已做）**：
```bash
# 备份后覆盖设备上的两个文件
scp initramfs/usb-gadget root@192.168.7.1:/usr/local/sbin/usb-gadget
scp initramfs/init        root@192.168.7.1:/init
# 上线（gadget 需重新 bind，会瞬时打断 NCM/SSH；用 detach 脚本自愈网络）
bash scripts/oob-gs1-activate.sh   # 见项目 scripts/
# 验证：主机出现 ttyACM0 + ttyACM1；
SERIAL_DEV=/dev/ttyACM1 bash scripts/serial-run.sh 'echo GS1_OK; id'
```
> 重启后也会自动生效（`/init` 已写入）。设备侧备份：`/init.bak-gs1`、
> `/usr/local/sbin/usb-gadget.bak-gs1`。

---

## 4. 可选增强（按性价比排序）

| 通道 | 现状 | 需要的改动 | 价值 |
|---|---|---|---|
| **ramoops / pstore** | ✅ **已在用，无需补丁** | 无 | 跨重启捕获 panic/hang 前日志 |
| 第二个 ACM（GS1）做干净 shell | ✅ **本轮已加** | — | 交互 shell 不被 dmesg 污染 |
| adb over `F_FS` | `CONFIG_USB_CONFIGFS_F_FS=y` | 需用户态 `adbd`（Alpine 无） | 功能最全，工作量大 |
| kgdb | `CONFIG_KGDB=y` + `KGDB_SERIAL_CONSOLE` | cmdline 加 `kgdboc=ttyGS1`（GS1 已专用于 shell，可换用） | 内核断点/单步，深挖 hang |
| netconsole | **未编译** | 内核开 `CONFIG_NETCONSOLE` | UDP 发日志，依赖网络（比串口弱） |

### 4.1 ramoops 实测状态（更正早期笔记）

早期笔记称"DT 无 ramoops 节点、`/sys/fs/pstore` 空"——**不对**。实测：
```
OF: reserved mem: 0x00000000c2000000..0x00000000c23fffff (4096 KiB) nomap ramoops@c2000000
printk: legacy console [ramoops-1] enabled
pstore: Registered ramoops as persistent store backend
ramoops: using 0x400000@0xc2000000, ecc: 0
```
`sm8750-lenovo-elden.dts` 的 `reserved-memory` 已有：
```dts
ramoops@c2000000 { compatible = "ramoops"; reg = <0 0xc2000000 0 0x400000>;
                   console-size = <0x200000>; pmsg-size = <0x200000>; no-map; };
```
且 `/init` 已设 `softlockup_panic=1`（hang 会变成 panic 落进 pstore）。
`/sys/fs/pstore` 在**无崩溃时本来就为空**——不是故障。

**验证 pstore 可用（会故意崩溃一次，需重启）**：
```sh
ssh root@192.168.7.1 'echo c > /proc/sysrq-trigger'   # 触发 panic
# 设备自动重启后：
ssh root@192.168.7.1 'ls -l /sys/fs/pstore/; cat /sys/fs/pstore/console-ramoops-0 | tail -50'
```

---

## 5. 与现有调试手段的关系

- `DEBUG-KERNEL-2026-09-30.md`（vk20）：ftrace/kprobes/KGDB/**pstore 相关**已在 debug 内核里。
- 本文补的是"**怎么用、怎么持久化**"，不改内核即可得 OOB console。
- Waydroid 排查已用上：Mesa 上机验证时靠 SSH + logcat 即可；若再遇 GPU hang，
  串口能直接看到 `hangcheck` / `gpu lockup` 而不依赖容器存活。

---

## 6. 变更记录

- 2026-10-02：初版。实测 `/dev/ttyACM0` 实时内核日志 + `ttyGS0` root shell（init respawn）；
  新增 `scripts/serial-run.sh`。
- 2026-10-02（同日）：新增 `acm.GS1` 专用 OOB shell（`initramfs/usb-gadget` + `initramfs/init`），
  主机得 `/dev/ttyACM1` 干净 shell；确认 **ramoops 早已启用**（更正旧笔记），无需 DT 补丁。
