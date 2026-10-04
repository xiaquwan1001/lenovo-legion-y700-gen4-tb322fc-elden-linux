#!/bin/bash
# 根目录兼容入口 —— 委托给 scripts/build-kernel.sh（ccache + CONFIG_ARCH_QCOM 校验）。
#
# 新用法请优先：
#   scripts/iterate.sh mod <driver-dir>   # 模块快环，不重启（~30s）
#   scripts/iterate.sh dtb|kernel         # kexec 热重载
# 本脚本保留仅为兼容旧文档/肌肉记忆。
exec bash "$(dirname "$0")/scripts/build-kernel.sh" "$@"
