# Android a 槽首启实测（2026-11-20 11:35–11:50，U2 HA2EXB0E）—— S1 的实测结论

> 目的：按 `reports/android-v3-bringup-packet-20261120.md` 的 S1 纪律（清 BCB → 读回校验 → 才 reset），
> 在 **v1 super** 在机的状态下实测一次 a 槽启动，用来判定「11-19 那 3 发未进桌面」里有多少是 BCB 污染。
> 结论一句话：**不是 BCB 单独能解释的——a 槽仍被判失败并由 ABL 回落到 b 槽（Linux）**，同时本轮**发现一个此前没登记的前置条件**：
> `boot_a` 的 GPT 属性长期是 `unbootable=1 / retry=0`（PITFALLS #672 的同一个坑），11-19 三次上机很可能从一开始就没被 ABL 认真启动过。

## 1. 起始现态（实测，不是文档抄写）

| 项 | 值 | 命令 |
|---|---|---|
| 运行系统 | Debian 13 / 内核 `7.3.1-debug-vk189-suspend-00005-g4bdf1711b5c0`，up 12:50 | `ssh root@192.168.7.1 uname -r; uptime` |
| 桌面 | `graphical.target` active、`greetd` active、`deploy-desktop-shell.sh --check` **MISS=0** | — |
| 槽位 | `qbootctl -a` = **_b**；`_a: Active0 Successful0 Bootable0` | `qbootctl` |
| **boot_a GPT 属性** | `byte6=0x82` ⇒ **retry=0, succ=0, unbootable=1** | `slot-attr.py --device /dev/sde show` |
| super 现态 | **v1**：`blockdev size 23622320128`、`system_a 5296 MiB`、7 个 `_a` 分区 | `super-head512k.bin` → `android-super.py list` |
| BCB（misc 4 KiB） | **全 0** | `dd if=/dev/disk/by-partlabel/misc bs=4096 count=1` → python 统计 |

件归档：`logs/device-s1-113527/`（`lun4-gpt-primary.bin` 17408 B、`lun4-gpt-backup.bin` 16896 B、`logfs.bin` 8 MiB、
`pre-reboot.txt`、`cleanup.txt`）。

## 2. 本轮动作（全部有读回）

1. **修 boot_a 属性**：`slot-attr.py set a --retry 7 --no-unbootable --successful` ⇒ 主备两表 `byte6 0x82 → 0x7a`，
   写入后 CRC 重算 + 读回校验（脚本自带）。`qbootctl` 侧 `_a: Bootable 1`。
2. **切 active**：`qbootctl -s a`（`-a` 是只读查询；设置用 `-s SLOT`）。
3. **清 BCB**：`dd if=/dev/zero of=/dev/disk/by-partlabel/misc bs=4096 count=1 conv=fsync` ⇒ 读回 16 KiB **nonzero=0**。
4. `sync; reboot`（active = a）。

## 3. 结果（时序）

| 时刻 | 现象 |
|---|---|
| 11:36:46 | reset |
| 11:36:54 – 11:39:27 | **主机侧 60 s 内无任何 USB 枚举**（`lsusb` 无 `05c6/18d1`，`fastboot devices` 空，`adb devices` 只有别的手机） |
| ~11:38:4x | 主机出现 `1d6b:0104 Multifunction Composite Gadget` + `enx021e5eede102` |
| 11:39:45 | `ssh root@192.168.7.1` 通：**Linux 已起，up 1 min**；`qbootctl -a` = **_b** |
| 11:39:5x | `_a: Active0 Successful0 Bootable0` ⇒ **又回到不可启**；BCB（misc）= **`boot-recovery`**（nonzero 71） |

**即：a 槽这一发没有进 Android，被判定失败后 ABL 回落 b 槽（Linux），并把 a 槽重新标 unbootable、把 BCB 写成 `boot-recovery`。**

### 3.1 失败发生在哪一层（证据）

- `logfs`（LUN4 `sde68`，8 MiB）里 `Shutting Down UEFI Boot Services` 共 **10 条**，最后一条 **13311 ms**，
  与 11-19 三发（13302 / 13307 / 13263 ms）同族 ⇒ ABL 侧走完了「载入 Android 内核 → ExitBootServices」，
  **失败在 EBS 之后**（内核/init 阶段），不是 ABL 拒启、也不是签校验失败。
- `pstoredump`（LUN0 `sda15`，128 MiB，本轮取前 64 MiB）：**可打印字符 0、`panic|oops|ramoops|watchdog|reset` 全 0 命中**
  ⇒ 拿不到内核崩溃文本（该区没被写入）。**所以「内核崩溃」目前是推断，不是取证。**
- 本轮**没有**新 logfs 条目增量证据（logfs 是环形日志，10 条计数不变，不能据此断言第二次也走了 a）。

## 4. 结论与对后续动作的影响

1. **BCB confound 不再能解释全部**：BCB 清 0 + boot_a 属性修好之后，a 槽仍然失败并回落。
   ⇒ 11-19 的「2 发被 BCB 污染」这一条**仍然成立**（那两次确实带着污染启动），但**「污染是唯一原因」不再成立**。
2. **新登记的前置条件（PITFALLS 待补）**：`boot_a` 会被 ABL 在上一次失败后写成 `unbootable=1 / retry=0`；
   **每次上机前必须显式复位这个属性**（`slot-attr.py set a --retry 7 --no-unbootable --successful`），
   否则「起不来」既可能是镜像问题、也可能是 ABL 直接跳过 a 槽。`slot-attr.py` 是唯一可靠读法（`qbootctl` 只报 Bootable 0/1）。
3. **下一步顺序（本报告给的建议）**：
   - S2（回写原厂 `metadata.img`，29 MiB，几分钟）——排除 H4「metadata 被 erase + super 声明 virtual-ab」。
   - S3（原厂 `super` 14.54 GiB 对照）——若 S3 也失败，则**问题不在 super 内容**，而在 a 槽链（vbmeta/init_boot/vendor_boot/userdata）。
   - S5 依赖 `boot-img-cmdline.py` 的 v4 支持（P0-4）才能拿 `console=ttyGS0` 日志；**没有它，Android 侧失败永远是黑盒**。
4. **设备已复原**（11:49，实测）：`active=_b`（Linux）、`boot_a byte6=0x7a`（retry7/bootable）、**BCB 全 0**、`graphical.target` active。

## 5. 复现命令

```sh
# 只读现态
ssh root@192.168.7.1 'qbootctl -a; dd if=/dev/disk/by-partlabel/misc bs=4096 count=1 | md5sum'
scp scripts/slot-attr.py scripts/partlun.py root@192.168.7.1:/tmp/
ssh root@192.168.7.1 'python3 /tmp/slot-attr.py --allow-wrong-lun --device /dev/sde show | grep boot_a'
# 复位 + 上机（会离开 Linux）
ssh root@192.168.7.1 'python3 /tmp/slot-attr.py --allow-wrong-lun --device /dev/sde set a --retry 7 --no-unbootable --successful; qbootctl -s a; dd if=/dev/zero of=/dev/disk/by-partlabel/misc bs=4096 count=1 conv=fsync; sync; reboot'
```
