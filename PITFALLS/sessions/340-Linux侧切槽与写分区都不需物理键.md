# #707 切 A/B 槽与写分区都不需要物理键：`qbootctl -s` 从 Linux 可用，`dd` 可写可读回

- 日期：2026-11-21 晚（上机三发期间顺带确立，绝对可复跑）
- 状态：已复核（命令 + 原始输出）
- 关联：修正 `#701`「Linux 侧无法切槽」的适用范围；`#701` 实测失败的是 `-u`（标 unbootable），不是 `-s`

## 结论

| 动作 | 从 Linux（root）能不能做 | 证据 |
|---|---|---|
| 查当前槽 / 槽属性 | 能 | `qbootctl`（全表）、`qbootctl -a`、`qbootctl -c` |
| **切 active 槽** | **能** | `qbootctl -s a` → rc=0、打印 `SLOT 0: Set as active slot`；`qbootctl -a` 读回 `Active slot: _a`（三发皆如此，且下一发 ABL 真的按 a 起） |
| 标 unbootable（`-u`） | **不能** | `#701`：`gpt_disk_commit: Invalid args`（要同时改 UFS bLun） |
| **写一个 64 KiB 级分区件** | **能** | `dd if=<件> of=/dev/disk/by-partlabel/vbmeta_a bs=65536 count=1 conv=fsync`，随后 `dd … \| sha256sum` 读回 = 主机件 sha（本轮 `55929c15…` → 写 `419e01ac…` → 读回 `419e01ac…` 逐字节一致） |
| 让 ABL 重新认一个 `boot_*` 件 | 视情况 | 写字节没问题，但 `boot_*` 换件后要**生效**通常要走 fastboot（`#701`：三软路径全灭，只能物理键） |

## 为什么值得记

`#701` 的写法容易被读成「Linux 侧完全切不了槽 ⇒ 每发都要物理键」，代价被高估了：本轮三发 a 槽试验
**全程没按过物理键**（切槽 `qbootctl -s a`，写 `vbmeta_a` 用 `dd`，回落由 ABL 自己完成）。
真需要物理键的只有「进 fastboot 让 ABL 重新验/载一个 boot 件」这一类。

## 判据（可直接复跑）

```
S=root@192.168.7.1
ssh $S 'qbootctl -a; qbootctl -s a; qbootctl -a'          # 期望：_b → rc=0 → _a
ssh $S 'dd if=/dev/disk/by-partlabel/vbmeta_a bs=65536 count=1 2>/dev/null | sha256sum'
# 主机侧对照：python3 scripts/odirect-sha.py <主机件>
```

注意：`-s` 只改槽属性，不改件；`-s` 之后若该槽启动失败，ABL 会把它标 `Bootable 0` 并把 active 改回
另一槽（本轮三发都是这个结果），此时**要再试必须先复位属性**（`scripts/slot-attr.py set a --retry 7
--no-unbootable`，见 `TASKS/README.md` 2026-11-20 条），否则 `-s a` 也起不来。
