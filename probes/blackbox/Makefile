# blackbox.ko — DDR 黑匣子窗口（详见 blackbox.c 头注释与 scripts/blackbox.py）
# 构建（必须带 ARCH=arm64，否则 kbuild 走 x86 找 asm/compiler.h 报错）：
#   . scripts/env-build.sh && make -C ../../build/vk151 M=$PWD ARCH=arm64 modules
obj-m := blackbox.o
