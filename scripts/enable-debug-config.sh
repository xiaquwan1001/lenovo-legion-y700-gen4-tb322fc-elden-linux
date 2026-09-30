#!/bin/bash
# 开启驱动调试所需的内核选项（elden / vk20-debug）。
# ⚠️ 绝不跑 olddefconfig（会删 CONFIG_ARCH_QCOM）。用 scripts/config 逐项改，随后直接 make。
# 用法：scripts/enable-debug-config.sh && ./build.sh
set -eu
cd "$(dirname "$0")/.."
cd linux
C=scripts/config

# --- 追踪：ftrace / 事件 ---
$C -e FTRACE -e FUNCTION_TRACER -e DYNAMIC_FTRACE -e FUNCTION_GRAPH_TRACER \
   -e STACK_TRACER -e FTRACE_SYSCALLS -e BLK_DEV_IO_TRACE
# --- 动态探针 ---
$C -e KPROBES -e KPROBE_EVENTS -e UPROBES
# --- KGDB over 串口控制台（ttyGS0）---
$C -e KGDB -e KGDB_SERIAL_CONSOLE -e KGDB_KDB
# --- 调试信息（vmlinux 带 DWARF；Image.gz 不受影响）---
$C -d DEBUG_INFO_NONE -e DEBUG_INFO -e DEBUG_INFO_DWARF5
# --- 子系统 debug ---
$C -e PM_DEBUG -e PM_ADVANCED_DEBUG -e SND_DEBUG -e SND_DEBUG_VERBOSE -e DEBUG_LIST
# DYNAMIC_DEBUG 本就已开，这里再确保一次
$C -e DYNAMIC_DEBUG
# --- 版本标识，便于区分当前跑的是哪版 ---
$C --set-str LOCALVERSION "-debug"

echo "[debug-config] done — 现跑 ./build.sh（会校验 CONFIG_ARCH_QCOM）"
grep -E "^CONFIG_(FTRACE|KPROBES|KGDB|DEBUG_INFO|SND_DEBUG|DYNAMIC_DEBUG|LOCALVERSION)=" .config
