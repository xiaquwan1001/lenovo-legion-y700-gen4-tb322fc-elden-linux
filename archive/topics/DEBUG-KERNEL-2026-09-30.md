# Debug 内核（vk20-debug）— 2026-09-30

> 目的：后续驱动排查（音频 tplg 路径、mmc 写一致性、显示等）时能开 `dev_dbg` / ftrace / KGDB。
> 入口 `INDEX.md`；音频见 `AUDIO-2026-09-30.md`。

## 0. 一句话

在 vk19 基础上开启 **ftrace / kprobes / KGDB / SND_DEBUG / DEBUG_INFO(DWARF5)**，
`LOCALVERSION="-debug"`。已编译、打包、签名为 `out/boot-elden-vk20-debug.img`。

## 1. 新增/变化的配置

| 类别 | 选项 |
|---|---|
| 追踪 | `FTRACE`, `FUNCTION_TRACER`, `DYNAMIC_FTRACE`, `FUNCTION_GRAPH_TRACER`, `STACK_TRACER`, `FTRACE_SYSCALLS`, `BLK_DEV_IO_TRACE`(blktrace) |
| 探针 | `KPROBES`, `KPROBE_EVENTS`, `UPROBES` |
| 内核调试器 | `KGDB`, `KGDB_SERIAL_CONSOLE`(ttyGS0), `KGDB_KDB` |
| 调试信息 | `DEBUG_INFO`, `DEBUG_INFO_DWARF5`（vmlinux 646 MB，带 DWARF；`Image.gz` 仍 ~20 MB） |
| 子系统 | `PM_DEBUG`, `PM_ADVANCED_DEBUG`, `SND_DEBUG`, `SND_DEBUG_VERBOSE`, `DEBUG_LIST` |
| 已有 | `DYNAMIC_DEBUG`, `DEBUG_FS`, `DEBUG_KERNEL`, `MAGIC_SYSRQ`, `SLUB_DEBUG`, `STACKTRACE` |

复现：`scripts/enable-debug-config.sh` → `./build.sh`（**不跑 olddefconfig**，避免丢 `CONFIG_ARCH_QCOM`）。
配置存档：`patches/config-vk20-debug`。旧配置备份：`linux/.config.bak-vk19-20260930`。

## 2. 产物

| 文件 | 说明 |
|---|---|
| `out/boot-elden-vk20-debug.img` | 打包好（79 MiB，含 Alpine ramdisk + DTB） |
| `bootslot-b/boot_b-debug.img` | 已用 `bootslot-b/avb.key`(fc1e3b33…) 签名、pad 到 96 MiB |

## 3. 闪写 / 回退

```bash
# 刷进 boot_b（设备在线时，无需 fastboot；含 sha256 回读校验）
scripts/flash-b.sh out/boot-elden-vk20-debug.img --reboot
# 回退到稳定基线
scripts/flash-b.sh out/boot-elden-vk19.img --reboot
```

## 4. 怎么用（驱动排查）

```bash
# 动态调试：开某文件/模块的 dev_dbg（重启后失效）
echo 'file sound/soc/qcom/qdsp6/* +p' > /sys/kernel/debug/dynamic_debug/control
echo 'module q6apm +p' > /sys/kernel/debug/dynamic_debug/control
# 固件加载路径取证（本次音频道关键一跳）
echo 'file drivers/base/firmware_loader/* +p' > /sys/kernel/debug/dynamic_debug/control
# ftrace
cd /sys/kernel/tracing && echo function > current_tracer && echo 1 > tracing_on && cat trace
# blktrace（TF/mmc 写一致性）
blktrace -d /dev/mmcblk0 -o - | blkparse -i -
# KGDB（需 cmdline 加 kgdboc=ttyGS0，主机侧 gdb vmlinux 连 USB 串口）
```

## 5. 注意

- debug 选项会增大 `vmlinux`、略有运行时开销；`FTRACE`/`KPROBES` 默认不激活（几乎零开销）。
- `DEBUG_LIST` 会主动报链表损坏；若出现 panic 日志，别慌，是它抓到的真实 bug。
- 若 debug 内核起不来：SSH 断了就走 fastboot 回刷（`scripts/flash-b.sh out/boot-elden-vk19.img` 需设备在线；
  设备不在线则 `fastboot flash boot_b bootslot-b/boot_b-vk19.img`，用户操作）。
