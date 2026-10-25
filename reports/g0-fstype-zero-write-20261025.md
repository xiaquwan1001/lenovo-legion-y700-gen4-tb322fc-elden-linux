# G0 达成：`/init` fstype 自动探测零写盘上机验证（2026-10-25）

> 目的：在**不改任何分区**的前提下证明「根挂载不再写死 ext4」在真机成立 —— 这是 f2fs 与 Mobian 两条
> 迁移路线的**共同前置**（`reports/f2fs-plan-20261021.md` §5 把它列为唯一代码阻断项）。
> 手段：内核/DTB **逐字沿用 vk152**（从 `out/boot-elden-vk152.img` 解出）、只换 ramdisk 里的 `/init`，
> `fastboot boot` 零写盘启动。**单变量，可比。**

## 0. 结论

**通过。** 新 `/init` 在真机上用 `blkid` 探到 `ext4` 并正常 `switch_root`，桌面/模块/WiFi/USB 全部无回归；
复位后设备照旧回到 `boot_b`=vk152，**槽属性一位未变**。

## 1. 构建物（可复现）

| 项 | 值 |
|---|---|
| 镜像 | `out/boot-elden-vk162-fstype.img`，85 557 248 B，sha256 `a0ef33818ada03bfaddd09f4a8e5b3e13235ea5c5789f23b877d882ebf92e9d9` |
| manifest | `out/boot-elden-vk162-fstype.manifest`（`verification=ZERO_WRITE_BOOT_OK_2026-10-25`） |
| 内核 | **= vk152 那份**：`kernel_sha256=b6a074ff…`、`kernel_payload_sha256=c0b39ccb…`、`kernel_identity_source=packed` |
| DTB | `7190ecf0…`（= vk152） |
| ramdisk | `out/initramfs-full-elden.cpio.gz`，sha256 `04254304b96c37ba…`（基底 `out/rootfs-vk127.cpio.gz` + 仓库 `initramfs/init`） |
| cmdline | 与 vk152 逐字相同（`elden_root=LABEL=linux17 … androidboot.slot_suffix=_b`） |

构建命令（两条，均可重跑）：

```bash
bash scripts/build-initramfs.sh full "$PWD/out/rootfs-vk127.cpio.gz"      # 注入仓库 /init
python3 scripts/mkbootimg.py --unpack out/boot-elden-vk152.img --unpack-dir /tmp/vk152un   # 取内核/DTB
VERSION=vk162-fstype KDIR="$PWD/build/vk151" \
  KERNEL_IMG=/tmp/vk152un/kernel DTB_FILE=/tmp/vk152un/dtb \
  RAMDISK="$PWD/out/initramfs-full-elden.cpio.gz" bash scripts/build-boot.sh
```

## 2. 上机实测（`fastboot boot`，零写盘）

```
fastboot boot out/boot-elden-vk162-fstype.img
  Sending 'boot.img' (83552 KB)  OKAY [1.890s]
  Booting                        OKAY [10.108s]
```

15 s 后 SSH 可达（usb0 192.168.7.1）。initramfs 阶段 dmesg（**本轮的核心判据**）：

```
[    7.714240] [init] disk root requested: LABEL=linux17
[    7.925555] [init] resolved LABEL=linux17 -> /dev/sda17
[    7.926427] [init] root fstype: ext4          ← 新逻辑：blkid -o value -s TYPE
[    8.159232] [init] switching root to /dev/sda17 (/init)
```

盘根起来后的验收：

| 判据 | 结果 |
|---|---|
| `uname -r` | `7.3.0-rc7-debug-vk127-00002-g24223e44ad80-dirty`（与在机模块树逐字一致） |
| `findmnt -no FSTYPE /` | `ext4` |
| 桌面 | `pgrep phoc` = 1、`pgrep greetd` = 2 |
| 面板 | `card0-DSI-1` = `connected`，亮度 511 |
| 模块 | `/proc/modules` 46 条，`dmesg | grep -c "version magic"` = **0** |
| 网络 | `usb0` = 192.168.7.1/24 |

复位回盘后（**回退验证**）：

| 判据 | 结果 |
|---|---|
| 盘根 `uname -r` / `findmnt` | 同上 / `ext4` |
| 新 init 标记行数 | **0**（`dmesg | grep -c "root fstype"`）⇒ 确认回到 vk152 的旧 ramdisk |
| 桌面 | `pgrep phoc` = 1 |
| 槽属性 | `boot_b byte6=0x77 retry=6 active=1 succ=1 unbootable=0`（与动手前基线**逐字相同**） |

⇒ **全程零写盘**：`fastboot boot` 不改 boot_b，也没有触发 AB 槽 retry 递减（retry 仍为 6）。

## 3. 顺带修掉的一个工具链 bug（`PITFALLS #398`）

本轮发现 `scripts/build-manifest.sh` 的 `kernel`/`kernel_sha256`/`kernel_image_sha256` 取的是
**工作树的默认产物**（`build/vk151/…/Image.gz`，`ddaa5c38…`），而不是实际 `--kernel` 入参
（镜像里真正的内核 `b6a074ff…`）。已改为「以打包入参为准 + `kernel_identity_source=packed|tree`」，
修复后重打镜像 sha 与修复前**逐字相同**（可复现性成立）。详见 `PITFALLS/sessions/87-*.md`。

## 4. 这意味着什么（对两条迁移路线）

- **f2fs**：唯一代码阻断项解除。剩下的都是「数据搬迁 + 一次格式化」，不再需要改 `/init`。
  下一步是主机侧 loop 台架（mkfs/mount/GC/fsck + discard 能力探测）+ 真分区手术。
- **Mobian**：S5「initramfs 通常零改动」升级为**已实测零改动**（Debian 的 `/sbin/init` 会被同一条
  `newinit` 链选中）。因此 S6 的 systemd unit 也已被 `packaging/elden-userland/` 渲染覆盖。
- **G0 之后不要重复做的事**：不要再为「fstype 支持」改 ramdisk；`out/boot-elden-vk162-fstype.img`
  可直接作为后续所有迁移实验的载具（内核=日常线，只多了一条 fstype 探测）。

## 5. 残留与边界

- 本发只验证了 **ext4** 分支（现网根就是 ext4）；f2fs 分支的真机验证要等真正 `mkfs.f2fs` 之后，
  属于 f2fs 路线自己的验收点，不在本报告范围。
- `fastboot boot` 期间失败过一次会标 `slot-unbootable=yes`（`PITFALLS` 记录）；本轮**未出现**，
  且已记录基线，若出现恢复 = `fastboot set_active b`。
- 设备当前状态：Linux、`boot_b`=vk152、root ext4、`slot-attr` 基线未变。
