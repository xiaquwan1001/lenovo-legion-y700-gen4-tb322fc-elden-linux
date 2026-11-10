# 主机侧调研：Phosh(phoc) × fcitx5 × OSK 共存可行性（2026-11-10）

> lane：纯主机侧调研（不写设备 / 不重启设备 / 不改仓库既有文件）。只读核验设备状态允许。
> 背景：`reports/ime-chinese-20261109.md`、`TASKS/README.md` G1-37、`PITFALLS/README.md` #576/#577/#578、
> `rootfs/debian/ime/`、`patches-userland/zh-ime/`（squeekboard + focusd 旧栈）、`patches/upstream/phoc-im-keyboard-grab-2026-10-18/`。
> 本次调查起点（2026-11-10 只读核验，设备在线）：**phoc 0.58.0-1 / phosh 0.59~alpha1-1 /
> phosh-osk-stevia 0.59~rc1-1 / squeekboard 1.43.1-2.1（装了但未跑）/ fcitx5 5.1.23-1**，
> 在跑进程：`phoc -v -S -C /usr/share/phosh/phoc.ini -E gnome-session --session=phosh`、
> `fcitx5 -r --disable waylandim`、`phosh-osk-stevia --allow-replacement`。

## §1 机制层：phoc 0.58 实现了哪些 Wayland 文本输入协议 —— 待填

DONE 1（待补）

## §2 fcitx5 侧：waylandim 需要哪个协议 + 与 phoc 的已知不兼容 —— 待填

DONE 2（待补）

## §3 xime 项目是什么 —— 待填

DONE 3（待补）

## §4 hook 方法全集（OSK 与 fcitx5 共存） —— 待填

DONE 4（待补）

## §5 上游是否已合并修复 —— 待填

DONE 5（待补）

## §6 最小判别实验清单（不在本次执行） —— 待填

DONE 6（待补）

## §7 结论性问题：为什么「点输入框 OSK 不弹」 —— 待填

DONE 7（待补）

## §8 未找到 / 未取证清单 —— 待填

DONE 8（待补）

## §9 给 Main 的 3 句话结论 + 建议下一步 —— 待填

DONE 9（待补）
