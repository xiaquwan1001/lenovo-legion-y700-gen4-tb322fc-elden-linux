# #746 一条串口上挂了两个读者 ⇒ 输的命令「有时执行、有时被当成用户名」

> 2026-11-27 16:2x–16:4x CST，vk189（`7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`），Debian 13 磁盘根 + systemd。
> 关系：与 Q28（DSI 冷起首模）**无关**；是 tty 输入队列层面的问题。发现时机 = Q28 复盘时顺带核对串口行为。

## 结论

`initramfs/init` 里的 `respawn ttyGS0 &` **无条件**执行（注释自己也写「ttyGS0 是内核 console、ttyGS1 是 out-of-band root shell」），
而磁盘根交给 systemd 后 systemd 又会起 `serial-getty@ttyGS0`。于是 `/dev/ttyGS0` 同时有两个读者：

- `agetty`（systemd 的 `serial-getty@ttyGS0`）→ 显示登录提示，把写入的字符当**用户名**，回车后要**口令**；
- `getty -n -l /bin/sh`（init 的 respawn 循环）→ 把同样的字符当**根 shell 命令**直接执行。

两者谁先 `read()` 谁吃掉输入 ⇒ 同一份脚本「有时执行成功、有时只看到 `密码：`、有时毫无反应」。

## 现场证据（可复现）

```
$ ssh elden 'sudo fuser -v /dev/ttyGS0'
/dev/ttyGS0: root 2884 F.... agetty          # systemd serial-getty@ttyGS0（16:11:19 起）
             root 2890 F.... sh              # init respawn 出的根 shell（16:11:20 起）
$ ps -eo pid,ppid,args | grep /init
    460       1 /bin/sh /init                 # respawn ttyGS0 的订阅 shell，ppid 已被 systemd 收养
$ sudo ls -l /proc/460/fd
    0 -> /dev/null   1 -> /dev/console (deleted)   9 -> /var/tmp/elden-init-trace.log (deleted)
```

`fd1 -> /dev/console (deleted)`、`fd9 -> …(deleted)` 是**跨 `switch_root` 存活**的硬证据：那两个文件属于已被释放的 initramfs。
同族：`461 -> 463` 是 ttyGS1 的 respawn（`/dev/ttyGS1` 上只有它一个读者，属**设计内**的 root shell，主机侧 `/dev/ttyACM1`）。

## 判据（下次怎么一眼认出）

- `sudo fuser /dev/ttyGS0` 返回 **>1 个 pid** ⇒ 双读者。
- 主机侧同一脚本「有时候生效、有时候出现 `密码：`」⇒ 先查读者数，**别先怀疑线路/波特率/脚本**。
- 串口日志里出现 `/bin/sh: <某个不是命令的字符串>: not found`（典型：`AT`）⇒ 有 shell 在接收本该发给别人/别的协议的数据。

## 修法（已落地）

- `initramfs/init`：`respawn ttyGS0` 只在 `on_initramfs=1 || init_mode=legacy` 时执行；磁盘根 + 原生 init 时 ttyGS0 交给 systemd 的 getty。
- `scripts/serial-run.sh`：默认口 `/dev/ttyACM0` → **`/dev/ttyACM1`**（= ttyGS1，设计上的 out-of-band root shell）。要读内核日志仍用 ttyACM0。
- 活体清理（无需重启）：`sudo kill 460`（respawn 订阅 shell）+ `sudo kill -9 2890`（它起的根 shell）；
  之后 `fuser /dev/ttyGS0` 只剩 agetty，`fuser /dev/ttyGS1` 仍是 463（保留）。**SIGTERM 不够**，实测 2890 要 `-9`。
- 生效范围：`initramfs/init` 与设备 `/init` 同一文件（md5 `01d9f6203476533070ab8d287e99ba7c`），但要**重新打包 ramdisk** 才在下次启动生效；
  本轮只做了活体清理 + 源码修正。

## 与之相邻但不同源的两件（别混）

- 主机侧 `ModemManager` 曾往 ttyACM 灌 `AT` ⇒ 设备侧成片 `/bin/sh: AT: not found`：那是被上面这个根 shell **真的执行**了；已用 udev `99-elden-serial-mm-ignore.rules`（`ID_MM_DEVICE_IGNORE`）堵住来源。
- `scripts/serial-console.sh send` 裸发 ⇒ 命令被登录提示当用户名（2026-11-27 早间实测）：已加 `SERIAL_CONSOLE_SEND_OK=1` 闸。

## 指针

- 代码：`initramfs/init`（`respawn()` / ttyGS 段）、`scripts/serial-run.sh`、`scripts/serial-console.sh`、`packaging/elden-userland/.../99-elden-serial-mm-ignore.rules`
- 设计说明：`initramfs/usb-gadget` 头注（GS0=console → ttyACM0，GS1=root shell → ttyACM1）
- 相关：PITFALLS #472（串口/SSH 同源，失联即全盲）、#418（串口仲裁）、`reports/q28-DOSSIER.md` §b B4（「不能靠串口 logger 判显示」）
