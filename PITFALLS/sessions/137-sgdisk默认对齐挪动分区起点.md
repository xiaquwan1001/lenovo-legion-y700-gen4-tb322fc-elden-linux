# #473 · `sgdisk --new` 默认按 2 扇区对齐，会把奇数起点的分区**挪 +1 扇区** ⇒ ext4 起不来

- 日期：2026-10-31（linux18 并入 linux17 实测）
- 相关：#290（本机无 `fastboot fetch`，备份走设备侧 dd）

## 现象

删掉旧分区后，用 `sgdisk --delete=17 --new=17:73277435:123609082 --typecode=17:8300` 重建同名分区，
`sgdisk -i 17` 显示 **First sector = 73277436**（原分区是 73277435，奇数扇区）。
分区起点偏移 512 B ⇒ ext4 superblock 读不到，重启后根分区直接挂不上（本机只能靠 boot_b 救）。

## 根因与正确做法

- `sgdisk` 默认 `--set-alignment=2048`（本处表现为按 2 扇区边界对齐），奇数起点会被向上取整。
- 扩容/重建**必须**：`sgdisk --set-alignment=1 --new=17:<原起点>:<新终点> ...`，然后 `sgdisk -i 17` 核对
  `First sector` 与原值**逐字节相同**，再 `partx -u /dev/sda` 刷新内核视图（在用的分区也能更新尺寸），
  最后 `resize2fs`。
- 顺序：GPT 双表备份 → 改表 → 核起点 → `partx -u` → 确认 `blockdev --getsize64` 已变大 → `resize2fs` → 重启复验。

## 判据

```bash
sgdisk -i 17 /dev/sda | grep 'First sector'   # 必须等于改表前的起点
partx -u /dev/sda && blockdev --getsize64 /dev/sda17
resize2fs /dev/sda17 && df -h /
```

> 若起点已挪错：**先改回正确起点再动文件系统**，不要在错位的表上 `resize2fs` 或重启。
