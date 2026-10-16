---
name: "qbootctl-slot-management"
description: "y700-elden 设备上管理 Qualcomm A/B 槽位（boot_a/boot_b 的 GPT 属性、mark boot successful、retry 计数、槽位是否 active/unbootable）。触发词：slot-attr、mark-successful、boot_b retry、unbootable、A/B slot、qbootctl、boot_control。"
version: 1
created: "2026-10-07"
updated: "2026-10-07"
---
## When to Use
当需要在 TB322FC/elden 上读取或修改 boot_a/boot_b 的 A/B 槽位元数据时（例如 PITFALLS #88 要求的 mark-boot-successful、检查 retry 计数、判断 slot active/unbootable）。优先用 qbootctl（Alpine 官方包），仅当需要离线编辑 GPT dump 或单独改 retry 计数时才用 scripts/slot-attr.py。

## Procedure
1. 只读确认 by-partlabel 存在：ls -l /dev/disk/by-partlabel/ | grep -E 'boot_|dtbo'（本机 boot_a->sde12, boot_b->sde45，LUN4 /dev/sde，4096 字节扇区）。
2. 安装（若缺）：apk add qbootctl（Alpine community 有包；不要装 qbootctl-openrc 除非确实要开机自动置成功）。
3. 只读基线：qbootctl（dump）与 python3 /usr/local/sbin/slot-attr.py show 对比，逐项应一致（active/successful/bootable）。
4. 写入必须显式带槽位：qbootctl -m b（mark successful）。⚠️ 本机 cmdline 无 slot_suffix，qbootctl -m 不带槽位会回退到 slot a，务必写 b。
5. 写入后等 1-2 秒再读（内核分区重扫窗口内 -n 可能瞬时报 No slots found）。
6. 独立校验两表：读取 GPT primary(lba2) 与 backup(lba1048571) 的 boot_b 条目 byte6（条目内偏移 48+6），两处都应置 bit6(0x40)。
7. 回读：qbootctl -n b 应显示 is marked successful；python3 slot-attr.py show | grep boot_b 应 succ=1。
8. 完整性：dmesg | grep -iE 'gpt|sde' 应无 CRC 错误（内核会重扫全部 78 个分区）。

## Pitfalls
- cmdline 缺 androidboot.slot_suffix => qbootctl 无法判定 current slot；getCurrentSlot() 失败返回 0（slot a）。必须显式传槽位，或在 build-boot.sh 的 CMDLINE 加 androidboot.slot_suffix=_b。
- qbootctl 写入会触发内核分区重扫（dmesg 可见多次 sde: sde1..sde78），紧跟其后的 qbootctl -n/-b 可能瞬时报 No slots found（by-partlabel 暂时不可见），稍等重读即可，不是 GPT 损坏。
- qbootctl -s（set active）会额外走 /dev/sgY 的 UFS BSG 去切换 xbl boot-LUN，本项目不走该路径，勿用；需要时加 -i 忽略 BSG。
- qbootctl 无离线 file 模式（只认 /dev/disk/by-partlabel/*）；离线编辑 GPT dump 或单独 top-up retry 计数仍需 scripts/slot-attr.py（--image / set --retry）。
- qbootctl 以 root 运行；设备侧无需 host sudo。
- mark-successful 与 slot-attr.py 等效且互补：retry 计数低（如 boot_b retry=1）时置 succ=1 可阻止 ABL 继续递减并最终标记 unbootable。

## Verification
1. qbootctl -n b 输出 'is marked successful'。
2. python3 /usr/local/sbin/slot-attr.py show | grep boot_b 显示 succ=1。
3. 独立解析 /dev/sde 的 primary 与 backup 条目，boot_b byte6 都含 0x40，且 boot_a 未变。
4. dmesg 无 GPT CRC 错误，/dev/disk/by-partlabel/boot_b 仍在。