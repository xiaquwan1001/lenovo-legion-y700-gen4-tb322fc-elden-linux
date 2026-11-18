#!/bin/bash
# rootfs-minbase-build.sh — 最小 Debian 根（GPT-minimal 路线的 A6 前置件）驱动脚本
#
# 为什么要这个驱动：`sudo` 在工具调用里是 argv 直执行、不能带 `VAR=val cmd` 环境赋值，
# 而 `rootfs/debian/build-rootfs.sh` 的最小档全靠环境变量选档（见该脚本头注释）。
# 这里把档位参数固化一处，命令行只留 `--background` / `--from=N`。
#
# 用法（需 root）：
#   sudo bash scripts/rootfs-minbase-build.sh --dry-run      # 免 root 也行：只验前置 + 打印计划
#   sudo bash scripts/rootfs-minbase-build.sh --background   # 自分离跑，日志 $LOG（默认 /tmp/elden-minbase-build.log）
#   sudo bash scripts/rootfs-minbase-build.sh                # 前台跑（几十分钟，别挂工具调用上）
#
# 产物：
#   /opt/elden/minbase-rootfs/                     目标根（可重入：已存在的步骤跳过）
#   out/p2-minbase-<日期>/rootfs-minbase-<日期>.ext4.img(+.sha256)   ext4 镜像，`qdl write 0/90504` 直写
#     （放子目录是因为 check-doctor §5/§5d 扫 `out/*.img`：顶级出现未登记的 *.img 会报「身份表已过期」）
# 口径与理由：RUNBOOK-BRINGUP/GPT-MINIMAL-DESIGN.md §3.2/§4 P2
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

export APTLIST=${APTLIST:-$ROOT/rootfs/debian/apt-list-min.txt}
export SUITE=${SUITE:-trixie}
export ROOTDIR=${ROOTDIR:-/opt/elden/minbase-rootfs}
export STAGE=${STAGE:-$ROOT/out/stage-min-20261118}
export ROOTSPEC=${ROOTSPEC:-LABEL=linux}   # busybox findfs 只支持 LABEL=（不支持 PARTLABEL=）
export SKIP_DESKTOP=1
export GATE_MIN=1
export IMG_MIB=${IMG_MIB:-6144}            # 6 GiB：装得下 1.8 G 模块 + 44 M 固件 + base；设备上再 resize2fs
export OUT=${OUT:-$ROOT/out}
export SSH_PUB=${SSH_PUB:-/home/xuqianhui/.ssh/id_rsa.pub}
export LOG=${LOG:-/tmp/elden-minbase-build.log}

exec bash "$ROOT/rootfs/debian/build-rootfs.sh" "$@"
