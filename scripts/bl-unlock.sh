#!/usr/bin/env bash
# ⚠ 适用前提（2026-10-03 定稿）：**只有 ROM ≤ 1.1.11.073/.076 才存在解锁命令**；
#   1.1.11.120 = trap（显成功但回滚）；1.5.x（229/259/C16）上**任何** sn.img 均无效。
#   未过版本门 ⇒ 先全量降级（含 GPT）再跑本脚本。权威顺序：RUNBOOK-BRINGUP.md §0.5；
#   取证/复盘：archive/topics/复盘-2026-10-03-BL解锁.md・PITFALLS #82–#87。
# 联想（ZUX OS / ZUI）平板官方解锁 BL —— U2/任一单元通用。
# 只做「已在 fastboot 模式 + 已拿到 sn.img」之后的两条命令，其余交给用户按键。
# 用法: SN_EXPECT=HA2EXB01 scripts/bl-unlock.sh /path/to/sn.img
set -uo pipefail
IMG="${1:?用法: scripts/bl-unlock.sh /path/to/sn.img}"
[ -f "$IMG" ] || { echo "sn.img 不存在: $IMG"; exit 1; }

echo "== 1/4 fastboot 设备 =="
fb=$(fastboot devices | awk '{print $1}' | head -1)
[ -n "$fb" ] || { echo "未见 fastboot 设备（先 adb reboot bootloader 或 音量下+电源）"; exit 1; }
echo "   序列号 = $fb"
if [ -n "${SN_EXPECT:-}" ] && [ "$fb" != "$SN_EXPECT" ]; then
  echo "   ⛔ 序列号与期望 $SN_EXPECT 不符 —— sn.img 一机一码，拒绝继续"; exit 1
fi

echo "== 2/4 解锁前 getvar（存档）=="
fastboot -s "$fb" getvar all 2>&1 | tee "backup/${fb}-preunlock-getvar.txt" | grep -iE "unlocked|secure|product|variant|slot" 

read -rp "== 3/4 确认解锁？将永久失去保修/FOTA/Widevine L1 并擦除全部用户数据 [y/N] " ans
[ "${ans:-n}" = y ] || { echo "已取消"; exit 1; }

# 本机型 fastboot 对连续命令响应差（PITFALLS #1）→ 逐条执行、逐条确认
echo "== 4/4 flash unlock =="
fastboot -s "$fb" flash unlock "$IMG" || { echo "flash unlock 失败（若 Write to device failed：单条 fastboot reboot bootloader 后重试）"; exit 1; }
sleep 2
echo "== oem unlock-go（屏上出现选择界面时：音量键选 UNLOCK，电源键确认）=="
fastboot -s "$fb" oem unlock-go
echo "设备将自动重启并擦数据，约 3-5 分钟，勿拔线。"
echo "开机后校验: adb shell getprop ro.boot.verifiedbootstate   # 期望 orange"
echo "           adb shell getprop ro.boot.flash.locked      # 期望 0"
echo "           fastboot getvar unlocked                    # 期望 yes"
